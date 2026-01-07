//
//  DailyStats.swift
//  LexiconFlow
//
//  Pre-aggregated daily statistics for dashboard performance
//

import SwiftData
import Foundation

/// Pre-aggregated statistics for a single calendar day
///
/// DailyStats stores computed metrics for efficient dashboard rendering.
/// Instead of calculating statistics from raw StudySession data every time
/// the dashboard loads, we aggregate daily statistics in the background.
///
/// This optimization is critical for performance:
/// - Dashboard loads in <100ms regardless of data size
/// - Trend graphs render instantly with pre-computed data points
/// - Study streak calculation is O(1) with daily records
///
/// Each DailyStats record contains:
/// - Number of new cards learned (first successful review)
/// - Total study time across all sessions
/// - Retention rate (successful reviews / total reviews)
/// - Links to all study sessions for the day
///
/// **Aggregation Strategy:**
/// - Created/updated when study sessions complete or app backgrounds
/// - One record per calendar day (midnight in user's timezone)
/// - Updated incrementally as new sessions are added
/// - Source of truth for dashboard display
@Model
final class DailyStats {
    /// Unique identifier for this stats record
    var id: UUID

    /// The calendar day for these statistics (time component normalized to midnight)
    ///
    /// **Timezone Handling:** Stored as midnight in user's current timezone.
    /// Use Calendar.startOfDay(for:) to normalize dates before querying.
    var date: Date

    /// Number of new cards learned on this day
    ///
    /// **Definition:** A card is "learned" when it graduates from the
    /// "learning" state to the "review" state (first successful interval).
    /// This metric tracks vocabulary growth progress.
    var cardsLearned: Int

    /// Total study time for this day in seconds
    ///
    /// **Calculation:** Sum of all StudySession.durationSeconds for the day.
    /// Includes all study modes (scheduled, learning, cram).
    var studyTimeSeconds: TimeInterval

    /// Retention rate for reviews on this day (0.0 to 1.0)
    ///
    /// **Definition:** (successful reviews / total reviews)
    /// - Successful: Again, Hard, Good ratings (response remembered)
    /// - Failed: Forgot rating (response forgotten)
    ///
    /// **Nil handling:** nil if no reviews occurred on this day.
    /// This distinguishes "0% retention (all failed)" from "no data".
    var retentionRate: Double?

    /// All study sessions that contributed to these statistics
    /// - Deleting DailyStats cascades to disassociate sessions (kept for analytics)
    /// - Inverse defined on StudySession.dailyStats
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify, inverse: \StudySession.dailyStats) var studySessions: [StudySession] = []

    // MARK: - Computed Properties

    /// Human-readable study time (e.g., "5m 23s", "1h 15m")
    var studyTimeFormatted: String {
        let seconds = Int(studyTimeSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            if minutes == 0 && remainingSeconds == 0 {
                return "\(hours)h"
            } else if remainingSeconds == 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h \(minutes)m \(remainingSeconds)s"
            }
        } else if minutes > 0 {
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        } else {
            return "\(remainingSeconds)s"
        }
    }

    /// Retention rate as percentage (e.g., "85%")
    var retentionRateFormatted: String? {
        guard let rate = retentionRate else { return nil }
        return "\(Int(rate * 100))%"
    }

    /// Whether this day has any study activity
    var hasActivity: Bool {
        studyTimeSeconds > 0 || cardsLearned > 0 || retentionRate != nil
    }

    // MARK: - Initialization

    /// Initialize daily statistics
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - date: Calendar day (time component will be normalized to midnight)
    ///   - cardsLearned: Number of new cards learned
    ///   - studyTimeSeconds: Total study time in seconds
    ///   - retentionRate: Retention rate (0.0-1.0, nil if no reviews)
    init(id: UUID = UUID(),
         date: Date,
         cardsLearned: Int = 0,
         studyTimeSeconds: TimeInterval = 0,
         retentionRate: Double? = nil) {

        self.id = id
        self.date = date
        self.cardsLearned = cardsLearned
        self.studyTimeSeconds = studyTimeSeconds
        self.retentionRate = retentionRate
    }

    /// Initialize with normalized date (midnight in current timezone)
    convenience init(cardsLearned: Int = 0,
                     studyTimeSeconds: TimeInterval = 0,
                     retentionRate: Double? = nil) {
        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())

        self.init(id: UUID(),
                  date: normalizedDate,
                  cardsLearned: cardsLearned,
                  studyTimeSeconds: studyTimeSeconds,
                  retentionRate: retentionRate)
    }
}
