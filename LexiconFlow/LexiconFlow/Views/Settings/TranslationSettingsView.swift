//
//  TranslationSettingsView.swift
//  LexiconFlow
//
//  Settings view for configuring on-device translation
//

import OSLog
import SwiftUI

/// Settings view for on-device translation configuration
///
/// Allows users to:
/// - Enable/disable automatic translation
/// - Configure source and target languages
/// - Download language packs for on-device translation
import Translation

@MainActor
struct TranslationSettingsView: View {
    // MARK: - On-Device Translation State

    @State private var sourceLanguageDownloaded = false
    @State private var targetLanguageDownloaded = false
    @State private var isCheckingAvailability = false
    @State private var isDownloadingLanguage = false
    @State private var downloadError: String?
    @SceneStorage("returnedFromSettings") private var returnedFromSettings = false

    // MARK: - Language Pack Download Configuration

    /// Configuration for triggering language pack downloads via .translationTask()
    ///
    /// **Important**: Language pack downloads must use SwiftUI's .translationTask() modifier
    /// because the TranslationSession API only works within SwiftUI views. The prepareTranslation()
    /// method, which triggers the actual system download prompt, can only be called on a session
    /// obtained from the .translationTask() modifier.
    @State private var downloadConfiguration: TranslationSession.Configuration?

    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "TranslationSettingsView")
    private let onDeviceService = OnDeviceTranslationService.shared

    var body: some View {
        Form {
            // Translation Settings
            Section {
                Toggle("Enable Auto-Translation", isOn: Binding(
                    get: { AppSettings.isTranslationEnabled },
                    set: { AppSettings.isTranslationEnabled = $0 }
                ))

                if AppSettings.isTranslationEnabled {
                    Picker("Source Language", selection: Binding(
                        get: { AppSettings.translationSourceLanguage },
                        set: { newLang in
                            AppSettings.translationSourceLanguage = newLang
                            // Recheck availability when language changes
                            Task {
                                await self.checkLanguageAvailability()
                            }
                        }
                    )) {
                        ForEach(AppSettings.supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    Picker("Target Language", selection: Binding(
                        get: { AppSettings.translationTargetLanguage },
                        set: { newLang in
                            AppSettings.translationTargetLanguage = newLang
                            // Recheck availability when language changes
                            Task {
                                await self.checkLanguageAvailability()
                            }
                        }
                    )) {
                        ForEach(AppSettings.supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    // On-Device Language Availability
                    OnDeviceLanguageStatusView(
                        sourceDownloaded: self.sourceLanguageDownloaded,
                        targetDownloaded: self.targetLanguageDownloaded,
                        isChecking: self.isCheckingAvailability,
                        isDownloading: self.isDownloadingLanguage,
                        downloadError: self.downloadError,
                        onDownloadSource: {
                            Task { await self.downloadLanguagePack(.source) }
                        },
                        onDownloadTarget: {
                            Task { await self.downloadLanguagePack(.target) }
                        },
                        onOpenSystemSettings: {
                            self.openSystemSettingsForLanguagePacks()
                        }
                    )
                }
            } header: {
                Text("Translation Settings")
            } footer: {
                Text("Automatically translate flashcard words using on-device translation. Language packs must be downloaded first.")
            }
        }
        .navigationTitle("Translation Settings")
        .translationTask(self.downloadConfiguration) { session in
            // This closure is called when downloadConfiguration changes
            // prepareTranslation() triggers the system download prompt for language packs
            do {
                try await session.prepareTranslation()
                self.logger.info("Language pack download completed successfully")
                // Refresh availability after download completes
                await self.checkLanguageAvailability()
            } catch {
                self.logger.error("Language pack download failed: \(error.localizedDescription)")
                self.downloadError = error.localizedDescription
                Analytics.trackError("language_pack_download", error: error)
            }
            // Reset download state and configuration
            self.isDownloadingLanguage = false
            self.downloadConfiguration = nil
        }
        .onAppear {
            // Check language availability on appear
            Task {
                // If user just returned from system settings, refresh availability
                // in case they installed language packs
                if self.returnedFromSettings {
                    self.logger.info("User returned from system settings - refreshing language availability")
                    self.returnedFromSettings = false
                }
                await self.checkLanguageAvailability()
            }
        }
    }

    // MARK: - Language Availability

    /// Check if selected language packs are downloaded for on-device translation
    private func checkLanguageAvailability() async {
        self.isCheckingAvailability = true
        self.downloadError = nil

        self.sourceLanguageDownloaded = await self.onDeviceService.isLanguageAvailable(AppSettings.translationSourceLanguage)
        self.targetLanguageDownloaded = await self.onDeviceService.isLanguageAvailable(AppSettings.translationTargetLanguage)

        self.logger.debug("""
        Language availability check:
        - Source (\(AppSettings.translationSourceLanguage)): \(self.sourceLanguageDownloaded ? "Downloaded" : "Not downloaded")
        - Target (\(AppSettings.translationTargetLanguage)): \(self.targetLanguageDownloaded ? "Downloaded" : "Not downloaded")
        """)

        self.isCheckingAvailability = false
    }

    /// Download language pack for on-device translation
    ///
    /// **Important**: This method creates a TranslationSession.Configuration which triggers
    /// the download via the .translationTask() modifier. The prepareTranslation() method
    /// called within the modifier is the only API that properly triggers the system
    /// download prompt for language packs.
    private func downloadLanguagePack(_ languageType: LanguageType) async {
        self.isDownloadingLanguage = true
        self.downloadError = nil

        let languageCode = languageType == .source
            ? AppSettings.translationSourceLanguage
            : AppSettings.translationTargetLanguage

        let language = Locale.Language(identifier: languageCode)

        // Use a temporary target language for download only
        // The actual translation will use the user's configured target language
        let temporaryTarget = Locale.Language(identifier: "en")

        self.logger.info("Requesting language pack download for '\(languageCode)'")

        // Create configuration to trigger download via .translationTask()
        // This is the Apple-documented pattern for language pack downloads
        self.downloadConfiguration = TranslationSession.Configuration(
            source: language,
            target: temporaryTarget
        )
    }

    /// Open iOS System Settings to download language packs
    ///
    /// This provides a reliable fallback when automatic download fails.
    /// Language packs can be downloaded in Settings → General → Translation.
    private func openSystemSettingsForLanguagePacks() {
        // Set flag to detect when user returns from settings
        self.returnedFromSettings = true

        // iOS 26 URL scheme for Translation settings
        // Note: URL schemes may change between iOS versions
        if let url = URL(string: "App-prefs:General&path=TRANSLATION") {
            self.logger.info("Opening system settings for language pack download")

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback: Open main settings if specific path doesn't work
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    self.logger.info("Opening main system settings as fallback")
                    UIApplication.shared.open(settingsURL)
                }
            }
        } else {
            // Final fallback: Open main settings
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                self.logger.info("Opening main system settings as final fallback")
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

// MARK: - Supporting Types

/// Language type for download operations
private enum LanguageType {
    case source
    case target
}

/// View component for displaying on-device language pack status
private struct OnDeviceLanguageStatusView: View {
    let sourceDownloaded: Bool
    let targetDownloaded: Bool
    let isChecking: Bool
    let isDownloading: Bool
    let downloadError: String?
    let onDownloadSource: () -> Void
    let onDownloadTarget: () -> Void
    let onOpenSystemSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if self.isChecking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking language pack availability...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Source Language Status
                LanguageStatusRow(
                    languageName: "Source Language",
                    languageCode: AppSettings.translationSourceLanguage,
                    isDownloaded: self.sourceDownloaded,
                    isDownloading: self.isDownloading,
                    onTap: self.onDownloadSource
                )

                // Target Language Status
                LanguageStatusRow(
                    languageName: "Target Language",
                    languageCode: AppSettings.translationTargetLanguage,
                    isDownloaded: self.targetDownloaded,
                    isDownloading: self.isDownloading,
                    onTap: self.onDownloadTarget
                )

                // Open System Settings Button (always shown when not all downloaded)
                if !self.sourceDownloaded || !self.targetDownloaded {
                    Button(action: self.onOpenSystemSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open System Settings to Download Language Packs")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                // Error Message
                if let error = downloadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Info Message
                if self.sourceDownloaded, self.targetDownloaded {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All language packs downloaded. Translation is ready.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Row component for displaying individual language pack status
private struct LanguageStatusRow: View {
    let languageName: String
    let languageCode: String
    let isDownloaded: Bool
    let isDownloading: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: self.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundStyle(self.isDownloaded ? .green : .blue)
                    Text(self.languageName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(self.languageCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(self.isDownloaded ? "Downloaded" : "Language pack required")
                    .font(.caption2)
                    .foregroundStyle(self.isDownloaded ? .green : .secondary)
            }

            Spacer()

            if !self.isDownloaded, !self.isDownloading {
                Button("Download") {
                    self.onTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if self.isDownloading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TranslationSettingsView()
    }
}
