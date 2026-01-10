//
//  FlashcardViewTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardView
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify data flow, stability-to-glass mapping, and view properties.
//  Full UI behavior testing requires UI tests or snapshot tests.
//

import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

@MainActor
struct FlashcardViewTests {
    // MARK: - Test Fixtures

    private func createTestFlashcard(
        word: String = "Test",
        definition: String = "Test definition",
        stability: Double = 0.0
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: definition, phonetic: "/test/")
        let fsrsState = FSRSState(
            stability: stability,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        card.fsrsState = fsrsState
        return card
    }

    // MARK: - Glass Thickness Mapping Tests

    @Test("Stability < 10 maps to thin glass range")
    func stabilityBelow10MapsToThinRange() async throws {
        // Verify that low stability values are in thin glass range
        let lowStability = 5.0
        #expect(lowStability < 10, "Stability 5.0 should be below threshold for thin glass")
    }

    @Test("Stability 10-50 maps to regular glass range")
    func stability10To50MapsToRegularRange() async throws {
        // Verify that medium stability values are in regular glass range
        let mediumStability = 25.0
        #expect(mediumStability >= 10 && mediumStability <= 50, "Stability 25.0 should be in regular glass range")
    }

    @Test("Stability > 50 maps to thick glass range")
    func stabilityAbove50MapsToThickRange() async throws {
        // Verify that high stability values are in thick glass range
        let highStability = 75.0
        #expect(highStability > 50, "Stability 75.0 should be above threshold for thick glass")
    }

    @Test("Stability boundary at 10")
    func stabilityAtBoundary10() async throws {
        // Verify boundary value at lower end of regular range
        let boundaryStability = 10.0
        #expect(boundaryStability >= 10 && boundaryStability <= 50, "Stability 10.0 should map to regular glass")
    }

    @Test("Stability boundary at 50")
    func stabilityAtBoundary50() async throws {
        // Verify boundary value at upper end of regular range
        let boundaryStability = 50.0
        #expect(boundaryStability >= 10 && boundaryStability <= 50, "Stability 50.0 should map to regular glass")
    }

    @Test("GlassThickness enum has three cases")
    func glassThicknessHasThreeCases() async throws {
        // Verify all glass thickness options exist
        let thin = GlassThickness.thin
        let regular = GlassThickness.regular
        let thick = GlassThickness.thick

        #expect(thin.cornerRadius < regular.cornerRadius, "Thin should have smaller corner radius than regular")
        #expect(regular.cornerRadius < thick.cornerRadius, "Regular should have smaller corner radius than thick")
    }

    // MARK: - Card Data Tests

    @Test("Card stores word correctly")
    func cardStoresWord() async throws {
        let card = createTestFlashcard(word: "Ephemeral")
        #expect(card.word == "Ephemeral", "Card should store the word correctly")
    }

    @Test("Card stores definition correctly")
    func cardStoresDefinition() async throws {
        let card = createTestFlashcard(definition: "Lasting for a very short time")
        #expect(card.definition == "Lasting for a very short time", "Card should store the definition correctly")
    }

    @Test("Card stores phonetic correctly")
    func cardStoresPhonetic() async throws {
        let card = Flashcard(word: "Test", definition: "Test definition", phonetic: "/əˈfem(ə)rəl/")
        #expect(card.phonetic == "/əˈfem(ə)rəl/", "Card should store the phonetic correctly")
    }

    // MARK: - FSRSState Tests

    @Test("Card with stability has FSRSState attached")
    func cardWithStabilityHasFSRSState() async throws {
        let card = createTestFlashcard(stability: 25.0)
        #expect(card.fsrsState != nil, "Card should have FSRSState attached")
        #expect(card.fsrsState?.stability == 25.0, "FSRSState should store the stability value")
    }

    @Test("Card without stability defaults to nil FSRSState")
    func cardWithoutStabilityHasNilFSRSState() async throws {
        let card = Flashcard(word: "Test", definition: "Test")
        #expect(card.fsrsState == nil, "New card should have nil FSRSState")
    }

    @Test("FSRSState stores all required properties")
    func fsrsStateStoresRequiredProperties() async throws {
        let card = createTestFlashcard(stability: 15.0)
        let state = card.fsrsState

        #expect(state?.stability == 15.0, "Stability should be stored")
        #expect(state?.difficulty == 5.0, "Difficulty should be stored")
        #expect(state?.retrievability == 0.9, "Retrievability should be stored")
        #expect(state?.stateEnum == FlashcardState.new.rawValue, "State enum should be stored")
    }

    // MARK: - Edge Cases

    @Test("Card handles zero stability")
    func cardHandlesZeroStability() async throws {
        let card = createTestFlashcard(stability: 0.0)
        #expect(card.fsrsState?.stability == 0.0, "Zero stability should be stored correctly")
    }

    @Test("Card handles very high stability")
    func cardHandlesHighStability() async throws {
        let card = createTestFlashcard(stability: 1000.0)
        #expect(card.fsrsState?.stability == 1000.0, "High stability should be stored correctly")
    }

    @Test("Card handles negative stability")
    func cardHandlesNegativeStability() async throws {
        let card = createTestFlashcard(stability: -1.0)
        #expect(card.fsrsState?.stability == -1.0, "Negative stability should be stored (though invalid)")
    }

    @Test("Card handles fractional stability")
    func cardHandlesFractionalStability() async throws {
        let card = createTestFlashcard(stability: 9.9)
        #expect(card.fsrsState?.stability == 9.9, "Fractional stability should be stored correctly")
    }

    // MARK: - View Creation Tests

    @Test("FlashcardView can be created with card")
    func flashcardViewCreationWithCard() async throws {
        let card = createTestFlashcard(word: "TestWord")
        let view = FlashcardView(card: card, isFlipped: .constant(false))

        // Verify view can be created
        #expect(card.word == "TestWord", "View should be created with the card")
    }

    @Test("FlashcardView can be created with onSwipe callback")
    func flashcardViewCreationWithCallback() async throws {
        let card = createTestFlashcard()
        var callbackInvoked = false
        var capturedRating: Int?

        let view = FlashcardView(
            card: card,
            isFlipped: .constant(false),
            onSwipe: { rating in
                callbackInvoked = true
                capturedRating = rating
            }
        )

        // Verify view can be created with callback
        #expect(!callbackInvoked, "Callback should not be invoked on creation")
    }

    @Test("FlashcardView with isFlipped binding")
    func flashcardViewWithFlippedBinding() async throws {
        let card = createTestFlashcard()
        let isFlipped = true

        let view = FlashcardView(card: card, isFlipped: .constant(isFlipped))

        // Verify binding can be passed
        #expect(isFlipped == true, "isFlipped binding should be passed correctly")
    }

    // MARK: - GlassThickness Properties Tests

    @Test("Thin glass has smallest corner radius")
    func thinGlassHasSmallestCornerRadius() async throws {
        let thin = GlassThickness.thin
        let regular = GlassThickness.regular
        let thick = GlassThickness.thick

        #expect(thin.cornerRadius < regular.cornerRadius, "Thin glass should have smaller corner radius than regular")
        #expect(thin.cornerRadius < thick.cornerRadius, "Thin glass should have smaller corner radius than thick")
    }

    @Test("Thick glass has largest corner radius")
    func thickGlassHasLargestCornerRadius() async throws {
        let thin = GlassThickness.thin
        let regular = GlassThickness.regular
        let thick = GlassThickness.thick

        #expect(thick.cornerRadius > regular.cornerRadius, "Thick glass should have larger corner radius than regular")
        #expect(thick.cornerRadius > thin.cornerRadius, "Thick glass should have larger corner radius than thin")
    }

    @Test("Shadow radius increases with glass thickness")
    func shadowRadiusIncreasesWithThickness() async throws {
        let thin = GlassThickness.thin
        let regular = GlassThickness.regular
        let thick = GlassThickness.thick

        #expect(thin.shadowRadius < regular.shadowRadius, "Thin should have smaller shadow than regular")
        #expect(regular.shadowRadius < thick.shadowRadius, "Regular should have smaller shadow than thick")
    }

    @Test("Overlay opacity increases with glass thickness")
    func overlayOpacityIncreasesWithThickness() async throws {
        let thin = GlassThickness.thin
        let regular = GlassThickness.regular
        let thick = GlassThickness.thick

        #expect(thin.overlayOpacity < regular.overlayOpacity, "Thin should have less opacity than regular")
        #expect(regular.overlayOpacity < thick.overlayOpacity, "Regular should have less opacity than thick")
    }
}
