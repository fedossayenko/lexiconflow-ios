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

    // MARK: - Retrievability Calculation Tests

    @Test("Retrievability formula matches expected calculation: 1.0 - elapsedDays / stability")
    func retrievabilityFormulaAccuracy() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set specific stability and last review to predict retrievability
        flashcard.fsrsState!.stability = 10.0
        flashcard.fsrsState!.lastReviewDate = Date().addingTimeInterval(-5 * 86400) // 5 days ago
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2, // Good
            now: Date()
        )

        // Verify the formula: retrievability = 1.0 - elapsedSinceReview / stability
        // With stability=10, scheduledDays should be based on FSRS calculation
        // The elapsedSinceReview is from now to dueDate
        let elapsedSinceReview = DateMath.elapsedDays(from: Date(), to: result.dueDate)
        let expectedRetrievability = max(0.0, min(1.0, 1.0 - elapsedSinceReview / result.stability))

        #expect(abs(result.retrievability - expectedRetrievability) < 0.001,
               "Retrievability should match formula: 1.0 - elapsedSinceReview / stability")
    }

    @Test("Retrievability clamped to 0-1 range for extreme values")
    func retrievabilityClamping() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Very low stability with large elapsed time should clamp to 0
        flashcard.fsrsState!.stability = 0.1
        flashcard.fsrsState!.lastReviewDate = Date().addingTimeInterval(-100 * 86400) // 100 days ago
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        #expect(result.retrievability >= 0.0, "Retrievability should not be negative")
        #expect(result.retrievability <= 1.0, "Retrievability should not exceed 1.0")
    }

    // MARK: - Clock Skew Tests

    @Test("Clock skew with future lastReviewDate handles gracefully")
    func clockSkewFutureLastReview() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Set lastReviewDate in the future (clock skew scenario)
        let futureDate = Date().addingTimeInterval(86400) // 1 day in future
        flashcard.fsrsState!.lastReviewDate = futureDate
        flashcard.fsrsState!.stability = 10.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: Date()
        )

        // Should handle negative elapsed days without crashing
        #expect(result.retrievability >= 0.0 && result.retrievability <= 1.0)
        #expect(result.dueDate > Date())
    }

    @Test("Clock skew across DST boundary calculates elapsed days correctly")
    func clockSkewDSTBoundary() async throws {
        let context = freshContext()
        try context.clearAll()
        let flashcard = createTestFlashcard(context: context, withState: true)

        // Create a date across a DST boundary (e.g., during spring forward)
        // Use calendar to ensure proper DST handling
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day:15, hour: 12))!
        let lastReview = calendar.date(from: DateComponents(year: 2026, month=3, day: 8, hour: 12))!

        flashcard.fsrsState!.lastReviewDate = lastReview
        flashcard.fsrsState!.stability = 10.0
        try context.save()

        let result = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 2,
            now: now
        )

        // DateMath should handle DST transitions correctly
        #expect(result.elapsedDays >= 6.0 && result.elapsedDays <= 8.0,
               "Elapsed days should account for DST transition")
    }
}
