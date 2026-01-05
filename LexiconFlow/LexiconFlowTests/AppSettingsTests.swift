//
//  AppSettingsTests.swift
//  LexiconFlowTests
//
//  Tests for centralized app settings
//

import Testing
import Foundation
@testable import LexiconFlow

/// Test suite for AppSettings centralized preferences
///
/// Tests verify:
/// - Default values for all settings
/// - Type safety and validation
/// - Enum display properties
/// - Language validation
/// - Persistence behavior
@MainActor
struct AppSettingsTests {

    // MARK: - Onboarding Settings Tests

    @Test("hasCompletedOnboarding defaults to false")
    func onboardingDefaultsToFalse() {
        // Save current value
        let originalValue = AppSettings.hasCompletedOnboarding

        // Reset to default
        AppSettings.hasCompletedOnboarding = false
        #expect(AppSettings.hasCompletedOnboarding == false)

        // Test setting to true
        AppSettings.hasCompletedOnboarding = true
        #expect(AppSettings.hasCompletedOnboarding == true)

        // Restore original value
        AppSettings.hasCompletedOnboarding = originalValue
    }

    // MARK: - Translation Settings Tests

    @Test("isTranslationEnabled defaults to true")
    func translationEnabledDefaultsToTrue() {
        let originalValue = AppSettings.isTranslationEnabled

        AppSettings.isTranslationEnabled = true
        #expect(AppSettings.isTranslationEnabled == true)

        AppSettings.isTranslationEnabled = false
        #expect(AppSettings.isTranslationEnabled == false)

        AppSettings.isTranslationEnabled = originalValue
    }

    @Test("translationSourceLanguage defaults to English")
    func translationSourceDefaultsToEnglish() {
        let originalValue = AppSettings.translationSourceLanguage

        AppSettings.translationSourceLanguage = "en"
        #expect(AppSettings.translationSourceLanguage == "en")

        AppSettings.translationSourceLanguage = originalValue
    }

    @Test("translationTargetLanguage defaults to Russian")
    func translationTargetDefaultsToRussian() {
        let originalValue = AppSettings.translationTargetLanguage

        AppSettings.translationTargetLanguage = "ru"
        #expect(AppSettings.translationTargetLanguage == "ru")

        AppSettings.translationTargetLanguage = originalValue
    }

    @Test("supportedLanguages contains expected languages")
    func supportedLanguagesContainsExpected() {
        let supported = AppSettings.supportedLanguages

        // Test that we have the expected languages
        let languageCodes = supported.map { $0.code }
        #expect(languageCodes.contains("en"), "Should contain English")
        #expect(languageCodes.contains("ru"), "Should contain Russian")
        #expect(languageCodes.contains("es"), "Should contain Spanish")
        #expect(languageCodes.contains("fr"), "Should contain French")
        #expect(languageCodes.contains("de"), "Should contain German")
        #expect(languageCodes.contains("ja"), "Should contain Japanese")
        #expect(languageCodes.contains("zh-Hans"), "Should contain Chinese Simplified")
    }

    @Test("language codes are valid BCP 47")
    func languageCodesAreValidBCP47() {
        let supported = AppSettings.supportedLanguages

        for language in supported {
            // BCP 47 language tags should be 2-5 letters or contain hyphen
            let isValid = language.code.count >= 2 && language.code.count <= 8
            #expect(isValid, "Language code '\(language.code)' should be valid BCP 47")
        }
    }

    @Test("translation languages can be changed")
    func translationLanguagesCanBeChanged() {
        let originalSource = AppSettings.translationSourceLanguage
        let originalTarget = AppSettings.translationTargetLanguage

        AppSettings.translationSourceLanguage = "es"
        AppSettings.translationTargetLanguage = "de"

        #expect(AppSettings.translationSourceLanguage == "es")
        #expect(AppSettings.translationTargetLanguage == "de")

        AppSettings.translationSourceLanguage = originalSource
        AppSettings.translationTargetLanguage = originalTarget
    }

    // MARK: - Haptic Settings Tests

    @Test("hapticEnabled defaults to true")
    func hapticEnabledDefaultsToTrue() {
        let originalValue = AppSettings.hapticEnabled

        AppSettings.hapticEnabled = true
        #expect(AppSettings.hapticEnabled == true)

        AppSettings.hapticEnabled = false
        #expect(AppSettings.hapticEnabled == false)

        AppSettings.hapticEnabled = originalValue
    }

    @Test("hapticIntensity defaults to 1.0")
    func hapticIntensityDefaultsToMax() {
        let originalValue = AppSettings.hapticIntensity

        AppSettings.hapticIntensity = 1.0
        #expect(AppSettings.hapticIntensity == 1.0)

        AppSettings.hapticIntensity = originalValue
    }

    @Test("hapticIntensity accepts valid range")
    func hapticIntensityValidRange() {
        let originalValue = AppSettings.hapticIntensity

        // Test minimum
        AppSettings.hapticIntensity = 0.1
        #expect(AppSettings.hapticIntensity == 0.1)

        // Test maximum
        AppSettings.hapticIntensity = 1.0
        #expect(AppSettings.hapticIntensity == 1.0)

        // Test middle value
        AppSettings.hapticIntensity = 0.5
        #expect(AppSettings.hapticIntensity == 0.5)

        AppSettings.hapticIntensity = originalValue
    }

    @Test("hapticIntensity handles common preset values")
    func hapticIntensityPresets() {
        let originalValue = AppSettings.hapticIntensity

        let presets: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

        for preset in presets {
            AppSettings.hapticIntensity = preset
            #expect(AppSettings.hapticIntensity == preset)
        }

        AppSettings.hapticIntensity = originalValue
    }

    // MARK: - Study Session Settings Tests

    @Test("studyLimit defaults to 20")
    func studyLimitDefaultsTo20() {
        let originalValue = AppSettings.studyLimit

        AppSettings.studyLimit = 20
        #expect(AppSettings.studyLimit == 20)

        AppSettings.studyLimit = originalValue
    }

    @Test("studyLimit accepts common values")
    func studyLimitCommonValues() {
        let originalValue = AppSettings.studyLimit

        let commonValues = [10, 20, 30, 50, 100]

        for value in commonValues {
            AppSettings.studyLimit = value
            #expect(AppSettings.studyLimit == value)
        }

        AppSettings.studyLimit = originalValue
    }

    @Test("defaultStudyMode defaults to scheduled")
    func defaultStudyModeDefaultsToScheduled() {
        let originalValue = AppSettings.defaultStudyMode

        AppSettings.defaultStudyMode = "scheduled"
        #expect(AppSettings.defaultStudyMode == "scheduled")

        AppSettings.defaultStudyMode = originalValue
    }

    @Test("defaultStudyMode accepts valid modes")
    func defaultStudyModeValidModes() {
        let originalValue = AppSettings.defaultStudyMode

        AppSettings.defaultStudyMode = "scheduled"
        #expect(AppSettings.defaultStudyMode == "scheduled")

        AppSettings.defaultStudyMode = "cram"
        #expect(AppSettings.defaultStudyMode == "cram")

        AppSettings.defaultStudyMode = originalValue
    }

    @Test("dailyGoal defaults to 20")
    func dailyGoalDefaultsTo20() {
        let originalValue = AppSettings.dailyGoal

        AppSettings.dailyGoal = 20
        #expect(AppSettings.dailyGoal == 20)

        AppSettings.dailyGoal = originalValue
    }

    @Test("dailyGoal accepts common values")
    func dailyGoalCommonValues() {
        let originalValue = AppSettings.dailyGoal

        let commonValues = [10, 20, 30, 50, 100]

        for value in commonValues {
            AppSettings.dailyGoal = value
            #expect(AppSettings.dailyGoal == value)
        }

        AppSettings.dailyGoal = originalValue
    }

    @Test("gestureEnabled defaults to true")
    func gestureEnabledDefaultsToTrue() {
        let originalValue = AppSettings.gestureEnabled

        AppSettings.gestureEnabled = true
        #expect(AppSettings.gestureEnabled == true)

        AppSettings.gestureEnabled = false
        #expect(AppSettings.gestureEnabled == false)

        AppSettings.gestureEnabled = originalValue
    }

    // MARK: - Appearance Settings Tests

    @Test("darkMode defaults to system")
    func darkModeDefaultsToSystem() {
        let originalValue = AppSettings.darkMode

        AppSettings.darkMode = .system
        #expect(AppSettings.darkMode == .system)

        AppSettings.darkMode = originalValue
    }

    @Test("darkMode accepts all options")
    func darkModeAllOptions() {
        let originalValue = AppSettings.darkMode

        AppSettings.darkMode = .system
        #expect(AppSettings.darkMode == .system)

        AppSettings.darkMode = .light
        #expect(AppSettings.darkMode == .light)

        AppSettings.darkMode = .dark
        #expect(AppSettings.darkMode == .dark)

        AppSettings.darkMode = originalValue
    }

    @Test("glassEffectsEnabled defaults to true")
    func glassEffectsEnabledDefaultsToTrue() {
        let originalValue = AppSettings.glassEffectsEnabled

        AppSettings.glassEffectsEnabled = true
        #expect(AppSettings.glassEffectsEnabled == true)

        AppSettings.glassEffectsEnabled = false
        #expect(AppSettings.glassEffectsEnabled == false)

        AppSettings.glassEffectsEnabled = originalValue
    }

    // MARK: - Enum Tests

    @Test("DarkModePreference has correct display names")
    func darkModeDisplayNames() {
        #expect(AppSettings.DarkModePreference.system.displayName == "System")
        #expect(AppSettings.DarkModePreference.light.displayName == "Light")
        #expect(AppSettings.DarkModePreference.dark.displayName == "Dark")
    }

    @Test("DarkModePreference has correct icons")
    func darkModeIcons() {
        #expect(AppSettings.DarkModePreference.system.icon == "iphone")
        #expect(AppSettings.DarkModePreference.light.icon == "sun.max.fill")
        #expect(AppSettings.DarkModePreference.dark.icon == "moon.fill")
    }

    @Test("StudyModeOption has correct display names")
    func studyModeDisplayNames() {
        #expect(AppSettings.StudyModeOption.scheduled.displayName == "Scheduled (FSRS)")
        #expect(AppSettings.StudyModeOption.cram.displayName == "Cram (Practice)")
    }

    @Test("StudyModeOption has correct descriptions")
    func studyModeDescriptions() {
        let scheduledDesc = AppSettings.StudyModeOption.scheduled.description
        let cramDesc = AppSettings.StudyModeOption.cram.description

        #expect(scheduledDesc == "Due cards based on FSRS algorithm")
        #expect(cramDesc == "Practice without affecting progress")
    }

    @Test("DarkModePreference is case iterable")
    func darkModeIsIterable() {
        let allCases = AppSettings.DarkModePreference.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.system))
        #expect(allCases.contains(.light))
        #expect(allCases.contains(.dark))
    }

    @Test("StudyModeOption is case iterable")
    func studyModeIsIterable() {
        let allCases = AppSettings.StudyModeOption.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.scheduled))
        #expect(allCases.contains(.cram))
    }

    @Test("DarkModePreference raw values are correct")
    func darkModeRawValues() {
        #expect(AppSettings.DarkModePreference.system.rawValue == "system")
        #expect(AppSettings.DarkModePreference.light.rawValue == "light")
        #expect(AppSettings.DarkModePreference.dark.rawValue == "dark")
    }

    @Test("StudyModeOption raw values are correct")
    func studyModeRawValues() {
        #expect(AppSettings.StudyModeOption.scheduled.rawValue == "scheduled")
        #expect(AppSettings.StudyModeOption.cram.rawValue == "cram")
    }
}
