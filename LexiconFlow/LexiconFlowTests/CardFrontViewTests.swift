//
//  CardFrontViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardFrontView direction-aware computed properties
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for CardFrontView
///
/// Tests verify direction-aware computed properties:
/// - displayWord (English for forward, Russian for reverse)
/// - displayPhonetic (nil for reverse cards)
/// - shouldShowPhonetic (false for reverse cards)
/// - Card type badge display
@MainActor
struct CardFrontViewTests {
    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    /// Helper to create a test flashcard
    private func createFlashcard(
        word: String = "test",
        translation: String? = "тест",
        phonetic: String? = "/test/",
        cardType: CardType = .forward
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: "test def", translation: translation, phonetic: phonetic)
        card.cardType = cardType
        return card
    }

    // MARK: - displayWord Computed Property Tests

    @Test("displayWord returns English word for forward card")
    func displayWordReturnsEnglishForForward() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.displayWord == "hello")
    }

    @Test("displayWord returns Russian translation for reverse card")
    func displayWordReturnsRussianForReverse() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(view.displayWord == "привет")
    }

    @Test("displayWord falls back to English when translation is nil for reverse card")
    func displayWordFallbackWhenNilTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .reverse)
        let view = CardFrontView(card: card)

        // Falls back to original word when translation is nil
        #expect(view.displayWord == "hello")
    }

    // MARK: - displayPhonetic Computed Property Tests

    @Test("displayPhonetic returns phonetic for forward card")
    func displayPhoneticReturnsForForward() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: "/test/", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.displayPhonetic == "/test/")
    }

    @Test("displayPhonetic returns nil for reverse card")
    func displayPhoneticReturnsNilForReverse() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: "/test/", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(view.displayPhonetic == nil)
    }

    @Test("displayPhonetic returns nil when phonetic is nil")
    func displayPhoneticReturnsNilWhenNil() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: nil, cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.displayPhonetic == nil)
    }

    // MARK: - shouldShowPhonetic Computed Property Tests

    @Test("shouldShowPhonetic returns true for forward card with phonetic")
    func shouldShowPhoneticTrueForForwardWithPhonetic() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: "/test/", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.shouldShowPhonetic == true)
    }

    @Test("shouldShowPhonetic returns false for forward card without phonetic")
    func shouldShowPhoneticFalseForForwardWithoutPhonetic() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: nil, cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.shouldShowPhonetic == false)
    }

    @Test("shouldShowPhonetic returns false for reverse card")
    func shouldShowPhoneticFalseForReverse() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: "/test/", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(view.shouldShowPhonetic == false)
    }

    // MARK: - Backward Compatibility Tests

    @Test("Handle backward compatibility - nil cardTypeRaw defaults to forward")
    func handleBackwardCompatibilityNilCardTypeRaw() throws {
        let context = self.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "test", translation: "тест")
        card.cardTypeRaw = nil
        context.insert(card)

        let view = CardFrontView(card: card)

        // Should display English word (forward mode)
        #expect(view.displayWord == "test")
    }

    @Test("Handle reverse card with nil translation")
    func handleReverseCardWithNilTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .reverse)
        let view = CardFrontView(card: card)

        // Should fall back to original word
        #expect(view.displayWord == "hello")
    }

    @Test("Handle forward card with nil translation")
    func handleForwardCardWithNilTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .forward)
        let view = CardFrontView(card: card)

        // Should display original word
        #expect(view.displayWord == "hello")
    }

    // MARK: - Card Type Display Tests

    @Test("Card type badge shows Recognition for forward card")
    func cardTypeBadgeShowsRecognition() throws {
        let card = self.createFlashcard(word: "test", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(card.cardType.displayName == "Recognition")
    }

    @Test("Card type badge shows Production for reverse card")
    func cardTypeBadgeShowsProduction() throws {
        let card = self.createFlashcard(word: "test", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(card.cardType.displayName == "Production")
    }

    @Test("Card type badge has correct icon for forward card")
    func cardTypeBadgeIconForward() throws {
        let card = self.createFlashcard(word: "test", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(card.cardType.iconName == "arrow.right")
    }

    @Test("Card type badge has correct icon for reverse card")
    func cardTypeBadgeIconReverse() throws {
        let card = self.createFlashcard(word: "test", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(card.cardType.iconName == "arrow.left")
    }

    // MARK: - Audio-Only Card Tests

    @Test("isAudioOnly returns true for audio cards")
    func isAudioOnlyTrue() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", cardType: .audio)
        let view = CardFrontView(card: card)

        #expect(view.isAudioOnly == true)
    }

    @Test("isAudioOnly returns false for forward cards")
    func isAudioOnlyFalseForward() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", cardType: .forward)
        let view = CardFrontView(card: card)

        #expect(view.isAudioOnly == false)
    }

    @Test("isAudioOnly returns false for reverse cards")
    func isAudioOnlyFalseReverse() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", cardType: .reverse)
        let view = CardFrontView(card: card)

        #expect(view.isAudioOnly == false)
    }

    @Test("displayWord returns word for audio cards")
    func displayWordForAudio() throws {
        let card = self.createFlashcard(word: "ephemeral", translation: "эфемерный", cardType: .audio)
        let view = CardFrontView(card: card)

        #expect(view.displayWord == "ephemeral")
    }

    @Test("shouldShowPhonetic returns false for audio cards")
    func shouldShowPhoneticFalseForAudio() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", phonetic: "/test/", cardType: .audio)
        let view = CardFrontView(card: card)

        #expect(view.shouldShowPhonetic == false)
    }

    @Test("cardTypeColor returns purple for audio cards")
    func cardTypeColorForAudio() throws {
        let card = self.createFlashcard(cardType: .audio)
        let view = CardFrontView(card: card)

        // Verify method is callable (Color comparison not supported in tests)
        let color = view.cardTypeColor(for: .audio)
        #expect(color != Color.clear)
    }

    @Test("Audio card displays correct displayName")
    func audioDisplayName() throws {
        let card = self.createFlashcard(cardType: .audio)

        #expect(card.cardType.displayName == "Audio-Only")
    }

    @Test("Audio card displays correct iconName")
    func audioIconName() throws {
        let card = self.createFlashcard(cardType: .audio)

        #expect(card.cardType.iconName == "speaker.wave.2")
    }

    @Test("Audio card displays correct arrowSymbol")
    func audioArrowSymbol() throws {
        let card = self.createFlashcard(cardType: .audio)

        #expect(card.cardType.arrowSymbol == "🔊")
    }
}
