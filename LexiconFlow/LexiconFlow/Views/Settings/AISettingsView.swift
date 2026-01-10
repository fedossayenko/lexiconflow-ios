//
//  AISettingsView.swift
//  LexiconFlow
//
//  Settings for AI-powered features (sentence generation, translation)
//

import SwiftUI

struct AISettingsView: View {
    var body: some View {
        Form {
            // AI Source Selection
            Section {
                Picker("AI Source", selection: Binding(
                    get: { AppSettings.aiSourcePreference },
                    set: { AppSettings.aiSourcePreference = $0 }
                )) {
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

            // API Key Configuration
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                        Text("Cloud API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("To use the Cloud API, configure your Z.ai API key in Translation Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        TranslationSettingsView()
                    } label: {
                        HStack {
                            Text("Configure API Key")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Cloud Configuration")
            }

            // Status Information
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    statusRow(
                        title: "Current Source",
                        value: Text(AppSettings.aiSourcePreference.displayName)
                            .fontWeight(.medium)
                    )

                    Divider()

                    statusRow(
                        title: "Foundation Models",
                        value: Group {
                            if #available(iOS 26.0, *) {
                                Text("Checking...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not Available")
                                    .foregroundStyle(.red)
                            }
                        }
                    )

                    Divider()

                    statusRow(
                        title: "API Key",
                        value: Group {
                            if KeychainManager.hasAPIKey() {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Configured")
                                        .foregroundStyle(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Not Set")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("Status")
            } footer: {
                Text("Foundation Models availability depends on your device and iOS version")
            }
        }
        .navigationTitle("AI Settings")
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

    private func statusRow(title: String, value: some View) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            value
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
