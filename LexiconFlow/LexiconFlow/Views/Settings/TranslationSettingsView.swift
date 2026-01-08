//
//  TranslationSettingsView.swift
//  LexiconFlow
//
//  Settings view for configuring on-device translation
//

import SwiftUI
import OSLog

/// Settings view for on-device translation configuration
///
/// Allows users to:
/// - Enable/disable automatic translation
/// - Configure source and target languages
/// - Download language packs for on-device translation
@MainActor
struct TranslationSettingsView: View {
    // MARK: - On-Device Translation State
    @State private var sourceLanguageDownloaded = false
    @State private var targetLanguageDownloaded = false
    @State private var isCheckingAvailability = false
    @State private var isDownloadingLanguage = false
    @State private var downloadError: String?
    @SceneStorage("returnedFromSettings") private var returnedFromSettings = false

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
                                await checkLanguageAvailability()
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
                                await checkLanguageAvailability()
                            }
                        }
                    )) {
                        ForEach(AppSettings.supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    // On-Device Language Availability
                    OnDeviceLanguageStatusView(
                        sourceDownloaded: sourceLanguageDownloaded,
                        targetDownloaded: targetLanguageDownloaded,
                        isChecking: isCheckingAvailability,
                        isDownloading: isDownloadingLanguage,
                        downloadError: downloadError,
                        onDownloadSource: {
                            Task { await downloadLanguagePack(.source) }
                        },
                        onDownloadTarget: {
                            Task { await downloadLanguagePack(.target) }
                        },
                        onOpenSystemSettings: {
                            openSystemSettingsForLanguagePacks()
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
        .onAppear {
            // Check language availability on appear
            Task {
                // If user just returned from system settings, refresh availability
                // in case they installed language packs
                if returnedFromSettings {
                    logger.info("User returned from system settings - refreshing language availability")
                    returnedFromSettings = false
                }
                await checkLanguageAvailability()
            }
        }
    }

    // MARK: - Language Availability

    /// Check if selected language packs are downloaded for on-device translation
    private func checkLanguageAvailability() async {
        isCheckingAvailability = true
        downloadError = nil

        do {
            sourceLanguageDownloaded = await onDeviceService.isLanguageAvailable(AppSettings.translationSourceLanguage)
            targetLanguageDownloaded = await onDeviceService.isLanguageAvailable(AppSettings.translationTargetLanguage)

            logger.debug("""
                Language availability check:
                - Source (\(AppSettings.translationSourceLanguage)): \(sourceLanguageDownloaded ? "Downloaded" : "Not downloaded")
                - Target (\(AppSettings.translationTargetLanguage)): \(targetLanguageDownloaded ? "Downloaded" : "Not downloaded")
                """)
        } catch {
            logger.error("Failed to check language availability: \(error.localizedDescription)")
            downloadError = error.localizedDescription
        }

        isCheckingAvailability = false
    }

    /// Download language pack for on-device translation
    private func downloadLanguagePack(_ languageType: LanguageType) async {
        isDownloadingLanguage = true
        downloadError = nil

        let languageCode = languageType == .source
            ? AppSettings.translationSourceLanguage
            : AppSettings.translationTargetLanguage

        logger.info("Requesting language pack download for '\(languageCode)'")

        do {
            try await onDeviceService.requestLanguageDownload(languageCode)
            logger.info("Language pack download initiated for '\(languageCode)'")

            // Refresh availability after download request
            await checkLanguageAvailability()
        } catch {
            logger.error("Failed to download language pack: \(error.localizedDescription)")
            downloadError = error.localizedDescription
            Analytics.trackError("language_pack_download", error: error)
        }

        isDownloadingLanguage = false
    }

    /// Open iOS System Settings to download language packs
    ///
    /// This provides a reliable fallback when automatic download fails.
    /// Language packs can be downloaded in Settings → General → Translation.
    private func openSystemSettingsForLanguagePacks() {
        // Set flag to detect when user returns from settings
        returnedFromSettings = true

        // iOS 26 URL scheme for Translation settings
        // Note: URL schemes may change between iOS versions
        if let url = URL(string: "App-prefs:General&path=TRANSLATION") {
            logger.info("Opening system settings for language pack download")

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback: Open main settings if specific path doesn't work
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    logger.info("Opening main system settings as fallback")
                    UIApplication.shared.open(settingsURL)
                }
            }
        } else {
            // Final fallback: Open main settings
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                logger.info("Opening main system settings as final fallback")
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
            if isChecking {
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
                    isDownloaded: sourceDownloaded,
                    isDownloading: isDownloading,
                    onTap: onDownloadSource
                )

                // Target Language Status
                LanguageStatusRow(
                    languageName: "Target Language",
                    languageCode: AppSettings.translationTargetLanguage,
                    isDownloaded: targetDownloaded,
                    isDownloading: isDownloading,
                    onTap: onDownloadTarget
                )

                // Open System Settings Button (always shown when not all downloaded)
                if !sourceDownloaded || !targetDownloaded {
                    Button(action: onOpenSystemSettings) {
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
                if sourceDownloaded && targetDownloaded {
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
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundStyle(isDownloaded ? .green : .blue)
                    Text(languageName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(languageCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(isDownloaded ? "Downloaded" : "Language pack required")
                    .font(.caption2)
                    .foregroundStyle(isDownloaded ? .green : .secondary)
            }

            Spacer()

            if !isDownloaded && !isDownloading {
                Button("Download") {
                    onTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isDownloading {
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
