//
//  FSRSState.swift
//  LexiconFlow
//
//  FSRS v5 Algorithm State Model
//  Encapsulates the mathematical state of the Free Spaced Repetition Scheduler
//

import Foundation
import SwiftData

/// FSRS algorithm state for tracking memory retention
///
/// This model stores the three core FSRS parameters:
/// - Stability (S): How long memory persists before dropping below threshold
/// - Difficulty (D): How hard the item is to learn (0-10 scale)
/// - Retrievability (R): Probability of recall at current time (0-1 scale)
@Model
final class FSRSState {
    /// Stability parameter: How long memory remains stable
    /// - Range: 0 to ∞
    /// - Higher = more stable memory (longer intervals)
    /// - Default: 0.0 (new card)
    var stability: Double

    /// Difficulty parameter: How hard the item is
    /// - Range: 0 (easy) to 10 (hard)
    /// - Default: 5.0 (medium difficulty)
    var difficulty: Double

    /// Retrievability: Probability of successful recall
    /// - Range: 0.0 (certain failure) to 1.0 (certain success)
    /// - Default: 0.9 (90% recall probability)
    /// - Updates each time a review occurs
    var retrievability: Double

    /// When the next review is due
    /// - Defaults to Date() (due now) for new cards
    var dueDate: Date

    /// Learning state as string for CloudKit compatibility
    /// - "new": Never been reviewed
    /// - "learning": In initial learning phase
    /// - "review": In long-term retention phase
    /// - "relearning": Relearning after failed review
    var stateEnum: String

    /// Cached last review date for O(1) access
    ///
    /// **Performance optimization**: Eliminates O(n) scan through reviewLogs
    /// when calculating elapsed days for FSRS algorithm. Updated automatically
    /// when reviews are processed.
    ///
    /// - Default: nil (never reviewed)
    /// - Updated by: Scheduler.processReview()
    var lastReviewDate: Date?

    /// Cached total review count for O(1) access
    ///
    /// **Performance optimization**: Eliminates O(n) scan through reviewLogs
    /// when building FSRS Card for algorithm processing. Updated automatically
    /// when reviews are processed.
    ///
    /// - Default: 0 (new card)
    /// - Updated by: Scheduler.processReview()
    var totalReviews: Int

    /// Cached lapse count (rating == 0) for O(1) access
    ///
    /// **Performance optimization**: Eliminates O(n) scan through reviewLogs
    /// when building FSRS Card for algorithm processing. Updated automatically
    /// when reviews are processed.
    ///
    /// - Default: 0 (new card)
    /// - Updated by: Scheduler.processReview()
    var totalLapses: Int

    /// The card this state belongs to (one-to-one relationship)
    /// - Inverse points to Flashcard.fsrsState
    @Relationship(inverse: \Flashcard.fsrsState) var card: Flashcard?

    /// Computed property for type-safe state enum access
    var state: FlashcardState {
        get { FlashcardState(rawValue: stateEnum) ?? .new }
        set { stateEnum = newValue.rawValue }
    }

    /// Initialize with default values for a new card
    init(
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        retrievability: Double = 0.9,
        dueDate: Date = Date(),
        stateEnum: String = FlashcardState.new.rawValue,
        totalReviews: Int = 0,
        totalLapses: Int = 0
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
        self.dueDate = dueDate
        self.stateEnum = stateEnum
        self.totalReviews = totalReviews
        self.totalLapses = totalLapses
    }

    /// Initialize with FlashcardState enum
    convenience init(
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        retrievability: Double = 0.9,
        dueDate: Date = Date(),
        state: FlashcardState = .new,
        totalReviews: Int = 0,
        totalLapses: Int = 0
    ) {
        self.init(
            stability: stability,
            difficulty: difficulty,
            retrievability: retrievability,
            dueDate: dueDate,
            stateEnum: state.rawValue,
            totalReviews: totalReviews,
            totalLapses: totalLapses
        )
    }
}

/// Card learning state
///
/// NOTE: Renamed from CardState to FlashcardState to avoid conflict with FSRS.CardState
enum FlashcardState: String, Sendable {
    /// Never been reviewed - first appearance
    case new

    /// In initial learning phase (short intervals)
    case learning

    /// Graduated to long-term retention (long intervals)
    case review

    /// Relearning after a failed review (again rating)
    case relearning
}
