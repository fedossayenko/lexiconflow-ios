//
//  StudySettingsView.swift
//  LexiconFlow
//
//  Study session settings screen
//

import SwiftData
import SwiftUI

struct StudySettingsView: View {
    // Use centralized AppSettings instead of direct @AppStorage (CLAUDE.md pattern #4)
    @State private var studyLimit: Int = AppSettings.studyLimit
    @State private var studyMode: String = AppSettings.defaultStudyMode
    @State private var dailyGoal: Int = AppSettings.dailyGoal

    @Environment(\.modelContext) private var modelContext

    private let limitOptions = [10, 20, 30, 50, 100]
    private let goalOptions = [10, 20, 30, 50, 100]

    var body: some View {
        Form {
            // Study Session Limits
            Section {
                Picker("Cards per Session", selection: self.$studyLimit) {
                    ForEach(self.limitOptions, id: \.self) { limit in
                        Text("\(limit) cards").tag(limit)
                    }
                }
                .accessibilityLabel("Cards per session")
                .onChange(of: self.studyLimit) { _, newValue in
                    AppSettings.studyLimit = newValue
                }

                Picker("Daily Goal", selection: self.$dailyGoal) {
                    ForEach(self.goalOptions, id: \.self) { goal in
                        Text("\(goal) cards").tag(goal)
                    }
                }
                .accessibilityLabel("Daily study goal")
                .onChange(of: self.dailyGoal) { _, newValue in
                    AppSettings.dailyGoal = newValue
                }
            } header: {
                Text("Session Limits")
            } footer: {
                Text("Maximum cards to fetch per study session. Changes apply to next session.")
            }

            // Study Mode
            Section {
                Picker("Default Mode", selection: self.$studyMode) {
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
                .onChange(of: self.studyMode) { _, newValue in
                    AppSettings.defaultStudyMode = newValue
                }
            } header: {
                Text("Study Mode")
            } footer: {
                Text("Learn New: Study cards you haven't seen before\nScheduled: Review cards due based on FSRS algorithm")
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
