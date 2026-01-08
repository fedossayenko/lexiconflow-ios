//
//  AppSettings.swift
//  LexiconFlow
//
//  Centralized app settings using @AppStorage for consistent key management
//

import OSLog
import SwiftUI

/// Centralized app settings to prevent scattered @AppStorage keys
///
/// Provides a single source of truth for all user preferences,
/// preventing naming conflicts and ensuring consistency across the app.
@MainActor
enum AppSettings {
    private static let logger = Logger(subsystem: "com.lexiconflow.settings", category: "AppSettings")

    // MARK: - Translation Settings

    /// Whether automatic translation is enabled
    @AppStorage("translationEnabled") static var isTranslationEnabled: Bool = true

    /// Source language code for translation (e.g., "en")
    @AppStorage("translationSourceLanguage") static var translationSourceLanguage: String = "en"

    /// Target language code for translation (e.g., "ru")
    @AppStorage("translationTargetLanguage") static var translationTargetLanguage: String = "ru"

    // MARK: - Sentence Generation Settings (NEW)

    /// Whether AI-powered sentence generation is enabled
    ///
    /// **Note**: This is an optional cloud feature that requires an API key.
    /// Disabled by default. Can be enabled in future "Premium" tier.
    /// When disabled, flashcards work normally but without example sentences.
    @AppStorage("sentenceGenerationEnabled") static var isSentenceGenerationEnabled: Bool = false

    /// Supported translation languages for on-device translation (24 languages supported by iOS Translation framework)
    static let supportedLanguages: [(code: String, name: String)] = [
        ("ar", "Arabic"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("es", "Spanish"),
        ("sv", "Swedish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
    ]

    // Note: API key is now stored securely in Keychain, not UserDefaults
    // Use KeychainManager.getAPIKey() and KeychainManager.setAPIKey() to access it

    // MARK: - Haptic Settings (NEW)

    /// Whether haptic feedback is enabled
    @AppStorage("hapticEnabled") static var hapticEnabled: Bool = true

    /// Whether audio feedback is enabled
    @AppStorage("audioEnabled") static var audioEnabled: Bool = true

    // MARK: - Study Session Settings (NEW)

    /// Maximum number of cards to fetch per study session
    @AppStorage("studyLimit") static var studyLimit: Int = 20

    /// Default study mode ("learning" or "scheduled")
    @AppStorage("defaultStudyMode") static var defaultStudyMode: String = "scheduled"

    /// Daily study goal in number of cards
    @AppStorage("dailyGoal") static var dailyGoal: Int = 20

    // MARK: - Statistics Settings (NEW)

    /// Selected time range for statistics dashboard ("7d", "30d", "all")
    @AppStorage("statisticsTimeRange") static var statisticsTimeRange: String = "7d"

    // MARK: - Deck Selection Settings (NEW)

    /// Raw JSON data for selected deck IDs
    /// Stored as JSON array of UUID strings for UserDefaults compatibility
    @AppStorage("selectedDeckIDsData") static var selectedDeckIDsData: String = "[]"

    /// Selected deck IDs for multi-deck study sessions
    /// Uses JSON encoding for reliable persistence
    ///
    /// **Error Recovery**: On JSON corruption or invalid data:
    /// - Logs error with details
    /// - Tracks issue with Analytics
    /// - Resets to empty set (safe default)
    /// - Clears corrupted data to prevent repeated errors
    ///
    /// **Thread Safety**: Explicitly @MainActor isolated to prevent data races
    /// when accessing @AppStorage properties from multiple contexts.
    static var selectedDeckIDs: Set<UUID> {
        get {
            guard let data = selectedDeckIDsData.data(using: .utf8) else {
                logger.error("Failed to convert selectedDeckIDsData to UTF-8")
                // Fire-and-forget acceptable for error recovery (no lifecycle to manage)
                Analytics.trackIssue("deck_selection_utf8_failed", message: "Selected deck IDs data is not valid UTF-8")
                return []
            }
            do {
                let ids = try JSONDecoder().decode([String].self, from: data)
                let validUUIDs = ids.compactMap { uuidString -> UUID? in
                    guard let uuid = UUID(uuidString: uuidString) else {
                        logger.warning("Invalid UUID string in selectedDeckIDs: \(uuidString)")
                        return nil
                    }
                    return uuid
                }
                if validUUIDs.count < ids.count {
                    let droppedCount = ids.count - validUUIDs.count
                    logger.warning("Dropped \(droppedCount) invalid UUIDs from selection")
                    Analytics.trackIssue(
                        "deck_selection_partial_loss",
                        message: "Dropped \(droppedCount) invalid UUIDs out of \(ids.count) total",
                        metadata: ["dropped_count": "\(droppedCount)", "total_count": "\(ids.count)"]
                    )
                }
                return Set(validUUIDs)
            } catch {
                logger.error("Failed to decode selectedDeckIDs: \(error)")

                // Reset corrupted data to prevent repeated errors
                selectedDeckIDsData = "[]"

                // Track the error for monitoring
                Analytics.trackError(
                    "deck_selection_decode_failed",
                    error: error,
                    metadata: ["data_length": "\(data.count)"]
                )

                return []
            }
        }
        set {
            let ids = Array(newValue.map { $0.uuidString })
            do {
                let data = try JSONEncoder().encode(ids)
                guard let string = String(data: data, encoding: .utf8) else {
                    logger.error("Failed to convert encoded data to UTF-8")
                    Analytics.trackError("deck_selection_utf8_encode_failed", error: AppSettings.EncodingError.utf8ConversionFailed)
                    return
                }
                selectedDeckIDsData = string
            } catch {
                logger.error("Failed to encode selectedDeckIDs: \(error)")
                Analytics.trackError("deck_selection_encode_failed", error: error)
            }
        }
    }

    /// Check if any decks are selected
    static var hasSelectedDecks: Bool {
        !selectedDeckIDs.isEmpty
    }

    /// Count of selected decks
    static var selectedDeckCount: Int {
        selectedDeckIDs.count
    }

    // MARK: - Appearance Settings (NEW)

    /// Dark mode preference
    @AppStorage("darkMode") static var darkMode: DarkModePreference = .system

    /// Whether glass morphism effects are enabled
    @AppStorage("glassEffectsEnabled") static var glassEffectsEnabled: Bool = true

    // MARK: - Test Support

    #if DEBUG
        /// Reset all settings to defaults (for testing)
        static func resetToDefaults() {
            let defaults = [
                "translationEnabled": true,
                "translationSourceLanguage": "en",
                "translationTargetLanguage": "ru",
                "sentenceGenerationEnabled": false,
                "hapticEnabled": true,
                "audioEnabled": true,
                "studyLimit": 20,
                "defaultStudyMode": "scheduled",
                "dailyGoal": 20,
                "statisticsTimeRange": "7d",
                "darkMode": "system",
                "glassEffectsEnabled": true,
            ] as [String: Any]

            for (key, value) in defaults {
                UserDefaults.standard.set(value, forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
    #endif

    // MARK: - Types

    /// Dark mode preference options
    enum DarkModePreference: String, CaseIterable, Sendable {
        case system
        case light
        case dark

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var icon: String {
            switch self {
            case .system: return "iphone"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }

    /// Study mode options
    enum StudyModeOption: String, CaseIterable, Sendable {
        case learning
        case scheduled

        var displayName: String {
            switch self {
            case .learning: return "Learn New"
            case .scheduled: return "Scheduled (FSRS)"
            }
        }

        var description: String {
            switch self {
            case .learning: return "Study new cards for the first time"
            case .scheduled: return "Due cards based on FSRS algorithm"
            }
        }
    }

    // MARK: - Error Types

    /// Errors that can occur during deck selection encoding/decoding
    enum EncodingError: LocalizedError, Sendable {
        case utf8ConversionFailed

        var errorDescription: String? {
            switch self {
            case .utf8ConversionFailed:
                return "Failed to convert deck IDs to/from UTF-8"
            }
        }
    }
}
