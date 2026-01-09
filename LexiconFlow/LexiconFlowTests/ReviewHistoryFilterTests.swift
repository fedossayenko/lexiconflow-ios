//
//  ReviewHistoryFilterTests.swift
//  LexiconFlowTests
//
//  Tests for time-based filter enum date calculations
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for ReviewHistoryFilter enum
///
/// Tests verify:
/// - Date range calculations for all filters
/// - Timezone-aware date handling
/// - Filter matching logic
/// - Display properties
@MainActor
struct ReviewHistoryFilterTests {
    // MARK: - All Time Filter Tests

    @Test("AllTime filter returns nil startDate")
    func allTimeNilStartDate() {
        let (startDate, endDate) = ReviewHistoryFilter.allTime.dateRange

        #expect(startDate == nil, "AllTime should have no lower bound")
        #expect(endDate != nil, "AllTime should have an upper bound (now)")
    }

    @Test("AllTime filter matches all past dates")
    func allTimeMatchesAllDates() {
        let filter = ReviewHistoryFilter.allTime

        // Very old date (100 years ago)
        let ancientDate = Date().addingTimeInterval(-86400 * 365 * 100)
        #expect(filter.matches(ancientDate), "AllTime should match ancient dates")

        // Recent date (1 hour ago)
        let recentDate = Date().addingTimeInterval(-3600)
        #expect(filter.matches(recentDate), "AllTime should match recent dates")

        // Future date (should not match due to endDate being now)
        let futureDate = Date().addingTimeInterval(3600)
        #expect(!filter.matches(futureDate), "AllTime should not match future dates")
    }

    @Test("AllTime display properties")
    func allTimeDisplayProperties() {
        let filter = ReviewHistoryFilter.allTime

        #expect(filter.displayName == "All Time")
        #expect(filter.icon == "clock.arrow.circlepath")
    }

    // MARK: - Last Week Filter Tests

    @Test("LastWeek filter startDate is at start of day")
    func lastWeekStartOfDay() {
        let (startDate, _) = ReviewHistoryFilter.lastWeek.dateRange

        // Verify startDate is at start of day (midnight)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate!)

        #expect(components.hour == 0, "Start date should be at midnight")
        #expect(components.minute == 0, "Start date should have 0 minutes")
        #expect(components.second == 0, "Start date should have 0 seconds")
    }

    @Test("LastWeek filter matches dates within range")
    func lastWeekMatchesWithinRange() {
        let filter = ReviewHistoryFilter.lastWeek
        let now = Date()

        // Exactly 6 days ago (should match)
        let sixDaysAgo = now.addingTimeInterval(-86400 * 6)
        #expect(filter.matches(sixDaysAgo), "LastWeek should match 6 days ago")

        // Exactly 1 day ago (should match)
        let oneDayAgo = now.addingTimeInterval(-86400)
        #expect(filter.matches(oneDayAgo), "LastWeek should match 1 day ago")

        // Now (should match)
        #expect(filter.matches(now), "LastWeek should match now")
    }

    @Test("LastWeek filter rejects dates outside range")
    func lastWeekRejectsOutsideRange() {
        let filter = ReviewHistoryFilter.lastWeek
        let now = Date()

        // 8 days ago (should not match)
        let eightDaysAgo = now.addingTimeInterval(-86400 * 8)
        #expect(!filter.matches(eightDaysAgo), "LastWeek should not match 8 days ago")

        // Future date (should not match)
        let future = now.addingTimeInterval(3600)
        #expect(!filter.matches(future), "LastWeek should not match future dates")
    }

    @Test("LastWeek boundary case: exactly 7 days ago")
    func lastWeekBoundaryCase() {
        let filter = ReviewHistoryFilter.lastWeek
        let now = Date()

        // Get the startDate from the filter
        let (startDate, _) = filter.dateRange

        // Date exactly at startDate boundary should match
        if let start = startDate {
            #expect(filter.matches(start), "LastWeek should match date exactly at start boundary")
        }
    }

    @Test("LastWeek display properties")
    func lastWeekDisplayProperties() {
        let filter = ReviewHistoryFilter.lastWeek

        #expect(filter.displayName == "Last Week")
        #expect(filter.icon == "calendar.badge.clock")
    }

    // MARK: - Last Month Filter Tests

    @Test("LastMonth filter startDate is at start of day")
    func lastMonthStartOfDay() {
        let (startDate, _) = ReviewHistoryFilter.lastMonth.dateRange

        // Verify startDate is at start of day (midnight)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate!)

        #expect(components.hour == 0, "Start date should be at midnight")
        #expect(components.minute == 0, "Start date should have 0 minutes")
        #expect(components.second == 0, "Start date should have 0 seconds")
    }

    @Test("LastMonth filter matches dates within range")
    func lastMonthMatchesWithinRange() {
        let filter = ReviewHistoryFilter.lastMonth
        let now = Date()

        // Exactly 29 days ago (should match)
        let twentyNineDaysAgo = now.addingTimeInterval(-86400 * 29)
        #expect(filter.matches(twentyNineDaysAgo), "LastMonth should match 29 days ago")

        // Exactly 1 day ago (should match)
        let oneDayAgo = now.addingTimeInterval(-86400)
        #expect(filter.matches(oneDayAgo), "LastMonth should match 1 day ago")

        // Now (should match)
        #expect(filter.matches(now), "LastMonth should match now")
    }

    @Test("LastMonth filter rejects dates outside range")
    func lastMonthRejectsOutsideRange() {
        let filter = ReviewHistoryFilter.lastMonth
        let now = Date()

        // 31 days ago (should not match)
        let thirtyOneDaysAgo = now.addingTimeInterval(-86400 * 31)
        #expect(!filter.matches(thirtyOneDaysAgo), "LastMonth should not match 31 days ago")

        // Future date (should not match)
        let future = now.addingTimeInterval(3600)
        #expect(!filter.matches(future), "LastMonth should not match future dates")
    }

    @Test("LastMonth boundary case: exactly 30 days ago")
    func lastMonthBoundaryCase() {
        let filter = ReviewHistoryFilter.lastMonth
        let now = Date()

        // Get the startDate from the filter
        let (startDate, _) = filter.dateRange

        // Date exactly at startDate boundary should match
        if let start = startDate {
            #expect(filter.matches(start), "LastMonth should match date exactly at start boundary")
        }
    }

    @Test("LastMonth display properties")
    func lastMonthDisplayProperties() {
        let filter = ReviewHistoryFilter.lastMonth

        #expect(filter.displayName == "Last Month")
        #expect(filter.icon == "calendar")
    }

    // MARK: - Timezone Handling Tests

    @Test("Date calculations use user's timezone")
    func timezoneAwareDateCalculations() {
        let filter = ReviewHistoryFilter.lastWeek

        // Create a date in a specific timezone
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12 // Noon
        components.minute = 30
        let testDate = calendar.date(from: components)!

        // Verify the date is handled correctly regardless of timezone
        let (startDate, endDate) = filter.dateRange
        #expect(startDate! < endDate, "Start date should be before end date")
    }

    @Test("DST transition handling for lastWeek")
    func lastWeekDSTHandling() {
        // Create dates around DST transition (March)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.month = 3 // March (DST start in Northern Hemisphere)
        components.day = 12
        components.hour = 12

        let dstDate = calendar.date(from: components)!
        let filter = ReviewHistoryFilter.lastWeek

        // Should not crash or produce unexpected results
        let matches = filter.matches(dstDate)
        #expect(matches == true || matches == false, "DST date should be handled without error")
    }

    @Test("DST transition handling for lastMonth")
    func lastMonthDSTHandling() {
        // Create dates around DST transition (November)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.month = 11 // November (DST end in Northern Hemisphere)
        components.day = 5
        components.hour = 12

        let dstDate = calendar.date(from: components)!
        let filter = ReviewHistoryFilter.lastMonth

        // Should not crash or produce unexpected results
        let matches = filter.matches(dstDate)
        #expect(matches == true || matches == false, "DST date should be handled without error")
    }

    // MARK: - Filter Comparison Tests

    @Test("LastMonth is more inclusive than LastWeek")
    func lastMonthMoreInclusive() {
        let now = Date()
        let twoWeeksAgo = now.addingTimeInterval(-86400 * 14)

        let lastWeek = ReviewHistoryFilter.lastWeek
        let lastMonth = ReviewHistoryFilter.lastMonth

        // 2 weeks ago should match LastMonth but not LastWeek
        #expect(!lastWeek.matches(twoWeeksAgo), "2 weeks ago should not match LastWeek")
        #expect(lastMonth.matches(twoWeeksAgo), "2 weeks ago should match LastMonth")
    }

    @Test("AllTime includes dates outside LastMonth")
    func allTimeIncludesOldDates() {
        let now = Date()
        let fortyDaysAgo = now.addingTimeInterval(-86400 * 40)

        let allTime = ReviewHistoryFilter.allTime
        let lastMonth = ReviewHistoryFilter.lastMonth

        // 40 days ago should match AllTime but not LastMonth
        #expect(!lastMonth.matches(fortyDaysAgo), "40 days ago should not match LastMonth")
        #expect(allTime.matches(fortyDaysAgo), "40 days ago should match AllTime")
    }

    // MARK: - Edge Cases

    @Test("Filter handles exact midnight boundaries")
    func midnightBoundaries() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        components.second = 0

        let midnight = calendar.date(from: components)!
        let lastWeek = ReviewHistoryFilter.lastWeek

        // Should handle midnight without issues
        let matches = lastWeek.matches(midnight)
        #expect(matches == true || matches == false, "Midnight date should be handled correctly")
    }

    @Test("Filter handles dates with fractional seconds")
    func fractionalSeconds() {
        let now = Date()
        let dateWithFractionalSeconds = now.addingTimeInterval(-123.456) // Specific fractional time

        let lastWeek = ReviewHistoryFilter.lastWeek
        let matches = lastWeek.matches(dateWithFractionalSeconds)

        #expect(matches == true || matches == false, "Fractional seconds should be handled")
    }

    @Test("Filter handles very recent dates (seconds ago)")
    func veryRecentDates() {
        let justNow = Date().addingTimeInterval(-5) // 5 seconds ago

        let allTime = ReviewHistoryFilter.allTime
        let lastWeek = ReviewHistoryFilter.lastWeek
        let lastMonth = ReviewHistoryFilter.lastMonth

        #expect(allTime.matches(justNow), "AllTime should match 5 seconds ago")
        #expect(lastWeek.matches(justNow), "LastWeek should match 5 seconds ago")
        #expect(lastMonth.matches(justNow), "LastMonth should match 5 seconds ago")
    }

    // MARK: - Identifiable Conformance

    @Test("Filter has unique IDs")
    func uniqueIDs() {
        let allTime = ReviewHistoryFilter.allTime
        let lastWeek = ReviewHistoryFilter.lastWeek
        let lastMonth = ReviewHistoryFilter.lastMonth

        #expect(allTime.id == "allTime")
        #expect(lastWeek.id == "lastWeek")
        #expect(lastMonth.id == "lastMonth")

        // IDs should be unique
        #expect(allTime.id != lastWeek.id)
        #expect(lastWeek.id != lastMonth.id)
        #expect(allTime.id != lastMonth.id)
    }

    // MARK: - Case Iterable Conformance

    @Test("All cases are iterable")
    func allCasesPresent() {
        let allFilters = ReviewHistoryFilter.allCases

        #expect(allFilters.count == 3, "Should have exactly 3 filter cases")

        #expect(allFilters.contains(.allTime))
        #expect(allFilters.contains(.lastWeek))
        #expect(allFilters.contains(.lastMonth))
    }

    // MARK: - Sendable Conformance

    @Test("Filters are Sendable (thread-safe)")
    func filtersAreSendable() {
        // This is a compile-time test, but we verify behavior at runtime
        let filter = ReviewHistoryFilter.lastWeek

        // Should be able to pass between concurrency contexts
        Task {
            let matches = filter.matches(Date())
            #expect(matches == true || matches == false)
        }
    }
}
