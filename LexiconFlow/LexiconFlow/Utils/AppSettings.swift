//
//  AppSettings.swift
//  LexiconFlow
//
//  Centralized app settings using @AppStorage for consistent key management
//

import SwiftUI

/// Centralized app settings to prevent scattered @AppStorage keys
///
/// Provides a single source of truth for all user preferences,
/// preventing naming conflicts and ensuring consistency across the app.
@MainActor
enum AppSettings {
    // MARK: - Translation Settings

    /// Whether automatic translation is enabled
    @AppStorage("translationEnabled") static var isTranslationEnabled: Bool = true

    /// Source language code for translation (e.g., "en")
    @AppStorage("translationSourceLanguage") static var translationSourceLanguage: String = "en"

    /// Target language code for translation (e.g., "ru")
    @AppStorage("translationTargetLanguage") static var translationTargetLanguage: String = "ru"

    /// Supported translation languages
    static let supportedLanguages: [(code: String, name: String)] = [
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

    // MARK: - Deck Selection Settings (NEW)

    /// Raw JSON data for selected deck IDs
    /// Stored as JSON array of UUID strings for UserDefaults compatibility
    @AppStorage("selectedDeckIDsData") static var selectedDeckIDsData: String = "[]"

    /// Selected deck IDs for multi-deck study sessions
    /// Uses JSON encoding for reliable persistence
    static var selectedDeckIDs: Set<UUID> {
        get {
            guard let data = selectedDeckIDsData.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(ids.compactMap { UUID(uuidString: $0) })
        }
        set {
            let ids = Array(newValue.map { $0.uuidString })
            guard let data = try? JSONEncoder().encode(ids),
                  let string = String(data: data, encoding: .utf8) else {
                return
            }
            selectedDeckIDsData = string
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
            "hapticEnabled": true,
            "audioEnabled": true,
            "studyLimit": 20,
            "defaultStudyMode": "scheduled",
            "dailyGoal": 20,
            "darkMode": "system",
            "glassEffectsEnabled": true
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
        case system = "system"
        case light = "light"
        case dark = "dark"

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
        case learning = "learning"
        case scheduled = "scheduled"

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
}
