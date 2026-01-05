//
//  SettingsViewsTests.swift
//  LexiconFlowTests
//
//  Tests for Settings views with meaningful assertions
//  Tests verify AppSettings bindings, enum values, property ranges, and view compilation
//
//  REWRITTEN: 42 tautological tests → 22 meaningful tests
//  Approach: Hybrid (Property verification + Enum validation + Compilation verification)
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for all Settings views
///
/// Tests verify:
/// - AppSettings binding functionality (read/write)
/// - Enum display properties and values
/// - Property range validation
/// - View compilation without crashes
@MainActor
struct SettingsViewsTests {

    // MARK: - Translation Settings Tests

    @Test("TranslationSettingsView.isTranslationEnabled binding works")
    func translationSettingsBindingEnabled() {
        let initialValue = AppSettings.isTranslationEnabled
        AppSettings.isTranslationEnabled.toggle()
        #expect(AppSettings.isTranslationEnabled != initialValue, "Translation enabled should toggle")
        AppSettings.isTranslationEnabled = initialValue // Reset
    }

    @Test("TranslationSettingsView.supportedLanguages has required languages")
    func translationSettingsSupportedLanguages() {
        let languages = AppSettings.supportedLanguages
        #expect(languages.count >= 10, "Should have at least 10 supported languages")
        #expect(languages.contains { $0.code == "en" }, "Should include English")
        #expect(languages.contains { $0.code == "ru" }, "Should include Russian")
        #expect(languages.contains { $0.code == "zh-Hans" }, "Should include Chinese (Simplified)")
    }

    @Test("TranslationSettingsView.language codes are unique")
    func translationSettingsLanguageCodesUnique() {
        let languages = AppSettings.supportedLanguages
        let codes = languages.map { $0.code }
        let uniqueCodes = Set(codes)
        #expect(codes.count == uniqueCodes.count, "Language codes should be unique")
    }

    @Test("TranslationSettingsView can set source and target languages")
    func translationSettingsLanguageBinding() {
        let initialSource = AppSettings.translationSourceLanguage
        let initialTarget = AppSettings.translationTargetLanguage

        AppSettings.translationSourceLanguage = "es"
        AppSettings.translationTargetLanguage = "de"

        #expect(AppSettings.translationSourceLanguage == "es", "Source language should be 'es'")
        #expect(AppSettings.translationTargetLanguage == "de", "Target language should be 'de'")

        // Reset
        AppSettings.translationSourceLanguage = initialSource
        AppSettings.translationTargetLanguage = initialTarget
    }

    // MARK: - Haptic Settings Tests

    @Test("HapticSettingsView.hapticEnabled binding works")
    func hapticSettingsBindingEnabled() {
        let initialValue = AppSettings.hapticEnabled
        AppSettings.hapticEnabled.toggle()
        #expect(AppSettings.hapticEnabled != initialValue, "Haptic enabled should toggle")
        AppSettings.hapticEnabled = initialValue // Reset
    }

    @Test("HapticSettingsView.hapticIntensity is within valid range")
    func hapticSettingsIntensityRange() {
        let intensity = AppSettings.hapticIntensity
        #expect(intensity >= 0.1 && intensity <= 1.0, "Haptic intensity should be between 0.1 and 1.0")
    }

    @Test("HapticSettingsView.hapticIntensity binding works")
    func hapticSettingsBindingIntensity() {
        let initialValue = AppSettings.hapticIntensity
        AppSettings.hapticIntensity = 0.5
        #expect(AppSettings.hapticIntensity == 0.5, "Haptic intensity should be settable")
        AppSettings.hapticIntensity = initialValue // Reset
    }

    // MARK: - Study Settings Tests

    @Test("StudySettingsView.studyLimit is within valid range")
    func studySettingsStudyLimitRange() {
        let limit = AppSettings.studyLimit
        #expect(limit >= 10 && limit <= 100, "Study limit should be between 10 and 100")
    }

    @Test("StudySettingsView.dailyGoal is within valid range")
    func studySettingsDailyGoalRange() {
        let goal = AppSettings.dailyGoal
        #expect(goal >= 5 && goal <= 100, "Daily goal should be between 5 and 100")
    }

    @Test("StudySettingsView.defaultStudyMode is valid")
    func studySettingsDefaultMode() {
        let mode = AppSettings.defaultStudyMode
        #expect(mode == "scheduled" || mode == "cram", "Default study mode should be 'scheduled' or 'cram'")
    }

    @Test("StudySettingsView.studyLimit binding works")
    func studySettingsBindingLimit() {
        let initialValue = AppSettings.studyLimit
        AppSettings.studyLimit = 50
        #expect(AppSettings.studyLimit == 50, "Study limit should be settable")
        AppSettings.studyLimit = initialValue // Reset
    }

    @Test("StudySettingsView.dailyGoal binding works")
    func studySettingsBindingGoal() {
        let initialValue = AppSettings.dailyGoal
        AppSettings.dailyGoal = 30
        #expect(AppSettings.dailyGoal == 30, "Daily goal should be settable")
        AppSettings.dailyGoal = initialValue // Reset
    }

    @Test("StudySettingsView.gestureEnabled binding works")
    func studySettingsBindingGesture() {
        let initialValue = AppSettings.gestureEnabled
        AppSettings.gestureEnabled.toggle()
        #expect(AppSettings.gestureEnabled != initialValue, "Gesture enabled should toggle")
        AppSettings.gestureEnabled = initialValue // Reset
    }

    // MARK: - Appearance Settings Tests

    @Test("AppearanceSettingsView.darkMode binding works")
    func appearanceSettingsBindingDarkMode() {
        let initialValue = AppSettings.darkMode
        AppSettings.darkMode = .light
        #expect(AppSettings.darkMode == .light, "Dark mode should be settable")
        AppSettings.darkMode = initialValue // Reset
    }

    @Test("AppearanceSettingsView.glassEffectsEnabled binding works")
    func appearanceSettingsBindingGlassEffects() {
        let initialValue = AppSettings.glassEffectsEnabled
        AppSettings.glassEffectsEnabled.toggle()
        #expect(AppSettings.glassEffectsEnabled != initialValue, "Glass effects enabled should toggle")
        AppSettings.glassEffectsEnabled = initialValue // Reset
    }

    @Test("AppearanceSettingsView.DarkModePreference display names are correct")
    func appearanceSettingsDarkModeDisplayNames() {
        #expect(AppSettings.DarkModePreference.system.displayName == "System", "System display name should match")
        #expect(AppSettings.DarkModePreference.light.displayName == "Light", "Light display name should match")
        #expect(AppSettings.DarkModePreference.dark.displayName == "Dark", "Dark display name should match")
    }

    @Test("AppearanceSettingsView.DarkModePreference has all cases")
    func appearanceSettingsDarkModeCases() {
        let cases = AppSettings.DarkModePreference.allCases
        #expect(cases.count == 3, "Should have 3 dark mode options")
        #expect(cases.contains(.system), "Should include system option")
        #expect(cases.contains(.light), "Should include light option")
        #expect(cases.contains(.dark), "Should include dark option")
    }

    // MARK: - Study Mode Option Tests

    @Test("StudySettingsView.StudyModeOption display names are correct")
    func studySettingsModeDisplayNames() {
        #expect(AppSettings.StudyModeOption.scheduled.displayName == "Scheduled (FSRS)", "Scheduled display name should match")
        #expect(AppSettings.StudyModeOption.cram.displayName == "Cram (Practice)", "Cram display name should match")
    }

    @Test("StudySettingsView.StudyModeOption descriptions are correct")
    func studySettingsModeDescriptions() {
        #expect(AppSettings.StudyModeOption.scheduled.description.contains("FSRS"), "Scheduled description should mention FSRS")
        #expect(AppSettings.StudyModeOption.cram.description.contains("Practice"), "Cram description should mention practice")
    }

    @Test("StudySettingsView.StudyModeOption has all cases")
    func studySettingsModeCases() {
        let cases = AppSettings.StudyModeOption.allCases
        #expect(cases.count == 2, "Should have 2 study mode options")
        #expect(cases.contains(.scheduled), "Should include scheduled option")
        #expect(cases.contains(.cram), "Should include cram option")
    }

    // MARK: - Onboarding Tests

    @Test("AppSettings.hasCompletedOnboarding binding works")
    func onboardingBinding() {
        let initialValue = AppSettings.hasCompletedOnboarding
        AppSettings.hasCompletedOnboarding.toggle()
        #expect(AppSettings.hasCompletedOnboarding != initialValue, "Onboarding completion should toggle")
        AppSettings.hasCompletedOnboarding = initialValue // Reset
    }

    // MARK: - View Compilation Tests

    @Test("All settings views compile without crash")
    func settingsViewsCompile() {
        let views: [any View] = [
            TranslationSettingsView(),
            AppearanceSettingsView(),
            HapticSettingsView(),
            StudySettingsView(),
            DataManagementView()
        ]

        for view in views {
            _ = view.body // Verify compilation
        }
        // If we reach here without crash, all views compiled successfully
    }

    @Test("All settings views render without crash")
    func settingsViewsRender() {
        // Verify views can be instantiated and rendered
        let translationView = TranslationSettingsView()
        let appearanceView = AppearanceSettingsView()
        let hapticView = HapticSettingsView()
        let studyView = StudySettingsView()
        let dataView = DataManagementView()

        // Access body to trigger rendering
        _ = translationView.body
        _ = appearanceView.body
        _ = hapticView.body
        _ = studyView.body
        _ = dataView.body

        // If we reach here without crash, all views render successfully
    }
}
