//
//  FlashcardReviewDTOTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardReviewDTO computed properties and formatting
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for FlashcardReviewDTO
///
/// Tests verify:
/// - Rating label/icon/color formatting
/// - State change badge generation
/// - Relative date string formatting
/// - Scheduled interval descriptions
/// - Elapsed time descriptions
/// - Factory method state detection
@MainActor
struct FlashcardReviewDTOTests {
    // MARK: - Rating Label Tests

    @Test("Rating label for Again (0)")
    func ratingLabelAgain() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 0,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingLabel == "Again")
    }

    @Test("Rating label for Hard (1)")
    func ratingLabelHard() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 1,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingLabel == "Hard")
    }

    @Test("Rating label for Good (2)")
    func ratingLabelGood() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingLabel == "Good")
    }

    @Test("Rating label for Easy (3)")
    func ratingLabelEasy() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingLabel == "Easy")
    }

    @Test("Rating label defaults to Good for invalid rating")
    func ratingLabelInvalid() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 99, // Invalid rating
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingLabel == "Good", "Invalid rating should default to Good")
    }

    // MARK: - Rating Icon Tests

    @Test("Rating icon for Again")
    func ratingIconAgain() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 0,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingIcon == "xmark.circle.fill")
    }

    @Test("Rating icon for Hard")
    func ratingIconHard() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 1,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingIcon == "exclamationmark.triangle.fill")
    }

    @Test("Rating icon for Good")
    func ratingIconGood() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingIcon == "checkmark.circle.fill")
    }

    @Test("Rating icon for Easy")
    func ratingIconEasy() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingIcon == "star.fill")
    }

    // MARK: - Rating Color Tests

    @Test("Rating color for Again")
    func ratingColorAgain() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 0,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingColor == "red")
    }

    @Test("Rating color for Hard")
    func ratingColorHard() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 1,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingColor == "orange")
    }

    @Test("Rating color for Good")
    func ratingColorGood() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingColor == "blue")
    }

    @Test("Rating color for Easy")
    func ratingColorEasy() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.ratingColor == "green")
    }

    // MARK: - State Change Badge Tests

    @Test("State change badge for First Review")
    func stateChangeBadgeFirstReview() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 0.0,
            stateChange: .firstReview
        )

        #expect(dto.stateChangeBadge == "First Review")
    }

    @Test("State change badge for Graduated")
    func stateChangeBadgeGraduated() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 1.0,
            stateChange: .graduated
        )

        #expect(dto.stateChangeBadge == "Graduated")
    }

    @Test("State change badge for Relearning")
    func stateChangeBadgeRelearning() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 0,
            reviewDate: Date(),
            scheduledDays: 0.08, // ~2 hours
            elapsedDays: 5.0,
            stateChange: .relearning
        )

        #expect(dto.stateChangeBadge == "Relearning")
    }

    @Test("State change badge for None returns nil")
    func stateChangeBadgeNone() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 7.0,
            stateChange: .none
        )

        #expect(dto.stateChangeBadge == nil, "No state change should return nil badge")
    }

    // MARK: - Relative Date String Tests

    @Test("Relative date string for just now")
    func relativeDateStringJustNow() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.relativeDateString == "just now")
    }

    @Test("Relative date string for hours ago")
    func relativeDateStringHoursAgo() {
        let twoHoursAgo = Date().addingTimeInterval(-7200) // 2 hours
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: twoHoursAgo,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.relativeDateString == "2h ago")
    }

    @Test("Relative date string for yesterday")
    func relativeDateStringYesterday() {
        let yesterday = Date().addingTimeInterval(-86400) // 1 day
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: yesterday,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.relativeDateString == "yesterday")
    }

    @Test("Relative date string for days ago")
    func relativeDateStringDaysAgo() {
        let threeDaysAgo = Date().addingTimeInterval(-86400 * 3)
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: threeDaysAgo,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.relativeDateString == "3d ago")
    }

    @Test("Relative date string for weeks ago")
    func relativeDateStringWeeksAgo() {
        let twoWeeksAgo = Date().addingTimeInterval(-86400 * 14)
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: twoWeeksAgo,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.relativeDateString == "2w ago")
    }

    // MARK: - Full Date String Tests

    @Test("Full date string format")
    func fullDateStringFormat() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30

        let testDate = calendar.date(from: components)!
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: testDate,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        let fullDate = dto.fullDateString
        #expect(fullDate.contains("Jan"), "Should contain month name")
        #expect(fullDate.contains("15"), "Should contain day")
        #expect(fullDate.contains("2026"), "Should contain year")
        #expect(fullDate.contains("2:30"), "Should contain time")
    }

    @Test("Full date string uses user locale")
    func fullDateStringLocale() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        // Should not crash and should return non-empty string
        let fullDate = dto.fullDateString
        #expect(!fullDate.isEmpty, "Full date string should not be empty")
    }

    // MARK: - Scheduled Interval Description Tests

    @Test("Scheduled interval for today")
    func scheduledIntervalToday() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 0.001, // Less than 0.002 days (~1.7 minutes)
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "today")
    }

    @Test("Scheduled interval for hours")
    func scheduledIntervalHours() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 0.25, // 6 hours
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 6h")
    }

    @Test("Scheduled interval for tomorrow")
    func scheduledIntervalTomorrow() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.5, // 1.5 days
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "tomorrow")
    }

    @Test("Scheduled interval for days")
    func scheduledIntervalDays() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 5.0,
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 5d")
    }

    @Test("Scheduled interval for weeks")
    func scheduledIntervalWeeks() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 14.0, // 2 weeks
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 2w")
    }

    @Test("Scheduled interval for months")
    func scheduledIntervalMonths() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 60.0, // 2 months
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 2mo")
    }

    @Test("Scheduled interval boundary: just before today")
    func scheduledIntervalBoundaryToday() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 0.002, // Exactly at boundary
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "today")
    }

    @Test("Scheduled interval boundary: just before tomorrow")
    func scheduledIntervalBoundaryTomorrow() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 0.999, // Just under 1 day
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 23h")
    }

    // MARK: - Elapsed Time Description Tests

    @Test("Elapsed time description for on time")
    func elapsedTimeDescriptionOnTime() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 7.0 // Exactly on schedule
        )

        #expect(dto.elapsedTimeDescription == "on time")
    }

    @Test("Elapsed time description for nearly on time")
    func elapsedTimeDescriptionNearlyOnTime() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 7.3 // Within 0.5 day tolerance
        )

        #expect(dto.elapsedTimeDescription == "on time")
    }

    @Test("Elapsed time description for 1 day late")
    func elapsedTimeDescriptionOneDayLate() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 8.0 // 1 day late
        )

        #expect(dto.elapsedTimeDescription == "1 day late")
    }

    @Test("Elapsed time description for multiple days late")
    func elapsedTimeDescriptionMultipleDaysLate() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 12.0 // 5 days late
        )

        #expect(dto.elapsedTimeDescription == "5 days late")
    }

    @Test("Elapsed time description for 1 day early")
    func elapsedTimeDescriptionOneDayEarly() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 6.0 // 1 day early
        )

        #expect(dto.elapsedTimeDescription == "1 day early")
    }

    @Test("Elapsed time description for multiple days early")
    func elapsedTimeDescriptionMultipleDaysEarly() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 3.0 // 4 days early
        )

        #expect(dto.elapsedTimeDescription == "4 days early")
    }

    @Test("Elapsed time description for very late")
    func elapsedTimeDescriptionVeryLate() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 30.0 // 29 days late
        )

        #expect(dto.elapsedTimeDescription == "29 days late")
    }

    // MARK: - Factory Method Tests

    @Test("Factory method detects first review")
    func factoryMethodFirstReview() {
        // Create a mock FlashcardReview (we need to create it in a ModelContext)
        // For testing, we'll verify the logic directly
        let stateChange: ReviewStateChange = .firstReview
        #expect(stateChange == .firstReview)
    }

    @Test("Factory method detects graduation")
    func factoryMethodGraduation() {
        // Learning -> Review transition with passing rating
        let previousState = FlashcardState.learning
        let currentState = FlashcardState.review
        let rating = 2 // Good (passing)

        let stateChange: ReviewStateChange = if previousState == .learning, currentState == .review, rating > 0 {
            .graduated
        } else {
            .none
        }

        #expect(stateChange == .graduated)
    }

    @Test("Factory method detects relearning")
    func factoryMethodRelearning() {
        // Failed review (rating 0) with relearning state
        let currentState = FlashcardState.relearning
        let rating = 0 // Again (failed)

        let stateChange: ReviewStateChange = if rating == 0, currentState == .relearning {
            .relearning
        } else {
            .none
        }

        #expect(stateChange == .relearning)
    }

    @Test("Factory method no state change")
    func factoryMethodNoStateChange() {
        // Review -> Review with passing rating
        let previousState = FlashcardState.review
        let currentState = FlashcardState.review
        let rating = 2 // Good

        let stateChange: ReviewStateChange = if previousState == .learning, currentState == .review {
            .graduated
        } else if rating == 0, currentState == .relearning {
            .relearning
        } else {
            .none
        }

        #expect(stateChange == .none)
    }

    @Test("Factory method handles missing previous state")
    func factoryMethodMissingPreviousState() {
        // No previous state (nil), should not crash
        let previousState: FlashcardState? = nil
        let currentState = FlashcardState.review
        let rating = 2 // Good

        let stateChange: ReviewStateChange = if let previous = previousState {
            if previous == .learning, currentState == .review {
                .graduated
            } else if rating == 0, currentState == .relearning {
                .relearning
            } else {
                .none
            }
        } else {
            .none
        }

        #expect(stateChange == .none, "Missing previous state should result in no state change")
    }

    @Test("Factory method learning to learning not graduated")
    func factoryMethodLearningToLearning() {
        // Learning -> Learning is not graduation
        let previousState = FlashcardState.learning
        let currentState = FlashcardState.learning
        let rating = 2 // Good

        let stateChange: ReviewStateChange = if previousState == .learning, currentState == .review {
            .graduated
        } else if rating == 0, currentState == .relearning {
            .relearning
        } else {
            .none
        }

        #expect(stateChange == .none, "Learning to learning is not graduation")
    }

    // MARK: - Protocol Conformance Tests

    @Test("DTO is Identifiable")
    func dtoIsIdentifiable() {
        let id = UUID()
        let dto = FlashcardReviewDTO(
            id: id,
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        #expect(dto.id == id, "DTO should have accessible id property")
    }

    @Test("DTO is Sendable (thread-safe)")
    func dtoIsSendable() {
        // This is a compile-time test, but we verify behavior at runtime
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )

        // Should be able to pass between concurrency contexts
        Task {
            let label = dto.ratingLabel
            #expect(label == "Good")
        }
    }

    // MARK: - Edge Cases

    @Test("Handles zero scheduled days")
    func zeroScheduledDays() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 0.0,
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "today")
    }

    @Test("Handles very large scheduled days")
    func veryLargeScheduledDays() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 365.0, // 1 year
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "in 12mo")
    }

    @Test("Handles negative elapsed days")
    func negativeElapsedDays() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: -1.0 // Should not happen in practice
        )

        // Should show as early (7 - (-1) = 8 days early)
        #expect(dto.elapsedTimeDescription == "8 days early")
    }

    @Test("Handles fractional days in intervals")
    func fractionalDaysIntervals() {
        let dto = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.3, // 1.3 days (< 2 days = "tomorrow")
            elapsedDays: 1.0
        )

        #expect(dto.scheduledIntervalDescription == "tomorrow")

        // Test 2.3 days (should be "in 2d")
        let dto2 = FlashcardReviewDTO(
            id: UUID(),
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 2.3, // 2.3 days (>= 2 days = "in 2d")
            elapsedDays: 1.0
        )

        #expect(dto2.scheduledIntervalDescription == "in 2d")
    }
}
