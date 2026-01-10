//
//  MetricCard.swift
//  LexiconFlow
//
//  Reusable metric card component with Liquid Glass design
//

import SwiftUI

struct MetricCard: View {
    // MARK: - Properties

    /// Card title (e.g., "Retention Rate")
    let title: String

    /// Primary value to display (e.g., "85%", "12 days")
    let value: String

    /// Subtitle providing additional context
    let subtitle: String

    /// SF Symbol icon name
    let icon: String

    /// Accent color for the icon
    let color: Color

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .cornerRadius(10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(subtitle)
    }
}

// MARK: - Preview

#Preview("Metric Card - Blue") {
    MetricCard(
        title: "Retention Rate",
        value: "85%",
        subtitle: "17 of 20 reviews successful",
        icon: "chart.line.uptrend.xyaxis",
        color: .blue
    )
    .padding()
}

#Preview("Metric Card - Orange") {
    MetricCard(
        title: "Study Streak",
        value: "12",
        subtitle: "days",
        icon: "flame.fill",
        color: .orange
    )
    .padding()
}

#Preview("Metric Card - Green") {
    MetricCard(
        title: "Study Time",
        value: "5h 23m",
        subtitle: "Total time studied",
        icon: "clock.fill",
        color: .green
    )
    .padding()
}

#Preview("Metric Card - Purple") {
    MetricCard(
        title: "Cards",
        value: "45",
        subtitle: "of 100 reviewed",
        icon: "rectangle.stack.fill",
        color: .purple
    )
    .padding()
}

#Preview("Metric Card - Dark Mode") {
    VStack(spacing: 16) {
        MetricCard(
            title: "Retention Rate",
            value: "85%",
            subtitle: "17 of 20 reviews successful",
            icon: "chart.line.uptrend.xyaxis",
            color: .blue
        )

        MetricCard(
            title: "Study Streak",
            value: "12",
            subtitle: "days",
            icon: "flame.fill",
            color: .orange
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
