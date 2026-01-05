//
//  StudySettingsView.swift
//  LexiconFlow
//
//  Study session settings screen
//

import SwiftUI

struct StudySettingsView: View {
    @AppStorage("studyLimit") private var studyLimit = 20
    @AppStorage("defaultStudyMode") private var studyMode = "scheduled"
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("gestureEnabled") private var gestureEnabled = true

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
                Text("Scheduled: Respects FSRS due dates\nCram: Practice without affecting progress")
            }

            // Grading Preference
            Section {
                Toggle("Swipe Gestures", isOn: $gestureEnabled)
                    .accessibilityLabel("Enable swipe gestures for grading")
            } header: {
                Text("Grading")
            } footer: {
                Text("Swipe gestures: Drag card left/right to grade\nButtons: Tap rating buttons to grade")
            }

            // Statistics Preview
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today's Progress")
                            .font(.subheadline)
                        Spacer()
                        Text("0/\(dailyGoal)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: 0.0, total: Double(dailyGoal))

                    Text("Study sessions coming soon!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Study Settings")
    }
}

#Preview {
    NavigationStack {
        StudySettingsView()
    }
}
