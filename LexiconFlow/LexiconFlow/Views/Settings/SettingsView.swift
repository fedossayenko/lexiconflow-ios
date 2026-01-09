//
//  SettingsView.swift
//  LexiconFlow
//
//  Main settings screen with navigation to dedicated settings views
//

import SwiftUI

struct SettingsView: View {
    // MARK: - URL Constants

    /// URL for FSRS algorithm repository
    /// Uses assertionFailure to validate URL and provides safe fallback
    private static let fsrsURL: URL = {
        let urlString = "https://github.com/open-spaced-repetition/fsrs.js"
        guard let url = URL(string: urlString) else {
            assertionFailure("Failed to create FSRS URL")
            // Fallback to home directory (always valid)
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return url
    }()

    /// URL for LexiconFlow iOS repository
    /// Uses assertionFailure to validate URL and provides safe fallback
    private static let repoURL: URL = {
        let urlString = "https://github.com/fedossayenko/lexiconflow-ios"
        guard let url = URL(string: urlString) else {
            assertionFailure("Failed to create repo URL")
            // Fallback to home directory (always valid)
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return url
    }()

    /// URL for SMARTool dataset (CC-BY 4.0 license)
    /// DOI: https://doi.org/10.18710/QNAPNE
    /// Citation: Janda, Laura A. and Francis M. Tyers. 2021
    private static let smartoolURL: URL = {
        let urlString = "https://doi.org/10.18710/QNAPNE"
        guard let url = URL(string: urlString) else {
            assertionFailure("Failed to create SMARTool URL")
            // Fallback to home directory (always valid)
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return url
    }()

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Study Section

                Section("Study") {
                    NavigationLink(destination: DeckSelectionView()) {
                        HStack {
                            Label("Deck Selection", systemImage: "square.stack.3d.up.fill")
                            Spacer()
                            Text("\(AppSettings.selectedDeckCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Deck Selection")

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

                    Link(destination: Self.fsrsURL) {
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

                    Link(destination: Self.repoURL) {
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

                    Link(destination: Self.smartoolURL) {
                        HStack {
                            Label("SMARTool Dataset", systemImage: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("View SMARTool dataset license and attribution")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
