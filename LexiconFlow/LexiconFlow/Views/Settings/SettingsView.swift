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

                    HStack {
                        Text("Haptic Feedback")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Glass Effects")
                        Spacer()
                        Text("Phase 2")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Phase 1)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Algorithm")
                        Spacer()
                        Text("FSRS v5")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
