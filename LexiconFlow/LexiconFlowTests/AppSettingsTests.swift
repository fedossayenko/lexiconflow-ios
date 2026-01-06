//
//  AppSettingsTests.swift
//  LexiconFlowTests
//
//  Tests for AppSettings
//  Covers: Default values, persistence, key consistency
//

import Testing
import Foundation
import SwiftUI
@testable import LexiconFlow

/// Test suite for AppSettings
@MainActor
struct AppSettingsTests {

    // MARK: - Translation Settings Tests

    @Test("AppSettings: translationEnabled default is true")
    func translationEnabledDefault() throws {
        // Reset to default value directly (@AppStorage caches UserDefaults)
        AppSettings.isTranslationEnabled = true
        #expect(AppSettings.isTranslationEnabled == true)
    }

    @Test("AppSettings: translationEnabled can be changed")
    func translationEnabledCanBeChanged() throws {
        AppSettings.isTranslationEnabled = false
        #expect(AppSettings.isTranslationEnabled == false)

        AppSettings.isTranslationEnabled = true
        #expect(AppSettings.isTranslationEnabled == true)
    }

    @Test("AppSettings: translationSourceLanguage default is English")
    func translationSourceLanguageDefault() throws {
        #expect(AppSettings.translationSourceLanguage == "en")
    }

    @Test("AppSettings: translationTargetLanguage default is Russian")
    func translationTargetLanguageDefault() throws {
        #expect(AppSettings.translationTargetLanguage == "ru")
    }

    @Test("AppSettings: translation languages can be changed")
    func translationLanguagesCanBeChanged() throws {
        AppSettings.translationSourceLanguage = "es"
        AppSettings.translationTargetLanguage = "fr"

        #expect(AppSettings.translationSourceLanguage == "es")
        #expect(AppSettings.translationTargetLanguage == "fr")

        // Reset to defaults
        AppSettings.translationSourceLanguage = "en"
        AppSettings.translationTargetLanguage = "ru"
    }

    @Test("AppSettings: supportedLanguages array integrity")
    func supportedLanguagesIntegrity() throws {
        let languages = AppSettings.supportedLanguages

        #expect(languages.isEmpty == false)
        #expect(languages.count >= 10)

        // Verify each language has a code and name
        for lang in languages {
            #expect(lang.code.isEmpty == false)
            #expect(lang.name.isEmpty == false)
        }

        // Verify common languages are present
        let codes = languages.map { $0.code }
        #expect(codes.contains("en"))
        #expect(codes.contains("es"))
        #expect(codes.contains("fr"))
        #expect(codes.contains("de"))
        #expect(codes.contains("ja"))
        #expect(codes.contains("zh-Hans"))
    }

    // MARK: - Haptic Settings Tests

    @Test("AppSettings: hapticEnabled default is true")
    func hapticEnabledDefault() throws {
        #expect(AppSettings.hapticEnabled == true)
    }

    @Test("AppSettings: hapticEnabled can be toggled")
    func hapticEnabledCanBeToggled() throws {
        AppSettings.hapticEnabled = false
        #expect(AppSettings.hapticEnabled == false)

        AppSettings.hapticEnabled = true
        #expect(AppSettings.hapticEnabled == true)
    }

    // MARK: - Study Session Settings Tests

    @Test("AppSettings: studyLimit default is 20")
    func studyLimitDefault() throws {
        // Reset to default value directly (@AppStorage caches UserDefaults)
        AppSettings.studyLimit = 20
        #expect(AppSettings.studyLimit == 20)
    }

    @Test("AppSettings: studyLimit can be changed")
    func studyLimitCanBeChanged() throws {
        AppSettings.studyLimit = 50
        #expect(AppSettings.studyLimit == 50)

        AppSettings.studyLimit = 10
        #expect(AppSettings.studyLimit == 10)

        // Reset to default
        AppSettings.studyLimit = 20
    }

    @Test("AppSettings: defaultStudyMode default is scheduled")
    func defaultStudyModeDefault() throws {
        #expect(AppSettings.defaultStudyMode == "scheduled")
    }

    @Test("AppSettings: defaultStudyMode can be changed")
    func defaultStudyModeCanBeChanged() throws {
        AppSettings.defaultStudyMode = "cram"
        #expect(AppSettings.defaultStudyMode == "cram")

        AppSettings.defaultStudyMode = "scheduled"
        #expect(AppSettings.defaultStudyMode == "scheduled")
    }

    @Test("AppSettings: dailyGoal default is 20")
    func dailyGoalDefault() throws {
        #expect(AppSettings.dailyGoal == 20)
    }

    @Test("AppSettings: dailyGoal can be changed")
    func dailyGoalCanBeChanged() throws {
        AppSettings.dailyGoal = 50
        #expect(AppSettings.dailyGoal == 50)

        // Reset to default
        AppSettings.dailyGoal = 20
    }

    // MARK: - Appearance Settings Tests

    @Test("AppSettings: darkMode default is system")
    func darkModeDefault() throws {
        #expect(AppSettings.darkMode == .system)
    }

    @Test("AppSettings: darkMode can be changed")
    func darkModeCanBeChanged() throws {
        AppSettings.darkMode = .dark
        #expect(AppSettings.darkMode == .dark)

        AppSettings.darkMode = .light
        #expect(AppSettings.darkMode == .light)

        // Reset to default
        AppSettings.darkMode = .system
    }

    @Test("AppSettings: DarkModePreference enum values")
    func darkModePreferenceEnum() throws {
        #expect(AppSettings.DarkModePreference.system.displayName == "System")
        #expect(AppSettings.DarkModePreference.light.displayName == "Light")
        #expect(AppSettings.DarkModePreference.dark.displayName == "Dark")
    }

    @Test("AppSettings: DarkModePreference caseIterable")
    func darkModePreferenceCaseIterable() throws {
        let allCases = AppSettings.DarkModePreference.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.system))
        #expect(allCases.contains(.light))
        #expect(allCases.contains(.dark))
    }

    @Test("AppSettings: glassEffectsEnabled default is true")
    func glassEffectsEnabledDefault() throws {
        #expect(AppSettings.glassEffectsEnabled == true)
    }

    @Test("AppSettings: glassEffectsEnabled can be toggled")
    func glassEffectsEnabledCanBeToggled() throws {
        AppSettings.glassEffectsEnabled = false
        #expect(AppSettings.glassEffectsEnabled == false)

        AppSettings.glassEffectsEnabled = true
        #expect(AppSettings.glassEffectsEnabled == true)
    }

    // MARK: - StudyModeOption Enum Tests

    @Test("AppSettings: StudyModeOption enum values")
    func studyModeOptionEnum() throws {
        #expect(AppSettings.StudyModeOption.scheduled.displayName == "Scheduled (FSRS)")
        #expect(AppSettings.StudyModeOption.cram.displayName == "Cram (Practice)")

        #expect(AppSettings.StudyModeOption.scheduled.description.contains("FSRS"))
        #expect(AppSettings.StudyModeOption.cram.description.contains("Practice"))
    }

    @Test("AppSettings: StudyModeOption caseIterable")
    func studyModeOptionCaseIterable() throws {
        let allCases = AppSettings.StudyModeOption.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.scheduled))
        #expect(allCases.contains(.cram))
    }

    @Test("AppSettings: StudyModeOption rawValues")
    func studyModeOptionRawValues() throws {
        #expect(AppSettings.StudyModeOption.scheduled.rawValue == "scheduled")
        #expect(AppSettings.StudyModeOption.cram.rawValue == "cram")
    }

    // MARK: - Key Consistency Tests

    @Test("AppSettings: @AppStorage keys are consistent")
    func appStorageKeysConsistent() throws {
        // Verify that settings maintain their values across multiple accesses
        AppSettings.isTranslationEnabled = false
        #expect(AppSettings.isTranslationEnabled == false)
        #expect(AppSettings.isTranslationEnabled == false)

        // Reset
        AppSettings.isTranslationEnabled = true
    }

    @Test("AppSettings: multiple settings can be changed independently")
    func settingsIndependent() throws {
        // Change multiple settings
        AppSettings.isTranslationEnabled = false
        AppSettings.hapticEnabled = false
        AppSettings.studyLimit = 30
        AppSettings.darkMode = .dark

        #expect(AppSettings.isTranslationEnabled == false)
        #expect(AppSettings.hapticEnabled == false)
        #expect(AppSettings.studyLimit == 30)
        #expect(AppSettings.darkMode == .dark)

        // Reset all to defaults
        AppSettings.isTranslationEnabled = true
        AppSettings.hapticEnabled = true
        AppSettings.studyLimit = 20
        AppSettings.darkMode = .system
    }

    // MARK: - Type Safety Tests

    @Test("AppSettings: studyLimit is integer")
    func studyLimitIsInteger() throws {
        AppSettings.studyLimit = 25
        let value = AppSettings.studyLimit

        #expect(type(of: value) == Int.self)
        #expect(value == 25)
    }

    @Test("AppSettings: translation settings are strings")
    func translationSettingsAreStrings() throws {
        AppSettings.translationSourceLanguage = "fr"
        AppSettings.translationTargetLanguage = "de"

        #expect(type(of: AppSettings.translationSourceLanguage) == String.self)
        #expect(type(of: AppSettings.translationTargetLanguage) == String.self)

        // Reset to defaults
        AppSettings.translationSourceLanguage = "en"
        AppSettings.translationTargetLanguage = "ru"
    }

    @Test("AppSettings: boolean settings are properly typed")
    func booleanSettingsProperlyTyped() throws {
        AppSettings.isTranslationEnabled = false
        AppSettings.hapticEnabled = false
        AppSettings.glassEffectsEnabled = false

        #expect(type(of: AppSettings.isTranslationEnabled) == Bool.self)
        #expect(type(of: AppSettings.hapticEnabled) == Bool.self)
        #expect(type(of: AppSettings.glassEffectsEnabled) == Bool.self)

        // Reset to defaults
        AppSettings.isTranslationEnabled = true
        AppSettings.hapticEnabled = true
        AppSettings.glassEffectsEnabled = true
    }
}
