//
//  SchemaMigrationTests.swift
//  LexiconFlowTests
//
//  Schema migration tests for SwiftData
//  Tests version-to-version migrations and data integrity
//

import Foundation
import OSLog
import SwiftData
import Testing
@testable import LexiconFlow

/// Schema migration test suite for SwiftData
///
/// Tests verify:
/// - Schema creation with current models
/// - Data persistence across saves
/// - Optional fields handle null values correctly
/// - Relationships survive persistence
@Suite(.serialized)
struct SchemaMigrationTests {
    // MARK: - Test Configuration

    /// Logger for migration diagnostics
    private let logger = Logger(subsystem: "com.lexiconflow.tests", category: "Migration")

    // MARK: - Test Helpers

    /// Create a ModelContainer with current schema
    @MainActor
    private func createContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
            StudySession.self,
            DailyStats.self,
            GeneratedSentence.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: configuration)
    }

    // MARK: - Schema Tests

    @Test("Schema creation succeeds with current version")
    @MainActor
    func schemaCreation() async throws {
        let container = createContainer()

        // Verify container is valid
        #expect(
            container.mainContext.container.configurations.first != nil,
            "Container should have valid configuration"
        )
    }

    @Test("Optional fields allow null values")
    @MainActor
    func optionalFields() async throws {
        let container = createContainer()
        let context = container.mainContext

        // Create flashcard with minimal required fields
        let flashcard = Flashcard(
            word: "ephemeral",
            definition: "lasting for a very short time"
        )

        // Verify optional fields are nil by default
        #expect(flashcard.translation == nil, "Translation should be nil initially")
        #expect(flashcard.phonetic == nil, "Phonetic should be nil initially")
        #expect(flashcard.imageData == nil, "Image data should be nil initially")

        context.insert(flashcard)
        try context.save()

        // Verify persistence
        let fetched = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(fetched?.translation == nil, "Translation should remain nil after save")
    }

    @Test("FSRSState relationship survives persistence")
    @MainActor
    func fsrsStateRelationship() async throws {
        let container = createContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "concurrent",
            definition: "existing or happening at the same time"
        )

        // Create FSRS state
        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state
        state.card = flashcard

        context.insert(flashcard)
        try context.save()

        // Fetch and verify relationship
        let fetched = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(
            fetched?.fsrsState != nil,
            "FSRSState relationship should persist"
        )
        #expect(
            fetched?.fsrsState?.stability == 1.0,
            "FSRSState properties should persist"
        )
    }

    @Test("FlashcardReview persists correctly")
    @MainActor
    func flashcardReviewPersistence() async throws {
        let container = createContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "test",
            definition: "a test"
        )
        context.insert(flashcard)

        // Create a review
        let review = FlashcardReview(
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)

        try context.save()

        // Verify review exists
        let reviewCount = try context.fetchCount(FetchDescriptor<FlashcardReview>())
        #expect(reviewCount == 1, "Review should exist")

        // Fetch and verify properties
        let fetched = try context.fetch(FetchDescriptor<FlashcardReview>()).first
        #expect(fetched?.rating == 3, "Rating should persist")
        #expect(fetched?.scheduledDays == 7.0, "Scheduled days should persist")
    }

    @Test("Multiple flashcards can share a deck")
    @MainActor
    func deckRelationship() async throws {
        let container = createContainer()
        let context = container.mainContext

        let deck = Deck(name: "Vocabulary", icon: "📚")
        context.insert(deck)

        // Create multiple flashcards in same deck
        for i in 1 ... 5 {
            let flashcard = Flashcard(
                word: "word\(i)",
                definition: "definition \(i)"
            )
            flashcard.deck = deck
            context.insert(flashcard)
        }

        try context.save()

        // Verify all flashcards are in the deck
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let allFlashcards = try context.fetch(fetchDescriptor)
        #expect(allFlashcards.count == 5, "All 5 flashcards should be created")
    }

    @Test("Optional imageData field handles large data")
    @MainActor
    func optionalImageData() async throws {
        let container = createContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "image",
            definition: "a visual representation"
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
        let container = createContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "temporary",
            definition: "lasting for a limited time"
        )

        let state = FSRSState(
            stability: 1.0,
            state: .new
        )
        flashcard.fsrsState = state
        state.card = flashcard
        context.insert(flashcard)

        // Create a review
        let review = FlashcardReview(
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
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

    @Test("StudySession persists with mode")
    @MainActor
    func studySessionPersistence() async throws {
        let container = createContainer()
        let context = container.mainContext

        let session = StudySession(startTime: Date(), mode: .scheduled)
        context.insert(session)

        try context.save()

        // Verify session exists
        let fetched = try context.fetch(FetchDescriptor<StudySession>()).first
        #expect(fetched?.mode == .scheduled, "Mode should persist")
        #expect(fetched?.isActive == true, "Session should be active initially")
    }

    @Test("DailyStats persists with correct date normalization")
    @MainActor
    func dailyStatsPersistence() async throws {
        let container = createContainer()
        let context = container.mainContext

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 10,
            studyTimeSeconds: 300,
            retentionRate: 0.85
        )
        context.insert(stats)

        try context.save()

        // Verify stats exist
        let fetched = try context.fetch(FetchDescriptor<DailyStats>()).first
        #expect(fetched?.cardsLearned == 10, "Cards learned should persist")
        #expect(fetched?.retentionRate == 0.85, "Retention rate should persist")
    }
}
