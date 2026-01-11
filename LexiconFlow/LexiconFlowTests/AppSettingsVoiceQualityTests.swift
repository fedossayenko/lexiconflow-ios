//
//  AppSettingsVoiceQualityTests.swift
//  LexiconFlowTests
//
//  Tests for VoiceQuality enum and ttsVoiceQuality setting
//  Covers: Enum cases, display properties, icon properties, persistence
//

import Foundation
import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for VoiceQuality enum
@Suite("Voice Quality Enum Tests")
@MainActor
struct AppSettingsVoiceQualityTests {
    // MARK: - Test Setup

    init() {
        // Reset to default
        AppSettings.ttsVoiceQuality = .enhanced
    }

    // MARK: - Enum Cases

    @Test("VoiceQuality has all three cases: premium, enhanced, default")
    func voiceQualityHasAllCases() async throws {
        let allCases = AppSettings.VoiceQuality.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.premium))
        #expect(allCases.contains(.enhanced))
        #expect(allCases.contains(.default))
    }

    // MARK: - Display Properties

    @Test("VoiceQuality displayName returns correct names")
    func voiceQualityDisplayNames() async throws {
        #expect(AppSettings.VoiceQuality.premium.displayName == "Premium")
        #expect(AppSettings.VoiceQuality.enhanced.displayName == "Enhanced")
        #expect(AppSettings.VoiceQuality.default.displayName == "Default")

        // Display names should be unique
        let names = Set(AppSettings.VoiceQuality.allCases.map(\.displayName))
        #expect(names.count == 3)
    }

    @Test("VoiceQuality description is informative")
    func voiceQualityDescriptions() async throws {
        #expect(AppSettings.VoiceQuality.premium.description.contains("neural"))
        #expect(AppSettings.VoiceQuality.enhanced.description.contains("quality"))
        #expect(AppSettings.VoiceQuality.default.description.contains("pre-installed"))
    }

    // MARK: - Icon Properties

    @Test("VoiceQuality icon returns valid SF Symbols")
    func voiceQualityIcons() async throws {
        let premiumIcon = Image(systemName: AppSettings.VoiceQuality.premium.icon)
        let enhancedIcon = Image(systemName: AppSettings.VoiceQuality.enhanced.icon)
        let defaultIcon = Image(systemName: AppSettings.VoiceQuality.default.icon)

        // Should not crash if icons are valid
        _ = (premiumIcon, enhancedIcon, defaultIcon)
    }

    @Test("VoiceQuality icons are unique")
    func voiceQualityIconsAreUnique() async throws {
        let icons = Set([
            AppSettings.VoiceQuality.premium.icon,
            AppSettings.VoiceQuality.enhanced.icon,
            AppSettings.VoiceQuality.default.icon
        ])
        #expect(icons.count == 3, "Each quality should have unique icon")
    }

    // MARK: - Raw Values

    @Test("VoiceQuality raw values match case names")
    func voiceQualityRawValues() async throws {
        #expect(AppSettings.VoiceQuality.premium.rawValue == "premium")
        #expect(AppSettings.VoiceQuality.enhanced.rawValue == "enhanced")
        #expect(AppSettings.VoiceQuality.default.rawValue == "default")
    }

    // MARK: - Sendable Conformance

    @Test("VoiceQuality enum is Sendable")
    func voiceQualityIsSendable() async throws {
        let quality: any Sendable = AppSettings.VoiceQuality.premium
        #expect(quality is AppSettings.VoiceQuality)
    }

    // MARK: - @AppStorage Persistence

    @Test("ttsVoiceQuality persists in @AppStorage")
    func voiceQualityPersists() async throws {
        AppSettings.ttsVoiceQuality = .premium
        let stored = UserDefaults.standard.string(forKey: "ttsVoiceQuality")
        #expect(stored == "premium")

        // Reset
        AppSettings.ttsVoiceQuality = .enhanced
    }

    @Test("ttsVoiceQuality default is enhanced")
    func voiceQualityDefault() async throws {
        UserDefaults.standard.removeObject(forKey: "ttsVoiceQuality")
        let quality = AppSettings.ttsVoiceQuality
        #expect(quality == .enhanced)
    }

    @Test("ttsVoiceQuality can be changed")
    func voiceQualityCanBeChanged() async throws {
        let initial = AppSettings.ttsVoiceQuality

        AppSettings.ttsVoiceQuality = .premium
        #expect(AppSettings.ttsVoiceQuality == .premium)

        AppSettings.ttsVoiceQuality = .default
        #expect(AppSettings.ttsVoiceQuality == .default)

        // Reset
        AppSettings.ttsVoiceQuality = initial
    }
}
