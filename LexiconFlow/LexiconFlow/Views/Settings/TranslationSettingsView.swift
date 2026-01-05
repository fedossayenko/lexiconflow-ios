//
//  TranslationSettingsView.swift
//  LexiconFlow
//
//  Settings view for configuring translation API and language preferences
//

import SwiftUI
import OSLog

/// Settings view for translation configuration
///
/// Allows users to:
/// - Configure their Z.ai API key
/// - Set source and target languages
/// - Enable/disable automatic translation
struct TranslationSettingsView: View {
    @AppStorage("zai_api_key") private var apiKey = ""
    @AppStorage("translationSourceLanguage") private var sourceLanguage = "en"
    @AppStorage("translationTargetLanguage") private var targetLanguage = "ru"
    @AppStorage("translationEnabled") private var translationEnabled = true

    @State private var showAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var isValidating = false
    @State private var isValid = false
    @State private var validationError: String?

    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "TranslationSettingsView")

    private let supportedLanguages = [
        ("en", "English"),
        ("ru", "Russian"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("pt", "Portuguese")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Enable Auto-Translation", isOn: $translationEnabled)

                if translationEnabled {
                    Picker("Source Language", selection: $sourceLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    Picker("Target Language", selection: $targetLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
            } header: {
                Text("Translation")
            } footer: {
                Text("Automatically translate flashcard words during creation using Z.ai API.")
            }

            Section {
                if showAPIKeyField {
                    SecureField("API Key", text: $tempAPIKey)
                        .textContentType(.password)

                    if let validationError = validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("Validate") {
                            Task {
                                await validateAPIKey()
                            }
                        }
                        .disabled(tempAPIKey.isEmpty || isValidating)

                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Spacer()

                        if isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Button("Save") {
                        apiKey = tempAPIKey
                        TranslationService.shared.setAPIKey(tempAPIKey)
                        showAPIKeyField = false
                        logger.info("API key saved")
                    }
                    .disabled(tempAPIKey.isEmpty || !isValid)
                } else {
                    HStack {
                        Text(apiKey.isEmpty ? "No API key configured" : "API key configured")
                            .foregroundStyle(apiKey.isEmpty ? .secondary : .primary)

                        Spacer()

                        Button(apiKey.isEmpty ? "Add Key" : "Change Key") {
                            tempAPIKey = apiKey
                            showAPIKeyField = true
                            isValid = false
                            validationError = nil
                        }
                    }
                }
            } header: {
                Text("Z.ai API Configuration")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter your Z.ai API key to enable automatic translation.")
                    Text("Get your key at: https://z.ai")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Translation Settings")
    }

    // MARK: - API Key Validation

    private func validateAPIKey() async {
        isValidating = true
        validationError = nil
        defer { isValidating = false }

        TranslationService.shared.setAPIKey(tempAPIKey)

        do {
            let result = try await TranslationService.shared.translate(
                word: "test",
                definition: "a trial or test",
                context: nil
            )
            isValid = !result.items.isEmpty
            if !isValid {
                validationError = "API returned empty results"
            }
        } catch {
            isValid = false
            validationError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        TranslationSettingsView()
    }
}
