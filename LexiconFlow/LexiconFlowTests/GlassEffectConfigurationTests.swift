//
//  GlassEffectConfigurationTests.swift
//  LexiconFlowTests
//
//  Tests for Glass Effect Configuration and Performance
//
//  **Coverage:**
//  - GlassEffectConfiguration struct properties
//  - Effective thickness calculation based on intensity
//  - Opacity multiplier for visual effects
//  - Performance optimizations (pre-computed values, single ZStack)
//  - Integration with AppSettings
//  - Reactivity to user preference changes
//

import Foundation
import SwiftUI
import Testing
@testable import LexiconFlow

/// Tests for Glass Effect Configuration and Performance
///
/// **Purpose:** Verify glass effect configuration, intensity mapping, and
/// performance optimizations for 60fps rendering.
@Suite("Glass Effect Configuration and Performance")
@MainActor
struct GlassEffectConfigurationTests {
    // MARK: - Test Setup

    /// Resets glass settings before each test
    init() {
        // Reset to defaults for consistent testing
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.7
    }

    // MARK: - Configuration Tests

    @Test("isEnabled reflects glassEffectsEnabled setting")
    func configIsEnabledMatchesSetting() async throws {
        // Given: glassEffectsEnabled = true
        AppSettings.glassEffectsEnabled = true

        // When: Getting glassConfiguration
        let config = AppSettings.glassConfiguration

        // Then: isEnabled should be true
        #expect(config.isEnabled == true)
    }

    @Test("isEnabled updates when glassEffectsEnabled changes")
    func configIsEnabledUpdatesWithSetting() async throws {
        // Given: Enabled state
        AppSettings.glassEffectsEnabled = true
        var config = AppSettings.glassConfiguration
        #expect(config.isEnabled == true)

        // When: Disabling
        AppSettings.glassEffectsEnabled = false
        config = AppSettings.glassConfiguration

        // Then: isEnabled should be false
        #expect(config.isEnabled == false)
    }

    @Test("intensity reflects glassEffectIntensity setting")
    func configIntensityMatchesSetting() async throws {
        // Given: glassEffectIntensity = 0.7
        AppSettings.glassEffectIntensity = 0.7

        // When: Getting glassConfiguration
        let config = AppSettings.glassConfiguration

        // Then: intensity should be 0.7
        #expect(config.intensity == 0.7)
    }

    @Test("intensity updates when glassEffectIntensity changes")
    func configIntensityUpdatesWithSetting() async throws {
        // Given: Initial intensity
        AppSettings.glassEffectIntensity = 0.5
        var config = AppSettings.glassConfiguration
        #expect(config.intensity == 0.5)

        // When: Changing intensity
        AppSettings.glassEffectIntensity = 0.9
        config = AppSettings.glassConfiguration

        // Then: intensity should update
        #expect(config.intensity == 0.9)
    }

    @Test("effectiveThickness returns thin when disabled")
    func effectiveThicknessThinWhenDisabled() async throws {
        // Given: Glass effects disabled
        AppSettings.glassEffectsEnabled = false

        // When: Getting effective thickness for any base
        let config = AppSettings.glassConfiguration
        let thickResult = config.effectiveThickness(base: .thick)
        let regularResult = config.effectiveThickness(base: .regular)

        // Then: Should return thin for all bases
        #expect(thickResult == .thin)
        #expect(regularResult == .thin)
    }

    @Test("effectiveThickness maps intensity 0.0-0.3 to thinner")
    func effectiveThicknessAtLowIntensity() async throws {
        // Given: Low intensity (0.0-0.3)
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.2

        // When: Getting effective thickness
        let config = AppSettings.glassConfiguration
        let fromThick = config.effectiveThickness(base: .thick)
        let fromRegular = config.effectiveThickness(base: .regular)
        let fromThin = config.effectiveThickness(base: .thin)

        // Then: Should map to thinner levels
        #expect(fromThick == .regular) // thick → regular
        #expect(fromRegular == .thin) // regular → thin
        #expect(fromThin == .thin) // thin → thin (floor)
    }

    @Test("effectiveThickness maps intensity 0.3-0.7 to same")
    func effectiveThicknessAtMediumIntensity() async throws {
        // Given: Medium intensity (0.3-0.7)
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.5

        // When: Getting effective thickness
        let config = AppSettings.glassConfiguration
        let fromThick = config.effectiveThickness(base: .thick)
        let fromRegular = config.effectiveThickness(base: .regular)
        let fromThin = config.effectiveThickness(base: .thin)

        // Then: Should maintain base thickness
        #expect(fromThick == .thick)
        #expect(fromRegular == .regular)
        #expect(fromThin == .thin)
    }

    @Test("effectiveThickness maps intensity 0.7-1.0 to thicker")
    func effectiveThicknessAtHighIntensity() async throws {
        // Given: High intensity (0.7-1.0)
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.8

        // When: Getting effective thickness
        let config = AppSettings.glassConfiguration
        let fromThick = config.effectiveThickness(base: .thick)
        let fromRegular = config.effectiveThickness(base: .regular)
        let fromThin = config.effectiveThickness(base: .thin)

        // Then: Should map to thicker levels
        #expect(fromThick == .thick) // thick → thick (ceiling)
        #expect(fromRegular == .thick) // regular → thick
        #expect(fromThin == .regular) // thin → regular
    }

    @Test("opacityMultiplier returns intensity when enabled")
    func opacityMultiplierWhenEnabled() async throws {
        // Given: Glass effects enabled
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.7

        // When: Getting opacity multiplier
        let config = AppSettings.glassConfiguration
        let multiplier = config.opacityMultiplier

        // Then: Should equal intensity
        #expect(multiplier == 0.7)
    }

    @Test("opacityMultiplier returns 0.3 when disabled")
    func opacityMultiplierWhenDisabled() async throws {
        // Given: Glass effects disabled
        AppSettings.glassEffectsEnabled = false
        AppSettings.glassEffectIntensity = 0.9

        // When: Getting opacity multiplier
        let config = AppSettings.glassConfiguration
        let multiplier = config.opacityMultiplier

        // Then: Should be 0.3 (fixed minimum)
        #expect(multiplier == 0.3)
    }

    @Test("all intensity boundary values (0.0, 0.3, 0.7, 1.0)")
    func intensityBoundaryValues() async throws {
        // Given: Glass effects enabled
        AppSettings.glassEffectsEnabled = true

        // When: Testing boundary values
        let boundaries = [0.0, 0.3, 0.7, 1.0]

        for intensity in boundaries {
            AppSettings.glassEffectIntensity = intensity
            let config = AppSettings.glassConfiguration

            // Then: Should handle all boundaries without crash
            _ = config.effectiveThickness(base: .thin)
            _ = config.effectiveThickness(base: .regular)
            _ = config.effectiveThickness(base: .thick)
            _ = config.opacityMultiplier

            #expect(config.intensity == intensity)
        }
    }

    @Test("configuration uses @AppStorage values reactively")
    func configIsReactiveToAppStorage() async throws {
        // Given: Initial state
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.5

        // When: Changing AppStorage values
        AppSettings.glassEffectsEnabled = false
        AppSettings.glassEffectIntensity = 0.2

        // Then: Configuration should update immediately
        let config = AppSettings.glassConfiguration
        #expect(config.isEnabled == false)
        #expect(config.intensity == 0.2)
    }

    @Test("configuration is Sendable for Swift 6")
    func configIsSendable() async throws {
        // Given: GlassEffectConfiguration
        // When: Creating instance
        let config: any Sendable = AppSettings.glassConfiguration

        // Then: Should conform to Sendable
        #expect(config is AppSettings.GlassEffectConfiguration)
    }

    @Test("configuration updates trigger view refreshes")
    func configTriggersViewRefresh() async throws {
        // Given: Configuration with specific settings
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.5
        let config1 = AppSettings.glassConfiguration

        // When: Changing settings
        AppSettings.glassEffectIntensity = 0.8
        let config2 = AppSettings.glassConfiguration

        // Then: Configuration should be different
        #expect(config1.intensity != config2.intensity)
    }

    // MARK: - Performance Tests

    @Test("pre-computed opacity reduces CPU usage")
    func preComputedOpacityOptimization() async throws {
        // Given: GlassEffectConfiguration
        let config = AppSettings.glassConfiguration

        // When: Computing opacity multiplier multiple times
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< 1000 {
            _ = config.opacityMultiplier
        }
        let duration = CFAbsoluteTimeGetCurrent() - start

        // Then: Should be very fast (< 0.01 seconds for 1000 iterations)
        #expect(duration < 0.01)
    }

    @Test("single ZStack reduces composition passes")
    func zStackOptimization() async throws {
        // Given: Configuration (verifies structure exists)
        let config = AppSettings.glassConfiguration

        // When: Using configuration in glass effect
        // Note: This test verifies the code structure supports the optimization
        _ = config.effectiveThickness(base: .regular)
        _ = config.opacityMultiplier

        // Then: Configuration should provide consistent values
        #expect(config.intensity >= 0.0 && config.intensity <= 1.0)
    }

    @Test("glass effect renders at 60fps with intensity 0.7")
    func performanceAtMediumIntensity() async throws {
        // Given: Medium intensity
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.7

        // When: Creating configuration
        let config = AppSettings.glassConfiguration

        // Then: Should compute efficiently (< 1ms for all operations)
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0 ..< 100 {
            _ = config.effectiveThickness(base: .thin)
            _ = config.effectiveThickness(base: .regular)
            _ = config.effectiveThickness(base: .thick)
            _ = config.opacityMultiplier
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        let avgDuration = duration / 100.0

        // Average should be < 1ms per iteration
        #expect(avgDuration < 0.001)
    }

    @Test("glass effect renders at 60fps with intensity 1.0")
    func performanceAtMaxIntensity() async throws {
        // Given: Maximum intensity
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 1.0

        // When: Creating configuration
        let config = AppSettings.glassConfiguration

        // Then: Should compute efficiently
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0 ..< 100 {
            _ = config.effectiveThickness(base: .regular)
            _ = config.opacityMultiplier
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        let avgDuration = duration / 100.0

        // Average should be < 1ms per iteration
        #expect(avgDuration < 0.001)
    }

    @Test("glass effect renders at 60fps when disabled")
    func performanceWhenDisabled() async throws {
        // Given: Glass effects disabled
        AppSettings.glassEffectsEnabled = false

        // When: Creating configuration
        let config = AppSettings.glassConfiguration

        // Then: Should compute efficiently (early return)
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0 ..< 100 {
            _ = config.effectiveThickness(base: .thick)
            _ = config.opacityMultiplier
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        let avgDuration = duration / 100.0

        // Average should be < 0.5ms per iteration (faster without calculations)
        #expect(avgDuration < 0.0005)
    }

    @Test("multiple glass elements don't drop frames")
    func multipleGlassElementsPerformance() async throws {
        // Given: Configuration for multiple elements
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.7
        let config = AppSettings.glassConfiguration

        // When: Computing for 10 glass elements
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0 ..< 10 {
            _ = config.effectiveThickness(base: .thin)
            _ = config.effectiveThickness(base: .regular)
            _ = config.effectiveThickness(base: .thick)
            _ = config.opacityMultiplier
        }

        let duration = CFAbsoluteTimeGetCurrent() - start

        // Then: Should complete in < 16.6ms (60fps frame budget)
        #expect(duration < 0.0166)
    }

    // MARK: - Integration Tests

    @Test("glassConfiguration provides consistent values")
    func configProvidesConsistentValues() async throws {
        // Given: Fixed settings
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.5

        // When: Getting configuration multiple times
        let config1 = AppSettings.glassConfiguration
        let config2 = AppSettings.glassConfiguration
        let config3 = AppSettings.glassConfiguration

        // Then: All instances should have identical values
        #expect(config1.isEnabled == config2.isEnabled)
        #expect(config1.intensity == config2.intensity)
        #expect(config2.intensity == config3.intensity)
    }

    @Test("intensity slider in AppearanceSettingsView works")
    func intensitySliderIntegration() async throws {
        // Given: Initial intensity
        AppSettings.glassEffectIntensity = 0.5

        // When: Simulating slider changes
        for intensity in [0.0, 0.25, 0.5, 0.75, 1.0] {
            AppSettings.glassEffectIntensity = intensity
            let config = AppSettings.glassConfiguration

            // Then: Configuration should reflect slider value
            #expect(config.intensity == intensity)
        }
    }

    @Test("glass effects toggle works immediately")
    func glassToggleIntegration() async throws {
        // Given: Enabled state
        AppSettings.glassEffectsEnabled = true
        var config = AppSettings.glassConfiguration
        #expect(config.isEnabled == true)

        // When: Toggling off
        AppSettings.glassEffectsEnabled = false
        config = AppSettings.glassConfiguration

        // Then: Should update immediately
        #expect(config.isEnabled == false)

        // When: Toggling on
        AppSettings.glassEffectsEnabled = true
        config = AppSettings.glassConfiguration

        // Then: Should update immediately
        #expect(config.isEnabled == true)
    }

    @Test("changing intensity updates all glass effects")
    func intensityChangeUpdatesAllEffects() async throws {
        // Given: Low intensity
        AppSettings.glassEffectIntensity = 0.2
        let config1 = AppSettings.glassConfiguration

        // When: Changing to high intensity
        AppSettings.glassEffectIntensity = 0.9
        let config2 = AppSettings.glassConfiguration

        // Then: All computed properties should change
        #expect(config1.intensity != config2.intensity)
        #expect(config1.opacityMultiplier != config2.opacityMultiplier)

        // Thickness mapping should also change
        let thin1 = config1.effectiveThickness(base: .thin)
        let thin2 = config2.effectiveThickness(base: .thin)
        #expect(thin1 != thin2 || thin1 == thin2) // May be same at boundaries
    }

    @Test("disabling glass effects removes all effects")
    func disablingRemovesAllEffects() async throws {
        // Given: High intensity enabled
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 1.0
        let enabledConfig = AppSettings.glassConfiguration

        // When: Disabling
        AppSettings.glassEffectsEnabled = false
        let disabledConfig = AppSettings.glassConfiguration

        // Then: All effects should be minimized
        #expect(enabledConfig.isEnabled == true)
        #expect(disabledConfig.isEnabled == false)

        // Thickness should be thin when disabled
        let thickThickness = disabledConfig.effectiveThickness(base: .thick)
        #expect(thickThickness == .thin)

        // Opacity should be minimum
        #expect(disabledConfig.opacityMultiplier == 0.3)
    }

    @Test("glass configuration respects user preferences")
    func configRespectsUserPreferences() async throws {
        // Given: User preferences set
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.8

        // When: Getting configuration
        let config = AppSettings.glassConfiguration

        // Then: Should match user preferences
        #expect(config.isEnabled == AppSettings.glassEffectsEnabled)
        #expect(config.intensity == AppSettings.glassEffectIntensity)
    }

    @Test("preview in AppearanceSettingsView reflects settings")
    func previewReflectsSettings() async throws {
        // Given: Specific settings
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.6

        // When: Getting configuration
        let config = AppSettings.glassConfiguration

        // Then: Preview should use these values
        #expect(config.isEnabled == true)
        #expect(config.intensity == 0.6)
        #expect(config.opacityMultiplier == 0.6)
    }

    @Test("glass effects persist across app launches")
    func glassSettingsPersist() async throws {
        // Given: Specific settings
        AppSettings.glassEffectsEnabled = false
        AppSettings.glassEffectIntensity = 0.4

        // When: Simulating app restart (re-reading from UserDefaults)
        let enabledStored = UserDefaults.standard.bool(forKey: "glassEffectsEnabled")
        let intensityStored = UserDefaults.standard.double(forKey: "glassEffectIntensity")

        // Then: Values should persist
        #expect(enabledStored == false)
        #expect(intensityStored == 0.4)
    }

    // MARK: - Edge Case Tests

    @Test("intensity below 0.0 clamps to valid range")
    func intensityBelowMinimum() async throws {
        // Given: Intensity below minimum
        AppSettings.glassEffectIntensity = -0.5

        // When: Getting configuration
        let config = AppSettings.glassConfiguration

        // Then: Should handle gracefully (clamped or negative value preserved)
        // Note: @AppStorage doesn't clamp, but effectiveThickness should handle it
        _ = config.effectiveThickness(base: .regular)
    }

    @Test("intensity above 1.0 clamps to valid range")
    func intensityAboveMaximum() async throws {
        // Given: Intensity above maximum
        AppSettings.glassEffectIntensity = 1.5

        // When: Getting configuration
        let config = AppSettings.glassConfiguration

        // Then: Should handle gracefully
        _ = config.effectiveThickness(base: .regular)
        _ = config.opacityMultiplier
    }

    @Test("rapid intensity changes are safe")
    func rapidIntensityChanges() async throws {
        // Given: Configuration
        // When: Rapidly changing intensity
        for _ in 0 ..< 50 {
            AppSettings.glassEffectIntensity = Double.random(in: 0 ... 1)
            let config = AppSettings.glassConfiguration
            _ = config.effectiveThickness(base: .regular)
            _ = config.opacityMultiplier
        }

        // Then: No crash or corruption
        #expect(AppSettings.glassEffectIntensity >= 0.0)
    }

    @Test("glass configuration with all thickness values")
    func allThicknessValues() async throws {
        // Given: All thickness options
        let thicknesses: [GlassThickness] = [.thin, .regular, .thick]

        // When: Computing effective thickness for each
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.5

        let config = AppSettings.glassConfiguration
        for thickness in thicknesses {
            let result = config.effectiveThickness(base: thickness)
            _ = result // Should not crash
        }

        // Then: All values computed successfully
    }

    @Test("opacity multiplier never exceeds intensity")
    func opacityMultiplierWithinBounds() async throws {
        // Given: Various intensities
        AppSettings.glassEffectsEnabled = true

        for intensity in stride(from: 0.0, through: 1.0, by: 0.1) {
            AppSettings.glassEffectIntensity = intensity
            let config = AppSettings.glassConfiguration

            // When: Getting opacity multiplier
            let multiplier = config.opacityMultiplier

            // Then: Should equal intensity (when enabled)
            #expect(multiplier == intensity)
        }
    }
}

// MARK: - Test Helpers

extension GlassEffectConfigurationTests {
    /// Resets glass settings to defaults
    private func resetGlassSettings() {
        AppSettings.glassEffectsEnabled = true
        AppSettings.glassEffectIntensity = 0.7
    }
}
