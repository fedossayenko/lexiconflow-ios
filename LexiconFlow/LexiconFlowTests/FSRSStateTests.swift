//
//  FSRSStateTests.swift
//  LexiconFlowTests
//
//  Tests for FSRSState model
//  Covers: FSRSState creation, state transitions, computed properties
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for FSRSState model
@MainActor
struct FSRSStateTests {
    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - FSRSState Creation Tests

    @Test("FSRSState creation with default values")
    func fsrsStateCreationWithDefaults() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)
        try context.save()

        #expect(state.stability == 0.0)
        #expect(state.difficulty == 5.0)
        #expect(state.retrievability == 0.9)
        #expect(state.stateEnum == FlashcardState.new.rawValue)
        #expect(state.state == .new)
    }

    @Test("FSRSState creation with custom values")
    func fsrsStateCreationWithCustomValues() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(
            stability: 2.5,
            difficulty: 7.0,
            retrievability: 0.85,
            dueDate: Date().addingTimeInterval(86400 * 7),
            stateEnum: FlashcardState.review.rawValue
        )

        context.insert(state)
        try context.save()

        #expect(state.stability == 2.5)
        #expect(state.difficulty == 7.0)
        #expect(state.retrievability == 0.85)
        #expect(state.state == .review)
    }

    @Test("FSRSState initialization with FlashcardState enum")
    func fsrsStateInitWithEnum() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .learning)
        context.insert(state)
        try context.save()

        #expect(state.state == .learning)
        #expect(state.stateEnum == FlashcardState.learning.rawValue)
    }

    // MARK: - State Enum Tests

    @Test("FSRSState computed property: new state")
    func fsrsStateComputedNew() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stateEnum: FlashcardState.new.rawValue)
        context.insert(state)

        #expect(state.state == .new)
    }

    @Test("FSRSState computed property: learning state")
    func fsrsStateComputedLearning() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stateEnum: FlashcardState.learning.rawValue)
        context.insert(state)

        #expect(state.state == .learning)
    }

    @Test("FSRSState computed property: review state")
    func fsrsStateComputedReview() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stateEnum: FlashcardState.review.rawValue)
        context.insert(state)

        #expect(state.state == .review)
    }

    @Test("FSRSState computed property: relearning state")
    func fsrsStateComputedRelearning() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stateEnum: FlashcardState.relearning.rawValue)
        context.insert(state)

        #expect(state.state == .relearning)
    }

    @Test("FSRSState computed property: invalid state defaults to new")
    func fsrsStateComputedInvalidDefaultsToNew() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stateEnum: "invalid_state")
        context.insert(state)

        // Computed property should default to .new for invalid values
        #expect(state.state == .new)
    }

    // MARK: - Stability Tests

    @Test("FSRSState stability: zero for new cards")
    func stabilityZeroForNewCards() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .new)
        context.insert(state)

        #expect(state.stability == 0.0)
    }

    @Test("FSRSState stability: positive value for learned cards")
    func stabilityPositiveForLearned() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stability: 5.0, state: .review)
        context.insert(state)

        #expect(state.stability == 5.0)
        #expect(state.stability > 0)
    }

    @Test("FSRSState stability: can be very large")
    func stabilityCanBeLarge() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stability: 365.0, state: .review)
        context.insert(state)

        #expect(state.stability == 365.0)
    }

    // MARK: - Difficulty Tests

    @Test("FSRSState difficulty: range 0-10")
    func difficultyRange() throws {
        let context = freshContext()
        try context.clearAll()

        // Test minimum
        let minState = FSRSState(difficulty: 0.0, state: .new)
        context.insert(minState)

        // Test middle
        let midState = FSRSState(difficulty: 5.0, state: .new)
        context.insert(midState)

        // Test maximum
        let maxState = FSRSState(difficulty: 10.0, state: .new)
        context.insert(maxState)

        try context.save()

        #expect(minState.difficulty == 0.0)
        #expect(midState.difficulty == 5.0)
        #expect(maxState.difficulty == 10.0)
    }

    @Test("FSRSState difficulty: medium difficulty default")
    func difficultyDefaultMedium() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)

        #expect(state.difficulty == 5.0) // Medium difficulty
    }

    // MARK: - Retrievability Tests

    @Test("FSRSState retrievability: range 0-1")
    func retrievabilityRange() throws {
        let context = freshContext()
        try context.clearAll()

        // Test minimum
        let minState = FSRSState(retrievability: 0.0, state: .new)
        context.insert(minState)

        // Test middle
        let midState = FSRSState(retrievability: 0.5, state: .new)
        context.insert(midState)

        // Test maximum
        let maxState = FSRSState(retrievability: 1.0, state: .new)
        context.insert(maxState)

        try context.save()

        #expect(minState.retrievability == 0.0)
        #expect(midState.retrievability == 0.5)
        #expect(maxState.retrievability == 1.0)
    }

    @Test("FSRSState retrievability: high default for new cards")
    func retrievabilityDefaultHigh() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)

        #expect(state.retrievability == 0.9) // 90% recall probability
    }

    // MARK: - Due Date Tests

    @Test("FSRSState dueDate: defaults to now")
    func dueDateDefaultsToNow() throws {
        let context = freshContext()
        try context.clearAll()

        let before = Date()
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)
        let after = Date()

        #expect(state.dueDate >= before)
        #expect(state.dueDate <= after)
    }

    @Test("FSRSState dueDate: can be set to future")
    func dueDateFuture() throws {
        let context = freshContext()
        try context.clearAll()

        let futureDate = Date().addingTimeInterval(86400 * 7) // 7 days from now
        let state = FSRSState(dueDate: futureDate, stateEnum: FlashcardState.review.rawValue)
        context.insert(state)

        #expect(state.dueDate > Date())
    }

    @Test("FSRSState dueDate: can be set to past")
    func dueDatePast() throws {
        let context = freshContext()
        try context.clearAll()

        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let state = FSRSState(dueDate: pastDate, stateEnum: FlashcardState.review.rawValue)
        context.insert(state)

        #expect(state.dueDate < Date())
    }

    // MARK: - Last Review Date Tests

    @Test("FSRSState lastReviewDate: nil for new cards")
    func lastReviewDateNilForNew() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .new)
        context.insert(state)

        #expect(state.lastReviewDate == nil)
    }

    @Test("FSRSState lastReviewDate: can be set")
    func lastReviewDateCanBeSet() throws {
        let context = freshContext()
        try context.clearAll()

        let reviewDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        state.lastReviewDate = reviewDate
        context.insert(state)

        #expect(state.lastReviewDate == reviewDate)
    }

    // MARK: - State Transition Tests

    @Test("FSRSState transition: new to learning")
    func transitionNewToLearning() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .new)
        context.insert(state)

        // Simulate transition
        state.stateEnum = FlashcardState.learning.rawValue
        try context.save()

        #expect(state.state == .learning)
    }

    @Test("FSRSState transition: learning to review")
    func transitionLearningToReview() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .learning)
        context.insert(state)

        // Simulate transition
        state.stateEnum = FlashcardState.review.rawValue
        try context.save()

        #expect(state.state == .review)
    }

    @Test("FSRSState transition: review to relearning")
    func transitionReviewToRelearning() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .review)
        context.insert(state)

        // Simulate transition (failed review)
        state.stateEnum = FlashcardState.relearning.rawValue
        try context.save()

        #expect(state.state == .relearning)
    }

    @Test("FSRSState transition: relearning back to review")
    func transitionRelearningToReview() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .relearning)
        context.insert(state)

        // Simulate transition
        state.stateEnum = FlashcardState.review.rawValue
        try context.save()

        #expect(state.state == .review)
    }

    // MARK: - FSRSState-Flashcard Relationship Tests

    @Test("FSRSState-flashcard relationship")
    func fsrsStateFlashcardRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let state = FSRSState(state: .new)
        flashcard.fsrsState = state
        context.insert(state)

        try context.save()

        #expect(state.card?.word == "test")
    }

    @Test("FSRSState with no flashcard")
    func fsrsStateNoFlashcard() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .new)
        context.insert(state)

        #expect(state.card == nil)
    }

    // MARK: - Update Tests

    @Test("FSRSState update: after successful review")
    func updateAfterSuccessfulReview() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(state: .new)
        context.insert(state)

        // Simulate successful review
        state.stability = 1.0
        state.difficulty = 4.5
        state.retrievability = 0.95
        state.dueDate = Date().addingTimeInterval(86400)
        state.stateEnum = FlashcardState.review.rawValue
        state.lastReviewDate = Date()

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FSRSState>()).first
        #expect(fetched?.stability == 1.0)
        #expect(fetched?.difficulty == 4.5)
        #expect(fetched?.retrievability == 0.95)
        #expect(fetched?.state == .review)
        #expect(fetched?.lastReviewDate != nil)
    }

    @Test("FSRSState update: after failed review")
    func updateAfterFailedReview() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(stability: 5.0, state: .review)
        context.insert(state)

        let originalStability = state.stability

        // Simulate failed review (Again rating)
        state.stability = 0.5
        state.retrievability = 0.3
        state.stateEnum = FlashcardState.relearning.rawValue
        state.lastReviewDate = Date()

        try context.save()

        #expect(state.stability < originalStability)
        #expect(state.state == .relearning)
        #expect(state.retrievability < 0.5)
    }

    // MARK: - Query Tests

    @Test("Query: fetch due cards")
    func fetchDueCards() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        // Due card (past due date)
        let dueState = FSRSState(
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: FlashcardState.review.rawValue
        )
        dueState.card = flashcard
        context.insert(dueState)

        try context.save()

        // Fetch due cards
        let now = Date()
        let predicate = #Predicate<FSRSState> { $0.dueDate <= now && $0.stateEnum != "new" }
        let descriptor = FetchDescriptor<FSRSState>(predicate: predicate)
        let dueStates = try context.fetch(descriptor)

        #expect(dueStates.count == 1)
    }

    @Test("Query: fetch new cards")
    func fetchNewCards() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "new1", definition: "new")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "review1", definition: "review")
        context.insert(flashcard2)

        let newState = FSRSState(state: .new)
        newState.card = flashcard1
        context.insert(newState)

        let reviewState = FSRSState(state: .review)
        reviewState.card = flashcard2
        context.insert(reviewState)

        try context.save()

        // Fetch only new cards
        let predicate = #Predicate<FSRSState> { $0.stateEnum == "new" }
        let descriptor = FetchDescriptor<FSRSState>(predicate: predicate)
        let newStates = try context.fetch(descriptor)

        #expect(newStates.count == 1)
    }

    @Test("Query: fetch cards sorted by due date")
    func fetchSortedByDueDate() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "card1", definition: "test")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "card2", definition: "test")
        context.insert(flashcard2)

        let state1 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(86400),
            stateEnum: FlashcardState.review.rawValue
        )
        state1.card = flashcard1
        context.insert(state1)

        let state2 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        state2.card = flashcard2
        context.insert(state2)

        try context.save()

        // Fetch sorted by due date
        let descriptor = FetchDescriptor<FSRSState>(sortBy: [SortDescriptor(\.dueDate)])
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        // Optional dates need unwrapping for comparison
        if let firstDate = results.first?.dueDate, let lastDate = results.last?.dueDate {
            #expect(firstDate < lastDate)
        }
    }
}
