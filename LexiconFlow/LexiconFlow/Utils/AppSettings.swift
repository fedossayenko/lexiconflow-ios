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
enum AppSettings {
    // MARK: - Translation Settings

    /// Whether automatic translation is enabled
    @AppStorage("translationEnabled") static var isTranslationEnabled: Bool = true

    /// Source language code for translation (e.g., "en")
    @AppStorage("translationSourceLanguage") static var translationSourceLanguage: String = "en"

    /// Target language code for translation (e.g., "ru")
    @AppStorage("translationTargetLanguage") static var translationTargetLanguage: String = "ru"

    /// Z.ai API key for translation service
    @AppStorage("zai_api_key") static var translationAPIKey: String = ""

    // MARK: - Haptic Settings (NEW)

    /// Whether haptic feedback is enabled
    @AppStorage("hapticEnabled") static var hapticEnabled: Bool = true

    /// Haptic feedback intensity (0.1 to 1.0)
    @AppStorage("hapticIntensity") static var hapticIntensity: Double = 1.0

    // MARK: - Study Session Settings (NEW)

    /// Maximum number of cards to fetch per study session
    @AppStorage("studyLimit") static var studyLimit: Int = 20

    /// Default study mode ("scheduled" or "cram")
    @AppStorage("defaultStudyMode") static var defaultStudyMode: String = "scheduled"

    /// Daily study goal in number of cards
    @AppStorage("dailyGoal") static var dailyGoal: Int = 20

    // MARK: - Appearance Settings (NEW)

    /// Dark mode preference
    @AppStorage("darkMode") static var darkMode: DarkModePreference = .system

    /// Whether glass morphism effects are enabled
    @AppStorage("glassEffectsEnabled") static var glassEffectsEnabled: Bool = true

    // MARK: - Types

    /// Dark mode preference options
    enum DarkModePreference: String, CaseIterable {
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
    }

    /// Study mode options
    enum StudyModeOption: String, CaseIterable {
        case scheduled = "scheduled"
        case cram = "cram"

        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled (FSRS)"
            case .cram: return "Cram (Practice)"
            }
        }

        var description: String {
            switch self {
            case .scheduled: return "Due cards based on FSRS algorithm"
            case .cram: return "Practice without affecting progress"
            }
        }
    }
}
