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

    // MARK: - Types

    /// AI source preference for sentence generation
    enum AISource: String, CaseIterable, Sendable {
        case onDevice
        case cloud

        var displayName: String {
            switch self {
            case .onDevice: "On-Device AI"
            case .cloud: "Cloud API"
            }
        }

        var description: String {
            switch self {
            case .onDevice: "Private, offline-capable (iOS 26+)"
            case .cloud: "Requires API key and internet"
            }
        }

        var icon: String {
            switch self {
            case .onDevice: "cpu"
            case .cloud: "cloud"
            }
        }
    }

    // MARK: - Translation Settings

    /// Whether automatic translation is enabled
    @AppStorage("translationEnabled") static var isTranslationEnabled: Bool = true

    /// Source language code for translation (e.g., "en")
    @AppStorage("translationSourceLanguage") static var translationSourceLanguage: String = "en"

    /// Target language code for translation (e.g., "ru")
    @AppStorage("translationTargetLanguage") static var translationTargetLanguage: String = "ru"

    // MARK: - Sentence Generation Settings

    /// Whether AI-powered sentence generation is enabled
    ///
    /// **Note**: This is an optional cloud feature that requires an API key.
    /// Disabled by default. Can be enabled in future "Premium" tier.
    /// When disabled, flashcards work normally but without example sentences.
    @AppStorage("sentenceGenerationEnabled") static var isSentenceGenerationEnabled: Bool = false

    /// AI source preference for sentence generation
    ///
    /// **Options:**
    /// - `.onDevice`: Use Apple's Foundation Models framework (iOS 26+, private)
    /// - `.cloud`: Use Z.ai API (requires API key, network connection)
    ///
    /// **Behavior:**
    /// - When `.onDevice`: Falls back to `.cloud` if Foundation Models unavailable
    /// - When `.cloud`: Falls back to static sentences if no API key
    @AppStorage("aiSourcePreference") static var aiSourcePreference: AISource = .onDevice

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
        ("vi", "Vietnamese")
    ]

    // Note: API key is now stored securely in Keychain, not UserDefaults
    // Use KeychainManager.getAPIKey() and KeychainManager.setAPIKey() to access it

    // MARK: - Haptic Settings (NEW)

    /// Whether haptic feedback is enabled
    @AppStorage("hapticEnabled") static var hapticEnabled: Bool = true

    // MARK: - Audio Settings (NEW)

    /// Whether audio feedback is enabled
    @AppStorage("audioEnabled") static var audioEnabled: Bool = true

    /// Whether streak chimes are enabled (plays harmonic chimes at streak milestones)
    @AppStorage("streakChimesEnabled") static var streakChimesEnabled: Bool = true

    // MARK: - Text-to-Speech Settings

    /// Whether TTS (Text-to-Speech) is enabled
    @AppStorage("ttsEnabled") static var ttsEnabled: Bool = true

    /// Speech rate multiplier (0.0 to 1.0, where 0.5 = default)
    @AppStorage("ttsSpeechRate") static var ttsSpeechRate: Double = 0.5

    /// Voice pitch multiplier (0.5 to 2.0, where 1.0 = normal)
    @AppStorage("ttsPitchMultiplier") static var ttsPitchMultiplier: Double = 1.0

    /// Selected voice language code (e.g., "en-US", "en-GB")
    @AppStorage("ttsVoiceLanguage") static var ttsVoiceLanguage: String = "en-US"

    /// Whether to auto-play pronunciation on card flip
    @AppStorage("ttsAutoPlayOnFlip") static var ttsAutoPlayOnFlip: Bool = false

    /// Pronunciation timing preference
    @AppStorage("ttsTiming") static var ttsTiming: TTSTiming = .onView

    /// Supported English TTS accents
    static let supportedTTSAccents: [(code: String, name: String)] = [
        ("en-US", "American English"),
        ("en-GB", "British English"),
        ("en-AU", "Australian English"),
        ("en-IE", "Irish English"),
        ("en-IN", "Indian English"),
        ("en-ZA", "South African English")
    ]

    // MARK: - Study Session Settings (NEW)

    /// Maximum number of cards to fetch per study session
    @AppStorage("studyLimit") static var studyLimit: Int = 20

    /// Default study mode ("learning" or "scheduled")
    @AppStorage("defaultStudyMode") static var defaultStudyMode: String = "scheduled"

    /// Daily study goal in number of cards
    @AppStorage("dailyGoal") static var dailyGoal: Int = 20

    // MARK: - Data Import Settings

    /// Whether IELTS vocabulary has been pre-populated
    /// Used to ensure one-time automatic import on first launch
    @AppStorage("hasPrepopulatedIELTS") static var hasPrepopulatedIELTS: Bool = false

    /// Whether user has completed onboarding flow
    /// Used to skip onboarding on subsequent app launches
    @AppStorage("hasCompletedOnboarding") static var hasCompletedOnboarding: Bool = false

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
            let ids = Array(newValue.map(\.uuidString))
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

    /// Glass effect intensity (0.0 to 1.0)
    ///
    /// Controls the opacity and blur intensity of glass effects.
    /// Higher values create more pronounced glass morphism visuals.
    @AppStorage("glassEffectIntensity") static var glassEffectIntensity: Double = 0.7

    /// Gesture sensitivity multiplier (0.5 to 2.0)
    ///
    /// Controls how responsive swipe gestures are to user input.
    /// - 1.0 = default sensitivity
    /// - < 1.0 = less sensitive (requires larger gestures)
    /// - > 1.0 = more sensitive (smaller gestures trigger rating)
    @AppStorage("gestureSensitivity") static var gestureSensitivity: Double = 1.0

    /// Whether matched geometry effect transitions are enabled for card flips
    ///
    /// **Note**: When enabled, card elements (word, phonetic) smoothly animate to new positions during flip.
    /// Disabled by default to maintain current ZStack transition behavior.
    @AppStorage("matchedGeometryEffectEnabled") static var matchedGeometryEffectEnabled: Bool = false

    // MARK: - Glass Configuration

    /// Centralized glass effect configuration
    ///
    /// Provides consistent glass effect behavior across all components
    /// based on user preferences set in Appearance Settings.
    struct GlassEffectConfiguration {
        /// Whether glass effects are enabled
        let isEnabled: Bool

        /// Current intensity multiplier (0.0 to 1.0)
        let intensity: Double

        /// Returns effective thickness based on intensity setting
        func effectiveThickness(base: GlassThickness) -> GlassThickness {
            guard self.isEnabled else { return .thin }

            // Map intensity to thickness levels
            switch self.intensity {
            case 0.0 ..< 0.3:
                return base == .thick ? .regular : .thin
            case 0.3 ..< 0.7:
                return base
            default:
                return base == .thin ? .regular : .thick
            }
        }

        /// Opacity multiplier for visual effects
        var opacityMultiplier: Double {
            self.isEnabled ? self.intensity : 0.3
        }
    }

    /// Current glass effect configuration from AppSettings
    static var glassConfiguration: GlassEffectConfiguration {
        GlassEffectConfiguration(
            isEnabled: glassEffectsEnabled,
            intensity: glassEffectIntensity
        )
    }

    // MARK: - Test Support

    #if DEBUG
        /// Reset all settings to defaults (for testing)
        static func resetToDefaults() {
            let defaults = [
                "translationEnabled": true,
                "translationSourceLanguage": "en",
                "translationTargetLanguage": "ru",
                "sentenceGenerationEnabled": false,
                "aiSourcePreference": "onDevice",
                "hapticEnabled": true,
                "audioEnabled": true,
                "streakChimesEnabled": true,
                "studyLimit": 20,
                "defaultStudyMode": "scheduled",
                "dailyGoal": 20,
                "statisticsTimeRange": "7d",
                "darkMode": "system",
                "glassEffectsEnabled": true,
                "glassEffectIntensity": 0.7,
                "gestureSensitivity": 1.0,
                "matchedGeometryEffectEnabled": false
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
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var icon: String {
            switch self {
            case .system: "iphone"
            case .light: "sun.max.fill"
            case .dark: "moon.fill"
            }
        }
    }

    /// Study mode options
    enum StudyModeOption: String, CaseIterable, Sendable {
        case learning
        case scheduled

        var displayName: String {
            switch self {
            case .learning: "Learn New"
            case .scheduled: "Scheduled (FSRS)"
            }
        }

        var description: String {
            switch self {
            case .learning: "Study new cards for the first time"
            case .scheduled: "Due cards based on FSRS algorithm"
            }
        }
    }

    /// Pronunciation timing options for TTS
    enum TTSTiming: String, CaseIterable, Sendable {
        case onView
        case onFlip
        case manual

        var displayName: String {
            switch self {
            case .onView: "On View"
            case .onFlip: "On Flip"
            case .manual: "Manual Only"
            }
        }

        var description: String {
            switch self {
            case .onView: "Play when card front appears"
            case .onFlip: "Play when card flips to back"
            case .manual: "Play only via speaker button"
            }
        }

        var icon: String {
            switch self {
            case .onView: "eye.fill"
            case .onFlip: "rectangle.2.swap"
            case .manual: "hand.tap.fill"
            }
        }
    }

    // MARK: - Migration

    /// Migrate from boolean ttsAutoPlayOnFlip to TTSTiming enum
    ///
    /// Called during app launch to migrate existing user preferences.
    /// Migration is idempotent and safe to call multiple times.
    static func migrateTTSTimingIfNeeded() {
        let migrationKey = "ttsTimingMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // Migrate existing boolean setting to enum
        self.ttsTiming = self.ttsAutoPlayOnFlip ? .onFlip : .onView

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Error Types

    /// Errors that can occur during deck selection encoding/decoding
    enum EncodingError: LocalizedError, Sendable {
        case utf8ConversionFailed

        var errorDescription: String? {
            switch self {
            case .utf8ConversionFailed:
                "Failed to convert deck IDs to/from UTF-8"
            }
        }
    }
}
