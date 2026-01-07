//
//  TimeRangePicker.swift
//  LexiconFlow
//
//  Segmented picker for selecting statistics time range (7d, 30d, all time)
//

import SwiftUI

struct TimeRangePicker: View {
    // MARK: - Properties

    /// Binding to the selected time range
    @Binding var selection: StatisticsTimeRange

    // MARK: - Body

    var body: some View {
        Picker("Time Range", selection: $selection) {
            ForEach(StatisticsTimeRange.allCases, id: \.self) { timeRange in
                Text(timeRange.displayName)
                    .tag(timeRange)
                    .accessibilityLabel(timeRange.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range selector")
        .accessibilityHint("Select time range for statistics display. Options: 7 days, 30 days, or all time")
    }
}

// MARK: - Preview

#Preview("TimeRangePicker - 7 Days") {
    TimeRangePicker(selection: .constant(.sevenDays))
        .padding()
        .previewLayout(.sizeThatFits)
}

#Preview("TimeRangePicker - 30 Days") {
    TimeRangePicker(selection: .constant(.thirtyDays))
        .padding()
        .previewLayout(.sizeThatFits)
}

#Preview("TimeRangePicker - All Time") {
    TimeRangePicker(selection: .constant(.allTime))
        .padding()
        .previewLayout(.sizeThatFits)
}

#Preview("TimeRangePicker - Dark Mode") {
    VStack(spacing: 16) {
        TimeRangePicker(selection: .constant(.sevenDays))
        TimeRangePicker(selection: .constant(.thirtyDays))
        TimeRangePicker(selection: .constant(.allTime))
    }
    .padding()
    .preferredColorScheme(.dark)
    .previewLayout(.sizeThatFits)
}

#Preview("TimeRangePicker - Interactive") {
    struct InteractivePreview: View {
        @State private var selection: StatisticsTimeRange = .sevenDays

        var body: some View {
            VStack(spacing: 24) {
                TimeRangePicker(selection: $selection)

                Text("Selected: \(selection.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    return InteractivePreview()
        .previewLayout(.sizeThatFits)
}
