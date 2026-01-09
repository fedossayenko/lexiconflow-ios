//
//  IELTSVocabularyImporter.swift
//  LexiconFlow
//
//  Created by Claude on 2025-01-08.
//  Copyright © 2025 LexiconFlow. All rights reserved.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Progress Counter Actor

/// Actor-isolated progress counter for Swift 6 strict concurrency compliance.
///
/// **Why This Exists**: Swift 6 prohibits mutation of captured variables in @Sendable closures.
/// This actor provides thread-safe progress tracking without data races.
///
/// **Performance**: Actor isolation is fast (minimal overhead) and prevents data races.
private actor ProgressCounter {
    private var _value: Int = 0

    var value: Int { self._value }

    func set(_ newValue: Int) {
        self._value = newValue
    }

    func increment(by: Int = 1) {
        self._value += by
    }
}

/// Imports IELTS vocabulary from JSON into SwiftData.
///
/// **Data Source**: SMARTool Dataset (CC-BY 4.0)
/// - Janda, Laura A. and Francis M. Tyers. 2021.
/// - DOI: https://doi.org/10.18710/QNAPNE
///
/// **Usage**:
/// ```swift
/// let importer = IELTSVocabularyImporter(modelContext: context)
/// let result = try await importer.importAllVocabulary()
/// print("Imported: \(result.importedCount) words")
/// ```
@MainActor
final class IELTSVocabularyImporter {
    /// Logger for import operations
    private let logger = Logger(subsystem: "com.lexiconflow.ielts", category: "VocabularyImporter")

    /// The model context for data operations
    private let modelContext: ModelContext

    /// Deck manager for creating/getting IELTS decks
    private let deckManager: IELTSDeckManager

    /// Data importer for creating flashcards
    private let dataImporter: DataImporter

    /// Initialize with dependencies
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - deckManager: Optional custom deck manager (defaults to new instance)
    ///   - dataImporter: Optional custom data importer (defaults to new instance)
    init(
        modelContext: ModelContext,
        deckManager: IELTSDeckManager? = nil,
        dataImporter: DataImporter? = nil
    ) {
        self.modelContext = modelContext
        self.deckManager = deckManager ?? IELTSDeckManager(modelContext: modelContext)
        self.dataImporter = dataImporter ?? DataImporter(modelContext: modelContext)
    }

    // MARK: - Validation Constants

    /// Security validation limits for bundle resources
    ///
    /// **Note:** Bundle resources are trusted, but size limits prevent
    /// accidental inclusion of oversized files during development.
    private enum ValidationLimits {
        /// Maximum file size: 10MB for JSON vocabulary files
        /// Based on typical IELTS vocabulary file size (~500KB)
        static let maxJSONFileSize: UInt64 = 10_000_000
    }

    // MARK: - Data Structures

    /// Vocabulary entry from JSON
    struct VocabularyEntry: Codable, Sendable {
        let word: String
        let partOfSpeech: String
        let cefrLevel: String
        let phonetic: String
        let definition: String
        let exampleSentence: String
        let russianTranslation: String
    }

    /// Vocabulary metadata from JSON
    struct VocabularyMetadata: Codable, Sendable {
        let title: String
        let version: String
        let source: String
        let targetLanguage: String
        let totalWords: Int
        let cefrDistribution: [String: Int]
        let license: String?
        let doi: String?
        let citation: String?
    }

    /// Complete vocabulary structure
    struct IELTSVocabulary: Codable, Sendable {
        let metadata: VocabularyMetadata
        let vocabulary: [VocabularyEntry]
    }

    /// Import result
    struct ImportResult: Sendable {
        let importedCount: Int
        let failedCount: Int
        let duration: TimeInterval
        let levelResults: [String: LevelResult]

        var totalWords: Int {
            self.importedCount + self.failedCount
        }

        var successRate: Double {
            guard self.totalWords > 0 else { return 0 }
            return Double(self.importedCount) / Double(self.totalWords)
        }
    }

    /// Result for a single CEFR level
    struct LevelResult: Sendable {
        let level: String
        let importedCount: Int
        let failedCount: Int
        let deckName: String
    }

    /// Import progress
    struct Progress: Sendable {
        let currentWord: String
        let currentLevel: String
        let currentLevelProgress: Int
        let currentLevelTotal: Int
        let overallProgress: Int
        let overallTotal: Int

        var percentageCompleted: Int {
            guard self.overallTotal > 0 else { return 0 }
            return (self.overallProgress * 100) / self.overallTotal
        }

        var description: String {
            "\(self.currentWord) [\(self.currentLevel)] - \(self.percentageCompleted)% (\(self.overallProgress)/\(self.overallTotal))"
        }
    }

    // MARK: - Validation

    /// Validate bundle resource file before loading
    ///
    /// **Security:** Bundle resources are trusted, but we validate:
    /// - File size (prevents accidental inclusion of oversized files)
    ///
    /// - Parameter url: The bundle resource URL
    /// - Throws: IELTSImportError if validation fails
    private func validateBundleFile(_ url: URL) throws {
        // Check file attributes
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        guard let fileSize = values.fileSize, let isDirectory = values.isDirectory else {
            throw IELTSImportError.importFailed("Cannot read file attributes")
        }

        // Ensure it's a file, not a directory
        guard !isDirectory else {
            throw IELTSImportError.importFailed("Expected file, found directory")
        }

        // Check file size
        guard UInt64(fileSize) <= ValidationLimits.maxJSONFileSize else {
            throw IELTSImportError.importFailed(
                "File too large: \(fileSize) bytes (max: \(ValidationLimits.maxJSONFileSize) bytes)"
            )
        }
    }

    // MARK: - Import Methods

    /// Import all IELTS vocabulary from JSON file in bundle.
    ///
    /// **Workflow**:
    /// 1. Load vocabulary from `ielts-vocabulary-smartool.json` in bundle
    /// 2. Group words by CEFR level
    /// 3. Create/get deck for each level
    /// 4. Import words into respective decks
    /// 5. Return aggregate result
    ///
    /// - Parameter progressHandler: Optional callback for progress updates
    /// - Returns: Import result with counts and statistics
    /// - Throws: IELTSImportError if loading or importing fails
    func importAllVocabulary(
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> ImportResult {
        let startTime = Date()
        self.logger.info("=== Starting IELTS Vocabulary Import ===")

        // Step 1: Load vocabulary from bundle
        guard let url = Bundle.main.url(
            forResource: "Resources/IELTS/ielts-vocabulary-smartool",
            withExtension: "json"
        ) else {
            self.logger.error("Vocabulary file not found in bundle")
            throw IELTSImportError.fileNotFound
        }

        self.logger.info("Loading vocabulary from: \(url.path)")

        // Validate file before loading
        try validateBundleFile(url)

        let data = try Data(contentsOf: url)
        let vocabulary = try JSONDecoder().decode(IELTSVocabulary.self, from: data)

        self.logger.info("""
        ✅ Loaded \(vocabulary.vocabulary.count) words
        Source: \(vocabulary.metadata.source)
        License: \(vocabulary.metadata.license ?? "Unknown")
        """)

        // Step 2: Group by CEFR level
        let wordsByLevel = Dictionary(grouping: vocabulary.vocabulary) { $0.cefrLevel }
        self.logger.info("Vocabulary grouped by CEFR level")

        // Step 3: Import each level
        var levelResults: [String: LevelResult] = [:]
        var totalImported = 0
        var totalFailed = 0

        // Swift 6 compliance: Use actor-isolated counter instead of mutable capture
        let counter = ProgressCounter()

        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

        for level in levels {
            guard let words = wordsByLevel[level], !words.isEmpty else {
                self.logger.info("No words found for level \(level)")
                continue
            }

            self.logger.info("Processing level \(level): \(words.count) words")

            do {
                // Get or create deck for this level
                let deck = try deckManager.getDeck(for: level)

                // Convert to FlashcardData
                let flashcardData = words.compactMap { entry -> FlashcardData? in
                    // Skip entries without required fields
                    guard !entry.word.isEmpty, !entry.russianTranslation.isEmpty else {
                        return nil
                    }

                    // Combine definition and example sentence for context
                    var definition = entry.definition
                    if !entry.exampleSentence.isEmpty {
                        if definition.isEmpty {
                            definition = "Example: \(entry.exampleSentence)"
                        } else {
                            definition = "\(definition)\n\nExample: \(entry.exampleSentence)"
                        }
                    }

                    // Fallback to Russian translation if definition is still empty
                    if definition.isEmpty {
                        definition = "Russian translation: \(entry.russianTranslation)"
                    }

                    return FlashcardData(
                        word: entry.word,
                        definition: definition,
                        phonetic: entry.phonetic.isEmpty ? nil : entry.phonetic,
                        imageData: nil,
                        cefrLevel: entry.cefrLevel,
                        russianTranslation: entry.russianTranslation
                    )
                }

                // Import with progress tracking
                let result = await dataImporter.importCards(
                    flashcardData,
                    into: deck,
                    batchSize: 100,
                    progressHandler: { progress in
                        // Swift 6 compliance: Update actor-isolated counter
                        Task { await counter.set(progress.current) }

                        let currentProgress = progress.current
                        let currentTotal = progress.total

                        let importProgress = Progress(
                            currentWord: words[min(currentProgress, words.count) - 1].word,
                            currentLevel: level,
                            currentLevelProgress: currentProgress,
                            currentLevelTotal: currentTotal,
                            overallProgress: currentProgress,
                            overallTotal: vocabulary.vocabulary.count
                        )

                        progressHandler?(importProgress)
                    }
                )

                totalImported += result.importedCount
                totalFailed += result.skippedCount

                levelResults[level] = LevelResult(
                    level: level,
                    importedCount: result.importedCount,
                    failedCount: result.skippedCount,
                    deckName: deck.name
                )

                self.logger.info("""
                ✅ \(level) complete:
                - Imported: \(result.importedCount)
                - Skipped: \(result.skippedCount)
                - Deck: \(deck.name)
                """)

            } catch {
                self.logger.error("Failed to import level \(level): \(error.localizedDescription)")

                levelResults[level] = LevelResult(
                    level: level,
                    importedCount: 0,
                    failedCount: words.count,
                    deckName: self.deckManager.deckName(for: level) ?? "Unknown"
                )

                totalFailed += words.count
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        let result = ImportResult(
            importedCount: totalImported,
            failedCount: totalFailed,
            duration: duration,
            levelResults: levelResults
        )

        self.logger.info("""
        === IELTS Vocabulary Import Complete ===
        Total words: \(result.totalWords)
        Imported: \(result.importedCount)
        Failed: \(result.failedCount)
        Success rate: \(String(format: "%.1f", result.successRate * 100))%
        Duration: \(String(format: "%.2f", duration))s
        """)

        return result
    }

    /// Import a specific CEFR level only.
    ///
    /// **Use Case**: Selective import or re-import of a single level.
    ///
    /// - Parameters:
    ///   - level: CEFR level to import (e.g., "A1", "B2")
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Import result for the specified level
    /// - Throws: IELTSImportError if loading or importing fails
    func importLevel(
        _ level: String,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> ImportResult {
        let startTime = Date()
        self.logger.info("=== Starting IELTS Level \(level) Import ===")

        // Load vocabulary from bundle
        guard let url = Bundle.main.url(
            forResource: "Resources/IELTS/ielts-vocabulary-smartool",
            withExtension: "json"
        ) else {
            self.logger.error("Vocabulary file not found in bundle")
            throw IELTSImportError.fileNotFound
        }

        // Validate file before loading
        try validateBundleFile(url)

        let data = try Data(contentsOf: url)
        let vocabulary = try JSONDecoder().decode(IELTSVocabulary.self, from: data)

        // Filter for specified level
        let words = vocabulary.vocabulary.filter { $0.cefrLevel == level }

        guard !words.isEmpty else {
            self.logger.warning("No words found for level \(level)")
            throw IELTSImportError.emptyLevel(level)
        }

        self.logger.info("Found \(words.count) words for level \(level)")

        // Get or create deck
        let deck = try deckManager.getDeck(for: level)

        // Convert to FlashcardData
        let flashcardData = words.compactMap { entry -> FlashcardData? in
            guard !entry.word.isEmpty, !entry.russianTranslation.isEmpty else {
                return nil
            }

            var definition = entry.definition
            if !entry.exampleSentence.isEmpty {
                if definition.isEmpty {
                    definition = "Example: \(entry.exampleSentence)"
                } else {
                    definition = "\(definition)\n\nExample: \(entry.exampleSentence)"
                }
            }

            if definition.isEmpty {
                definition = "Russian translation: \(entry.russianTranslation)"
            }

            return FlashcardData(
                word: entry.word,
                definition: definition,
                phonetic: entry.phonetic.isEmpty ? nil : entry.phonetic,
                imageData: nil,
                cefrLevel: entry.cefrLevel,
                russianTranslation: entry.russianTranslation
            )
        }

        // Import
        let result = await dataImporter.importCards(
            flashcardData,
            into: deck,
            batchSize: 100,
            progressHandler: { progress in
                let importProgress = Progress(
                    currentWord: words[min(progress.current, words.count) - 1].word,
                    currentLevel: level,
                    currentLevelProgress: progress.current,
                    currentLevelTotal: progress.total,
                    overallProgress: progress.current,
                    overallTotal: progress.total
                )

                progressHandler?(importProgress)
            }
        )

        let duration = Date().timeIntervalSince(startTime)

        return ImportResult(
            importedCount: result.importedCount,
            failedCount: result.skippedCount,
            duration: duration,
            levelResults: [
                level: LevelResult(
                    level: level,
                    importedCount: result.importedCount,
                    failedCount: result.skippedCount,
                    deckName: deck.name
                )
            ]
        )
    }

    /// Check if vocabulary file exists in bundle
    ///
    /// - Returns: true if the file exists, false otherwise
    func vocabularyFileExists() -> Bool {
        Bundle.main.url(
            forResource: "Resources/IELTS/ielts-vocabulary-smartool",
            withExtension: "json"
        ) != nil
    }

    /// Get vocabulary metadata without importing
    ///
    /// - Returns: Vocabulary metadata if file exists
    /// - Throws: IELTSImportError if loading fails
    func getVocabularyMetadata() throws -> VocabularyMetadata {
        guard let url = Bundle.main.url(
            forResource: "Resources/IELTS/ielts-vocabulary-smartool",
            withExtension: "json"
        ) else {
            throw IELTSImportError.fileNotFound
        }

        // Validate file before loading
        try validateBundleFile(url)

        let data = try Data(contentsOf: url)
        let vocabulary = try JSONDecoder().decode(IELTSVocabulary.self, from: data)

        return vocabulary.metadata
    }
}

// MARK: - Import Errors

/// Errors that can occur during import
enum IELTSImportError: LocalizedError, @unchecked Sendable {
    case fileNotFound
    case invalidFormat(String)
    case emptyLevel(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "IELTS vocabulary file not found in bundle"
        case let .invalidFormat(message):
            "Invalid vocabulary format: \(message)"
        case let .emptyLevel(level):
            "No vocabulary found for level \(level)"
        case let .importFailed(message):
            "Import failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            "Ensure ielts-vocabulary-smartool.json is in the IELTS resources folder"
        case .invalidFormat:
            "Check that the JSON file matches the expected schema"
        case .emptyLevel:
            "The vocabulary file may not contain words for this CEFR level"
        case .importFailed:
            "Check your database and try re-importing"
        }
    }
}
