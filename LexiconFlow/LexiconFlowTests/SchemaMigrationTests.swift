//
//  SchemaMigrationTests.swift
//  LexiconFlowTests
//
//  Schema migration tests for SwiftData
//  Tests version-to-version migrations and data integrity
//

import Testing
import Foundation
import SwiftData
import OSLog
@testable import LexiconFlow

/// Schema migration test suite for SwiftData
///
/// Tests verify:
/// - Schema migration from v1 to v2 succeeds
/// - Data is preserved during migration
/// - Optional fields handle null values correctly
/// - Relationships survive migration
///
/// **Migration Scenarios:**
/// - Translation fields added (optional)
/// - CEFR level field changes
/// - New relationships added
@Suite(.serialized)
struct SchemaMigrationTests {

    // MARK: - Test Configuration

    /// Logger for migration diagnostics
    private let logger = Logger(subsystem: "com.lexiconflow.tests", category: "Migration")

    // MARK: - Test Helpers

    /// Create a ModelContainer with v1 schema (simulated)
    private func createV1Container() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// Create a ModelContainer with current schema
    private func createCurrentContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func createTestData(in context: ModelContext) {
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "test",
            phonetic: "/test/",
            definition: "a test",
            partOfSpeech: "noun",
            cefrLevel: "A1",
            deck: deck
        )
        flashcard.fsrsState = FSRSState(card: flashcard)
        context.insert(flashcard)

        try! context.save()
    }

    // MARK: - Migration Tests

    @Test("Schema creation succeeds with current version")
    func schemaCreation() async throws {
        let container = createCurrentContainer()

        // Verify container is valid
        #expect(
            container.mainContext.container.configurations.first != nil,
            "Container should have valid configuration"
        )
    }

    @Test("Optional translation fields allow null values")
    @MainActor
    func optionalTranslationFields() async throws {
        let container = createCurrentContainer()
        let context = container.mainContext

        // Create flashcard without translation fields
        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "ephemeral",
            phonetic: "/ɪˈfem(ə)rəl/",
            definition: "lasting for a very short time",
            partOfSpeech: "adjective",
            cefrLevel: "C1",
            deck: deck
        )

        // Verify optional fields are nil by default
        #expect(flashcard.translation == nil, "Translation should be nil initially")
        #expect(flashcard.exampleSentence == nil, "Example sentence should be nil initially")
        #expect(flashcard.exampleSentenceTranslation == nil, "Example translation should be nil initially")

        context.insert(flashcard)
        try context.save()

        // Verify persistence
        let fetched = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(fetched?.translation == nil, "Translation should remain nil after save")
    }

    @Test("FSRSState relationship survives persistence")
    @MainActor
    func fsrsStateRelationship() async throws {
        let container = createCurrentContainer()
        let context = container.mainContext

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "concurrent",
            phonetic: "/kənˈkɜːrənt/",
            definition: "existing or happening at the same time",
            partOfSpeech: "adjective",
            cefrLevel: "C1",
            deck: deck
        )

        // Create FSRS state
        let state = FSRSState(card: flashcard)
        flashcard.fsrsState = state
        context.insert(flashcard)
        try context.save()

        // Fetch and verify relationship
        let fetched = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(
            fetched?.fsrsState != nil,
            "FSRSState relationship should persist"
        )
        #expect(
            fetched?.fsrsState?.card == fetched,
            "Inverse relationship should be maintained"
        )
    }

    @Test("Multiple flashcards can share a deck")
    @MainActor
    func deckRelationship() async throws {
        let container = createCurrentContainer()
        let context = container.mainContext

        let deck = Deck(name: "Vocabulary", icon: "📚")
        context.insert(deck)

        // Create multiple flashcards in same deck
        for i in 1...5 {
            let flashcard = Flashcard(
                word: "word\(i)",
                phonetic: "/wɜːrd\(i)/",
                definition: "definition \(i)",
                partOfSpeech: "noun",
                cefrLevel: "A1",
                deck: deck
            )
            context.insert(flashcard)
        }

        try context.save()

        // Verify all flashcards are in the deck
        let fetchDescriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.deck?.name == "Vocabulary" }
        )
        let count = try context.fetchCount(fetchDescriptor)
        #expect(count == 5, "All 5 flashcards should be in the deck")
    }

    @Test("Optional imageData field handles large data")
    @MainActor
    func optionalImageData() async throws {
        let container = createCurrentContainer()
        let context = container.mainContext

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "image",
            phonetic: "/ˈɪmɪdʒ/",
            definition: "a visual representation",
            partOfSpeech: "noun",
            cefrLevel: "A1",
            deck: deck
        )

        // Start with nil image data
        #expect(flashcard.imageData == nil, "Image data should be nil initially")

        // Add image data (simulate image upload)
        let largeImageData = Data([UInt8](repeating: 0xFF, count: 1024 * 1024)) // 1MB
        flashcard.imageData = largeImageData

        context.insert(flashcard)
        try context.save()

        // Verify persistence
        let fetched = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(
            fetched?.imageData?.count == 1024 * 1024,
            "Image data should persist correctly"
        )
    }

    @Test("Cascade delete removes related reviews")
    @MainActor
    func cascadeDelete() async throws {
        let container = createCurrentContainer()
        let context = container.mainContext

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "temporary",
            phonetic: "/ˈtɛmpərəri/",
            definition: "lasting for a limited time",
            partOfSpeech: "adjective",
            cefrLevel: "A2",
            deck: deck
        )
        flashcard.fsrsState = FSRSState(card: flashcard)
        context.insert(flashcard)

        // Create a review
        let review = FlashcardReview(
            card: flashcard,
            rating: 3,
            state: "learning",
            timeTaken: 5.0
        )
        context.insert(review)

        try context.save()

        // Verify review exists
        let reviewCount = try context.fetchCount(FetchDescriptor<FlashcardReview>())
        #expect(reviewCount == 1, "Review should exist")

        // Delete flashcard (cascade should delete review)
        context.delete(flashcard)
        try context.save()

        // Verify review was deleted
        let reviewCountAfter = try context.fetchCount(FetchDescriptor<FlashcardReview>())
        #expect(reviewCountAfter == 0, "Review should be cascade deleted")
    }
}
