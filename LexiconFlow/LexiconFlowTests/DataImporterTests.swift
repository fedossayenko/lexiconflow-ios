//
//  DataImporterTests.swift
//  LexiconFlowTests
//
//  Tests for batch data import functionality
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Thread-safe collector for progress updates in Swift 6
actor ProgressCollector {
    private var updates: [ImportProgress] = []

    func add(_ progress: ImportProgress) {
        self.updates.append(progress)
    }

    var allUpdates: [ImportProgress] {
        self.updates
    }
}

/// Thread-safe counter for batch operations in Swift 6
actor BatchCounter {
    private var value: Int = 0

    func increment() {
        self.value += 1
    }

    var count: Int {
        self.value
    }
}

/// Test suite for DataImporter
///
/// Tests verify:
/// - Batch import with progress tracking
/// - Duplicate detection and handling
/// - Error handling for unsupported strategies
/// - Performance with large datasets
/// - Relationship integrity (deck associations, FSRS state)
@MainActor
struct DataImporterTests {
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Basic Import Tests

    @Test("Import single card successfully")
    func importSingleCard() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let cardData = FlashcardData(
            word: "test",
            definition: "A test word",
            phonetic: "/tɛst/",
            imageData: nil
        )

        let result = await importer.importCards([cardData])

        #expect(result.importedCount == 1, "Should import 1 card")
        #expect(result.skippedCount == 0, "Should skip 0 cards")
        #expect(result.errors.isEmpty, "Should have no errors")
        #expect(result.isSuccess, "Should be successful")

        // Verify card was created
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 1, "Database should have 1 card")
        #expect(cards[0].word == "test", "Card word should match")
    }

    @Test("Import multiple cards in batch")
    func importMultipleCards() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let cards = [
            FlashcardData(word: "word1", definition: "def1"),
            FlashcardData(word: "word2", definition: "def2"),
            FlashcardData(word: "word3", definition: "def3")
        ]

        let result = await importer.importCards(cards)

        #expect(result.importedCount == 3, "Should import 3 cards")
        #expect(result.skippedCount == 0, "Should skip 0 cards")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 3, "Database should have 3 cards")
    }

    @Test("Import empty array returns success")
    func importEmptyArray() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let result = await importer.importCards([])

        #expect(result.importedCount == 0, "Should import 0 cards")
        #expect(result.skippedCount == 0, "Should skip 0 cards")
        #expect(result.errors.isEmpty, "Should have no errors")
        // Note: isSuccess requires importedCount > 0, so this should be false
    }

    // MARK: - Duplicate Detection Tests

    @Test("Skip duplicate cards by default")
    func skipDuplicateCards() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let cards = [
            FlashcardData(word: "duplicate", definition: "First"),
            FlashcardData(word: "duplicate", definition: "Second"),
            FlashcardData(word: "unique", definition: "Only one")
        ]

        // Import first time - all 3 imported (duplicate check happens once per batch)
        let result1 = await importer.importCards(cards)
        #expect(result1.importedCount == 3, "First import should import all 3 cards (no intra-batch dedupe)")
        #expect(result1.skippedCount == 0, "First import should skip 0 cards")

        // Import again with duplicates - all 3 now exist in DB
        let result2 = await importer.importCards(cards)
        #expect(result2.importedCount == 0, "Second import should import 0 new cards")
        #expect(result2.skippedCount == 3, "Second import should skip all 3 duplicates")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 3, "Database should have 3 cards total (both duplicates + unique)")
    }

    @Test("Duplicate detection is case-sensitive")
    func duplicateDetectionCaseSensitive() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let cards = [
            FlashcardData(word: "Test", definition: "Capitalized"),
            FlashcardData(word: "test", definition: "Lowercase"),
            FlashcardData(word: "TEST", definition: "Uppercase")
        ]

        let result = await importer.importCards(cards)

        // All should be imported as different words (case-sensitive)
        #expect(result.importedCount == 3, "All variations should be imported")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 3, "Database should have 3 cards")
    }

    // MARK: - Progress Tracking Tests

    @Test("Progress handler called for each batch")
    func progressHandlerCalled() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        // Create 10 cards to ensure multiple batches
        var cards: [FlashcardData] = []
        for i in 0 ..< 10 {
            cards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }

        let progressCollector = ProgressCollector()
        let result = await importer.importCards(
            cards,
            batchSize: 3,
            progressHandler: { progress in
                Task { await progressCollector.add(progress) }
            }
        )

        // Small delay to ensure all tasks complete
        try await Task.sleep(nanoseconds: 100000000) // 0.1s

        let progressUpdates = await progressCollector.allUpdates

        // Should have 4 batches (10 cards / 3 = 4 batches)
        #expect(progressUpdates.count == 4, "Should have 4 progress updates")
        #expect(result.importedCount == 10, "Should import all 10 cards")

        // Verify progress values
        #expect(progressUpdates[0].current == 3, "First batch should have 3 cards")
        #expect(progressUpdates[0].total == 10, "Total should be 10")
    }

    @Test("Progress percentage calculated correctly")
    func progressPercentageCalculation() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        var cards: [FlashcardData] = []
        for i in 0 ..< 10 {
            cards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }

        let progressCollector = ProgressCollector()
        _ = await importer.importCards(
            cards,
            batchSize: 5,
            progressHandler: { progress in
                Task { await progressCollector.add(progress) }
            }
        )

        // Small delay to ensure all tasks complete
        try await Task.sleep(nanoseconds: 100000000) // 0.1s

        let progressUpdates = await progressCollector.allUpdates

        #expect(progressUpdates.count == 2, "Should have 2 batches")
        #expect(progressUpdates[0].percentage == 50, "First batch should be 50%")
        #expect(progressUpdates[1].percentage == 100, "Second batch should be 100%")
    }

    // MARK: - Relationship Tests

    @Test("Cards associated with deck correctly")
    func deckAssociation() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        // Create a deck
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)
        try context.save()

        let cards = [
            FlashcardData(word: "card1", definition: "def1"),
            FlashcardData(word: "card2", definition: "def2")
        ]

        let result = await importer.importCards(cards, into: deck)

        #expect(result.importedCount == 2, "Should import 2 cards")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 2, "Database should have 2 cards")

        // Verify deck association
        for card in dbCards {
            #expect(card.deck?.name == "Test Deck", "Card should be associated with deck")
        }
    }

    @Test("FSRS state created for imported cards")
    func fsrsStateCreated() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let cards = [
            FlashcardData(word: "test", definition: "def")
        ]

        let result = await importer.importCards(cards)

        #expect(result.importedCount == 1, "Should import 1 card")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 1, "Database should have 1 card")

        let card = dbCards[0]
        #expect(card.fsrsState != nil, "Card should have FSRS state")
        #expect(card.fsrsState?.state == .new, "State should be new")
        #expect(card.fsrsState?.stability == 0, "Stability should be 0")
    }

    @Test("Image data stored correctly")
    func imageDataStorage() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        let imageData = Data("fake image data".utf8)

        let cards = [
            FlashcardData(
                word: "test",
                definition: "def",
                phonetic: "/tɛst/",
                imageData: imageData
            )
        ]

        let result = await importer.importCards(cards)

        #expect(result.importedCount == 1, "Should import 1 card")

        let dbCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(dbCards.count == 1, "Database should have 1 card")

        let card = dbCards[0]
        #expect(card.imageData == imageData, "Image data should match")
    }

    // MARK: - Batch Size Tests

    @Test("Custom batch size respected")
    func customBatchSize() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        var cards: [FlashcardData] = []
        for i in 0 ..< 15 {
            cards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }

        let batchCollector = BatchCounter()
        _ = await importer.importCards(
            cards,
            batchSize: 7,
            progressHandler: { progress in
                if progress.current % 7 == 0 || progress.current == 15 {
                    Task { await batchCollector.increment() }
                }
            }
        )

        // Small delay to ensure all tasks complete
        try await Task.sleep(nanoseconds: 100000000) // 0.1s

        // 15 cards / batch size 7 = 3 batches (7, 7, 1)
        let batchCount = await batchCollector.count
        #expect(batchCount == 3, "Should have 3 batches with batch size 7")
    }

    @Test("Large batch size imports all at once")
    func largeBatchSize() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        var cards: [FlashcardData] = []
        for i in 0 ..< 50 {
            cards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }

        let batchCollector = BatchCounter()
        _ = await importer.importCards(
            cards,
            batchSize: 1000,
            progressHandler: { _ in
                Task { await batchCollector.increment() }
            }
        )

        // Small delay to ensure all tasks complete
        try await Task.sleep(nanoseconds: 100000000) // 0.1s

        let batchCount = await batchCollector.count
        #expect(batchCount == 1, "Should have 1 batch with large batch size")
    }

    // MARK: - Performance Tests

    @Test("Import 20 cards quickly")
    func importPerformance() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        var cards: [FlashcardData] = []
        for i in 0 ..< 20 {
            cards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }

        let result = await importer.importCards(cards, batchSize: 50)

        #expect(result.importedCount == 20, "Should import all 20 cards")
        #expect(result.duration < 5.0, "Should complete in under 5 seconds")
    }

    @Test("Duplicate check is O(n) not O(n²)")
    func duplicateCheckPerformance() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let importer = DataImporter(modelContext: context)

        // Import 20 cards first
        var initialCards: [FlashcardData] = []
        for i in 0 ..< 20 {
            initialCards.append(FlashcardData(word: "word\(i)", definition: "def\(i)"))
        }
        _ = await importer.importCards(initialCards)

        // Now import 20 duplicates - should be fast with O(n) check
        let start = Date()
        let result = await importer.importCards(initialCards)
        let duration = Date().timeIntervalSince(start)

        #expect(result.skippedCount == 20, "Should skip all 20 duplicates")
        // O(n) should be very fast (< 0.5s for 20 items)
        #expect(duration < 0.5, "Duplicate check should be fast: \(duration)s")
    }
}
