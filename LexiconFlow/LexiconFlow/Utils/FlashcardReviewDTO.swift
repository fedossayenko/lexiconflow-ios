//
//  FlashcardReviewDTO.swift
//  LexiconFlow
//
//  Sendable data transfer object for review history display
//  Provides computed properties for UI formatting and state change detection
//

import Foundation

/// State transition between reviews for highlighting
///
/// **Why this matters**: Users want to see when cards graduate from
/// "learning" to "review" state, or when they fail and need relearning.
/// This DTO captures that transition data for UI highlighting.
enum ReviewStateChange: String, Sendable {
    /// First review of a new card
    case firstReview = "First Review"

    /// Card graduated from learning to review state
    case graduated = "Graduated"

    /// Card failed and entered relearning
    case relearning = "Relearning"

    /// State remained the same (no transition)
    case none = "None"
}

/// Sendable data transfer object for review history display
///
/// **Why DTO?**: FlashcardReview is a SwiftData @Model that cannot be Sendable.
/// This DTO provides a thread-safe snapshot of review data for passing across
/// actor boundaries to ViewModels and Views.
///
/// **Concurrency**: Sendable struct allows safe sharing across actors without
/// risk of data races. This follows the DTO pattern used in FSRSReviewResult.
struct FlashcardReviewDTO: Sendable, Identifiable {
    /// Unique identifier (matches FlashcardReview.id)
    let id: UUID

    /// The rating given during review (0-3)
    let rating: Int

    /// When this review occurred
    let reviewDate: Date

    /// Days until next review (as scheduled by FSRS)
    let scheduledDays: Double

    /// Days elapsed since previous review
    let elapsedDays: Double

    /// State transition that occurred during this review
    let stateChange: ReviewStateChange

    // MARK: - Time Interval Constants

    /// Threshold constants for time interval display
    private enum TimeInterval {
        /// Today threshold: ~2.88 minutes (0.002 days)
        static let todayThreshold: Double = 0.002
        /// One day in days
        static let oneDay: Double = 1.0
        /// Two days in days
        static let twoDays: Double = 2.0
        /// One week in days
        static let oneWeek: Double = 7.0
        /// One month in days
        static let oneMonth: Double = 30.0
        /// Half day tolerance for "on time" determination
        static let halfDay: Double = 0.5
    }

    /// Initialize from FlashcardReview model
    ///
    /// **Why convenience init**: Separates mapping logic from struct definition.
    /// ViewModel will handle state change detection and pass it here.
    ///
    /// - Parameters:
    ///   - id: Review identifier
    ///   - rating: The FSRS rating (0-3)
    ///   - reviewDate: When review occurred
    ///   - scheduledDays: Days until next review
    ///   - elapsedDays: Days since previous review
    ///   - stateChange: Detected state transition
    init(
        id: UUID,
        rating: Int,
        reviewDate: Date,
        scheduledDays: Double,
        elapsedDays: Double,
        stateChange: ReviewStateChange = .none
    ) {
        self.id = id
        self.rating = rating
        self.reviewDate = reviewDate
        self.scheduledDays = scheduledDays
        self.elapsedDays = elapsedDays
        self.stateChange = stateChange
    }

    // MARK: - Computed Properties for UI

    /// User-friendly rating label
    ///
    /// **Example**: "Again", "Hard", "Good", "Easy"
    var ratingLabel: String {
        CardRating.validate(rating).label
    }

    /// System icon name for rating badge
    ///
    /// **Example**: "xmark.circle.fill", "star.fill"
    var ratingIcon: String {
        CardRating.validate(rating).iconName
    }

    /// Color name for rating badge
    ///
    /// **Example**: "red", "orange", "blue", "green"
    var ratingColor: String {
        CardRating.validate(rating).color
    }

    /// Badge text for state change highlighting
    ///
    /// **Returns**: Badge text if state changed, nil otherwise
    ///
    /// **Example**:
    /// - "First Review" for initial card review
    /// - "Graduated" for learning → review transition
    /// - "Relearning" for failed review
    /// - nil for normal review (no state change)
    var stateChangeBadge: String? {
        switch stateChange {
        case .none:
            nil
        case .firstReview, .graduated, .relearning:
            stateChange.rawValue
        }
    }

    /// Human-readable relative date string
    ///
    /// **Example**: "2d ago", "yesterday", "just now"
    ///
    /// **Implementation**: Uses DateMath.formatElapsed for timezone-aware
    /// formatting that handles calendar boundaries correctly.
    var relativeDateString: String {
        let daysSinceReview = DateMath.elapsedDays(since: reviewDate)
        return DateMath.formatElapsed(daysSinceReview)
    }

    /// Full date string for accessibility
    ///
    /// **Example**: "Jan 15, 2026 at 2:30 PM"
    ///
    /// **Why separate from relativeDateString**: VoiceOver users need
    /// absolute dates for context, while visual users prefer relative.
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter.string(from: reviewDate)
    }

    /// Scheduled interval description
    ///
    /// **Example**: "in 3 days", "tomorrow", "today"
    ///
    /// **Why computed**: Shows user when their next review was scheduled
    /// at the time of this review. Useful for understanding algorithm behavior.
    var scheduledIntervalDescription: String {
        if scheduledDays <= TimeInterval.todayThreshold {
            return "today"
        } else if scheduledDays < TimeInterval.oneDay {
            let hours = Int(scheduledDays * 24)
            return "in \(hours)h"
        } else if scheduledDays < TimeInterval.twoDays {
            return "tomorrow"
        } else if scheduledDays < TimeInterval.oneWeek {
            let days = Int(scheduledDays)
            return "in \(days)d"
        } else if scheduledDays < TimeInterval.oneMonth {
            let weeks = Int(scheduledDays / TimeInterval.oneWeek)
            return "in \(weeks)w"
        } else {
            let months = Int(scheduledDays / TimeInterval.oneMonth)
            return "in \(months)mo"
        }
    }

    /// Elapsed time description
    ///
    /// **Example**: "2 days late", "1 day early", "on time"
    ///
    /// **Why this matters**: Shows whether user reviewed on schedule or
    /// early/late. Important for understanding FSRS behavior.
    var elapsedTimeDescription: String {
        let difference = elapsedDays - scheduledDays

        if abs(difference) < TimeInterval.halfDay {
            return "on time"
        } else if difference > 0 {
            let daysLate = Int(difference)
            return daysLate == 1 ? "1 day late" : "\(daysLate) days late"
        } else {
            let daysEarly = Int(-difference)
            return daysEarly == 1 ? "1 day early" : "\(daysEarly) days early"
        }
    }
}

// MARK: - Factory Methods

extension FlashcardReviewDTO {
    /// Create DTO from FlashcardReview model with state change detection
    ///
    /// **Why factory method**: Encapsulates the mapping logic and separates
    /// state change detection from struct initialization.
    ///
    /// - Parameters:
    ///   - review: The FlashcardReview SwiftData model
    ///   - previousState: The state before this review (for transition detection)
    ///   - currentState: The state after this review
    ///   - isFirstReview: True if this is the card's first review
    /// - Returns: Configured DTO with state change detected
    static func from(
        _ review: FlashcardReview,
        previousState: FlashcardState?,
        currentState: FlashcardState,
        isFirstReview: Bool = false
    ) -> FlashcardReviewDTO {
        // Detect state transition
        let stateChange: ReviewStateChange = if isFirstReview {
            .firstReview
        } else if let previous = previousState {
            if previous == .learning, currentState == .review {
                .graduated
            } else if review.rating == 0, currentState == .relearning {
                .relearning
            } else {
                .none
            }
        } else {
            .none
        }

        return FlashcardReviewDTO(
            id: review.id,
            rating: review.rating,
            reviewDate: review.reviewDate,
            scheduledDays: review.scheduledDays,
            elapsedDays: review.elapsedDays,
            stateChange: stateChange
        )
    }
}
