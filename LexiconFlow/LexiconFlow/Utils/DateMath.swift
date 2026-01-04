//
//  DateMath.swift
//  LexiconFlow
//
//  Timezone-aware date calculations for FSRS algorithm
//  Handles calendar boundaries, DST transitions, and localization
//

import Foundation

/// Timezone-aware date calculations for spaced repetition
///
/// **Why this matters**:
/// - Simple division (seconds / 86400) fails during DST transitions
/// - Users in different timezones expect "day" to mean "calendar day"
/// - FSRS algorithm assumes day-based intervals, not second-based
@MainActor
enum DateMath {

    /// The user's current calendar with locale settings
    private static var currentCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }

    // MARK: - Day Calculations

    /// Calculate elapsed days between two dates using calendar components
    ///
    /// **Example**:
    /// - Between Jan 1 23:59 and Jan 2 00:01 → 1 day (same calendar day)
    /// - Between Jan 1 00:01 and Jan 1 23:59 → 0 days (same calendar day)
    ///
    /// - Parameters:
    ///   - start: Earlier date
    ///   - end: Later date
    /// - Returns: Number of elapsed calendar days (non-negative)
    static func elapsedDays(from start: Date, to end: Date) -> Double {
        // Clamp to non-negative (handles clock skew)
        let clampedStart = min(start, end)

        // Use calendar components for day-accurate calculation
        let components = Self.currentCalendar.dateComponents(
            [.day, .hour, .minute, .second],
            from: clampedStart,
            to: end
        )

        var totalDays = Double(components.day ?? 0)

        // Add fractional time if less than a full day
        if let hour = components.hour,
           let minute = components.minute,
           let second = components.second {
            let fractionalDay = Double(hour) / 24.0 +
                               Double(minute) / 1440.0 +
                               Double(second) / 86400.0
            totalDays += fractionalDay
        }

        return max(0, totalDays)
    }

    /// Calculate elapsed days from a date to now
    ///
    /// - Parameter date: The past date to calculate from
    /// - Returns: Days elapsed (non-negative)
    static func elapsedDays(since date: Date) -> Double {
        elapsedDays(from: date, to: Date())
    }

    /// Add days to a date, respecting calendar boundaries
    ///
    /// - Parameters:
    ///   - days: Number of days to add (can be negative or fractional)
    ///   - date: Starting date
    /// - Returns: New date with days added
    static func addingDays(_ days: Double, to date: Date) -> Date {
        // For fractional days, use time interval
        let wholeDays = Int(days)
        let fractionalDay = days - Double(wholeDays)

        var result = date

        // Add whole days using calendar (handles DST correctly)
        if wholeDays != 0 {
            result = Self.currentCalendar.date(
                byAdding: .day,
                value: wholeDays,
                to: result
            ) ?? result
        }

        // Add fractional part using time interval
        if fractionalDay != 0 {
            result = result.addingTimeInterval(fractionalDay * 86400.0)
        }

        return result
    }

    // MARK: - Date Comparisons

    /// Check if a date is today in the user's timezone
    ///
    /// - Parameter date: Date to check
    /// - Returns: True if date is within current calendar day
    static func isToday(_ date: Date) -> Bool {
        Self.currentCalendar.isDateInToday(date)
    }

    /// Check if a date is in the past (before today in user's timezone)
    ///
    /// - Parameter date: Date to check
    /// - Returns: True if date is before start of today
    static func isPast(_ date: Date) -> Bool {
        let todayStart = Self.currentCalendar.startOfDay(for: Date())
        return date < todayStart
    }

    /// Check if a date is due (due date has passed)
    ///
    /// - Parameter dueDate: The due date to check
    /// - Returns: True if due date is in the past or today
    static func isDue(_ dueDate: Date) -> Bool {
        let now = Date()
        return dueDate <= now
    }

    // MARK: - Human-Readable Formats

    /// Format a date interval as human-readable string
    ///
    /// - Parameter date: The date to format
    /// - Returns: String like "in 3 days", "today", "2 days ago"
    static func formatRelative(_ date: Date) -> String {
        let now = Date()
        // Determine if date is in the past or future
        let isPast = date < now
        // Compute elapsed days in the correct direction to avoid clamp issues
        let days = isPast ? elapsedDays(from: date, to: now) : elapsedDays(from: now, to: date)

        // Handle past dates
        if isPast {
            if days >= 7.0 {
                let dayCount = Int(days)
                return "\(dayCount)d ago"
            } else if days >= 0.9 {
                // Close to 1 day ago -> "yesterday"
                return "yesterday"
            } else if days >= 0.002 {
                let hours = Int(days * 24)
                return "\(hours)h ago"
            } else {
                return "now"
            }
        }

        // Handle future dates
        if days < 0.002 {
            return "now"
        } else if days < 1.0 {
            let hours = Int(days * 24)
            return "in \(hours)h"
        } else if days == 0 {
            return "today"
        } else if days < 2.0 {
            return "tomorrow"
        } else if days < 7.0 {
            let dayCount = Int(days)
            return "in \(dayCount)d"
        } else if days < 30.0 {
            let weeks = Int(days / 7.0)
            return "in \(weeks)w"
        } else if days < 365.0 {
            let months = Int(days / 30.0)
            return "in \(months)mo"
        } else {
            let years = Int(days / 365.0)
            return "in \(years)y"
        }
    }

    /// Format elapsed time as human-readable string
    ///
    /// - Parameter days: Days elapsed (from past to now)
    /// - Returns: String like "just now", "2h ago", "3 days ago"
    static func formatElapsed(_ days: Double) -> String {
        if days < 0.002 {
            return "just now"
        } else if days < 1.0 {
            let hours = Int(days * 24)
            return "\(hours)h ago"
        } else if days == 1.0 {
            return "yesterday"
        } else if days < 7.0 {
            let dayCount = Int(days)
            return "\(dayCount)d ago"
        } else if days < 30.0 {
            let weeks = Int(days / 7.0)
            return "\(weeks)w ago"
        } else if days < 365.0 {
            let months = Int(days / 30.0)
            return "\(months)mo ago"
        } else {
            let years = Int(days / 365.0)
            return "\(years)y ago"
        }
    }

    // MARK: - Timezone Helpers

    /// Get the start of day for a date in user's timezone
    ///
    /// - Parameter date: Date to get start of day for
    /// - Returns: Midnight of the given date
    static func startOfDay(for date: Date) -> Date {
        Self.currentCalendar.startOfDay(for: date)
    }

    /// Get the end of day for a date in user's timezone
    ///
    /// - Parameter date: Date to get end of day for
    /// - Returns: 23:59:59.999 of the given date
    static func endOfDay(for date: Date) -> Date {
        let start = Self.currentCalendar.startOfDay(for: date)
        return start.addingTimeInterval(86400 - 0.001)
    }

    /// Check if two dates are on the same calendar day
    ///
    /// - Parameters:
    ///   - date1: First date
    ///   - date2: Second date
    /// - Returns: True if dates are in same day/month/year
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Self.currentCalendar.isDate(date1, inSameDayAs: date2)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Calculate days elapsed from this date to now
    var daysElapsed: Double {
        DateMath.elapsedDays(since: self)
    }

    /// Check if this date is due (has passed)
    var isDue: Bool {
        DateMath.isDue(self)
    }

    /// Format as relative string
    var relativeString: String {
        DateMath.formatRelative(self)
    }

    /// Add calendar days to this date
    func adding(days: Double) -> Date {
        DateMath.addingDays(days, to: self)
    }
}
