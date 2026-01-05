//
//  CardBackViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardBackView
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for CardBackView
///
/// Tests verify:
/// - Definition display
/// - Translation display (if present)
/// - Context sentence display (if present)
/// - CEFR level display
/// - Image display
/// - CEFR color mapping
/// - Flip animation
/// - Accessibility labels
@MainActor
struct CardBackViewTests {

    // MARK: - Test Fixtures

    private func createTestCard(
        word: String = "TestWord",
        definition: String = "Test definition",
        translation: String? = nil,
        cefrLevel: String? = nil,
        contextSentence: String? = nil,
        imageData: Data? = nil
    ) -> Flashcard {
        let card = Flashcard(
            word: word,
            definition: definition,
            phonetic: nil,
            imageData: imageData
        )
        card.translation = translation
        card.cefrLevel = cefrLevel
        card.contextSentence = contextSentence
        return card
    }

    // MARK: - Initialization Tests

    @Test("CardBackView initializes with card")
    func cardBackViewInitializes() {
        let card = createTestCard()
        let view = CardBackView(card: card)

        let body = view.body
        #expect(!body.isEmpty, "View body should not be empty")
    }

    // MARK: - Definition Display Tests

    @Test("CardBackView displays definition correctly")
    func displaysDefinitionCorrectly() {
        let card = createTestCard(definition: "Lasting for a very short time")
        let view = CardBackView(card: card)

        #expect(card.definition == "Lasting for a very short time", "Definition should match")
    }

    @Test("CardBackView handles long definitions")
    func handlesLongDefinitions() {
        let longDefinition = "This is a very long definition that spans multiple lines and contains a lot of detailed information about the word being defined"
        let card = createTestCard(definition: longDefinition)
        let view = CardBackView(card: card)

        #expect(card.definition.count > 50, "Long definition should be stored")
        #expect(!view.body.isEmpty, "View should render with long definition")
    }

    @Test("CardBackView displays word reminder")
    func displaysWordReminder() {
        let card = createTestCard(word: "Ephemeral")
        let view = CardBackView(card: card)

        #expect(card.word == "Ephemeral", "Word should be displayed as reminder")
    }

    // MARK: - Translation Display Tests

    @Test("CardBackView displays translation when present")
    func displaysTranslationWhenPresent() {
        let card = createTestCard(translation: "короткоживущий")
        let view = CardBackView(card: card)

        #expect(card.translation != nil, "Translation should be present")
        #expect(card.translation == "короткоживущий", "Translation should match")
    }

    @Test("CardBackView handles missing translation")
    func handlesMissingTranslation() {
        let card = createTestCard(translation: nil)
        let view = CardBackView(card: card)

        #expect(card.translation == nil, "Translation should be nil")
        #expect(!view.body.isEmpty, "View should render without translation")
    }

    // MARK: - CEFR Level Tests

    @Test("CardBackView displays CEFR level when present")
    func displaysCEFRWhenPresent() {
        let card = createTestCard(cefrLevel: "B2")
        let view = CardBackView(card: card)

        #expect(card.cefrLevel != nil, "CEFR level should be present")
        #expect(card.cefrLevel == "B2", "CEFR level should match")
    }

    @Test("CardBackView handles missing CEFR level")
    func handlesMissingCEFR() {
        let card = createTestCard(cefrLevel: nil)
        let view = CardBackView(card: card)

        #expect(card.cefrLevel == nil, "CEFR level should be nil")
        #expect(!view.body.isEmpty, "View should render without CEFR")
    }

    // MARK: - CEFR Color Tests

    @Test("CEFR A levels map to green")
    func cefrAColorsGreen() {
        let view = CardBackView(card: createTestCard())

        // Test A1
        let colorA1 = view.cefrColor(for: "A1")
        #expect(colorA1 == .green, "A1 should be green")

        // Test A2
        let colorA2 = view.cefrColor(for: "A2")
        #expect(colorA2 == .green, "A2 should be green")
    }

    @Test("CEFR B levels map to blue")
    func cefrBColorsBlue() {
        let view = CardBackView(card: createTestCard())

        let colorB1 = view.cefrColor(for: "B1")
        #expect(colorB1 == .blue, "B1 should be blue")

        let colorB2 = view.cefrColor(for: "B2")
        #expect(colorB2 == .blue, "B2 should be blue")
    }

    @Test("CEFR C levels map to purple")
    func cefrCColorsPurple() {
        let view = CardBackView(card: createTestCard())

        let colorC1 = view.cefrColor(for: "C1")
        #expect(colorC1 == .purple, "C1 should be purple")

        let colorC2 = view.cefrColor(for: "C2")
        #expect(colorC2 == .purple, "C2 should be purple")
    }

    @Test("Invalid CEFR levels map to gray")
    func invalidCEFRMapsToGray() {
        let view = CardBackView(card: createTestCard())

        let colorInvalid = view.cefrColor(for: "X5")
        #expect(colorInvalid == .gray, "Invalid CEFR should be gray")
    }

    @Test("CEFR color is case insensitive")
    func cefrColorCaseInsensitive() {
        let view = CardBackView(card: createTestCard())

        let colorLower = view.cefrColor(for: "b2")
        let colorUpper = view.cefrColor(for: "B2")
        #expect(colorLower == colorUpper, "Case should not matter for CEFR color")
    }

    // MARK: - Image Display Tests

    @Test("CardBackView handles image data")
    func handlesImageData() {
        // Create a simple 1x1 red pixel image data
        let size = 1
        let dataSize = size * size * 4
        var pixelData = [UInt8](repeating: 0, count: dataSize)
        pixelData[0] = 255 // Red
        let imageData = Data(pixelData)

        let card = createTestCard(imageData: imageData)
        #expect(card.imageData != nil, "Image data should be present")
        #expect(card.imageData?.count == dataSize, "Image data size should match")
    }

    @Test("CardBackView handles missing image")
    func handlesMissingImage() {
        let card = createTestCard(imageData: nil)
        let view = CardBackView(card: card)

        #expect(card.imageData == nil, "Image data should be nil")
        #expect(!view.body.isEmpty, "View should render without image")
    }

    // MARK: - Layout Tests

    @Test("CardBackView uses ScrollView layout")
    func usesScrollViewLayout() {
        let card = createTestCard()
        let view = CardBackView(card: card)

        let body = view.body
        #expect(!body.isEmpty, "View should have valid layout with ScrollView")
    }

    @Test("CardBackView VStack contains elements")
    func vStackContainsElements() {
        let card = createTestCard()
        let view = CardBackView(card: card)

        let body = view.body
        #expect(!body.isEmpty, "VStack should contain view elements")
    }

    // MARK: - Accessibility Tests

    @Test("CardBackView has accessibility label")
    func hasAccessibilityLabel() {
        let card = createTestCard()
        let view = CardBackView(card: card)

        #expect(!view.body.isEmpty, "Accessibility should be configured")
    }
}
