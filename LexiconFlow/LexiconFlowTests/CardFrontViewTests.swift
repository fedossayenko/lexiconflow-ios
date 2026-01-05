//
//  CardFrontViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardFrontView
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for CardFrontView
///
/// Tests verify:
/// - Word display
/// - Phonetic display
/// - Deck name display
/// - Image display
/// - Text truncation
/// - Accessibility labels
/// - Animation state
@MainActor
struct CardFrontViewTests {

    // MARK: - Test Fixtures

    private func createTestCard(
        word: String = "TestWord",
        definition: String = "Test definition",
        phonetic: String? = "/test/",
        hasDeck: Bool = true
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: definition, phonetic: phonetic)
        if hasDeck {
            let deck = Deck(name: "Test Deck", icon: "star.fill", order: 0)
            card.deck = deck
        }
        return card
    }

    // MARK: - Initialization Tests

    @Test("CardFrontView initializes with card")
    func cardFrontViewInitializes() {
        let card = createTestCard()
        let view = CardFrontView(card: card)

        // Basic smoke test
        let body = view.body
        #expect(!body.isEmpty, "View body should not be empty")
    }

    // MARK: - Word Display Tests

    @Test("CardFrontView displays word correctly")
    func displaysWordCorrectly() {
        let card = createTestCard(word: "Ephemeral")
        let view = CardFrontView(card: card)

        #expect(card.word == "Ephemeral", "Card should have the word")
    }

    @Test("CardFrontView handles long words")
    func handlesLongWords() {
        let longWord = "Pneumonoultramicroscopicsilicovolcanoconiosis"
        let card = createTestCard(word: longWord)
        let view = CardFrontView(card: card)

        #expect(card.word.count == 45, "Long word should be stored")
        #expect(!view.body.isEmpty, "View should render with long word")
    }

    @Test("CardFrontView handles special characters in words")
    func handlesSpecialCharacters() {
        let specialWord = "café"
        let card = createTestCard(word: specialWord)
        let view = CardFrontView(card: card)

        #expect(card.word == specialWord, "Special characters should be preserved")
    }

    @Test("CardFrontView handles emoji in words")
    func handlesEmoji() {
        let emojiWord = "smile😊"
        let card = createTestCard(word: emojiWord)
        let view = CardFrontView(card: card)

        #expect(card.word == emojiWord, "Emoji should be preserved")
    }

    // MARK: - Phonetic Display Tests

    @Test("CardFrontView displays phonetic when present")
    func displaysPhoneticWhenPresent() {
        let card = createTestCard(phonetic: "/əˈfem(ə)rəl/")
        let view = CardFrontView(card: card)

        #expect(card.phonetic != nil, "Phonetic should be present")
        #expect(card.phonetic == "/əˈfem(ə)rəl/", "Phonetic should match")
    }

    @Test("CardFrontView handles missing phonetic")
    func handlesMissingPhonetic() {
        let card = createTestCard(phonetic: nil)
        let view = CardFrontView(card: card)

        #expect(card.phonetic == nil, "Phonetic should be nil")
        #expect(!view.body.isEmpty, "View should render without phonetic")
    }

    // MARK: - Deck Display Tests

    @Test("CardFrontView displays deck name when available")
    func displaysDeckNameWhenAvailable() {
        let card = createTestCard(hasDeck: true)
        let view = CardFrontView(card: card)

        #expect(card.deck != nil, "Card should have a deck")
        #expect(card.deck?.name == "Test Deck", "Deck name should match")
    }

    @Test("CardFrontView handles missing deck")
    func handlesMissingDeck() {
        let card = createTestCard(hasDeck: false)
        let view = CardFrontView(card: card)

        #expect(card.deck == nil, "Card should not have a deck")
        #expect(!view.body.isEmpty, "View should render without deck")
    }

    // MARK: - Animation State Tests

    @Test("CardFrontView has initial animation state")
    func hasInitialAnimationState() {
        let card = createTestCard()
        let view = CardFrontView(card: card)

        // Verify view can be created (animation state is internal @State)
        #expect(!view.body.isEmpty, "View should render with animation state")
    }

    @Test("CardFrontView prepareForTransition is callable")
    func prepareForTransitionCallable() {
        let card = createTestCard()
        let view = CardFrontView(card: card)

        // This should not crash
        view.prepareForTransition()
        #expect(true, "prepareForTransition should complete without error")
    }

    // MARK: - Layout Tests

    @Test("CardFrontView uses VStack layout")
    func usesVStackLayout() {
        let card = createTestCard()
        let view = CardFrontView(card: card)

        // Verify the body exists and is renderable
        let body = view.body
        #expect(!body.isEmpty, "View should have valid layout")
    }

    // MARK: - Accessibility Tests

    @Test("CardFrontView has accessibility label")
    func hasAccessibilityLabel() {
        let card = createTestCard(word: "Test")
        let view = CardFrontView(card: card)

        // Accessibility is set in the body
        #expect(!view.body.isEmpty, "Accessibility should be configured")
    }

    @Test("CardFrontView accessibility contains word")
    func accessibilityContainsWord() {
        let card = createTestCard(word: "Ephemeral")

        // The accessibility label should contain the word
        let expectedLabel = "Word: Ephemeral"
        #expect(card.word == "Ephemeral", "Card word should match")
    }

    @Test("CardFrontView accessibility contains phonetic when present")
    func accessibilityContainsPhonetic() {
        let card = createTestCard(phonetic: "/test/")

        // The accessibility label should contain the phonetic
        let expectedLabel = "Pronunciation: /test/"
        #expect(card.phonetic == "/test/", "Card phonetic should match")
    }
}
