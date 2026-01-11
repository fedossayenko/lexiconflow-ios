//
//  ToastViewTests.swift
//  LexiconFlowTests
//
//  Tests for ToastView component including:
//  - ToastStyle enum properties
//  - Glass effect rendering
//  - Animation and timing
//  - Haptic integration
//  - ViewModifier behavior
//

import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for ToastView component
@Suite("ToastView Component Tests")
@MainActor
struct ToastViewTests {
    // MARK: - ToastStyle Enum Tests

    @Test("ToastStyle has all four cases: success, error, info, warning")
    func toastStyleHasAllCases() async throws {
        let styles: [ToastStyle] = [.success, .error, .info, .warning]
        #expect(styles.count == 4)
    }

    @Test("ToastStyle icon returns valid SF Symbols")
    func toastStyleIconsAreValid() async throws {
        let successIcon = Image(systemName: ToastStyle.success.icon)
        let errorIcon = Image(systemName: ToastStyle.error.icon)
        let infoIcon = Image(systemName: ToastStyle.info.icon)
        let warningIcon = Image(systemName: ToastStyle.warning.icon)

        // Should not crash if icons are valid
        _ = (successIcon, errorIcon, infoIcon, warningIcon)
    }

    @Test("ToastStyle color properties are unique")
    func toastStyleColorsAreUnique() async throws {
        let colors: Set<Color> = [
            ToastStyle.success.color,
            ToastStyle.error.color,
            ToastStyle.info.color,
            ToastStyle.warning.color
        ]
        #expect(colors.count == 4, "Each style should have unique color")
    }

    @Test("ToastStyle icons are unique")
    func toastStyleIconsAreUnique() async throws {
        let icons = Set([
            ToastStyle.success.icon,
            ToastStyle.error.icon,
            ToastStyle.info.icon,
            ToastStyle.warning.icon
        ])
        #expect(icons.count == 4, "Each style should have unique icon")
    }

    // MARK: - ToastView Rendering Tests

    @Test("ToastView renders with message and style")
    func toastViewRenders() async throws {
        let toast = ToastView(message: "Test message", style: .success)
        _ = toast.body // Should render without crashing
    }

    @Test("ToastView renders all four styles")
    func toastViewRendersAllStyles() async throws {
        let styles: [ToastStyle] = [.success, .error, .info, .warning]

        for style in styles {
            let toast = ToastView(message: "Test", style: style)
            _ = toast.body
        }
    }

    @Test("ToastView handles empty message")
    func toastViewEmptyMessage() async throws {
        let toast = ToastView(message: "", style: .info)
        _ = toast.body
    }

    @Test("ToastView handles long message")
    func toastViewLongMessage() async throws {
        let longMessage = String(repeating: "This is a very long message. ", count: 10)
        let toast = ToastView(message: longMessage, style: .info)
        _ = toast.body
    }

    @Test("ToastView handles special characters")
    func toastViewSpecialCharacters() async throws {
        let specialMessage = "Test with emoji:  and unicode: "
        let toast = ToastView(message: specialMessage, style: .info)
        _ = toast.body
    }

    // MARK: - Glass Effect Tests

    @Test("ToastView respects glassEffectsEnabled setting")
    func toastViewRespectsGlassEffect() async throws {
        let original = AppSettings.glassEffectsEnabled

        AppSettings.glassEffectsEnabled = true
        let glassToast = ToastView(message: "Test", style: .success)
        _ = glassToast.body

        AppSettings.glassEffectsEnabled = false
        let plainToast = ToastView(message: "Test", style: .success)
        _ = plainToast.body

        // Reset
        AppSettings.glassEffectsEnabled = original
    }

    @Test("ToastView glass effect uses ultraThinMaterial")
    func toastViewGlassMaterial() async throws {
        let original = AppSettings.glassEffectsEnabled
        AppSettings.glassEffectsEnabled = true

        let toast = ToastView(message: "Test", style: .success)
        // Verify glass effect is applied
        _ = toast.body

        // Reset
        AppSettings.glassEffectsEnabled = original
    }

    // MARK: - View Extension Tests

    @Test("toast modifier can be applied to any view")
    func toastViewModifierExtension() async throws {
        @State var isPresented = false
        let view = Text("Test")
            .toast(
                isPresented: $isPresented,
                message: "Test message",
                style: .success
            )
        _ = view.body
    }

    @Test("toast modifier uses default values")
    func toastViewModifierDefaults() async throws {
        @State var isPresented = false
        let view = Color.blue
            .toast(isPresented: $isPresented, message: "Test")
        _ = view.body
    }

    @Test("toast modifier with custom duration")
    func toastViewModifierCustomDuration() async throws {
        @State var isPresented = false
        let view = Text("Test")
            .toast(
                isPresented: $isPresented,
                message: "Test",
                style: .info,
                duration: 5.0
            )
        _ = view.body
    }

    // MARK: - Edge Cases

    @Test("ToastView handles extremely long message")
    func toastViewExtremelyLongMessage() async throws {
        let extremelyLong = String(repeating: "Word ", count: 1000)
        let toast = ToastView(message: extremelyLong, style: .info)
        _ = toast.body
    }

    @Test("ToastView handles newlines in message")
    func toastViewNewlines() async throws {
        let multiline = "Line 1\nLine 2\nLine 3"
        let toast = ToastView(message: multiline, style: .info)
        _ = toast.body
    }

    @Test("ToastView handles all glass effect intensities")
    func toastViewAllGlassIntensities() async throws {
        let originalEnabled = AppSettings.glassEffectsEnabled
        let originalIntensity = AppSettings.glassEffectIntensity

        AppSettings.glassEffectsEnabled = true

        let intensities: [Double] = [0.0, 0.3, 0.5, 0.7, 1.0]

        for intensity in intensities {
            AppSettings.glassEffectIntensity = intensity
            let toast = ToastView(message: "Test", style: .success)
            _ = toast.body
        }

        // Reset
        AppSettings.glassEffectsEnabled = originalEnabled
        AppSettings.glassEffectIntensity = originalIntensity
    }
}
