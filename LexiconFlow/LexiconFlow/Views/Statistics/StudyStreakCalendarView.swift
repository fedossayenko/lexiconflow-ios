//
//  StudyStreakCalendarView.swift
//  LexiconFlow
//
//  Calendar heatmap visualization showing study activity with streak highlighting
//  GitHub contribution graph style
//

import SwiftUI

struct StudyStreakCalendarView: View {
    // MARK: - Properties

    /// Study streak data containing calendar heatmap data
    let data: StudyStreakData

    /// Number of weeks to display (default: 12 weeks)
    var weeksToShow: Int = 12

    /// Size of each day cell
    var cellSize: CGFloat = 12

    /// Spacing between cells
    var cellSpacing: CGFloat = 3

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with streak info
            headerView

            if data.calendarData.isEmpty {
                // Empty state
                emptyView
            } else {
                // Calendar heatmap
                calendarView
            }

            // Legend
            legendView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Study calendar heatmap")
        .accessibilityHint(calendarAccessibilityHint)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Study Calendar")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Current streak badge
            if data.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(data.currentStreak)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .accessibilityLabel("Current streak \(data.currentStreak) days")
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day labels
            dayLabelsView

            // Heatmap grid
            ScrollView(.horizontal, showsIndicators: false) {
                heatmapGrid
            }
        }
    }

    // MARK: - Day Labels

    private var dayLabelsView: some View {
        HStack(spacing: cellSpacing) {
            Text("")
                .frame(width: cellSize)

            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize)
            }

            Spacer()
        }
    }

    /// Day labels to show (Mon, Wed, Fri)
    private var dayLabels: [String] {
        ["Mon", "", "Wed", "", "Fri", ""]
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            // Month labels (left side)
            VStack(alignment: .trailing, spacing: cellSpacing) {
                ForEach(monthLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: cellSize)
                }
            }

            // Weeks grid
            ForEach(weekIndices, id: \.self) { weekIndex in
                VStack(spacing: cellSpacing) {
                    ForEach(0 ..< 7) { dayIndex in
                        let date = dateFor(week: weekIndex, day: dayIndex)
                        let studyTime = data.calendarData[date]

                        DayCell(
                            date: date,
                            studyTime: studyTime,
                            size: cellSize,
                            isToday: isToday(date),
                            isInStreak: isInCurrentStreak(date)
                        )
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    /// Week indices to display
    private var weekIndices: [Int] {
        let calendar = Calendar.autoupdatingCurrent
        let today = Date()

        // Start from weeksToShow weeks ago
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let endDate = calendar.date(byAdding: .day, value: -(weeksToShow * 7), to: startOfWeek) ?? today

        // Calculate week offset
        let weeks = Int(DateMath.elapsedDays(from: endDate, to: startOfWeek) / 7.0)
        return Array(0 ..< weeks)
    }

    /// Month labels for vertical axis
    private var monthLabels: [String] {
        let calendar = Calendar.autoupdatingCurrent
        _ = Date()
        var labels: [String] = []
        var lastMonth = -1

        // Generate month labels for each week
        for weekIndex in weekIndices {
            let date = dateFor(week: weekIndex, day: 0)
            let month = calendar.component(.month, from: date)

            if month != lastMonth {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                labels.append(formatter.string(from: date))
                lastMonth = month
            } else {
                labels.append("")
            }
        }

        return labels
    }

    // MARK: - Legend View

    private var legendView: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(legendLevels, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForLevel(level))
                    .frame(width: cellSize, height: cellSize)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Activity levels for legend
    private var legendLevels: [Int] {
        [0, 1, 2, 3, 4]
    }

    // MARK: - Helper Methods

    /// Get date for given week and day index
    ///
    /// **Why reverse week indexing?**: Grid displays from past to present,
    /// so week 0 is the oldest week and max week is the current week.
    private func dateFor(week: Int, day: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let today = Date()

        // Find first day of week (Sunday)
        let firstOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        // Calculate offset: week 0 = oldest week
        let totalWeeks = weekIndices.count
        let weekOffset = (totalWeeks - 1 - week) * 7

        // Add day offset (0 = Sunday, 1 = Monday, etc.)
        let dayOffset = weekOffset + day

        return calendar.date(byAdding: .day, value: -dayOffset, to: firstOfWeek) ?? today
    }

    /// Check if date is today
    private func isToday(_ date: Date) -> Bool {
        DateMath.isSameDay(date, Date())
    }

    /// Check if date is part of current streak
    ///
    /// **Why this logic?**: Current streak counts backward from today,
    /// so any day within currentStreak days from today is part of the streak.
    private func isInCurrentStreak(_ date: Date) -> Bool {
        guard data.currentStreak > 0 else { return false }

        let calendar = Calendar.autoupdatingCurrent
        let today = Date()

        for dayOffset in 0 ..< data.currentStreak {
            let streakDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            if DateMath.isSameDay(date, streakDate) {
                return true
            }
        }

        return false
    }

    /// Get activity level (0-4) based on study time
    ///
    /// **Why logarithmic scale?**: Study time varies widely (30s to 1h+).
    /// Logarithmic buckets make the heatmap more visually informative.
    private func activityLevel(for studyTime: TimeInterval) -> Int {
        let minutes = studyTime / 60.0

        if minutes < 1 { return 0 }
        if minutes < 5 { return 1 }
        if minutes < 15 { return 2 }
        if minutes < 30 { return 3 }
        return 4
    }

    /// Get color for activity level
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: Color(.systemGray6)
        case 1: Color.green.opacity(0.3)
        case 2: Color.green.opacity(0.5)
        case 3: Color.green.opacity(0.7)
        case 4: Color.green
        default: Color(.systemGray6)
        }
    }

    /// Accessibility hint describing calendar activity
    private var calendarAccessibilityHint: String {
        let activeDays = data.activeDays
        let streak = data.currentStreak

        if activeDays == 0 {
            return "No study activity recorded yet"
        }

        return "\(activeDays) active days, current streak \(streak) days"
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No study activity yet")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Complete study sessions to build your streak")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }
}

// MARK: - Day Cell Component

private struct DayCell: View {
    let date: Date
    let studyTime: TimeInterval?
    let size: CGFloat
    let isToday: Bool
    let isInStreak: Bool

    var body: some View {
        // Use optional binding instead of force unwrap
        let hasActivity = (studyTime ?? 0) > 0
        let level = hasActivity ? activityLevel(for: studyTime ?? 0) : 0

        RoundedRectangle(cornerRadius: 2)
            .fill(colorForLevel(level))
            .overlay(
                // Streak highlight border
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.orange, lineWidth: isInStreak ? 2 : 0)
            )
            .overlay(
                // Today indicator
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.blue, lineWidth: isToday ? 2 : 0)
            )
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
    }

    /// Activity level (0-4) based on study time
    private func activityLevel(for studyTime: TimeInterval) -> Int {
        let minutes = studyTime / 60.0

        if minutes < 1 { return 0 }
        if minutes < 5 { return 1 }
        if minutes < 15 { return 2 }
        if minutes < 30 { return 3 }
        return 4
    }

    /// Color for activity level
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: Color(.systemGray6)
        case 1: Color.green.opacity(0.3)
        case 2: Color.green.opacity(0.5)
        case 3: Color.green.opacity(0.7)
        case 4: Color.green
        default: Color(.systemGray6)
        }
    }

    /// Accessibility label for day cell
    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let dateString = formatter.string(from: date)

        if let time = studyTime, time > 0 {
            let minutes = Int(time / 60.0)
            return "\(dateString), \(minutes) minutes studied"
        } else {
            return "\(dateString), no activity"
        }
    }

    /// Accessibility hint for day cell
    private var accessibilityHint: String {
        if isToday, isInStreak {
            "Today, part of current streak"
        } else if isToday {
            "Today"
        } else if isInStreak {
            "Part of current streak"
        } else {
            ""
        }
    }
}

// MARK: - Preview

#Preview("Study Streak Calendar - Active User") {
    let calendar = Calendar.autoupdatingCurrent
    let now = Date()

    // Generate 30 days of activity with varying intensity
    var calendarData: [Date: TimeInterval] = [:]
    for i in 0 ..< 30 {
        let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
        let day = DateMath.startOfDay(for: date)

        // Skip some days to break streak
        if i == 7 || i == 15 || i == 22 {
            continue
        }

        // Varying study time (5min to 45min)
        let minutes = Double.random(in: 5 ... 45)
        calendarData[day] = minutes * 60
    }

    let data = StudyStreakData(
        currentStreak: 7,
        longestStreak: 15,
        calendarData: calendarData,
        activeDays: 27,
        hasStudiedToday: true
    )

    return VStack {
        StudyStreakCalendarView(data: data)
        Spacer()
    }
    .padding()
}

#Preview("Study Streak Calendar - New User") {
    let data = StudyStreakData(
        currentStreak: 0,
        longestStreak: 0,
        calendarData: [:],
        activeDays: 0,
        hasStudiedToday: false
    )

    return VStack {
        StudyStreakCalendarView(data: data)
        Spacer()
    }
    .padding()
}

#Preview("Study Streak Calendar - Dark Mode") {
    let calendar = Calendar.autoupdatingCurrent
    let now = Date()

    // Generate 45 days of activity
    var calendarData: [Date: TimeInterval] = [:]
    for i in 0 ..< 45 {
        let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
        let day = DateMath.startOfDay(for: date)

        // Consecutive days for long streak
        if i <= 30 {
            let minutes = Double.random(in: 10 ... 60)
            calendarData[day] = minutes * 60
        }
    }

    let data = StudyStreakData(
        currentStreak: 30,
        longestStreak: 45,
        calendarData: calendarData,
        activeDays: 45,
        hasStudiedToday: true
    )

    return VStack {
        StudyStreakCalendarView(data: data)
        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Study Streak Calendar - Light Activity") {
    let calendar = Calendar.autoupdatingCurrent
    let now = Date()

    // Generate light activity (5-10min sessions)
    var calendarData: [Date: TimeInterval] = [:]
    for i in 0 ..< 20 {
        let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
        let day = DateMath.startOfDay(for: date)

        if i % 2 == 0 { // Every other day
            let minutes = Double.random(in: 5 ... 10)
            calendarData[day] = minutes * 60
        }
    }

    let data = StudyStreakData(
        currentStreak: 0,
        longestStreak: 5,
        calendarData: calendarData,
        activeDays: 10,
        hasStudiedToday: false
    )

    return VStack {
        StudyStreakCalendarView(data: data)
        Spacer()
    }
    .padding()
}
