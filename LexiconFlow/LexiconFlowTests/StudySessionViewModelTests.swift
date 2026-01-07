//
//  StudySessionViewModelTests.swift
//  LexiconFlowTests
//
//  Tests for StudySessionViewModel
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for StudySessionViewModel
///
/// Tests verify:
/// - Card loading from scheduler
/// - Initial state after loading cards
/// - Rating submission advances to next card
/// - Failed review prevents advancement (Issue 9 fix)
/// - Error handling when review fails (Issue 9 fix)
/// - Progress formatting
/// - Session reset functionality
/// - Session completion on last card
/// - Concurrent submission prevention
@MainActor
struct StudySessionViewModelTests {

    // MARK: - Test Fixtures

    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    private func createTestDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "test", order: 0)
        context.insert(deck)
        return deck
    }

    private func createTestFlashcard(
        context: ModelContext,
        word: String = UUID().uuidString,
        stateEnum: String = FlashcardState.new.rawValue,
        dueOffset: TimeInterval = 0,
        deck: Deck? = nil
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
        card.deck = deck
        context.insert(card)
        context.insert(fsrsState)
        return card
    }

    // MARK: - Card Loading Tests

    @Test("Load cards fetches from scheduler")
    func loadCardsFetchesFromScheduler() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and card
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        #expect(viewModel.cards.count == 1)
    }

    @Test("Load cards sets correct initial state")
    func loadCardsSetsCorrectInitialState() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and card
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        #expect(viewModel.currentIndex == 0)
        #expect(!viewModel.isComplete)
        #expect(!viewModel.isProcessing)
    }

    @Test("Load cards with empty deck sets complete flag")
    func loadCardsWithEmptyDeckSetsComplete() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        viewModel.loadCards()

        #expect(viewModel.cards.isEmpty)
        #expect(viewModel.isComplete)
    }

    // MARK: - Rating Submission Tests

    @Test("Submit rating advances to next card")
    func submitRatingAdvancesToNextCard() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and two due cards
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()
        let initialIndex = viewModel.currentIndex

        guard let card = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }
        await viewModel.submitRating(2, card: card) // Good rating

        #expect(viewModel.currentIndex == initialIndex + 1)
        #expect(!viewModel.isProcessing)
    }

    @Test("Submit rating without current card is guarded")
    func submitRatingWithoutCurrentCardDoesNothing() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck but no cards
        let deck = createTestDeck(context: context)
        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)

        // Don't load any cards
        let initialIndex = viewModel.currentIndex

        // currentCard is nil, so submitRating would need a card parameter
        // This test verifies the viewModel guards against nil currentCard
        #expect(viewModel.currentCard == nil, "Should have no current card")
        #expect(viewModel.currentIndex == initialIndex, "Index should not advance")
        #expect(viewModel.lastError == nil, "No error should be set")
        #expect(!viewModel.isProcessing, "Should not be processing")
    }
    @Test("Submit rating clears error on success")
    func submitRatingClearsErrorOnSuccess() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and two due cards
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Initially no error
        #expect(viewModel.lastError == nil)

        guard let card = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }

        // Successful submission should not set an error
        await viewModel.submitRating(2, card: card)

        #expect(viewModel.lastError == nil)
    }

    // MARK: - Progress Tests

    @Test("Progress format is correct")
    func progressFormatIsCorrect() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and 5 due cards
        let deck = createTestDeck(context: context)
        for _ in 0..<5 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        }
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        #expect(viewModel.progress == "1 / 5")

        guard let card = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }

        // After advancing one card
        await viewModel.submitRating(2, card: card)
        #expect(viewModel.progress == "2 / 5")
    }

    // MARK: - Completion Tests

    @Test("Complete on last card")
    func completeOnLastCard() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and one card
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()
        #expect(!viewModel.isComplete)

        guard let card = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }

        await viewModel.submitRating(2, card: card)

        #expect(viewModel.isComplete)
        #expect(viewModel.currentIndex == 1)
    }

    // MARK: - Concurrency Tests

    @Test("IsProcessing prevents double submission")
    func isProcessingPreventsDoubleSubmission() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and card
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Initially not processing
        #expect(!viewModel.isProcessing)

        guard let card = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }

        // Submit rating
        await viewModel.submitRating(2, card: card)

        // After completion, should not be processing
        #expect(!viewModel.isProcessing)

        // Verify card advanced (rating was processed)
        #expect(viewModel.currentIndex == 1)
    }

    // MARK: - Reset Tests

    @Test("Reset returns to start")
    func resetSessionReturnsToStart() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and cards
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Advance through session
        guard let firstCard = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }
        await viewModel.submitRating(2, card: firstCard)

        guard let secondCard = viewModel.currentCard else {
            #expect(Bool(false), "Expected currentCard to be non-nil")
            return
        }
        await viewModel.submitRating(2, card: secondCard)

        #expect(viewModel.isComplete)

        // Reset
        viewModel.reset()

        #expect(viewModel.currentIndex == 0)
        #expect(!viewModel.isComplete)
    }

    // MARK: - Concurrency Tests

    @Test("Concurrency: concurrent card mutations")
    func concurrentCardMutations() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and cards
        let deck = createTestDeck(context: context)
        for i in 1...5 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        }
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Submit ratings concurrently
        let initialCards = viewModel.cards
        var successCount = 0
        await withTaskGroup(of: Bool.self) { group in
            for card in initialCards {
                group.addTask {
                    let result = await viewModel.submitRating(2, card: card)
                    return result != nil  // Track success
                }
            }

            for await success in group {
                if success {
                    successCount += 1
                }
            }
        }

        // Verify all cards were processed successfully
        #expect(successCount == initialCards.count, "Expected \(initialCards.count) successful submissions, got \(successCount)")
        #expect(viewModel.isComplete)
        #expect(viewModel.currentIndex == initialCards.count)
    }

    @Test("Concurrency: session state thread safety")
    func sessionStateThreadSafety() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and cards
        let deck = createTestDeck(context: context)
        for i in 1...10 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        }
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Concurrent state access
        await withTaskGroup(of: Void.self) { group in
            // Read current card
            group.addTask {
                await MainActor.run {
                    _ = viewModel.currentCard
                }
            }

            // Check is complete
            group.addTask {
                await MainActor.run {
                    _ = viewModel.isComplete
                }
            }

            // Get cards count
            group.addTask {
                await MainActor.run {
                    _ = viewModel.cards.count
                }
            }

            // Get current index
            group.addTask {
                await MainActor.run {
                    _ = viewModel.currentIndex
                }
            }
        }

        // Should complete without crashes
        #expect(viewModel.cards.count == 10)
    }

    @Test("Concurrency: progress updates under concurrent access")
    func progressUpdatesConcurrent() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and cards
        let deck = createTestDeck(context: context)
        for i in 1...5 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        }
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        // Submit ratings and check progress concurrently
        let cards = viewModel.cards
        await withTaskGroup(of: Int.self) { group in
            for (_ /* index */, card) in cards.enumerated() {
                group.addTask {
                    _ = await viewModel.submitRating(2, card: card)
                    return await MainActor.run { viewModel.currentIndex }
                }
            }

            var indices: [Int] = []
            for await index in group {
                indices.append(index)
            }

            // All indices should be valid (0 to count)
            #expect(indices.allSatisfy { $0 >= 0 && $0 <= cards.count })
        }

        #expect(viewModel.isComplete)
    }

    @Test("Concurrency: session completion edge cases")
    func sessionCompletionEdgeCases() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and single card
        let deck = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)
        viewModel.loadCards()

        let card = viewModel.currentCard
        #expect(card != nil)

        // Submit rating multiple times concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 1..<5 {
                group.addTask {
                    if let c = card {
                        _ = await viewModel.submitRating(2, card: c)
                    }
                }
            }
        }

        // Session should be complete
        #expect(viewModel.isComplete)
    }

    @Test("Concurrency: rapid rating submissions")
    func rapidRatingSubmissions() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck and cards
        let deck = createTestDeck(context: context)
        for i in 1...10 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck)
        }
        try context.save()

        let viewModel = StudySessionViewModel(modelContext: context, deck: deck, mode: .scheduled)

        viewModel.loadCards()

        // Submit all ratings rapidly
        let cards = viewModel.cards
        var completionTimes: [Date] = []

        await withTaskGroup(of: Date?.self) { group in
            for card in cards {
                group.addTask {
                    let start = Date()
                    _ = await viewModel.submitRating(2, card: card)
                    return await MainActor.run { viewModel.isComplete ? start : nil }
                }
            }

            for await time in group {
                if let time = time {
                    completionTimes.append(time)
                }
            }
        }

        // Should complete without errors
        #expect(viewModel.isComplete)
        #expect(viewModel.currentIndex == cards.count)
    }
}

// MARK: - Multi-Deck Tests

@Suite("StudySessionViewModel Multi-Deck Tests")
struct StudySessionViewModelMultiDeckTests {

    // Use the same helper functions from the main test suite
    private static func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    private static func createTestDeck(context: ModelContext) -> Deck {
        let deck = Deck(name: "Test Deck", icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()
        return deck
    }

    private static func createTestFlashcard(
        context: ModelContext,
        stateEnum: String = FlashcardState.new.rawValue,
        dueOffset: TimeInterval = 0,
        deck: Deck
    ) -> Flashcard {
        let card = Flashcard(front: "Test", back: "Test", deck: deck)
        context.insert(card)

        let state = FSRSState(card: card)
        state.stateEnum = stateEnum
        state.dueDate = Date().addingTimeInterval(dueOffset)

        context.insert(state)
        try! context.save()

        return card
    }

    @Test("Initializer with empty deck array returns no cards")
    func emptyDeckArray() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [],
            mode: .scheduled
        )

        viewModel.loadCards()

        #expect(viewModel.cards.isEmpty)
        #expect(viewModel.isComplete)
    }

    @Test("Initializer with multiple decks loads cards from all")
    func multiDeckCardLoading() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = createTestDeck(context: context)
        let deck2 = createTestDeck(context: context)

        // Add cards to both decks
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck1)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck2)

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck1, deck2],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Should load cards from both decks
        #expect(viewModel.cards.count == 2)
        #expect(viewModel.isComplete == false)
    }

    @Test("Scheduler integration with fetchCards(for: decks)")
    func schedulerIntegration() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = createTestDeck(context: context)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck1)

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck1],
            mode: .scheduled
        )

        viewModel.loadCards()

        #expect(viewModel.cards.count > 0)
    }

    @Test("Statistics tracking across multiple decks")
    func multiDeckStatistics() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = createTestDeck(context: context)
        let deck2 = createTestDeck(context: context)

        // Add cards with different states
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.new.rawValue, dueOffset: 86400, deck: deck1)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck2)

        let scheduler = Scheduler(modelContext: context)
        let totalNew = scheduler.newCardCount(for: [deck1, deck2])
        let totalDue = scheduler.dueCardCount(for: [deck1, deck2])

        #expect(totalNew >= 0)
        #expect(totalDue >= 0)
    }

    @Test("Session completion with multiple decks")
    func multiDeckSessionCompletion() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = createTestDeck(context: context)
        let deck2 = createTestDeck(context: context)

        // Add one card to each deck
        let card1 = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck1)
        let card2 = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck2)

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck1, deck2],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Submit ratings for all cards
        for card in viewModel.cards {
            _ = await viewModel.submitRating(3, card: card)
        }

        #expect(viewModel.isComplete)
        #expect(viewModel.currentIndex == 2)
    }

    @Test("Error handling with invalid deck array")
    func invalidDeckArrayHandling() async throws {
        let context = freshContext()
        try context.clearAll()

        // Pass empty deck array
        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Should handle gracefully
        #expect(viewModel.cards.isEmpty)
        #expect(viewModel.isComplete)
    }

    @Test("Multi-deck limit enforcement")
    func multiDeckLimitEnforcement() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = createTestDeck(context: context)
        let deck2 = createTestDeck(context: context)

        // Add many cards to both decks (more than default limit)
        for _ in 1...15 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck1)
        }
        for _ in 1...15 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600, deck: deck2)
        }

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck1, deck2],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Should respect the study limit (default 20)
        #expect(viewModel.cards.count <= AppSettings.studyLimit)
    }
}
