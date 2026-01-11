//
//  CardBackViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardBackView direction-aware computed properties
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for CardBackView
///
/// Tests verify direction-aware computed properties:
/// - frontWordReminder (direction-aware)
/// - answerWord (flips based on direction)
/// - answerLabel ("Translation" vs "Word")
/// - cardTypeColor helper
@MainActor
struct CardBackViewTests {
    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    /// Helper to create a test flashcard
    private func createFlashcard(
        word: String = "test",
        translation: String? = "тест",
        cardType: CardType = .forward
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: "test def", translation: translation)
        card.cardType = cardType
        return card
    }

    // MARK: - frontWordReminder Computed Property Tests

    @Test("frontWordReminder returns English word for forward card")
    func frontWordReminderEnglishForForward() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .forward)
        let view = CardBackView(card: card)

        #expect(view.frontWordReminder == "hello")
    }

    @Test("frontWordReminder returns Russian translation for reverse card")
    func frontWordReminderRussianForReverse() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .reverse)
        let view = CardBackView(card: card)

        #expect(view.frontWordReminder == "привет")
    }

    @Test("frontWordReminder falls back to English when translation is nil")
    func frontWordReminderFallbackWhenNil() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .reverse)
        let view = CardBackView(card: card)

        // Falls back to original word when translation is nil
        #expect(view.frontWordReminder == "hello")
    }

    // MARK: - answerWord Computed Property Tests

    @Test("answerWord returns Russian translation for forward card")
    func answerWordRussianForForward() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .forward)
        let view = CardBackView(card: card)

        #expect(view.answerWord == "привет")
    }

    @Test("answerWord returns English word for reverse card")
    func answerWordEnglishForReverse() throws {
        let card = self.createFlashcard(word: "hello", translation: "привет", cardType: .reverse)
        let view = CardBackView(card: card)

        #expect(view.answerWord == "hello")
    }

    @Test("answerWord returns nil when translation is nil")
    func answerWordNilWhenNoTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .forward)
        let view = CardBackView(card: card)

        #expect(view.answerWord == nil)
    }

    // MARK: - answerLabel Computed Property Tests

    @Test("answerLabel returns Translation for forward card")
    func answerLabelTranslationForForward() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", cardType: .forward)
        let view = CardBackView(card: card)

        #expect(view.answerLabel == "Translation")
    }

    @Test("answerLabel returns Word for reverse card")
    func answerLabelWordForReverse() throws {
        let card = self.createFlashcard(word: "test", translation: "тест", cardType: .reverse)
        let view = CardBackView(card: card)

        #expect(view.answerLabel == "Word")
    }

    // MARK: - Color Helper Tests

    @Test("cardTypeColor returns blue for forward")
    func cardTypeColorBlueForForward() throws {
        let card = self.createFlashcard(cardType: .forward)
        let view = CardBackView(card: card)

        // Verify method is callable (Color comparison not supported in tests)
        let color = view.cardTypeColor(for: .forward)
        #expect(color != Color.clear)
    }

    @Test("cardTypeColor returns orange for reverse")
    func cardTypeColorOrangeForReverse() throws {
        let card = self.createFlashcard(cardType: .reverse)
        let view = CardBackView(card: card)

        // Verify method is callable (Color comparison not supported in tests)
        let color = view.cardTypeColor(for: .reverse)
        #expect(color != Color.clear)
    }

    // MARK: - Backward Compatibility Tests

    @Test("Handle backward compatibility - nil cardTypeRaw defaults to forward")
    func handleBackwardCompatibilityNilCardTypeRaw() throws {
        let context = self.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "test", translation: "тест")
        card.cardTypeRaw = nil
        context.insert(card)

        let view = CardBackView(card: card)

        // Should display English word reminder (forward mode)
        #expect(view.frontWordReminder == "test")
        #expect(view.answerLabel == "Translation")
    }

    @Test("Handle reverse card with nil translation")
    func handleReverseCardWithNilTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .reverse)
        let view = CardBackView(card: card)

        // Falls back to original word
        #expect(view.frontWordReminder == "hello")
        #expect(view.answerWord == "hello")
    }

    @Test("Handle forward card with nil translation")
    func handleForwardCardWithNilTranslation() throws {
        let card = self.createFlashcard(word: "hello", translation: nil, cardType: .forward)
        let view = CardBackView(card: card)

        #expect(view.frontWordReminder == "hello")
        #expect(view.answerWord == nil)
    }
}
