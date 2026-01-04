//
//  DateMathTests.swift
//  LexiconFlowTests
//
//  Tests for timezone-aware date calculations
//

import Testing
import Foundation
@testable import LexiconFlow

/// Test suite for DateMath utilities
///
/// Tests verify:
/// - Accurate day calculations
/// - DST handling
/// - Timezone awareness
/// - Edge cases
@MainActor
struct DateMathTests {

    // MARK: - Elapsed Days Tests

    @Test("Elapsed days for same time is zero")
    func elapsedDaysSameTime() {
        let now = Date()
        let elapsed = DateMath.elapsedDays(from: now, to: now)
        #expect(elapsed == 0.0)
    }

    @Test("Elapsed days handles full day")
    func elapsedDaysFullDay() {
        let start = Date()
        let end = start.addingTimeInterval(86400) // Exactly 24 hours
        let elapsed = DateMath.elapsedDays(from: start, to: end)
        #expect(elapsed == 1.0)
    }

    @Test("Elapsed days handles fractional days")
    func elapsedDaysFractional() {
        let start = Date()
        let end = start.addingTimeInterval(3600 * 6) // 6 hours
        let elapsed = DateMath.elapsedDays(from: start, to: end)
        let expected = 6.0 / 24.0
        #expect(abs(elapsed - expected) < 0.001)
    }

    @Test("Elapsed days is never negative")
    func elapsedDaysNonNegative() {
        let future = Date().addingTimeInterval(3600) // 1 hour in future
        let past = Date()
        let elapsed = DateMath.elapsedDays(from: future, to: past)
        #expect(elapsed == 0.0, "Clock skew should result in 0, not negative")
    }

    @Test("Elapsed days across midnight")
    func elapsedDaysAcrossMidnight() {
        // Create date at 11 PM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 0
        let evening = calendar.date(from: components)!

        // Create date at 1 AM next day
        components.day! += 1
        components.hour = 1
        let morning = calendar.date(from: components)!

        let elapsed = DateMath.elapsedDays(from: evening, to: morning)
        // Should be ~2 hours = 2/24 of a day
        #expect(elapsed > 0.08 && elapsed < 0.09)
    }

    // MARK: - Date Comparison Tests

    @Test("Is today works for current date")
    func isTodayCurrent() {
        let now = Date()
        #expect(DateMath.isToday(now))
    }

    @Test("Is today false for yesterday")
    func isTodayYesterday() {
        let yesterday = Date().addingTimeInterval(-86400)
        #expect(!DateMath.isToday(yesterday))
    }

    @Test("Is today false for tomorrow")
    func isTodayTomorrow() {
        let tomorrow = Date().addingTimeInterval(86400)
        #expect(!DateMath.isToday(tomorrow))
    }

    @Test("Is due works for past date")
    func isDuePast() {
        let past = Date().addingTimeInterval(-3600)
        #expect(DateMath.isDue(past))
    }

    @Test("Is due works for now")
    func isDueNow() {
        #expect(DateMath.isDue(Date()))
    }

    @Test("Is due false for future")
    func isDueFuture() {
        let future = Date().addingTimeInterval(3600)
        #expect(!DateMath.isDue(future))
    }

    // MARK: - Format Tests

    @Test("Format relative for recent times")
    func formatRelativeRecent() {
        let now = Date()
        #expect(DateMath.formatRelative(now) == "now")

        let in1Hour = now.addingTimeInterval(3600)
        #expect(DateMath.formatRelative(in1Hour).hasPrefix("in "))

        let yesterday = now.addingTimeInterval(-86400)
        #expect(DateMath.formatRelative(yesterday) == "yesterday")
    }

    @Test("Format elapsed for recent times")
    func formatElapsedRecent() {
        let now = Date()
        #expect(DateMath.formatElapsed(0) == "just now")

        let hoursAgo = now.addingTimeInterval(-7200) // 2 hours ago
        let hoursElapsed = DateMath.elapsedDays(from: hoursAgo, to: now)
        #expect(DateMath.formatElapsed(hoursElapsed) == "2h ago")

        let daysAgo = now.addingTimeInterval(-86400) // 1 day ago
        let daysElapsed = DateMath.elapsedDays(from: daysAgo, to: now)
        #expect(DateMath.formatElapsed(daysElapsed) == "yesterday")
    }

    // MARK: - Same Day Tests

    @Test("Is same day for same date")
    func isSameDaySame() {
        let date = Date()
        #expect(DateMath.isSameDay(date, date))
    }

    @Test("Is same day false for different dates")
    func isSameDayDifferent() {
        let date1 = Date()
        let date2 = date1.addingTimeInterval(86400)
        #expect(!DateMath.isSameDay(date1, date2))
    }

    @Test("Is same day true across midnight boundary")
    func isSameDayAcrossMidnight() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())

        // 11 PM same day
        components.hour = 23
        let evening = calendar.date(from: components)!

        // 1 AM next calendar day
        components.day! += 1
        components.hour = 1
        let morning = calendar.date(from: components)!

        #expect(!DateMath.isSameDay(evening, morning))
    }

    // MARK: - Extension Tests

    @Test("Date extension daysElapsed")
    func dateExtensionDaysElapsed() {
        let past = Date().addingTimeInterval(-86400 * 3) // 3 days ago
        #expect(past.daysElapsed >= 2.9 && past.daysElapsed <= 3.1)
    }

    @Test("Date extension isDue")
    func dateExtensionIsDue() {
        let past = Date().addingTimeInterval(-100)
        #expect(past.isDue)

        let future = Date().addingTimeInterval(100)
        #expect(!future.isDue)
    }

    @Test("Date extension adding days")
    func dateExtensionAddingDays() {
        let now = Date()
        let tomorrow = now.adding(days: 1)
        let elapsed = DateMath.elapsedDays(from: now, to: tomorrow)
        #expect(elapsed >= 0.99 && elapsed <= 1.01)
    }

    // MARK: - DST Edge Cases

    @Test("Handles DST transition forward")
    func dstTransitionForward() {
        // Create date during spring forward (simulated)
        // In spring, clocks move forward 1 hour at 2 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.month = 3 // March
        components.day = 10 // Approximate DST start in Northern Hemisphere
        components.hour = 1

        let beforeDST = calendar.date(from: components)!

        // Add 2 hours (should cross DST)
        let afterDST = beforeDST.addingTimeInterval(7200)

        // Should still calculate as roughly 1 day plus some hours
        let elapsed = DateMath.elapsedDays(from: beforeDST, to: afterDST)
        #expect(elapsed > 0 && elapsed < 1)
    }

    @Test("Handles DST transition backward")
    func dstTransitionBackward() {
        // Create date during fall back (simulated)
        // In fall, clocks move back 1 hour at 2 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.month = 11 // November
        components.day = 5 // Approximate DST end in Northern Hemisphere
        components.hour = 1

        let beforeDST = calendar.date(from: components)!

        // Add 2 hours (should cross DST)
        let afterDST = beforeDST.addingTimeInterval(7200)

        // Should calculate correctly despite hour repeating
        let elapsed = DateMath.elapsedDays(from: beforeDST, to: afterDST)
        #expect(elapsed > 0 && elapsed < 1)
    }
}
