//
//  FSRSWrapperTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for FSRS algorithm integration
//  Updated for DTO-based API (tests data transfer instead of mutation)
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for FSRSWrapper actor with DTO API
///
/// Tests verify:
/// - DTO accuracy from FSRS algorithm
/// - State value calculations
/// - Rating mappings
/// - Edge cases and error handling
@MainActor
struct FSRSWrapperTests {

    // MARK: - Test Fixtures

    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    /// Create a test flashcard with optional FSRS state (does NOT save - caller must save)
    private func createTestFlashcard(context: ModelContext, word: String = "test", withState: Bool = false) -> Flashcard {
        let flashcard = Flashcard(
            word: word,
            definition: "a test",
            phonetic: "tɛst"
        )

        if withState {
            let state = FSRSState(
                stability: 10.0,
                difficulty: 5.0,
                retrievability: 0.9,
                dueDate: Date(),
                stateEnum: FlashcardState.review.rawValue
            )
            context.insert(state)
            flashcard.fsrsState = state
        }

        context.insert(flashcard)
        return flashcard
    }

    // MARK: - DTO Tests

    @Test("Process review returns DTO with correct values for new card")
    func dtoNewCardValues() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: false)
        try context.save()
        let now = Date()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2, // Good
            now: now
        )

        // Verify DTO contains expected values
        #expect(result.stability > 0)
        #expect(result.difficulty > 0 && result.difficulty <= 10)
        #expect(result.retrievability >= 0 && result.retrievability <= 1)
        #expect(result.dueDate > now)
        #expect(result.stateEnum == FlashcardState.review.rawValue ||
                result.stateEnum == FlashcardState.learning.rawValue)
        #expect(result.scheduledDays > 0)
        #expect(result.elapsedDays == 0) // New card has no elapsed time
    }

    @Test("DTO scheduled days differ by rating")
    func dtoScheduledDifferences() async throws {
        let context = freshContext()
        let baseDate = Date()

        var scheduledDays: [Int: Double] = [:]

        for rating in 0...3 {
            try context.clearAll()
            let flashcard = createTestFlashcard(context: context, word: "card\(rating)")
            try context.save()
            let result = try await FSRSWrapper.shared.processReview(
                flashcard: flashcard,
                rating: rating,
                now: baseDate
            )
            scheduledDays[rating] = result.scheduledDays
        }

        // Again (0) should have shortest interval
        #expect(scheduledDays[0]! < scheduledDays[1]!)
        // Easy (3) should have longest interval
        #expect(scheduledDays[3]! > scheduledDays[2]!)
        #expect(scheduledDays[3]! > scheduledDays[1]!)
    }

    @Test("DTO stability increases with good ratings")
    func dtoStabilityIncrease() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)
        try context.save()

        // Use the default stability (10.0) from createTestFlashcard
        // FSRS should increase stability for a well-learned card rated Easy
        let initialStability = flashcard.fsrsState!.stability

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 3, // Easy
            now: Date()
        )

        #expect(result.stability >= initialStability, "Easy rating should maintain or increase stability")
    }

    @Test("DTO difficulty adjusts based on rating")
    func dtoDifficultyAdjustment() async throws {
        let context = freshContext()

        // Test Again rating (should increase difficulty)
        try context.clearAll()
        let flashcard1 = createTestFlashcard(context: context, word: "again_test", withState: true)
        try context.save()
        let initialDifficulty = flashcard1.fsrsState!.difficulty

        let resultAgain = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard1,
            rating: 0, // Again
            now: Date()
        )

        #expect(resultAgain.difficulty >= initialDifficulty)

        // Test Easy rating (should decrease difficulty)
        try context.clearAll()
        let flashcard2 = createTestFlashcard(context: context, word: "easy_test", withState: true)
        try context.save()
        let resultEasy = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard2,
            rating: 3, // Easy
            now: Date()
        )

        #expect(resultEasy.difficulty <= flashcard2.fsrsState!.difficulty)
    }

    @Test("DTO state transitions correctly")
    func dtoStateTransitions() async throws {
        let context = freshContext()

        // New → Learning (Again rating)
        try context.clearAll()
        let flashcard1 = createTestFlashcard(context: context, word: "new_to_learning", withState: false)
        try context.save()
        let result1 = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard1,
            rating: 0, // Again
            now: Date()
        )
        #expect(result1.stateEnum == FlashcardState.learning.rawValue ||
                result1.stateEnum == FlashcardState.relearning.rawValue)

        // Review → Relearning (Again on review card)
        try context.clearAll()
        let flashcard2 = createTestFlashcard(context: context, word: "review_to_relearning", withState: true)
        flashcard2.fsrsState!.stateEnum = FlashcardState.review.rawValue
        try context.save()

        let result2 = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard2,
            rating: 0, // Again
            now: Date()
        )
        #expect(result2.stateEnum == FlashcardState.relearning.rawValue)
    }

    @Test("Reset DTO returns to new state values")
    func dtoResetValues() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set to review state with high values
        flashcard.fsrsState!.stateEnum = FlashcardState.review.rawValue
        flashcard.fsrsState!.stability = 50.0
        flashcard.fsrsState!.difficulty = 8.0
        try context.save()

        let result = await FSRSWrapper.shared.resetFlashcard(flashcard, now: Date())

        #expect(result.stateEnum == FlashcardState.new.rawValue)
        #expect(result.dueDate <= Date()) // Should be due now
        #expect(result.retrievability == 0.9) // Reset to default
    }

    // MARK: - Preview Tests

    @Test("Preview returns all four rating options")
    func previewCompleteness() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)
        try context.save()

        let previews = await FSRSWrapper.shared.previewRatings(flashcard: flashcard)

        #expect(previews.count == 4)
        #expect(previews[0] != nil)
        #expect(previews[1] != nil)
        #expect(previews[2] != nil)
        #expect(previews[3] != nil)
    }

    @Test("Preview due dates are correctly ordered")
    func previewOrdering() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)
        try context.save()

        let previews = await FSRSWrapper.shared.previewRatings(flashcard: flashcard)

        // Should be ordered: Again < Hard < Good < Easy
        #expect(previews[0]! < previews[1]!)
        #expect(previews[1]! < previews[2]!)
        #expect(previews[2]! < previews[3]!)
    }

    // MARK: - Edge Case Tests

    @Test("Invalid rating defaults to Good")
    func invalidRatingHandling() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: false)
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 99, // Invalid
            now: Date()
        )

        // Should default to Good behavior
        #expect(result.stateEnum == FlashcardState.review.rawValue ||
                result.stateEnum == FlashcardState.learning.rawValue)
    }

    @Test("Handles negative elapsed days (clock skew)")
    func negativeElapsedDays() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set lastReviewDate in future (clock skew)
        let futureDate = Date().addingTimeInterval(3600) // 1 hour ahead
        flashcard.fsrsState!.lastReviewDate = futureDate
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should handle gracefully (elapsedDays may be negative)
        #expect(result.dueDate > Date())
    }

    @Test("Zero stability calculates retrievability safely")
    func zeroStabilityRetrievability() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.stability = 0.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Retrievability should be in valid range
        #expect(result.retrievability >= 0.0)
        #expect(result.retrievability <= 1.0)
    }

    // MARK: - FSRS Edge Case Tests

    @Test("Negative stability values are handled")
    func negativeStabilityValues() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set negative stability (edge case)
        flashcard.fsrsState!.stability = -10.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // FSRS should handle this gracefully
        // Stability should be adjusted to valid range
        #expect(result.stability >= 0, "Stability should be non-negative after processing")
    }

    @Test("Extreme difficulty value of 0 is handled")
    func extremeDifficultyZero() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.difficulty = 0.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Difficulty should be adjusted to valid range
        #expect(result.difficulty >= 1 && result.difficulty <= 10, "Difficulty should be in valid range")
    }

    @Test("Extreme difficulty value of 10 is handled")
    func extremeDifficultyTen() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.difficulty = 10.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should handle max difficulty
        #expect(result.difficulty <= 10, "Difficulty should not exceed 10")
    }

    @Test("Invalid difficulty value below 0 is clamped")
    func invalidDifficultyBelowZero() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.difficulty = -1.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should clamp to valid range
        #expect(result.difficulty >= 1 && result.difficulty <= 10, "Difficulty should be in valid range")
    }

    @Test("Invalid difficulty value above 10 is clamped")
    func invalidDifficultyAboveTen() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.difficulty = 11.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should clamp to valid range
        #expect(result.difficulty >= 1 && result.difficulty <= 10, "Difficulty should be in valid range")
    }

    @Test("Zero retrievability is handled")
    func zeroRetrievability() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        flashcard.fsrsState!.retrievability = 0.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should handle zero retrievability
        #expect(result.retrievability >= 0, "Retrievability should be non-negative")
    }

    @Test("Negative scheduled days are handled")
    func negativeScheduledDays() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set a past due date
        flashcard.fsrsState!.dueDate = Date().addingTimeInterval(-86400) // 1 day ago
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should schedule for future despite past due date
        #expect(result.scheduledDays >= 0, "Scheduled days should be non-negative")
        #expect(result.dueDate > Date(), "Due date should be in the future")
    }

    @Test("Very large elapsed days (1000+) is handled")
    func veryLargeElapsedDays() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Simulate card reviewed 1000 days ago
        let pastDate = Date().addingTimeInterval(-86400 * 1000)
        flashcard.fsrsState!.lastReviewDate = pastDate
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should handle large elapsed time gracefully
        #expect(result.elapsedDays >= 1000, "Should recognize large elapsed time")
        #expect(result.dueDate > Date(), "Should still schedule for future")
    }

    @Test("New to learning state transition works")
    func newToLearningTransition() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: false)

        // New card (no state yet)
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 0, // Again - should move to learning
            now: Date()
        )

        // Should transition from new to learning
        #expect(result.stateEnum == FlashcardState.learning.rawValue ||
                result.stateEnum == FlashcardState.relearning.rawValue,
                "Should transition to learning state")
    }

    @Test("State enum handles all valid values")
    func stateEnumValidValues() async throws {
        let context = freshContext()
        try context.clearAll()

        for stateEnum in [FlashcardState.new.rawValue, FlashcardState.learning.rawValue,
                       FlashcardState.review.rawValue, FlashcardState.relearning.rawValue] {
            let flashcard = createTestFlashcard(context: context, word: "state_\(stateEnum)", withState: true)
            flashcard.fsrsState!.stateEnum = stateEnum
            try context.save()

            let result = try await FSRSWrapper.shared.processReview(
                flashcard: flashcard,
                rating: 2,
                now: Date()
            )

            // Should process without error
            #expect(result.stateEnum != "", "State enum should be valid")
        }
    }
}
