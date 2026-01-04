//
//  FSRSWrapper.swift
//  LexiconFlow
//
//  Thread-safe wrapper for SwiftFSRS algorithm
//  Handles conversion between SwiftData models and SwiftFSRS types
//  Refactored to return DTOs instead of mutating models
//

import Foundation
import FSRS

// MARK: - Data Transfer Objects

/// Result of processing a review with FSRS algorithm
///
/// **Why DTO?**: Returning data instead of mutating models prevents
/// cross-actor concurrency issues and makes the code more testable.
struct FSRSReviewResult: Sendable {
    /// Updated stability value
    let stability: Double

    /// Updated difficulty value
    let difficulty: Double

    /// New due date for next review
    let dueDate: Date

    /// New state as raw value string
    let stateEnum: String

    /// Calculated retrievability (0-1 scale)
    let retrievability: Double

    /// Days until next review
    let scheduledDays: Double

    /// Days elapsed since last review
    let elapsedDays: Double
}

/// Actor-isolated wrapper for FSRS algorithm operations
///
/// FSRS is not thread-safe by default, so we use an actor to ensure
/// all algorithm operations are serialized and safe to call from anywhere.
actor FSRSWrapper {
    /// Shared singleton instance for app-wide access
    static let shared = FSRSWrapper()

    /// The underlying FSRS algorithm instance
    private let fsrs: FSRS

    /// Private initializer for singleton pattern
    private init() {
        // Create FSRS instance with default parameters
        let params = FSRSParameters()
        self.fsrs = FSRS(parameters: params)
    }

    // MARK: - Type Conversions

    /// Convert SwiftData Flashcard to FSRS Card
    ///
    /// **Performance**: Uses cached lastReviewDate for O(1) access instead
    /// of O(n) scan through reviewLogs.
    ///
    /// - Parameters:
    ///   - flashcard: Our SwiftData Flashcard model
    ///   - elapsedDays: Days since last review (calculated by caller)
    /// - Returns: FSRS Card ready for algorithm processing
    private func toFSCard(_ flashcard: Flashcard, elapsedDays: Double) -> Card {
        let fsrsState = flashcard.fsrsState

        // Use cached lastReviewDate if available (O(1) vs O(n) scan)
        let lastReview = fsrsState?.lastReviewDate

        return Card(
            due: fsrsState?.dueDate ?? Date(),
            stability: fsrsState?.stability ?? 0.0,
            difficulty: fsrsState?.difficulty ?? 5.0,
            elapsedDays: elapsedDays,
            scheduledDays: 0,
            reps: flashcard.reviewLogs.count,
            lapses: flashcard.reviewLogs.filter { $0.rating == 0 }.count,
            state: toFSCardState(fsrsState?.stateEnum),
            lastReview: lastReview
        )
    }

    /// Convert our FlashcardState rawValue to FSRS CardState
    private func toFSCardState(_ stateEnum: String?) -> CardState {
        switch stateEnum {
        case "new", nil:
            return CardState.new
        case "learning":
            return CardState.learning
        case "review":
            return CardState.review
        case "relearning":
            return CardState.relearning
        default:
            return CardState.new
        }
    }

    // MARK: - Public API

    /// Process a flashcard review using the FSRS algorithm
    ///
    /// **Refactored**: Now returns a DTO instead of mutating the flashcard directly.
    /// The caller (Scheduler on @MainActor) is responsible for applying the updates.
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard being reviewed
    ///   - rating: The user's rating (0=Again, 1=Hard, 2=Good, 3=Easy)
    ///   - now: Current time (defaults to Date())
    /// - Returns: DTO with updated FSRS state values
    func processReview(
        flashcard: Flashcard,
        rating: Int,
        now: Date = Date()
    ) throws -> FSRSReviewResult {
        // Calculate elapsed days using timezone-aware math
        let elapsedDays: Double
        if let lastReview = flashcard.fsrsState?.lastReviewDate {
            elapsedDays = DateMath.elapsedDays(from: lastReview, to: now)
        } else {
            elapsedDays = 0.0
        }

        let fsrsCard = toFSCard(flashcard, elapsedDays: elapsedDays)

        // Convert our rating (0-3) to FSRS Rating (again=1, hard=2, good=3, easy=4)
        let fsrsRating: Rating
        switch rating {
        case 0: fsrsRating = Rating.again
        case 1: fsrsRating = Rating.hard
        case 2: fsrsRating = Rating.good
        case 3: fsrsRating = Rating.easy
        default: fsrsRating = Rating.good
        }

        let result = try fsrs.next(card: fsrsCard, now: now, grade: fsrsRating)

        // Calculate retrievability based on new stability
        let retrievability: Double
        if result.card.stability > 0 {
            let elapsedSinceReview = DateMath.elapsedDays(from: now, to: result.card.due)
            retrievability = max(0.0, min(1.0, 1.0 - elapsedSinceReview / result.card.stability))
        } else {
            retrievability = 0.9
        }

        // Convert FSRS CardState to our FlashcardState rawValue
        let stateEnum: String
        switch result.card.state {
        case .new:
            stateEnum = FlashcardState.new.rawValue
        case .learning:
            stateEnum = FlashcardState.learning.rawValue
        case .review:
            stateEnum = FlashcardState.review.rawValue
        case .relearning:
            stateEnum = FlashcardState.relearning.rawValue
        }

        let scheduledDays = result.card.due.timeIntervalSince(now) / 86400.0

        return FSRSReviewResult(
            stability: result.card.stability,
            difficulty: result.card.difficulty,
            dueDate: result.card.due,
            stateEnum: stateEnum,
            retrievability: retrievability,
            scheduledDays: scheduledDays,
            elapsedDays: elapsedDays
        )
    }

    /// Get preview of all 4 rating options for a flashcard
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard to preview
    ///   - now: Current time (defaults to Date())
    /// - Returns: Dictionary mapping ratings (0-3) to due dates
    func previewRatings(
        flashcard: Flashcard,
        now: Date = Date()
    ) -> [Int: Date] {
        // Calculate elapsed days using cached lastReviewDate
        let elapsedDays: Double
        if let lastReview = flashcard.fsrsState?.lastReviewDate {
            elapsedDays = DateMath.elapsedDays(from: lastReview, to: now)
        } else {
            elapsedDays = 0.0
        }

        let fsrsCard = toFSCard(flashcard, elapsedDays: elapsedDays)
        let preview = fsrs.repeat(card: fsrsCard, now: now)

        // Use the public subscript to access preview for each rating
        return [
            0: preview[.again]?.card.due ?? Date(),
            1: preview[.hard]?.card.due ?? Date(),
            2: preview[.good]?.card.due ?? Date(),
            3: preview[.easy]?.card.due ?? Date()
        ]
    }

    /// Reset a flashcard's FSRS state to new (forgetting)
    ///
    /// **Refactored**: Now returns a DTO instead of mutating the flashcard.
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard to reset
    ///   - now: Current time (defaults to Date())
    /// - Returns: DTO with reset FSRS state values
    func resetFlashcard(
        _ flashcard: Flashcard,
        now: Date = Date()
    ) -> FSRSReviewResult {
        // Calculate elapsed days using cached lastReviewDate
        let elapsedDays: Double
        if let lastReview = flashcard.fsrsState?.lastReviewDate {
            elapsedDays = DateMath.elapsedDays(from: lastReview, to: now)
        } else {
            elapsedDays = 0.0
        }

        let fsrsCard = toFSCard(flashcard, elapsedDays: elapsedDays)
        let result = fsrs.forget(card: fsrsCard, now: now)

        // Convert FSRS CardState to our FlashcardState rawValue
        let stateEnum: String
        switch result.card.state {
        case .new:
            stateEnum = FlashcardState.new.rawValue
        case .learning:
            stateEnum = FlashcardState.learning.rawValue
        case .review:
            stateEnum = FlashcardState.review.rawValue
        case .relearning:
            stateEnum = FlashcardState.relearning.rawValue
        }

        return FSRSReviewResult(
            stability: result.card.stability,
            difficulty: result.card.difficulty,
            dueDate: result.card.due,
            stateEnum: stateEnum,
            retrievability: 0.9, // Reset retrievability for new cards
            scheduledDays: 0,
            elapsedDays: elapsedDays
        )
    }
}
