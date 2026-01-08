//
//  IELTSVocabularyTranslator.swift
//  LexiconFlow
//
//  Created by Claude on 2025-01-08.
//  Copyright © 2025 LexiconFlow. All rights reserved.
//

import Foundation
import OSLog

/// Translates IELTS vocabulary from English to Russian using on-device translation.
@MainActor
final class IELTSVocabularyTranslator {
    private let translationService = OnDeviceTranslationService.shared
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "IELTSVocabulary")

    // MARK: - Data Structures

    /// Vocabulary entry from JSON
    struct VocabularyEntry: Codable, Sendable {
        let word: String
        let partOfSpeech: String
        let cefrLevel: String
        var phonetic: String
        var definition: String
        var exampleSentence: String
        var russianTranslation: String
    }

    /// Vocabulary metadata from JSON
    struct VocabularyMetadata: Codable, Sendable {
        let title: String
        let version: String
        let source: String
        let targetLanguage: String
        let totalWords: Int
        let cefrDistribution: [String: Int]
    }

    /// Complete vocabulary structure
    struct IELTSVocabulary: Codable, Sendable {
        let metadata: VocabularyMetadata
        var vocabulary: [VocabularyEntry]
    }

    /// Translation result
    struct TranslationResult: Sendable {
        let successCount: Int
        let failedCount: Int
        let totalCount: Int
        let duration: TimeInterval
        let errors: [TranslationError]

        var isSuccess: Bool {
            failedCount == 0
        }

        var successRate: Double {
            guard totalCount > 0 else { return 0 }
            return Double(successCount) / Double(totalCount)
        }
    }

    /// Translation error
    struct TranslationError: Error, Sendable {
        let word: String
        let cefrLevel: String
        let underlyingError: Error

        var localizedDescription: String {
            "Failed to translate '\(word)' [\(cefrLevel)]: \(underlyingError.localizedDescription)"
        }
    }

    /// Progress during translation
    struct Progress: Sendable {
        let currentWord: String
        let currentLevel: String
        let completedCount: Int
        let totalCount: Int
        let currentBatch: Int
        let totalBatches: Int

        var fractionCompleted: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        var percentageCompleted: Int {
            Int(fractionCompleted * 100)
        }

        var description: String {
            "\(currentWord) [\(currentLevel)] - \(percentageCompleted)% (\(completedCount)/\(totalCount))"
        }
    }

    // MARK: - Translation

    // swiftlint:disable function_body_length
    /// Translates all vocabulary entries to Russian.
    ///
    /// - Parameters:
    ///   - batchSize: Number of words to translate concurrently (default: 5)
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Translation result with success/failure counts
    func translateVocabulary(
        batchSize: Int = 5,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> TranslationResult {
        logger.info("Starting IELTS vocabulary translation")

        let startTime = Date()

        // Load vocabulary from bundle
        guard let url = Bundle.main.url(forResource: "IELTS/ielts_vocabulary_for_translation", withExtension: "json") else {
            logger.error("Vocabulary file not found in bundle")
            throw VocabularyError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        var vocabulary = try JSONDecoder().decode(IELTSVocabulary.self, from: data)

        logger.info("Loaded \(vocabulary.vocabulary.count) words for translation")

        // Configure translation service
        await translationService.setLanguages(source: "en", target: "ru")

        // Check if Russian language pack is available
        let needsDownload = await translationService.needsLanguageDownload("ru")
        if needsDownload {
            logger.warning("Russian language pack not downloaded")
            throw VocabularyError.languagePackNotDownloaded
        }

        // Group words by CEFR level for better progress tracking
        let wordsByLevel = Dictionary(grouping: vocabulary.vocabulary) { $0.cefrLevel }

        var allErrors: [TranslationError] = []
        var totalSuccess = 0
        var totalFailed = 0
        var completedCount = 0

        // Process each level
        for level in ["A1", "A2", "B1", "B2", "C1", "C2"] {
            guard let words = wordsByLevel[level] else { continue }

            logger.info("Processing \(level): \(words.count) words")

            // Translate words in batches
            for batchStart in stride(from: 0, to: words.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, words.count)
                let batch = Array(words[batchStart ..< batchEnd])

                // Translate batch
                let textsToTranslate = batch.map(\.word)
                let batchNumber = (batchStart / batchSize) + 1
                let totalBatches = (words.count + batchSize - 1) / batchSize

                do {
                    let result = try await translationService.translateBatch(
                        textsToTranslate,
                        maxConcurrency: batchSize
                    )

                    // Update vocabulary with translations
                    for (index, translation) in result.successfulTranslations.enumerated() {
                        let wordIndex = batchStart + index
                        if wordIndex < vocabulary.vocabulary.count {
                            vocabulary.vocabulary[wordIndex].russianTranslation = translation.translatedText
                            totalSuccess += 1
                        }
                    }

                    // Track errors - mark non-successful words as failed
                    let successfulWords = Set(result.successfulTranslations.map(\.sourceText))
                    for (index, word) in textsToTranslate.enumerated() where !successfulWords.contains(word) {
                        let wordIndex = batchStart + index
                        if wordIndex < vocabulary.vocabulary.count {
                            let entry = vocabulary.vocabulary[wordIndex]
                            let translationError = TranslationError(
                                word: entry.word,
                                cefrLevel: entry.cefrLevel,
                                underlyingError: result.errors.first ?? OnDeviceTranslationError.translationFailed(
                                    reason: "Unknown error"
                                )
                            )
                            allErrors.append(translationError)
                            totalFailed += 1
                        }
                    }

                    // Update progress
                    completedCount += batch.count
                    let progress = Progress(
                        currentWord: batch.last?.word ?? "",
                        currentLevel: level,
                        completedCount: completedCount,
                        totalCount: vocabulary.vocabulary.count,
                        currentBatch: batchNumber,
                        totalBatches: totalBatches
                    )
                    progressHandler?(progress)

                    logger.info("Progress: \(progress.description)")

                } catch {
                    logger.error("Batch translation failed: \(error.localizedDescription)")

                    // Mark all words in batch as failed
                    for entry in batch {
                        let translationError = TranslationError(
                            word: entry.word,
                            cefrLevel: entry.cefrLevel,
                            underlyingError: error
                        )
                        allErrors.append(translationError)
                        totalFailed += 1
                    }
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Save translated vocabulary
        try saveTranslatedVocabulary(vocabulary)

        let result = TranslationResult(
            successCount: totalSuccess,
            failedCount: totalFailed,
            totalCount: vocabulary.vocabulary.count,
            duration: duration,
            errors: allErrors
        )

        logger.info("""
        Translation complete:
        - Success: \(result.successCount)
        - Failed: \(result.failedCount)
        - Duration: \(String(format: "%.2f", duration))s
        - Success rate: \(String(format: "%.1f", result.successRate * 100))%
        """)

        return result
    } // swiftlint:enable function_body_length

    // MARK: - Save

    private func saveTranslatedVocabulary(_ vocabulary: IELTSVocabulary) throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsURL.appendingPathComponent("ielts_vocabulary_translated.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(vocabulary)
        try data.write(to: outputURL)

        logger.info("Saved translated vocabulary to: \(outputURL.path)")
    }

    // MARK: - Errors

    enum VocabularyError: LocalizedError {
        case fileNotFound
        case invalidFormat
        case languagePackNotDownloaded
        case translationFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                "Vocabulary file not found in bundle"
            case .invalidFormat:
                "Invalid vocabulary file format"
            case .languagePackNotDownloaded:
                "Russian language pack not downloaded. Please download it in Settings."
            case .translationFailed:
                "Translation failed"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .fileNotFound:
                "Ensure ielts_vocabulary_for_translation.json is in the IELTS resources folder"
            case .invalidFormat:
                "Check that the JSON file matches the expected schema"
            case .languagePackNotDownloaded:
                "Go to Settings → Translation and download the Russian language pack"
            case .translationFailed:
                "Check your internet connection and try again"
            }
        }
    }
}
