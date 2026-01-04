//
//  FSRSState.swift
//  LexiconFlow
//
//  FSRS v5 Algorithm State Model
//  Encapsulates the mathematical state of the Free Spaced Repetition Scheduler
//

import SwiftData
import Foundation

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

    /// The card this state belongs to (one-to-one relationship)
    /// - Inverse points to Card.fsrsState
    @Relationship(inverse: \Card.fsrsState) var card: Card?

    /// Computed property for type-safe state enum access
    var state: CardState {
        get { CardState(rawValue: stateEnum) ?? .new }
        set { stateEnum = newValue.rawValue }
    }

    /// Initialize with default values for a new card
    init(stability: Double = 0.0,
         difficulty: Double = 5.0,
         retrievability: Double = 0.9,
         dueDate: Date = Date(),
         stateEnum: String = CardState.new.rawValue) {

        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
        self.dueDate = dueDate
        self.stateEnum = stateEnum
    }

    /// Initialize with CardState enum
    convenience init(stability: Double = 0.0,
                     difficulty: Double = 5.0,
                     retrievability: Double = 0.9,
                     dueDate: Date = Date(),
                     state: CardState = .new) {
        self.init(stability: stability,
                  difficulty: difficulty,
                  retrievability: retrievability,
                  dueDate: dueDate,
                  stateEnum: state.rawValue)
    }
}

/// Card learning state
enum CardState: String {
    /// Never been reviewed - first appearance
    case new

    /// In initial learning phase (short intervals)
    case learning

    /// Graduated to long-term retention (long intervals)
    case review

    /// Relearning after a failed review (again rating)
    case relearning
}
