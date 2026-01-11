//
//  AISettingsView.swift
//  LexiconFlow
//
//  Settings for AI-powered features (sentence generation, translation)
//

import SwiftUI

struct AISettingsView: View {
    // MARK: - State

    @State private var aiSourcePreference: AppSettings.AISource = .onDevice

    // MARK: - Body

    var body: some View {
        Form {
            // AI Source Selection
            Section {
                Picker("AI Source", selection: $aiSourcePreference) {
                    ForEach(AppSettings.AISource.allCases, id: \.self) { source in
                        HStack(spacing: 12) {
                            Image(systemName: source.icon)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.displayName)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(source)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityLabel("AI source preference")
                .onChange(of: aiSourcePreference) { _, newValue in
                    AppSettings.aiSourcePreference = newValue
                }

                // AI Source Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("How AI Sources Work")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("When you select an AI source, the app will use it for sentence generation. If the preferred source is unavailable, it automatically falls back to the next best option.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        aiSourceDescriptionRow(
                            icon: "cpu",
                            title: "On-Device AI",
                            description: "Uses Apple's Foundation Models (iOS 26+). Private, offline-capable."
                        )
                        aiSourceDescriptionRow(
                            icon: "arrow.down",
                            description: "Falls back to Cloud API if unavailable."
                        )
                        aiSourceDescriptionRow(
                            icon: "cloud",
                            title: "Cloud API",
                            description: "Uses Z.ai API. Requires API key and internet connection."
                        )
                        aiSourceDescriptionRow(
                            icon: "arrow.down",
                            description: "Falls back to static sentences if no API key."
                        )
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Sentence Generation")
            } footer: {
                Text("Choose how sentences are generated for your vocabulary cards")
            }

            // Cloud API Configuration
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    Text("Cloud API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    // Show API key status inline
                    Group {
                        if KeychainManager.hasAPIKey() {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("Configured")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("Not Set")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } header: {
                Text("Cloud Configuration")
            } footer: {
                Text("API key configuration will be available in a future update")
            }
        }
        .navigationTitle("AI Settings")
        .onAppear {
            // Sync state with AppSettings on view appear
            aiSourcePreference = AppSettings.aiSourcePreference
        }
    }

    // MARK: - Helper Views

    private func aiSourceDescriptionRow(icon: String, title: String? = nil, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
