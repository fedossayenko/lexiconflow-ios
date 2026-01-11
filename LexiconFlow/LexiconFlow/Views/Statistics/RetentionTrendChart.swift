//
//  RetentionTrendChart.swift
//  LexiconFlow
//
//  Line chart showing retention rate over time using Swift Charts
//

import Charts
import SwiftUI

struct RetentionTrendChart: View {
    // MARK: - Properties

    /// Retention data containing trend data points
    let data: RetentionRateData

    /// Chart height for consistent sizing
    var chartHeight: CGFloat = 200

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart header
            HStack {
                Text("Retention Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Overall rate badge
                Text(self.data.formattedPercentage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }

            if self.data.trendData.isEmpty {
                // Empty state
                self.emptyView
            } else {
                // Chart view
                self.chartView
                    .frame(height: self.chartHeight)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Retention trend chart")
        .accessibilityHint(self.chartAccessibilityHint)
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // Area fill below line
            ForEach(self.sortedTrendData, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Retention Rate", point.rate * 100)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Main line
            ForEach(self.sortedTrendData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Retention Rate", point.rate * 100)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Data points (only show if <= 30 points to avoid clutter)
            if self.sortedTrendData.count <= 30 {
                ForEach(self.sortedTrendData, id: \.date) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Retention Rate", point.rate * 100)
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .top) {
                        if self.shouldShowLabel(for: point) {
                            Text("\(Int(point.rate * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: self.xAxisValues) { value in
                AxisValueLabel {
                    if let dateValue = value.as(Date.self) {
                        Text(self.formatDate(dateValue))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
            }
        }
        .chartYScale(domain: 0 ... 100)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No trend data yet")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Complete more reviews to see trends")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: self.chartHeight)
    }

    // MARK: - Computed Properties

    /// Trend data sorted by date
    private var sortedTrendData: [(date: Date, rate: Double)] {
        self.data.trendData.sorted { $0.date < $1.date }
    }

    /// X-axis values (show fewer labels for many data points)
    private var xAxisValues: [Date] {
        let count = self.sortedTrendData.count
        if count <= 7 {
            // Show all dates for small datasets
            return self.sortedTrendData.map(\.date)
        } else if count <= 30 {
            // Show every 5th date for medium datasets
            return stride(from: 0, to: count, by: 5).map {
                self.sortedTrendData[$0].date
            }
        } else {
            // Show first, middle, last for large datasets
            let first = self.sortedTrendData.first?.date
            let middle = self.sortedTrendData[count / 2].date
            let last = self.sortedTrendData.last?.date
            return [first, middle, last].compactMap(\.self)
        }
    }

    /// Accessibility hint describing the trend
    private var chartAccessibilityHint: String {
        let sorted = self.sortedTrendData
        guard !sorted.isEmpty else {
            return "No retention trend data available"
        }

        // Safe to force unwrap after isEmpty check
        guard let firstRate = sorted.first?.rate,
              let lastRate = sorted.last?.rate
        else {
            return "No retention trend data available"
        }

        let firstPercent = Int(firstRate * 100)
        let lastPercent = Int(lastRate * 100)
        let trend = lastPercent >= firstPercent ? "improving" : "declining"

        return "Retention rate is \(trend), from \(firstPercent)% to \(lastPercent)% over \(sorted.count) days"
    }

    // MARK: - Helper Methods

    /// Format date for x-axis label
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()

        // Check if date is within current week
        if let daysUntil = calendar.dateComponents([.day], from: now, to: date).day {
            if abs(daysUntil) <= 7 {
                // Show weekday (Mon, Tue, etc.)
                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                formatter.calendar = calendar
                return formatter.string(from: date)
            }
        }

        // Otherwise show month/day (Jan 6)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.calendar = calendar
        return formatter.string(from: date)
    }

    /// Determine if data point should show percentage label
    ///
    /// **Why selective labeling?**: Prevents visual clutter when many data points exist.
    /// Shows labels for first/last points and extrema (min/max values).
    private func shouldShowLabel(for point: (date: Date, rate: Double)) -> Bool {
        let sorted = self.sortedTrendData
        guard sorted.count > 0 else { return false }

        // Always show first and last points
        if point.date == sorted.first?.date || point.date == sorted.last?.date {
            return true
        }

        // Show min/max retention rates
        let rates = sorted.map(\.rate)
        let minRate = rates.min() ?? 0
        let maxRate = rates.max() ?? 0

        if abs(point.rate - minRate) < 0.01 || abs(point.rate - maxRate) < 0.01 {
            return true
        }

        // For small datasets (<= 7), show all labels
        if sorted.count <= 7 {
            return true
        }

        return false
    }
}

// MARK: - Preview

#Preview("Retention Trend Chart - 7 Days") {
    let _ = Calendar.autoupdatingCurrent
    let now = Date()

    let trendData = [
        (date: now.addingTimeInterval(-6 * 24 * 3600), rate: 0.75),
        (date: now.addingTimeInterval(-5 * 24 * 3600), rate: 0.78),
        (date: now.addingTimeInterval(-4 * 24 * 3600), rate: 0.82),
        (date: now.addingTimeInterval(-3 * 24 * 3600), rate: 0.80),
        (date: now.addingTimeInterval(-2 * 24 * 3600), rate: 0.85),
        (date: now.addingTimeInterval(-1 * 24 * 3600), rate: 0.88),
        (date: now, rate: 0.90)
    ]

    let data = RetentionRateData(
        rate: 0.82,
        successfulCount: 45,
        failedCount: 10,
        trendData: trendData
    )

    return VStack {
        RetentionTrendChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("Retention Trend Chart - 30 Days") {
    let _ = Calendar.autoupdatingCurrent
    let now = Date()

    var trendData: [(date: Date, rate: Double)] = []
    for i in 0 ..< 30 {
        let date = now.addingTimeInterval(-Double(29 - i) * 24 * 3600)
        // Simulate gradual improvement with some fluctuation
        let baseRate = 0.70 + (Double(i) / 30.0) * 0.20
        let fluctuation = Double.random(in: -0.05 ... 0.05)
        let rate = min(max(baseRate + fluctuation, 0.0), 1.0)
        trendData.append((date: date, rate: rate))
    }

    let data = RetentionRateData(
        rate: 0.85,
        successfulCount: 180,
        failedCount: 32,
        trendData: trendData
    )

    return VStack {
        RetentionTrendChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("Retention Trend Chart - Empty Data") {
    let _ = Calendar.autoupdatingCurrent

    let data = RetentionRateData(
        rate: 0.0,
        successfulCount: 0,
        failedCount: 0,
        trendData: []
    )

    return VStack {
        RetentionTrendChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("Retention Trend Chart - Dark Mode") {
    let _ = Calendar.autoupdatingCurrent
    let now = Date()

    let trendData = [
        (date: now.addingTimeInterval(-6 * 24 * 3600), rate: 0.75),
        (date: now.addingTimeInterval(-5 * 24 * 3600), rate: 0.78),
        (date: now.addingTimeInterval(-4 * 24 * 3600), rate: 0.82),
        (date: now.addingTimeInterval(-3 * 24 * 3600), rate: 0.80),
        (date: now.addingTimeInterval(-2 * 24 * 3600), rate: 0.85),
        (date: now.addingTimeInterval(-1 * 24 * 3600), rate: 0.88),
        (date: now, rate: 0.90)
    ]

    let data = RetentionRateData(
        rate: 0.82,
        successfulCount: 45,
        failedCount: 10,
        trendData: trendData
    )

    return VStack {
        RetentionTrendChart(data: data)
        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Retention Trend Chart - Many Data Points") {
    let _ = Calendar.autoupdatingCurrent
    let now = Date()

    var trendData: [(date: Date, rate: Double)] = []
    for i in 0 ..< 45 {
        let date = now.addingTimeInterval(-Double(44 - i) * 24 * 3600)
        // Simulate gradual improvement with some fluctuation
        let baseRate = 0.65 + (Double(i) / 45.0) * 0.25
        let fluctuation = Double.random(in: -0.08 ... 0.08)
        let rate = min(max(baseRate + fluctuation, 0.0), 1.0)
        trendData.append((date: date, rate: rate))
    }

    let data = RetentionRateData(
        rate: 0.83,
        successfulCount: 285,
        failedCount: 58,
        trendData: trendData
    )

    return VStack {
        RetentionTrendChart(data: data)
        Spacer()
    }
    .padding()
}
