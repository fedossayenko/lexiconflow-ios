//
//  StudySettingsView.swift
//  LexiconFlow
//
//  Study session settings screen
//

import SwiftUI
import SwiftData

struct StudySettingsView: View {
    @AppStorage("studyLimit") private var studyLimit = 20
    @AppStorage("defaultStudyMode") private var studyMode = "scheduled"
    @AppStorage("dailyGoal") private var dailyGoal = 20

    @Environment(\.modelContext) private var modelContext
    @State private var statistics: StudyStatisticsViewModel?

    private let limitOptions = [10, 20, 30, 50, 100]
    private let goalOptions = [10, 20, 30, 50, 100]

    var body: some View {
        Form {
            // Study Session Limits
            Section {
                Picker("Cards per Session", selection: $studyLimit) {
                    ForEach(limitOptions, id: \.self) { limit in
                        Text("\(limit) cards").tag(limit)
                    }
                }
                .accessibilityLabel("Cards per session")

                Picker("Daily Goal", selection: $dailyGoal) {
                    ForEach(goalOptions, id: \.self) { goal in
                        Text("\(goal) cards").tag(goal)
                    }
                }
                .accessibilityLabel("Daily study goal")
            } header: {
                Text("Session Limits")
            } footer: {
                Text("Maximum cards to fetch per study session. Changes apply to next session.")
            }

            // Study Mode
            Section {
                Picker("Default Mode", selection: $studyMode) {
                    ForEach(AppSettings.StudyModeOption.allCases, id: \.rawValue) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName)
                                .font(.body)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode.rawValue)
                    }
                }
                .accessibilityLabel("Default study mode")
            } header: {
                Text("Study Mode")
            } footer: {
                Text("Learn New: Study cards you haven't seen before\nScheduled: Review cards due based on FSRS algorithm")
            }

            // Statistics Preview
            Section {
                if let stats = statistics {
                    if stats.isLoading {
                        ProgressView("Loading statistics...")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.todayStudied)")
                                        .font(.title2)
                                        .bold()
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Due")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.dueCount)")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(stats.dueCount > 0 ? .orange : .primary)
                                }
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Streak")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.streakDays) days")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.totalCards)")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Progress bar for daily goal
                            HStack {
                                Text("Goal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(stats.todayStudied), total: Double(dailyGoal))
                                    .tint(stats.todayStudied >= dailyGoal ? .green : .blue)
                            }
                        }
                    }
                } else {
                    ProgressView("Loading...")
                }
            } header: {
                Text("Statistics")
            } footer: {
                Text("Streak counts consecutive days with card reviews.")
            }
        }
        .navigationTitle("Study Settings")
        .task {
            // Initialize statistics with proper model context
            statistics = StudyStatisticsViewModel(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        StudySettingsView()
    }
}
