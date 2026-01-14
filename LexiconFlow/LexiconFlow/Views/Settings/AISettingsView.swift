//
//  AISettingsView.swift
//  LexiconFlow
//
//  Settings for AI-powered features (sentence generation, translation)
//

import SwiftUI

struct AISettingsView: View {
    // MARK: - State

    @State private var sentenceGenerationEnabled: Bool = AppSettings.isSentenceGenerationEnabled
    @State private var cloudStatus: CloudConnectionStatus = .checking

    enum CloudConnectionStatus {
        case checking
        case connected
        case error(String)
    }

    // MARK: - Body

    var body: some View {
        Form {
            // Cloud Status Section (NEW)
            Section {
                HStack(spacing: 12) {
                    Image(systemName: self.statusIcon)
                        .foregroundStyle(self.statusColor)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cloud Services")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(self.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if case .checking = self.cloudStatus {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            } header: {
                Text("Connection Status")
            } footer: {
                Text("AI services are provided by Firebase Cloud Functions with automatic provider routing (Gemini 2.5 Flash, Zhipu GLM-4.7)")
            }

            // Sentence Generation Toggle
            Section {
                Toggle(isOn: self.$sentenceGenerationEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generate Example Sentences")
                            .font(.body)
                        Text("AI generates contextual sentences for vocabulary cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Enable sentence generation")
                .onChange(of: self.sentenceGenerationEnabled) { _, newValue in
                    AppSettings.isSentenceGenerationEnabled = newValue
                }
            } header: {
                Text("Sentence Generation")
            } footer: {
                Text("When enabled, example sentences are generated using AI. Powered by Gemini 2.5 Flash and Zhipu GLM-4.7.")
            }
        }
        .navigationTitle("AI Settings")
        .task {
            await self.checkCloudStatus()
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch self.cloudStatus {
        case .checking:
            "arrow.triangle.2.circlepath"
        case .connected:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch self.cloudStatus {
        case .checking:
            .blue
        case .connected:
            .green
        case .error:
            .orange
        }
    }

    private var statusMessage: String {
        switch self.cloudStatus {
        case .checking:
            "Checking connection..."
        case .connected:
            "Connected to Firebase"
        case let .error(message):
            message
        }
    }

    // MARK: - Methods

    private func checkCloudStatus() async {
        self.cloudStatus = .checking

        do {
            // Test Firebase connection
            _ = try await FirebaseService.shared.signInAnonymously()
            self.cloudStatus = .connected
        } catch {
            self.cloudStatus = .error(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
