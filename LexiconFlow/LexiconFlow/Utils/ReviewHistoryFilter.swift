//
//  ReviewHistoryFilter.swift
//  LexiconFlow
//
//  Time-based filtering options for review history
//

import Foundation

/// Time-based filtering options for review history display
///
/// **Why this matters**:
/// - Users want to see recent progress (last week/month)
/// - Power users want full history (all time)
/// - Date range calculation must be timezone-aware for consistency
///
/// **Concurrency**: This is a pure enum with computed properties using DateMath.
/// No actor isolation needed since DateMath uses thread-safe Calendar.autoupdatingCurrent.
enum ReviewHistoryFilter: String, CaseIterable, Sendable {
    case allTime
    case lastWeek
    case lastMonth

    // MARK: - Display Properties

    /// User-facing display name for the filter
    var displayName: String {
        switch self {
        case .allTime: "All Time"
        case .lastWeek: "Last Week"
        case .lastMonth: "Last Month"
        }
    }

    /// System icon for the filter
    var icon: String {
        switch self {
        case .allTime: "clock.arrow.circlepath"
        case .lastWeek: "calendar.badge.clock"
        case .lastMonth: "calendar"
        }
    }

    // MARK: - Date Range Calculation

    /// Calculate the date range for this filter
    ///
    /// **Returns**: A tuple containing:
    ///   - startDate: The start date for filtering (nil for allTime)
    ///   - endDate: The end date for filtering (always Date())
    ///
    /// **Example**:
    /// ```swift
    /// let (start, end) = ReviewHistoryFilter.lastWeek.dateRange
    /// // start: 7 days ago at midnight
    /// // end: now
    ///
    /// let (start, end) = ReviewHistoryFilter.allTime.dateRange
    /// // start: nil (no lower bound)
    /// // end: now
    /// ```
    var dateRange: (startDate: Date?, endDate: Date) {
        let now = Date()

        switch self {
        case .allTime:
            return (nil, now)

        case .lastWeek:
            // Start of day, 7 days ago
            let sevenDaysAgo = DateMath.addingDays(-7, to: now)
            let startOfPeriod = DateMath.startOfDay(for: sevenDaysAgo)
            return (startOfPeriod, now)

        case .lastMonth:
            // Start of day, 30 days ago
            let thirtyDaysAgo = DateMath.addingDays(-30, to: now)
            let startOfPeriod = DateMath.startOfDay(for: thirtyDaysAgo)
            return (startOfPeriod, now)
        }
    }

    // MARK: - Filtering

    /// Check if a review date matches this filter
    ///
    /// **Why a separate method**: Makes filtering code more readable than
    /// directly accessing `dateRange` and doing comparisons.
    ///
    /// - Parameter reviewDate: The date of the review to check
    /// - Returns: True if the review date falls within this filter's range
    func matches(_ reviewDate: Date) -> Bool {
        let (startDate, endDate) = dateRange

        // No lower bound for allTime
        if let start = startDate {
            return reviewDate >= start && reviewDate <= endDate
        } else {
            return reviewDate <= endDate
        }
    }
}

// MARK: - Picker Support

extension ReviewHistoryFilter: Identifiable {
    var id: String { rawValue }
}
