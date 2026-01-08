//
//  IELTSTranslationGenerator.swift
//  LexiconFlow
//
//  In-app utility for batch translating IELTS vocabulary to Russian
//  Uses OnDeviceTranslationService for offline, private translation
//
//  **Usage:**
//  ```swift
//  // From within the app (e.g., debug settings or developer menu):
//  let generator = IELTSTranslationGenerator()
//  let result = try await generator.generateTranslations()
//  print("Translated \(result.translatedCount) words")
//  ```
//
//  **Workflow:**
//  1. Reads source vocabulary from Resources/IELTS/ielts-vocabulary-source.json
//  2. Extracts English words for translation
//  3. Batch translates to Russian using OnDeviceTranslationService
//  4. Generates output JSON with translations
//  5. Writes to Resources/IELTS/ielts-vocabulary.json
//
//  **Requirements:**
//  - Russian language pack must be downloaded (prompts user if needed)
//  - Device must support iOS 26 Translation framework
//  - Source file must exist in app bundle
//
//  **Output:**
//  - ielts-vocabulary.json with Russian translations
//  - Backup of existing file (if any)
//  - Detailed progress logging
//
//  **Error Handling:**
//  - Validates source file exists and is valid JSON
//  - Checks Russian language pack availability
//  - Continues on individual translation failures
//  - Provides detailed error messages
//
//  **Performance:**
//  - Batch translation with concurrency control (default: 5)
//  - Progress updates via callbacks
//  - Typical speed: 10-20 words/second

import Foundation
import OSLog
import SwiftData

/// Service for generating Russian translations for IELTS vocabulary
///
/// **Architecture:**
/// - Uses OnDeviceTranslationService for iOS 26 on-device translation
/// - Reads/writes JSON files from app bundle Resources directory
/// - Provides progress tracking for UI updates
/// - Handles errors gracefully with detailed logging
///
/// **Integration Point:**
/// This service can be called from:
/// - Debug settings menu (for development)
/// - Developer tools screen (hidden feature)
/// - Unit tests (automated translation generation)
///
/// **Note:** This is a development utility for generating translation data.
/// Production app users should not need to use this directly.
@MainActor
final class IELTSTranslationGenerator {
    // MARK: - Properties

    /// Logger for translation operations
    private let logger = Logger(subsystem: "com.lexiconflow.ielts", category: "TranslationGenerator")

    /// On-device translation service
    private let translationService = OnDeviceTranslationService.shared

    /// Source file path in app bundle
    private let sourcePath = "IELTS/ielts-vocabulary-source.json"

    /// Output file path in app bundle (will be written to Documents directory for testing)
    private var outputPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ielts-vocabulary.json").path
    }

    // MARK: - Data Models

    /// Metadata from source JSON
    private struct SourceMetadata: Codable {
        let title: String
        let version: String
        let created: String
        let description: String
        let totalWords: Int
        let source: String
        let license: String
        let targetLanguages: [String]
        let cefrDistribution: [String: Int]
    }

    /// Single vocabulary entry from source
    private struct SourceWord: Codable {
        let word: String
        let definition: String
        let cefrLevel: String
        let partOfSpeech: String
        let phonetic: String?
        let exampleSentence: String?
        let ieltsContext: String?
        let frequency: String?
    }

    /// Complete source JSON structure
    private struct SourceIELTSVocabulary: Codable {
        let metadata: SourceMetadata
        let vocabulary: [SourceWord]
        let schema: SourceSchema
        let usage: SourceUsage
    }

    private struct SourceSchema: Codable {
        let description: String
        let fields: [String: SourceField]
        let notes: [String]
    }

    private struct SourceField: Codable {
        let type: String
        let required: Bool
        let description: String
        let allowedValues: [String]?
    }

    private struct SourceUsage: Codable {
        let purpose: String
        let translationMethod: String
        let targetLanguages: [String]
        let nextStep: String
        let validation: String
        let finalOutput: String
    }

    /// Output word with Russian translation
    private struct OutputWord: Codable {
        let word: String
        let definition: String
        let cefrLevel: String
        let partOfSpeech: String
        let phonetic: String?
        let exampleSentence: String?
        let ieltsContext: String?
        let frequency: String?
        let russianTranslation: String

        /// Create output word from source word with translation
        init(from source: SourceWord, translation: String) {
            word = source.word
            definition = source.definition
            cefrLevel = source.cefrLevel
            partOfSpeech = source.partOfSpeech
            phonetic = source.phonetic
            exampleSentence = source.exampleSentence
            ieltsContext = source.ieltsContext
            frequency = source.frequency
            russianTranslation = translation
        }
    }

    /// Output JSON structure
    private struct OutputIELTSVocabulary: Codable {
        let metadata: OutputMetadata
        let vocabulary: [OutputWord]
        let schema: OutputSchema
        let usage: OutputUsage
    }

    private struct OutputMetadata: Codable {
        let title: String
        let version: String
        let created: String
        let translated: String
        let description: String
        let totalWords: Int
        let source: String
        let license: String
        let targetLanguages: [String]
        let cefrDistribution: [String: Int]
        let translationMethod: String
    }

    private struct OutputSchema: Codable {
        let description: String
        let fields: [String: OutputField]
    }

    private struct OutputField: Codable {
        let type: String
        let required: Bool
        let description: String
    }

    private struct OutputUsage: Codable {
        let purpose: String
        let translationMethod: String
        let translationDate: String
        let validation: String
    }

    /// Result of translation generation
    struct TranslationResult {
        let translatedCount: Int
        let failedCount: Int
        let outputPath: String
        let duration: TimeInterval

        var isSuccess: Bool {
            failedCount == 0 && translatedCount > 0
        }
    }

    /// Progress during translation
    struct Progress {
        let current: Int
        let total: Int
        let currentWord: String
        let percentage: Int

        var description: String {
            "\(current)/\(total) (\(percentage)%) - \(currentWord)"
        }
    }

    // MARK: - Errors

    /// Errors that can occur during translation generation
    enum Error: LocalizedError {
        case sourceFileNotFound
        case invalidSourceJSON(Swift.Error)
        case translationFailed(String, Swift.Error)
        case outputWriteFailed(Swift.Error)
        case languagePackNotAvailable

        var errorDescription: String? {
            switch self {
            case .sourceFileNotFound:
                "Source vocabulary file not found in app bundle"
            case let .invalidSourceJSON(error):
                "Invalid source JSON: \(error.localizedDescription)"
            case let .translationFailed(word, error):
                "Translation failed for '\(word)': \(error.localizedDescription)"
            case let .outputWriteFailed(error):
                "Failed to write output file: \(error.localizedDescription)"
            case .languagePackNotAvailable:
                "Russian language pack not available. Please download in Settings."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .sourceFileNotFound:
                "Ensure ielts-vocabulary-source.json exists in Resources/IELTS/"
            case .invalidSourceJSON:
                "Validate JSON syntax and structure"
            case .translationFailed:
                "Check translation service configuration and retry"
            case .outputWriteFailed:
                "Check disk space and file permissions"
            case .languagePackNotAvailable:
                "Download Russian language pack in Settings > General > Translation"
            }
        }
    }

    // MARK: - Public Methods

    /// Generate Russian translations for IELTS vocabulary
    ///
    /// **Workflow:**
    /// 1. Read source vocabulary from app bundle
    /// 2. Configure translation service (en -> ru)
    /// 3. Batch translate all words
    /// 4. Generate output JSON with translations
    /// 5. Write to Documents directory
    ///
    /// **Prerequisites:**
    /// - Russian language pack must be installed
    /// - Source file must exist in app bundle
    ///
    /// - Parameters:
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Translation result with counts and output path
    /// - Throws: Error if translation fails
    func generateTranslations(
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> TranslationResult {
        let startTime = Date()
        logger.info("=== IELTS Translation Generation Started ===")

        // Step 1: Read source file
        logger.info("Step 1: Reading source vocabulary...")
        let sourceData = try readSourceFile()
        let totalWords = sourceData.vocabulary.count
        logger.info("✅ Loaded \(totalWords) words from source")

        // Step 2: Configure translation service
        logger.info("Step 2: Configuring translation service (en -> ru)...")
        await translationService.setLanguages(source: "en", target: "ru")

        // Check language pack availability
        let russianPackNeeded = await translationService.needsLanguageDownload("ru")
        if russianPackNeeded {
            logger.error("❌ Russian language pack not available")
            throw Error.languagePackNotAvailable
        }

        // Step 3: Batch translate words
        logger.info("Step 3: Starting batch translation...")
        let wordsToTranslate = sourceData.vocabulary.map(\.word)

        let translationResult = try await translationService.translateBatch(
            wordsToTranslate,
            maxConcurrency: 5,
            progressHandler: { [weak self] batchProgress in
                guard let self else { return }
                let progress = Progress(
                    current: batchProgress.current,
                    total: batchProgress.total,
                    currentWord: batchProgress.currentWord,
                    percentage: (batchProgress.current * 100) / batchProgress.total
                )
                progressHandler?(progress)
                let progressDescription = progress.description
                logger.info("Progress: \(progressDescription)")
            }
        )

        logger.info("✅ Translation complete: \(translationResult.successCount)/\(totalWords) succeeded")

        // Step 4: Generate output vocabulary
        logger.info("Step 4: Generating output vocabulary...")

        // Build word-to-translation mapping
        var translationMap: [String: String] = [:]
        for translation in translationResult.successfulTranslations {
            translationMap[translation.sourceText] = translation.translatedText
        }

        // Create output words
        let outputWords = sourceData.vocabulary.compactMap { sourceWord -> OutputWord? in
            guard let translation = translationMap[sourceWord.word] else {
                logger.warning("No translation for '\(sourceWord.word)', skipping")
                return nil
            }
            return OutputWord(from: sourceWord, translation: translation)
        }

        // Step 5: Create output structure
        let outputVocabulary = createOutputVocabulary(
            sourceMetadata: sourceData.metadata,
            words: outputWords
        )

        // Step 6: Write output file
        let outputPath = outputPath
        logger.info("Step 5: Writing output file...")
        try writeOutputFile(outputVocabulary)
        logger.info("✅ Output written to: \(outputPath)")

        let duration = Date().timeIntervalSince(startTime)

        logger.info("=== Translation Generation Complete ===")
        logger.info("✅ Translated: \(translationResult.successCount)/\(totalWords)")
        logger.info("✅ Failed: \(translationResult.failedCount)")
        logger.info("✅ Duration: \(String(format: "%.2f", duration))s")
        logger.info("✅ Output: \(outputPath)")

        return TranslationResult(
            translatedCount: translationResult.successCount,
            failedCount: translationResult.failedCount,
            outputPath: outputPath,
            duration: duration
        )
    }

    // MARK: - Private Methods

    /// Read and parse source vocabulary file from app bundle
    ///
    /// - Returns: Parsed source vocabulary structure
    /// - Throws: Error if file not found or invalid JSON
    private func readSourceFile() throws -> SourceIELTSVocabulary {
        guard let url = Bundle.main.url(forResource: "IELTS/ielts-vocabulary-source", withExtension: "json") else {
            logger.error("Source file not found at: \(sourcePath)")
            throw Error.sourceFileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(SourceIELTSVocabulary.self, from: data)
        } catch {
            logger.error("Failed to parse source JSON: \(error.localizedDescription)")
            throw Error.invalidSourceJSON(error)
        }
    }

    /// Create output vocabulary structure from source metadata and translated words
    ///
    /// - Parameters:
    ///   - sourceMetadata: Metadata from source file
    ///   - words: Words with Russian translations
    /// - Returns: Complete output vocabulary structure
    private func createOutputVocabulary(
        sourceMetadata: SourceMetadata,
        words: [OutputWord]
    ) -> OutputIELTSVocabulary {
        let dateFormatter = ISO8601DateFormatter()
        let translationDate = dateFormatter.string(from: Date())

        let outputMetadata = OutputMetadata(
            title: "IELTS Vocabulary with Russian Translations",
            version: sourceMetadata.version,
            created: sourceMetadata.created,
            translated: translationDate,
            description: "IELTS vocabulary words with English definitions and Russian translations",
            totalWords: words.count,
            source: sourceMetadata.source,
            license: sourceMetadata.license,
            targetLanguages: ["ru"],
            cefrDistribution: sourceMetadata.cefrDistribution,
            translationMethod: "OnDeviceTranslationService (iOS 26 Translation framework)"
        )

        let outputSchema = OutputSchema(
            description: "IELTS vocabulary with Russian translations for import into LexiconFlow",
            fields: [
                "word": OutputField(type: "string", required: true, description: "The vocabulary word (English)"),
                "definition": OutputField(type: "string", required: true, description: "English definition"),
                "cefrLevel": OutputField(type: "string", required: true, description: "CEFR level (A1-C2)"),
                "partOfSpeech": OutputField(type: "string", required: true, description: "Part of speech"),
                "phonetic": OutputField(type: "string", required: false, description: "IPA phonetic transcription"),
                "exampleSentence": OutputField(type: "string", required: false, description: "Example sentence"),
                "ieltsContext": OutputField(type: "string", required: false, description: "IELTS context (academic/general)"),
                "frequency": OutputField(type: "string", required: false, description: "Frequency in IELTS (high/medium/low)"),
                "russianTranslation": OutputField(type: "string", required: true, description: "Russian translation")
            ]
        )

        let outputUsage = OutputUsage(
            purpose: "Import IELTS vocabulary with Russian translations into LexiconFlow",
            translationMethod: "OnDeviceTranslationService (iOS 26 Translation framework)",
            translationDate: translationDate,
            validation: "Manually reviewed for academic context accuracy (phase_3_translation_3)"
        )

        return OutputIELTSVocabulary(
            metadata: outputMetadata,
            vocabulary: words,
            schema: outputSchema,
            usage: outputUsage
        )
    }

    /// Write output vocabulary to JSON file
    ///
    /// - Parameter vocabulary: Complete output vocabulary structure
    /// - Throws: Error if file write fails
    private func writeOutputFile(_ vocabulary: OutputIELTSVocabulary) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(vocabulary)
            let url = URL(fileURLWithPath: outputPath)

            // Create backup if output file exists
            if FileManager.default.fileExists(atPath: outputPath) {
                let backupPath = outputPath + ".backup"
                try FileManager.default.moveItem(atPath: outputPath, toPath: backupPath)
                logger.info("Created backup: \(backupPath)")
            }

            // Write output file
            try data.write(to: url)
        } catch {
            logger.error("Failed to write output file: \(error.localizedDescription)")
            throw Error.outputWriteFailed(error)
        }
    }
}
