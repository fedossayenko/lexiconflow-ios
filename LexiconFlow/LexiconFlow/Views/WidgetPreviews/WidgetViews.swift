//
//  WidgetViews.swift
//  LexiconFlow
//
//  Shared SwiftUI views for Widgets.
//  These are kept in the main app to allow for easier Previewing and sharing code.
//

import SwiftUI
import WidgetKit

// MARK: - Design Constants

private enum WidgetDesign {
    static let cornerRadius: CGFloat = 16
    static let glassOpacity: CGFloat = 0.2
}

// MARK: - Models

/// Mock data model for previews
struct WidgetEntryMock {
    let date: Date
    let dueCount: Int
    let streakCount: Int
}

// MARK: - Small Stats View (SystemSmall)

struct SmallStatsWidgetView: View {
    let dueCount: Int
    let streakCount: Int

    var body: some View {
        ZStack {
            // Background gradient
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                // Streak Row
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("\(self.streakCount) day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }

                Spacer()

                // Due Count (Main Focus)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(self.dueCount)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text(self.dueCount == 1 ? "card due" : "cards due")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }

                Spacer()

                // Button visual (non-interactive but indicates action)
                HStack {
                    Text("Study Now")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background {
                    Capsule()
                        .fill(Color.accentColor.gradient)
                }
            }
            .padding()
        }
    }
}

// MARK: - Lock Screen Circular (AccessoryCircular)

struct LockScreenCircularView: View {
    let dueCount: Int

    var body: some View {
        Gauge(value: min(Double(self.dueCount), 20.0), in: 0 ... 20) {
            Text("Review")
        } currentValueLabel: {
            Text("\(self.dueCount)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Lock Screen Rectangular (AccessoryRectangular)

struct LockScreenRectangularView: View {
    let dueCount: Int
    let streakCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Vertical bar
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                    Text("\(self.dueCount) Due")
                        .font(.headline)
                }

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(self.streakCount) Day Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Small System") {
    SmallStatsWidgetView(dueCount: 12, streakCount: 5)
        .frame(width: 155, height: 155)
        .clipShape(RoundedRectangle(cornerRadius: 20))
}

#Preview("Lock Screen Circular") {
    LockScreenCircularView(dueCount: 8)
        .padding()
        .background(.black)
}

#Preview("Lock Screen Rectangular") {
    LockScreenRectangularView(dueCount: 12, streakCount: 45)
        .padding()
        .background(.black)
}

// Helper for preview syntax compatibility
extension View {
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            return self.containerBackground(color, for: .widget)
        } else {
            return self.background(color)
        }
    }
}
