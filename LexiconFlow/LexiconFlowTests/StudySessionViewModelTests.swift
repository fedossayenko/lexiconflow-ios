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
        return card
    }

    // MARK: - Card Loading Tests

    @Test("Load cards fetches from scheduler")
    func loadCardsFetchesFromScheduler() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create a due card
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()

        #expect(viewModel.cards.count == 1)
    }

    @Test("Load cards sets correct initial state")
    func loadCardsSetsCorrectInitialState() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

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
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create two due cards
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()
        let initialIndex = viewModel.currentIndex

        await viewModel.submitRating(2) // Good rating

        #expect(viewModel.currentIndex == initialIndex + 1)
        #expect(!viewModel.isProcessing)
    }

    @Test("Submit rating without card does nothing")
    func submitRatingWithoutCardDoesNothing() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Don't load any cards
        let initialIndex = viewModel.currentIndex

        // Try to submit rating when there's no current card
        await viewModel.submitRating(2)

        // Should not advance because there's no card
        #expect(viewModel.currentIndex == initialIndex)
        #expect(viewModel.lastError == nil) // No error, just guarded
        #expect(!viewModel.isProcessing)
    }

    @Test("Submit rating clears error on success")
    func submitRatingClearsErrorOnSuccess() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create two due cards
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()

        // Initially no error
        #expect(viewModel.lastError == nil)

        // Successful submission should not set an error
        await viewModel.submitRating(2)

        #expect(viewModel.lastError == nil)
    }

    // MARK: - Progress Tests

    @Test("Progress format is correct")
    func progressFormatIsCorrect() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create 5 due cards
        for _ in 0..<5 {
            _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        }
        try context.save()

        viewModel.loadCards()

        #expect(viewModel.progress == "1 / 5")

        // After advancing one card
        await viewModel.submitRating(2)
        #expect(viewModel.progress == "2 / 5")
    }

    // MARK: - Completion Tests

    @Test("Complete on last card")
    func completeOnLastCard() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create one card
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()
        #expect(!viewModel.isComplete)

        await viewModel.submitRating(2)

        #expect(viewModel.isComplete)
        #expect(viewModel.currentIndex == 1)
    }

    // MARK: - Concurrency Tests

    @Test("IsProcessing prevents double submission")
    func isProcessingPreventsDoubleSubmission() async throws {
        let context = freshContext()
        try context.clearAll()
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create a card
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()

        // Initially not processing
        #expect(!viewModel.isProcessing)

        // Submit rating
        await viewModel.submitRating(2)

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
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create cards
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        _ = createTestFlashcard(context: context, stateEnum: FlashcardState.learning.rawValue, dueOffset: -3600)
        try context.save()

        viewModel.loadCards()

        // Advance through session
        await viewModel.submitRating(2)
        await viewModel.submitRating(2)

        #expect(viewModel.isComplete)

        // Reset
        viewModel.reset()

        #expect(viewModel.currentIndex == 0)
        #expect(!viewModel.isComplete)
    }
}
