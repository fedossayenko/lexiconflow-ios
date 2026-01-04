//
//  ReviewLog.swift
//  LexiconFlow
//
//  Audit trail of card reviews for tracking learning history
//

import SwiftData
import Foundation

/// A record of a single card review session
///
/// ReviewLogs provide a complete history of when cards were reviewed,
/// the rating given, and how the FSRS algorithm scheduled the next review.
/// This data is essential for:
/// - Analytics and progress tracking
/// - Debugging FSRS behavior
/// - Undo/redo functionality
/// - Data export and analysis
@Model
final class ReviewLog {
    /// Unique identifier for this log entry
    var id: UUID

    /// The rating given during review
    /// - 0: Again (failed, reset to learning)
    /// - 1: Hard (remembered but difficult)
    /// - 2: Good (remembered normally)
    /// - 3: Easy (remembered easily)
    var rating: Int

    /// When this review occurred
    var reviewDate: Date

    /// Days until next review (as scheduled by FSRS)
    /// - Calculated by FSRS algorithm
    /// - Used to verify algorithm behavior
    var scheduledDays: Double

    /// Days elapsed since previous review
    /// - Actual elapsed time
    /// - May differ from scheduled (early/late reviews)
    var elapsedDays: Double

    /// The card that was reviewed
    /// - Deleting card sets this to nil (orphaned logs kept for analytics)
    /// - Inverse points to Card.reviewLogs
    @Relationship(deleteRule: .nullify, inverse: \Card.reviewLogs) var card: Card?

    // MARK: - Initialization

    /// Initialize a new review log entry
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - rating: The FSRS rating (0-3)
    ///   - reviewDate: When review occurred (defaults to now)
    ///   - scheduledDays: Days until next review
    ///   - elapsedDays: Days since previous review
    init(id: UUID = UUID(),
         rating: Int,
         reviewDate: Date = Date(),
         scheduledDays: Double = 0.0,
         elapsedDays: Double = 0.0) {

        self.id = id
        self.rating = rating
        self.reviewDate = reviewDate
        self.scheduledDays = scheduledDays
        self.elapsedDays = elapsedDays
    }

    /// Initialize review log with minimal parameters
    convenience init(rating: Int,
                     scheduledDays: Double,
                     elapsedDays: Double) {
        self.init(rating: rating,
                  reviewDate: Date(),
                  scheduledDays: scheduledDays,
                  elapsedDays: elapsedDays)
    }
}

/// FSRS rating values
enum Rating: Int {
    /// Again: Failed recall, reset to learning state
    case again = 0

    /// Hard: Remembered but with difficulty
    case hard = 1

    /// Good: Normal recall
    case good = 2

    /// Easy: Effortless recall
    case easy = 3
}
