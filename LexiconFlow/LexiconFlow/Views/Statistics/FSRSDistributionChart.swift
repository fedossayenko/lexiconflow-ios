//
//  FSRSDistributionChart.swift
//  LexiconFlow
//
//  Bar chart showing distribution of card stability and difficulty levels
//

import Charts
import SwiftUI

struct FSRSDistributionChart: View {
    // MARK: - Properties

    /// FSRS metrics data containing distribution histograms
    let data: FSRSMetricsData

    /// Chart height for consistent sizing
    var chartHeight: CGFloat = 180

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart header
            HStack {
                Text("FSRS Metrics")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Average metrics badge
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Stability")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(data.formattedStability)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Difficulty")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(data.formattedDifficulty)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
            }

            if data.reviewedCards == 0 {
                // Empty state
                emptyView
            } else {
                // Stability distribution chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Stability Distribution")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    stabilityChart
                        .frame(height: chartHeight)
                }

                Divider()
                    .padding(.vertical, 4)

                // Difficulty distribution chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty Distribution")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    difficultyChart
                        .frame(height: chartHeight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FSRS metrics distribution")
        .accessibilityHint(chartAccessibilityHint)
    }

    // MARK: - Stability Chart

    private var stabilityChart: some View {
        let chartData = stabilityChartData

        return Chart {
            ForEach(chartData, id: \.label) { bucket in
                BarMark(
                    x: .value("Stability", bucket.label),
                    y: .value("Cards", bucket.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(shortenedStabilityLabel(label))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.purple.opacity(0.05))
        }
    }

    // MARK: - Difficulty Chart

    private var difficultyChart: some View {
        let chartData = difficultyChartData

        return Chart {
            ForEach(chartData, id: \.label) { bucket in
                BarMark(
                    x: .value("Difficulty", bucket.label),
                    y: .value("Cards", bucket.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(shortenedDifficultyLabel(label))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.blue.opacity(0.05))
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No FSRS data yet")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Review cards to see memory stability and difficulty distribution")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    // MARK: - Computed Properties

    /// Stability distribution data sorted by bucket order
    private var stabilityChartData: [(label: String, count: Int)] {
        let orderedBuckets = [
            "0-1 days", "1-3 days", "3-7 days", "1-2 weeks", "2-4 weeks",
            "1-3 months", "3-6 months", "6-12 months", "1+ years"
        ]

        return orderedBuckets.map { label in
            (label: label, count: data.stabilityDistribution[label] ?? 0)
        }
    }

    /// Difficulty distribution data sorted by bucket order
    private var difficultyChartData: [(label: String, count: Int)] {
        let orderedBuckets = [
            "0-2 (Very Easy)", "2-4 (Easy)", "4-6 (Medium)", "6-8 (Hard)", "8-10 (Very Hard)"
        ]

        return orderedBuckets.map { label in
            (label: label, count: data.difficultyDistribution[label] ?? 0)
        }
    }

    /// Accessibility hint describing the distributions
    private var chartAccessibilityHint: String {
        let reviewed = data.reviewedCards
        let avgStability = data.formattedStability
        let avgDifficulty = data.formattedDifficulty

        if reviewed == 0 {
            return "No FSRS metrics available yet. Review cards to see memory patterns."
        }

        return "\(reviewed) cards reviewed. Average stability \(avgStability), average difficulty \(avgDifficulty)"
    }

    // MARK: - Helper Methods

    /// Shorten stability label for x-axis display
    ///
    /// **Why shortening?**: Long labels like "6-12 months" overcrowd the x-axis.
    /// Shortened versions maintain readability while fitting available space.
    private func shortenedStabilityLabel(_ label: String) -> String {
        let shortMappings: [String: String] = [
            "0-1 days": "0-1d",
            "1-3 days": "1-3d",
            "3-7 days": "3-7d",
            "1-2 weeks": "1-2w",
            "2-4 weeks": "2-4w",
            "1-3 months": "1-3mo",
            "3-6 months": "3-6mo",
            "6-12 months": "6-12mo",
            "1+ years": "1+yr"
        ]

        return shortMappings[label] ?? label
    }

    /// Shorten difficulty label for x-axis display
    ///
    /// **Why shortening?**: Labels like "0-2 (Very Easy)" are too long for narrow bars.
    /// Shows just the descriptive category for cleaner visual.
    private func shortenedDifficultyLabel(_ label: String) -> String {
        if label.contains("Very Easy") { return "V. Easy" }
        if label.contains("Easy"), !label.contains("Very") { return "Easy" }
        if label.contains("Medium") { return "Medium" }
        if label.contains("Hard"), !label.contains("Very") { return "Hard" }
        if label.contains("Very Hard") { return "V. Hard" }
        return label
    }
}

// MARK: - Preview

#Preview("FSRS Distribution Chart - New User") {
    let data = FSRSMetricsData(
        averageStability: 0.0,
        averageDifficulty: 5.0,
        stabilityDistribution: [:],
        difficultyDistribution: [:],
        totalCards: 10,
        reviewedCards: 0
    )

    return VStack {
        FSRSDistributionChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("FSRS Distribution Chart - Mixed Stability") {
    let data = FSRSMetricsData(
        averageStability: 45.5,
        averageDifficulty: 4.8,
        stabilityDistribution: [
            "0-1 days": 5,
            "1-3 days": 8,
            "3-7 days": 12,
            "1-2 weeks": 15,
            "2-4 weeks": 20,
            "1-3 months": 18,
            "3-6 months": 10,
            "6-12 months": 6,
            "1+ years": 3
        ],
        difficultyDistribution: [
            "0-2 (Very Easy)": 15,
            "2-4 (Easy)": 25,
            "4-6 (Medium)": 30,
            "6-8 (Hard)": 20,
            "8-10 (Very Hard)": 10
        ],
        totalCards: 97,
        reviewedCards: 97
    )

    return VStack {
        FSRSDistributionChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("FSRS Distribution Chart - Advanced Learner") {
    let data = FSRSMetricsData(
        averageStability: 180.0,
        averageDifficulty: 6.5,
        stabilityDistribution: [
            "0-1 days": 2,
            "1-3 days": 5,
            "3-7 days": 8,
            "1-2 weeks": 10,
            "2-4 weeks": 15,
            "1-3 months": 25,
            "3-6 months": 30,
            "6-12 months": 20,
            "1+ years": 15
        ],
        difficultyDistribution: [
            "0-2 (Very Easy)": 5,
            "2-4 (Easy)": 15,
            "4-6 (Medium)": 40,
            "6-8 (Hard)": 30,
            "8-10 (Very Hard)": 10
        ],
        totalCards: 130,
        reviewedCards: 130
    )

    return VStack {
        FSRSDistributionChart(data: data)
        Spacer()
    }
    .padding()
}

#Preview("FSRS Distribution Chart - Dark Mode") {
    let data = FSRSMetricsData(
        averageStability: 60.0,
        averageDifficulty: 5.2,
        stabilityDistribution: [
            "0-1 days": 10,
            "1-3 days": 15,
            "3-7 days": 20,
            "1-2 weeks": 18,
            "2-4 weeks": 22,
            "1-3 months": 15,
            "3-6 months": 10,
            "6-12 months": 5,
            "1+ years": 2
        ],
        difficultyDistribution: [
            "0-2 (Very Easy)": 20,
            "2-4 (Easy)": 30,
            "4-6 (Medium)": 35,
            "6-8 (Hard)": 12,
            "8-10 (Very Hard)": 3
        ],
        totalCards: 117,
        reviewedCards: 117
    )

    return VStack {
        FSRSDistributionChart(data: data)
        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("FSRS Distribution Chart - Easy Cards") {
    let data = FSRSMetricsData(
        averageStability: 90.0,
        averageDifficulty: 3.2,
        stabilityDistribution: [
            "0-1 days": 3,
            "1-3 days": 5,
            "3-7 days": 8,
            "1-2 weeks": 10,
            "2-4 weeks": 25,
            "1-3 months": 30,
            "3-6 months": 15,
            "6-12 months": 8,
            "1+ years": 5
        ],
        difficultyDistribution: [
            "0-2 (Very Easy)": 45,
            "2-4 (Easy)": 35,
            "4-6 (Medium)": 15,
            "6-8 (Hard)": 4,
            "8-10 (Very Hard)": 1
        ],
        totalCards: 109,
        reviewedCards: 109
    )

    return VStack {
        FSRSDistributionChart(data: data)
        Spacer()
    }
    .padding()
}
