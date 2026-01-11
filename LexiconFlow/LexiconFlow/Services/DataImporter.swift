//
//  DataImporter.swift
//  LexiconFlow
//
//  Batch import optimization for large datasets
//  Uses @MainActor with background task offloading for performance
//

import Foundation
import OSLog
import SwiftData

/// Batch data import service with progress tracking
///
/// **Architecture**: Uses @MainActor for SwiftData ModelContext access required by SwiftData.
/// **Performance**: Offloads heavy work to background while ModelContext operations run on main thread.
/// Batch processing prevents UI blocking during large imports.
///
/// **Usage**:
/// ```swift
/// let importer = DataImporter(modelContext: context)
/// let progress = await importer.importCards(cards, batchSize: 500)
/// ```
@MainActor
final class DataImporter {
    /// Logger for import operations
    private static let logger = Logger(subsystem: "com.lexiconflow.importer", category: "DataImport")

    /// The model context for data operations
    private let modelContext: ModelContext

    /// Initialize with a model context
    ///
    /// - Parameter modelContext: The SwiftData model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Batch Import

    /// Import a batch of flashcards with progress tracking
    ///
    /// **Performance**: Commits every `batchSize` cards to avoid:
    /// - Memory pressure from large transactions
    /// - UI blocking during long operations
    /// - SQLite lock contention
    ///
    /// **Optimization**: Pre-fetches all existing words ONCE before batch processing.
    /// This achieves true O(n) complexity instead of O(n²) where n = total cards.
    /// For importing 1000 cards with 10,000 existing cards: 1 query instead of 10 queries.
    ///
    /// - Parameters:
    ///   - cards: Array of flashcard data to import
    ///   - deck: Optional deck to associate cards with
    ///   - batchSize: Number of cards per transaction (default: 500)
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Import result with counts and any errors
    func importCards(
        _ cards: [FlashcardData],
        into deck: Deck? = nil,
        batchSize: Int = 500,
        progressHandler: (@Sendable (ImportProgress) -> Void)? = nil
    ) async -> ImportResult {
        let startTime = Date()
        let totalCount = cards.count
        Self.logger.info("Starting import of \(totalCount) cards in batches of \(batchSize)")

        // Pre-fetch existing words for O(1) duplicate checking
        let allExistingWords = self.prefetchExistingWords()

        // Process in batches
        let config = BatchProcessingConfig(
            cards: cards,
            deck: deck,
            batchSize: batchSize,
            totalCount: totalCount,
            existingWords: allExistingWords,
            startTime: startTime,
            progressHandler: progressHandler
        )
        let result = await processBatches(config)

        // Log completion and analytics
        self.logImportCompletion(result, duration: result.duration)

        // Invalidate statistics cache after data import
        StatisticsService.shared.invalidateCache()

        return result
    }

    // MARK: - Private Helpers

    /// Parameters for batch processing configuration
    private struct BatchProcessingConfig: Sendable {
        let cards: [FlashcardData]
        let deck: Deck?
        let batchSize: Int
        let totalCount: Int
        let existingWords: Set<String>
        let startTime: Date
        let progressHandler: (@Sendable (ImportProgress) -> Void)?
    }

    /// Pre-fetch all existing words for O(1) duplicate checking
    private func prefetchExistingWords() -> Set<String> {
        do {
            let allCards = try modelContext.fetch(FetchDescriptor<Flashcard>())
            let words = Set(allCards.map(\.word))
            Self.logger.info("Pre-fetched \(words.count) existing words for duplicate checking")
            return words
        } catch {
            Self.logger.error("Failed to pre-fetch existing words: \(error)")
            return []
        }
    }

    /// Process cards in batches with progress tracking
    private func processBatches(_ config: BatchProcessingConfig) async -> ImportResult {
        var result = ImportResult()
        let batches = config.cards.chunked(into: config.batchSize)
        let totalBatches = (config.totalCount + config.batchSize - 1) / config.batchSize

        for (index, batch) in batches.enumerated() {
            let batchNumber = index + 1

            Self.logger.info("Processing batch \(batchNumber)/\(totalBatches) (\(batch.count) cards)")

            do {
                let batchStats = try importBatch(batch, into: config.deck, existingWords: config.existingWords)

                result.importedCount += batchStats.success
                result.skippedCount += batchStats.skipped
                result.errors.append(contentsOf: batchStats.errors)

                try self.modelContext.save()

                // Invalidate statistics cache after importing cards
                if let deckID = config.deck?.id {
                    DeckStatisticsCache.shared.invalidate(deckID: deckID)
                } else {
                    // If no deck specified, clear all cache
                    DeckStatisticsCache.shared.invalidate()
                }

                self.reportProgress(
                    result.importedCount,
                    total: config.totalCount,
                    batchNumber: batchNumber,
                    totalBatches: totalBatches,
                    handler: config.progressHandler
                )

                self.trackBatchPerformance(batchNumber, batchCount: batch.count, startTime: config.startTime)

            } catch {
                self.handleBatchError(error, batchNumber: batchNumber, batchCount: batch.count, result: &result)
            }
        }

        result.duration = Date().timeIntervalSince(config.startTime)
        return result
    }

    /// Report import progress
    private func reportProgress(
        _ current: Int,
        total: Int,
        batchNumber: Int,
        totalBatches: Int,
        handler: (@Sendable (ImportProgress) -> Void)?
    ) {
        let progress = ImportProgress(
            current: current,
            total: total,
            batchNumber: batchNumber,
            totalBatches: totalBatches
        )
        handler?(progress)
    }

    /// Track batch performance analytics
    private func trackBatchPerformance(_ batchNumber: Int, batchCount: Int, startTime: Date) {
        Task {
            Analytics.trackPerformance(
                "import_batch_\(batchNumber)",
                duration: Date().timeIntervalSince(startTime),
                metadata: [
                    "batch_size": "\(batchCount)",
                    "total_processed": "\(batchNumber * batchCount)"
                ]
            )
        }
    }

    /// Handle batch import error
    private func handleBatchError(
        _ error: Error,
        batchNumber: Int,
        batchCount: Int,
        result: inout ImportResult
    ) {
        Self.logger.error("❌ Batch \(batchNumber) failed: \(error)")
        result.errors.append(
            ImportError(
                batchNumber: batchNumber,
                error: error,
                cardWord: nil
            )
        )

        Task {
            Analytics.trackError(
                "import_batch_failed",
                error: error,
                metadata: [
                    "batch_number": "\(batchNumber)",
                    "batch_size": "\(batchCount)"
                ]
            )
        }
    }

    /// Log import completion and track final analytics
    private func logImportCompletion(_ result: ImportResult, duration: TimeInterval) {
        Self.logger.info("""
        Import complete:
        - Imported: \(result.importedCount)
        - Skipped: \(result.skippedCount)
        - Errors: \(result.errors.count)
        - Duration: \(String(format: "%.2f", duration))s
        """)

        Task {
            Analytics.trackEvent("data_import_complete", metadata: [
                "imported_count": "\(result.importedCount)",
                "skipped_count": "\(result.skippedCount)",
                "error_count": "\(result.errors.count)",
                "duration_seconds": String(format: "%.2f", duration)
            ])
        }
    }

    /// Import a single batch of cards
    ///
    /// **Performance**: Uses pre-fetched existing words Set for O(1) duplicate checking.
    /// **Optimization**: True O(n) complexity - fetches all existing words ONCE in importCards(),
    /// then each batch simply checks against the pre-fetched Set.
    /// **Thread Safety**: Uses Set for O(1) duplicate checks, no race conditions.
    ///
    /// - Parameters:
    ///   - cards: Cards in this batch
    ///   - deck: Optional deck to associate with
    ///   - existingWords: Pre-fetched Set of all existing words (passed from importCards)
    /// - Returns: Batch statistics
    private func importBatch(
        _ cards: [FlashcardData],
        into deck: Deck?,
        existingWords: Set<String>
    ) throws -> BatchStats {
        var stats = BatchStats()

        for cardData in cards {
            // O(1) duplicate check using pre-fetched Set
            if existingWords.contains(cardData.word) {
                stats.skipped += 1
                continue
            }

            // Create new flashcard
            let flashcard = Flashcard(
                word: cardData.word,
                definition: cardData.definition,
                phonetic: cardData.phonetic,
                imageData: cardData.imageData
            )

            // Set CEFR level if provided
            if let cefrLevel = cardData.cefrLevel {
                do {
                    try flashcard.setCEFRLevel(cefrLevel)
                } catch {
                    // Log but continue - don't fail entire batch for invalid CEFR level
                    Self.logger.warning("⚠️ Invalid CEFR level '\(cefrLevel)' for word '\(cardData.word)': \(error)")
                }
            }

            // Set translation if provided
            if let translation = cardData.russianTranslation {
                flashcard.translation = translation
            }

            // Associate with deck if provided
            if let deck {
                flashcard.deck = deck
            }

            // Create FSRS state
            let state = FSRSState(
                stability: 0,
                difficulty: 5,
                retrievability: 0.9,
                dueDate: Date(),
                stateEnum: FlashcardState.new.rawValue
            )
            self.modelContext.insert(state)
            flashcard.fsrsState = state

            // Insert flashcard
            self.modelContext.insert(flashcard)

            stats.success += 1
        }

        return stats
    }
}

// MARK: - Supporting Types

/// Flashcard data for import
struct FlashcardData: Sendable {
    let word: String
    let definition: String
    let phonetic: String?
    let imageData: Data?
    let cefrLevel: String? // CEFR level (A1, A2, B1, B2, C1, C2)
    let russianTranslation: String? // Russian translation of the word

    init(
        word: String,
        definition: String,
        phonetic: String? = nil,
        imageData: Data? = nil,
        cefrLevel: String? = nil,
        russianTranslation: String? = nil
    ) {
        self.word = word
        self.definition = definition
        self.phonetic = phonetic
        self.imageData = imageData
        self.cefrLevel = cefrLevel
        self.russianTranslation = russianTranslation
    }
}

/// Progress information during import
struct ImportProgress: Sendable {
    /// Number of cards imported so far
    let current: Int

    /// Total number of cards to import
    let total: Int

    /// Current batch number (1-indexed)
    let batchNumber: Int

    /// Total number of batches
    let totalBatches: Int

    /// Progress as percentage (0-100)
    var percentage: Int {
        guard self.total > 0 else { return 0 }
        return (self.current * 100) / self.total
    }

    /// Human-readable progress string
    var description: String {
        "\(self.current)/\(self.total) (\(self.percentage)%) - Batch \(self.batchNumber)/\(self.totalBatches)"
    }
}

/// Result of a batch import operation
struct ImportResult: Sendable {
    /// Number of successfully imported cards
    var importedCount: Int = 0

    /// Number of skipped cards (duplicates)
    var skippedCount: Int = 0

    /// Errors encountered during import
    var errors: [ImportError] = []

    /// Total duration of import in seconds
    var duration: TimeInterval = 0

    /// Whether import was completely successful
    var isSuccess: Bool {
        self.errors.isEmpty && self.importedCount > 0
    }
}

/// Statistics for a single batch
private struct BatchStats: Sendable {
    var success: Int = 0
    var skipped: Int = 0
    var errors: [ImportError] = []
}

/// Error during import
struct ImportError: Sendable {
    let batchNumber: Int
    let error: Error
    let cardWord: String?
}

// MARK: - Array Chunking Extension

extension Array {
    /// Split array into chunks of specified size
    ///
    /// - Parameter size: Maximum size of each chunk
    /// - Returns: Array of chunked arrays
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        var chunks: [[Element]] = []
        var currentChunk: [Element] = []
        currentChunk.reserveCapacity(size)

        for element in self {
            currentChunk.append(element)

            if currentChunk.count == size {
                chunks.append(currentChunk)
                currentChunk = []
                currentChunk.reserveCapacity(size)
            }
        }

        // Add remaining elements
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }
}
