//
//  SettingsView.swift
//  LexiconFlow
//
//  Settings screen (placeholder for Phase 1)
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Study Settings") {
                    HStack {
                        Text("Audio Feedback")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Audio Feedback, Coming Soon")
                    .accessibilityAddTraits(.isButton)

                    HStack {
                        Text("Haptic Feedback")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Haptic Feedback, Coming Soon")
                    .accessibilityAddTraits(.isButton)
                }

                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Dark Mode, Coming Soon")
                    .accessibilityAddTraits(.isButton)

                    HStack {
                        Text("Glass Effects")
                        Spacer()
                        Text("Phase 2")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Glass Effects, coming in Phase 2")
                    .accessibilityAddTraits(.isButton)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Phase 1)")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version 1.0.0 Phase 1")

                    HStack {
                        Text("Algorithm")
                        Spacer()
                        Text("FSRS v5")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("FSRS v5 algorithm")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
