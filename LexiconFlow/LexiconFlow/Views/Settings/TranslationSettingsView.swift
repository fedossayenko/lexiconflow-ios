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
    @AppStorage("translationSourceLanguage") private var sourceLanguage = "en"
    @AppStorage("translationTargetLanguage") private var targetLanguage = "ru"
    @AppStorage("translationEnabled") private var translationEnabled = true

    @State private var showAPIKeyField = false
    @State private var apiKey = ""
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
                        Task {
                            do {
                                try KeychainManager.setAPIKey(tempAPIKey)
                                apiKey = tempAPIKey
                                do {
                                    try TranslationService.shared.setAPIKey(tempAPIKey)
                                } catch {
                                    // Log but don't fail - Keychain is the source of truth
                                    logger.error("Failed to update TranslationService: \(error.localizedDescription)")
                                }
                                showAPIKeyField = false
                                logger.info("API key saved securely to Keychain")
                            } catch {
                                validationError = "Failed to save API key: \(error.localizedDescription)"
                                Analytics.trackError("api_key_save", error: error)
                            }
                        }
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
        .onAppear {
            loadAPIKey()
        }
    }

    // MARK: - API Key Management

    private func loadAPIKey() {
        if let key = try? KeychainManager.getAPIKey() {
            apiKey = key
        }
    }

    // MARK: - API Key Validation

    private func validateAPIKey() async {
        isValidating = true
        validationError = nil
        defer { isValidating = false }

        do {
            // Store key in Keychain temporarily for validation
            // Note: This has the side effect of storing the key if validation succeeds
            try KeychainManager.setAPIKey(tempAPIKey)

            let result = try await TranslationService.shared.translate(
                word: "test",
                definition: "a trial or test",
                context: nil
            )
            isValid = !result.items.isEmpty
            if !isValid {
                validationError = "API returned empty results"
                // Remove invalid key from Keychain
                try? KeychainManager.deleteAPIKey()
            }
            logger.info("API key validation completed: isValid=\(isValid)")
        } catch {
            isValid = false
            validationError = error.localizedDescription
            Analytics.trackError("api_key_validation", error: error)
            // Remove invalid key from Keychain if validation failed
            try? KeychainManager.deleteAPIKey()
        }
    }
}

#Preview {
    NavigationStack {
        TranslationSettingsView()
    }
}
