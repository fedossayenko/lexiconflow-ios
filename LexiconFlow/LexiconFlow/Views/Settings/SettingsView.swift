//
//  SettingsView.swift
//  LexiconFlow
//
//  Main settings screen with navigation to dedicated settings views
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Study Section
                Section("Study") {
                    NavigationLink(destination: StudySettingsView()) {
                        Label("Study Settings", systemImage: "brain.head.profile")
                    }
                    .accessibilityLabel("Study Settings")

                    NavigationLink(destination: HapticSettingsView()) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                    .accessibilityLabel("Haptic Feedback")

                    NavigationLink(destination: TranslationSettingsView()) {
                        HStack {
                            Label("Translation", systemImage: "character.book.closed")
                            Spacer()
                            Text("Z.ai API")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Translation Settings")
                }

                // MARK: - Data Section
                Section("Data") {
                    NavigationLink(destination: DataManagementView()) {
                        Label("Data Management", systemImage: "tray.full")
                    }
                    .accessibilityLabel("Data Management")
                }

                // MARK: - Appearance Section
                Section("Appearance") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .accessibilityLabel("Appearance")
                }

                // MARK: - About Section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0 (Phase 1)")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version 1.0.0 Phase 1")

                    HStack {
                        Label("Algorithm", systemImage: "function")
                        Spacer()
                        Text("FSRS v5")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("FSRS v5 algorithm")

                    if let fsrsURL = URL(string: "https://github.com/open-spaced-repetition/fsrs.js") {
                        Link(destination: fsrsURL) {
                            HStack {
                                Label("FSRS Algorithm", systemImage: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel("Learn more about FSRS algorithm")
                    }

                    if let repoURL = URL(string: "https://github.com/fedossayeno/lexiconflow-ios") {
                        Link(destination: repoURL) {
                            HStack {
                                Label("GitHub Repository", systemImage: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel("View GitHub repository")
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
