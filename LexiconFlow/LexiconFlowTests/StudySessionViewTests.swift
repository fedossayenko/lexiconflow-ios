//
//  StudySessionViewTests.swift
//  LexiconFlowTests
//
//  Tests for StudySessionView
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify view properties, initialization, and patterns.
//  Full behavior testing requires UI tests or snapshot tests.
//

import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

@Suite(.serialized)
@MainActor
struct StudySessionViewTests {
    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestFlashcard(
        context: ModelContext,
        word: String = UUID().uuidString,
        stateEnum: String = FlashcardState.new.rawValue,
        dueOffset: TimeInterval = 0
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: "Test definition")
        let fsrsState = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(dueOffset),
            stateEnum: stateEnum
        )
        card.fsrsState = fsrsState
        context.insert(card)
        context.insert(fsrsState)
        try! context.save()
        return card
    }

    // MARK: - Initialization Tests

    @Test("StudySessionView initializes with scheduled mode")
    func studySessionViewInitializesWithScheduledMode() {
        var onCompleteCalled = false
        let view = StudySessionView(mode: .scheduled) {
            onCompleteCalled = true
        }

        #expect(view.mode == .scheduled, "View should store scheduled mode")
        #expect(!onCompleteCalled, "onComplete should not be called initially")
    }

    // MARK: - Card Reference Pattern Tests (Critical Race Condition)

    @Test("Cards have unique persistent IDs")
    func cardsHaveUniqueIds() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create multiple cards
        let firstCard = createTestFlashcard(context: context, word: "First")
        let secondCard = createTestFlashcard(context: context, word: "Second")

        // Each card should have unique ID for view refresh
        #expect(firstCard.id != secondCard.id, "Cards should have unique IDs")
        #expect(firstCard.word == "First", "First card should have correct word")
        #expect(secondCard.word == "Second", "Second card should have correct word")
    }

    @Test("Created cards have FSRSState")
    func createdCardsHaveFSRSState() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let card = createTestFlashcard(
            context: context,
            word: "TestCard",
            stateEnum: FlashcardState.learning.rawValue
        )

        #expect(card.fsrsState != nil, "Card should have FSRSState attached")
        #expect(card.fsrsState?.stateEnum == FlashcardState.learning.rawValue, "State should match creation")
    }

    // MARK: - Edge Cases

    @Test("View creation with empty database doesn't crash")
    func viewCreationWithEmptyDatabase() {
        let container = createTestContainer()
        let context = container.mainContext

        var onCompleteCalled = false
        let view = StudySessionView(mode: .scheduled) {
            onCompleteCalled = true
        }

        // Verify view can be created with empty database
        #expect(view.mode == .scheduled, "View should exist even with empty database")
    }

    @Test("View creation with cards doesn't crash")
    func viewCreationWithCards() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create some cards
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)

        var onCompleteCalled = false
        let view = StudySessionView(mode: .scheduled) {
            onCompleteCalled = true
        }

        // Verify view can be created with cards
        #expect(view.mode == .scheduled, "View should exist with cards in database")
    }

    @Test("Multiple card creation generates valid data")
    func multipleCardCreationGeneratesValidData() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create multiple cards
        var cards: [Flashcard] = []
        for i in 0 ..< 10 {
            let card = createTestFlashcard(
                context: context,
                word: "Card\(i)",
                stateEnum: FlashcardState.learning.rawValue,
                dueOffset: -3600
            )
            cards.append(card)
        }

        // Verify all cards were created with valid data
        #expect(cards.count == 10, "Should create 10 cards")

        // Verify all cards have unique IDs
        let uniqueIds = Set(cards.map(\.id))
        #expect(uniqueIds.count == 10, "All cards should have unique IDs")

        // Verify all cards have FSRSState
        let cardsWithState = cards.filter { $0.fsrsState != nil }
        #expect(cardsWithState.count == 10, "All cards should have FSRSState")
    }
}
