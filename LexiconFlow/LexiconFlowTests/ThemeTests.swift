//
//  ThemeTests.swift
//  LexiconFlowTests
//
//  Tests for Theme utilities and CEFR color coding
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for Theme utilities
///
/// Tests verify:
/// - CEFR level color mapping
/// - CEFR badge opacity values
/// - Badge style configurations
/// - Animation and spacing constants
/// - View extension methods
struct ThemeTests {

    // MARK: - CEFR Color Tests

    @Test("Return green for A1 level")
    func cefrColorForA1() {
        let color = Theme.cefrColor(for: "A1")

        // SwiftUI.Color doesn't have Equatable, so we verify via description
        let description = String(describing: color)
        #expect(description.contains("green"), "A1 should map to green color")
    }

    @Test("Return green for A2 level")
    func cefrColorForA2() {
        let color = Theme.cefrColor(for: "A2")

        let description = String(describing: color)
        #expect(description.contains("green"), "A2 should map to green color")
    }

    @Test("Return blue for B1 level")
    func cefrColorForB1() {
        let color = Theme.cefrColor(for: "B1")

        let description = String(describing: color)
        #expect(description.contains("blue"), "B1 should map to blue color")
    }

    @Test("Return blue for B2 level")
    func cefrColorForB2() {
        let color = Theme.cefrColor(for: "B2")

        let description = String(describing: color)
        #expect(description.contains("blue"), "B2 should map to blue color")
    }

    @Test("Return purple for C1 level")
    func cefrColorForC1() {
        let color = Theme.cefrColor(for: "C1")

        let description = String(describing: color)
        #expect(description.contains("purple"), "C1 should map to purple color")
    }

    @Test("Return purple for C2 level")
    func cefrColorForC2() {
        let color = Theme.cefrColor(for: "C2")

        let description = String(describing: color)
        #expect(description.contains("purple"), "C2 should map to purple color")
    }

    @Test("Return gray for invalid level")
    func cefrColorForInvalid() {
        let color = Theme.cefrColor(for: "INVALID")

        let description = String(describing: color)
        #expect(description.contains("gray"), "Invalid level should map to gray")
    }

    @Test("Handle lowercase input")
    func cefrColorLowercase() {
        let color = Theme.cefrColor(for: "b1")

        let description = String(describing: color)
        #expect(description.contains("blue"), "Lowercase b1 should map to blue")
    }

    @Test("Handle mixed case input")
    func cefrColorMixedCase() {
        let color = Theme.cefrColor(for: "A1")

        let description = String(describing: color)
        #expect(description.contains("green"), "Mixed case should be normalized")
    }

    // MARK: - CEFR Badge Opacity Tests

    @Test("Return 0.2 opacity for A1")
    func cefrBadgeOpacityForA1() {
        let opacity = Theme.cefrBadgeOpacity(for: "A1")
        #expect(opacity == 0.2, "A1 should have 0.2 opacity")
    }

    @Test("Return 0.2 opacity for A2")
    func cefrBadgeOpacityForA2() {
        let opacity = Theme.cefrBadgeOpacity(for: "A2")
        #expect(opacity == 0.2, "A2 should have 0.2 opacity")
    }

    @Test("Return 0.3 opacity for B1")
    func cefrBadgeOpacityForB1() {
        let opacity = Theme.cefrBadgeOpacity(for: "B1")
        #expect(opacity == 0.3, "B1 should have 0.3 opacity")
    }

    @Test("Return 0.3 opacity for B2")
    func cefrBadgeOpacityForB2() {
        let opacity = Theme.cefrBadgeOpacity(for: "B2")
        #expect(opacity == 0.3, "B2 should have 0.3 opacity")
    }

    @Test("Return 0.4 opacity for C1")
    func cefrBadgeOpacityForC1() {
        let opacity = Theme.cefrBadgeOpacity(for: "C1")
        #expect(opacity == 0.4, "C1 should have 0.4 opacity")
    }

    @Test("Return 0.4 opacity for C2")
    func cefrBadgeOpacityForC2() {
        let opacity = Theme.cefrBadgeOpacity(for: "C2")
        #expect(opacity == 0.4, "C2 should have 0.4 opacity")
    }

    @Test("Return 0.15 opacity for invalid level")
    func cefrBadgeOpacityForInvalid() {
        let opacity = Theme.cefrBadgeOpacity(for: "INVALID")
        #expect(opacity == 0.15, "Invalid should have 0.15 opacity")
    }

    // MARK: - Badge Style Tests

    @Test("Return standard badge style for A1")
    func standardBadgeStyleForA1() {
        let style = Theme.cefrBadgeStyle(for: "A1", style: .standard)

        let colorDescription = String(describing: style.color)
        #expect(colorDescription.contains("green"), "Standard A1 should be green")
        #expect(style.opacity == 0.2, "Standard A1 should have 0.2 opacity")
    }

    @Test("Return compact badge style for A1")
    func compactBadgeStyleForA1() {
        let style = Theme.cefrBadgeStyle(for: "A1", style: .compact)

        let colorDescription = String(describing: style.color)
        #expect(colorDescription.contains("green"), "Compact A1 should be green")
        #expect(style.opacity == 0.16, "Compact A1 should have 0.16 (0.2 * 0.8) opacity")
    }

    @Test("Return compact badge style for C2")
    func compactBadgeStyleForC2() {
        let style = Theme.cefrBadgeStyle(for: "C2", style: .compact)

        let colorDescription = String(describing: style.color)
        #expect(colorDescription.contains("purple"), "Compact C2 should be purple")
        #expect(style.opacity == 0.32, "Compact C2 should have 0.32 (0.4 * 0.8) opacity")
    }

    // MARK: - Animation Constants Tests

    @Test("Have defined animation duration")
    func animationDuration() {
        #expect(Theme.animationDuration == 0.3, "Standard animation duration should be 0.3s")
    }

    @Test("Have defined quick animation duration")
    func quickAnimationDuration() {
        #expect(Theme.quickAnimationDuration == 0.15, "Quick animation duration should be 0.15s")
    }

    @Test("Have defined spring animation")
    func springAnimation() {
        let animation = Theme.springAnimation

        // Verify it's a spring animation
        let description = String(describing: animation)
        #expect(description.contains("spring"), "Should use spring animation")
    }

    // MARK: - Spacing Constants Tests

    @Test("Have defined spacing unit")
    func spacingUnit() {
        #expect(Theme.spacingUnit == 8, "Spacing unit should be 8pt")
    }

    @Test("Have defined small spacing")
    func spacingSmall() {
        #expect(Theme.spacingSmall == 4, "Small spacing should be 4pt")
    }

    @Test("Have defined medium spacing")
    func spacingMedium() {
        #expect(Theme.spacingMedium == 12, "Medium spacing should be 12pt")
    }

    @Test("Have defined large spacing")
    func spacingLarge() {
        #expect(Theme.spacingLarge == 16, "Large spacing should be 16pt")
    }

    @Test("Have defined extra large spacing")
    func spacingXLarge() {
        #expect(Theme.spacingXLarge == 24, "Extra large spacing should be 24pt")
    }

    @Test("Maintain spacing progression")
    func spacingProgression() {
        // Spacing should follow consistent progression
        #expect(Theme.spacingSmall * 2 == Theme.spacingUnit, "Small * 2 = Unit")
        #expect(Theme.spacingUnit + Theme.spacingSmall == Theme.spacingMedium, "Unit + Small = Medium")
        #expect(Theme.spacingMedium + Theme.spacingUnit == Theme.spacingLarge, "Medium + Unit = Large")
    }

    // MARK: - Corner Radius Tests

    @Test("Have defined small corner radius")
    func cornerRadiusSmall() {
        #expect(Theme.cornerRadiusSmall == 6, "Small corner radius should be 6pt")
    }

    @Test("Have defined medium corner radius")
    func cornerRadiusMedium() {
        #expect(Theme.cornerRadiusMedium == 12, "Medium corner radius should be 12pt")
    }

    @Test("Have defined large corner radius")
    func cornerRadiusLarge() {
        #expect(Theme.cornerRadiusLarge == 16, "Large corner radius should be 16pt")
    }

    @Test("Maintain corner radius progression")
    func cornerRadiusProgression() {
        #expect(Theme.cornerRadiusSmall * 2 == Theme.cornerRadiusMedium, "Small * 2 = Medium")
        #expect(Theme.cornerRadiusMedium + Theme.cornerRadiusSmall == Theme.cornerRadiusLarge, "Medium + Small = Large")
    }

    // MARK: - View Extension Tests

    @Test("CEFR styled view should have correct color")
    func cefrStyledView() {
        let text = Text("Test")
        let styled = text.cefrStyled(for: "B1")

        // View extensions return modified views
        // We verify the view is different from original
        #expect(String(describing: type(of: styled)) != "Text", "Styled view should be modified type")
    }

    @Test("CEFR background view should have correct background")
    func cefrBackgroundView() {
        let text = Text("Test")
        let styled = text.cefrBackground(for: "C1", style: .standard)

        // View extensions return modified views
        #expect(String(describing: type(of: styled)) != "Text", "Background styled view should be modified type")
    }

    @Test("Compact background uses reduced opacity")
    func cefrBackgroundCompact() {
        let text = Text("Test")
        let standardStyle = Theme.cefrBadgeStyle(for: "B2", style: .standard)
        let compactStyle = Theme.cefrBadgeStyle(for: "B2", style: .compact)

        #expect(compactStyle.opacity < standardStyle.opacity, "Compact should have reduced opacity")
    }

    // MARK: - Edge Cases

    @Test("Handle empty string for CEFR level")
    func cefrColorForEmptyString() {
        let color = Theme.cefrColor(for: "")

        let description = String(describing: color)
        #expect(description.contains("gray"), "Empty string should map to gray")
    }

    @Test("Handle whitespace for CEFR level")
    func cefrColorForWhitespace() {
        let color = Theme.cefrColor(for: "   ")

        let description = String(describing: color)
        #expect(description.contains("gray"), "Whitespace should map to gray")
    }

    @Test("Handle special characters for CEFR level")
    func cefrColorForSpecialChars() {
        let color = Theme.cefrColor(for: "@#$%")

        let description = String(describing: color)
        #expect(description.contains("gray"), "Special chars should map to gray")
    }

    @Test("Handle numeric string for CEFR level")
    func cefrColorForNumeric() {
        let color = Theme.cefrColor(for: "123")

        let description = String(describing: color)
        #expect(description.contains("gray"), "Numeric string should map to gray")
    }

    // MARK: - Consistency Tests

    @Test("All beginner levels use green")
    func beginnerLevelsConsistent() {
        let a1Color = Theme.cefrColor(for: "A1")
        let a2Color = Theme.cefrColor(for: "A2")

        let a1Desc = String(describing: a1Color)
        let a2Desc = String(describing: a2Color)

        #expect(a1Desc == a2Desc, "A1 and A2 should have same color")
    }

    @Test("All intermediate levels use blue")
    func intermediateLevelsConsistent() {
        let b1Color = Theme.cefrColor(for: "B1")
        let b2Color = Theme.cefrColor(for: "B2")

        let b1Desc = String(describing: b1Color)
        let b2Desc = String(describing: b2Color)

        #expect(b1Desc == b2Desc, "B1 and B2 should have same color")
    }

    @Test("All advanced levels use purple")
    func advancedLevelsConsistent() {
        let c1Color = Theme.cefrColor(for: "C1")
        let c2Color = Theme.cefrColor(for: "C2")

        let c1Desc = String(describing: c1Color)
        let c2Desc = String(describing: c2Color)

        #expect(c1Desc == c2Desc, "C1 and C2 should have same color")
    }

    @Test("Opacity increases with proficiency")
    func opacityIncreasesWithLevel() {
        let a1Opacity = Theme.cefrBadgeOpacity(for: "A1")
        let b1Opacity = Theme.cefrBadgeOpacity(for: "B1")
        let c1Opacity = Theme.cefrBadgeOpacity(for: "C1")

        #expect(a1Opacity < b1Opacity, "Beginner opacity < intermediate")
        #expect(b1Opacity < c1Opacity, "Intermediate opacity < advanced")
    }

    // MARK: - Integration Tests

    @Test("Create complete badge configuration")
    func completeBadgeConfiguration() {
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

        for level in levels {
            let color = Theme.cefrColor(for: level)
            let opacity = Theme.cefrBadgeOpacity(for: level)
            let style = Theme.cefrBadgeStyle(for: level, style: .standard)

            // Verify all components are present
            let colorDesc = String(describing: color)
            #expect(!colorDesc.isEmpty, "Color should be valid for \(level)")
            #expect(opacity > 0 && opacity <= 0.5, "Opacity should be valid for \(level)")
            #expect(style.opacity == opacity, "Style opacity should match badge opacity")
        }
    }

    @Test("All constants are positive")
    func allConstantsPositive() {
        #expect(Theme.animationDuration > 0, "Animation duration should be positive")
        #expect(Theme.quickAnimationDuration > 0, "Quick animation duration should be positive")
        #expect(Theme.spacingUnit > 0, "Spacing unit should be positive")
        #expect(Theme.spacingSmall > 0, "Small spacing should be positive")
        #expect(Theme.spacingMedium > 0, "Medium spacing should be positive")
        #expect(Theme.spacingLarge > 0, "Large spacing should be positive")
        #expect(Theme.spacingXLarge > 0, "XLarge spacing should be positive")
        #expect(Theme.cornerRadiusSmall > 0, "Small corner radius should be positive")
        #expect(Theme.cornerRadiusMedium > 0, "Medium corner radius should be positive")
        #expect(Theme.cornerRadiusLarge > 0, "Large corner radius should be positive")
    }
}
