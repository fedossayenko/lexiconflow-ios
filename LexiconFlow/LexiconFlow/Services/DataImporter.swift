//
//  DataImporter.swift
//  LexiconFlow
//
//  Batch import optimization for large datasets
//  Uses actor for background-safe SwiftData operations
//

import Foundation
import SwiftData
import OSLog

/// Batch data import service with progress tracking
///
/// **Architecture**: Uses actor for thread-safe bulk operations.
/// **Performance**: Batches inserts to avoid memory pressure and maintains UI responsiveness.
///
/// **Usage**:
/// ```swift
/// let importer = DataImporter(modelContext: context)
/// let progress = await importer.importCards(cards, batchSize: 500)
/// ```
actor DataImporter {
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
    /// **Optimization**: Uses actor to run on background queue,
    /// keeping UI responsive during large imports.
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
        var result = ImportResult()

        let totalCount = cards.count
        Self.logger.info("Starting import of \(totalCount) cards in batches of \(batchSize)")

        // Process in batches
        let batches = cards.chunked(into: batchSize)
        for (index, batch) in batches.enumerated() {
            let batchNumber = index + 1
            let totalBatches = (totalCount + batchSize - 1) / batchSize

            Self.logger.info("Processing batch \(batchNumber)/\(totalBatches) (\(batch.count) cards)")

            do {
                // Import this batch
                let batchStats = try importBatch(batch, into: deck)

                // Update result
                result.importedCount += batchStats.success
                result.skippedCount += batchStats.skipped
                result.errors.append(contentsOf: batchStats.errors)

                // Commit after each batch
                try modelContext.save()

                // Report progress
                let progress = ImportProgress(
                    current: result.importedCount,
                    total: totalCount,
                    batchNumber: batchNumber,
                    totalBatches: totalBatches
                )
                progressHandler?(progress)

                // Analytics for performance monitoring
                await Analytics.trackPerformance(
                    "import_batch_\(batchNumber)",
                    duration: Date().timeIntervalSince(startTime),
                    metadata: [
                        "batch_size": "\(batch.count)",
                        "total_processed": "\(result.importedCount)"
                    ]
                )

            } catch {
                Self.logger.error("❌ Batch \(batchNumber) failed: \(error)")
                result.errors.append(
                    ImportError(
                        batchNumber: batchNumber,
                        error: error,
                        cardWord: nil
                    )
                )

                await Analytics.trackError(
                    "import_batch_failed",
                    error: error,
                    metadata: [
                        "batch_number": "\(batchNumber)",
                        "batch_size": "\(batch.count)"
                    ]
                )
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        result.duration = duration

        Self.logger.info("""
            Import complete:
            - Imported: \(result.importedCount)
            - Skipped: \(result.skippedCount)
            - Errors: \(result.errors.count)
            - Duration: \(String(format: "%.2f", duration))s
            """)

        await Analytics.trackEvent("data_import_complete", metadata: [
            "imported_count": "\(result.importedCount)",
            "skipped_count": "\(result.skippedCount)",
            "error_count": "\(result.errors.count)",
            "duration_seconds": String(format: "%.2f", duration)
        ])

        return result
    }

    /// Import a single batch of cards
    ///
    /// - Parameters:
    ///   - cards: Cards in this batch
    ///   - deck: Optional deck to associate with
    /// - Returns: Batch statistics
    private func importBatch(
        _ cards: [FlashcardData],
        into deck: Deck?
    ) throws -> BatchStats {
        var stats = BatchStats()

        for cardData in cards {
            // Check for duplicates using fetch without predicate
            let allCards = try modelContext.fetch(FetchDescriptor<Flashcard>())
            let existing = allCards.first { $0.word == cardData.word }

            if existing != nil {
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

            // Associate with deck if provided
            if let deck = deck {
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
            modelContext.insert(state)
            flashcard.fsrsState = state

            // Insert flashcard
            modelContext.insert(flashcard)

            stats.success += 1
        }

        return stats
    }

    // MARK: - Import Strategies

    /// Import cards with automatic deduplication strategy
    ///
    /// - Parameters:
    ///   - cards: Cards to import
    ///   - strategy: How to handle duplicates
    ///   - deck: Optional deck
    /// - Returns: Import result
    func importCardsWithStrategy(
        _ cards: [FlashcardData],
        strategy: DuplicateStrategy = .skip,
        deck: Deck? = nil
    ) async -> ImportResult {
        switch strategy {
        case .skip:
            return await importCards(cards, into: deck)

        case .update:
            return await importCardsWithUpdate(cards, into: deck)

        case .replace:
            return await importCardsWithReplace(cards, into: deck)
        }
    }

    /// Import cards updating existing ones
    private func importCardsWithUpdate(
        _ cards: [FlashcardData],
        into deck: Deck?
    ) async -> ImportResult {
        // TODO: Implement update strategy
        fatalError("Not implemented")
    }

    /// Import cards replacing existing ones
    private func importCardsWithReplace(
        _ cards: [FlashcardData],
        into deck: Deck?
    ) async -> ImportResult {
        // TODO: Implement replace strategy
        fatalError("Not implemented")
    }
}

// MARK: - Supporting Types

/// Flashcard data for import
struct FlashcardData: Sendable {
    let word: String
    let definition: String
    let phonetic: String?
    let imageData: Data?

    init(
        word: String,
        definition: String,
        phonetic: String? = nil,
        imageData: Data? = nil
    ) {
        self.word = word
        self.definition = definition
        self.phonetic = phonetic
        self.imageData = imageData
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
        guard total > 0 else { return 0 }
        return (current * 100) / total
    }

    /// Human-readable progress string
    var description: String {
        "\(current)/\(total) (\(percentage)%) - Batch \(batchNumber)/\(totalBatches)"
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
        errors.isEmpty && importedCount > 0
    }
}

/// Statistics for a single batch
private struct BatchStats {
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

/// Strategy for handling duplicate cards
enum DuplicateStrategy {
    /// Skip duplicates, keep existing
    case skip

    /// Update existing cards with new data
    case update

    /// Delete existing and insert new
    case replace
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
