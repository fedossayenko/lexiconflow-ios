//
//  ReverseCardServiceTests.swift
//  LexiconFlowTests
//
//  Tests for reverse card generation service
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for ReverseCardService
///
/// Tests verify:
/// - Reverse card generation from forward cards
/// - Duplicate detection and prevention
/// - Error handling for cards without translations
/// - Card type assignment
/// - Deck and FSRS state preservation
@Suite(.serialized)
@MainActor
struct ReverseCardServiceTests {
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Basic Generation Tests

    @Test("Generate reverse card for flashcard with translation")
    func generateReverseCardWithTranslation() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create a forward card with translation
        let forwardCard = Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            translation: "Мимолетный"
        )
        forwardCard.cardTypeRaw = CardType.forward.rawValue
        context.insert(forwardCard)
        try context.save()

        // Generate reverse card
        let count = try ReverseCardService.shared.generateReverseCards(
            for: [forwardCard],
            context: context
        )

        // Verify one reverse card was created
        #expect(count == 1)

        // Verify reverse card exists with correct properties
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { card in
            card.cardTypeRaw == reverseTypeValue
        }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 1)
        let reverseCard = reverseCards.first

        // Verify reverse card properties
        #expect(reverseCard?.word == "Ephemeral")
        #expect(reverseCard?.definition == "Lasting for a very short time")
        #expect(reverseCard?.translation == "Мимолетный")
        #expect(reverseCard?.cardType == .reverse)
    }

    @Test("Skip cards without translation")
    func skipCardsWithoutTranslation() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create card without translation
        let card = Flashcard(
            word: "Word",
            definition: "Definition",
            translation: nil
        )
        context.insert(card)
        try context.save()

        // Generate reverse cards
        let count = try ReverseCardService.shared.generateReverseCards(
            for: [card],
            context: context
        )

        // Verify no reverse cards were created
        #expect(count == 0)

        // Verify no reverse cards exist in database
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { $0.cardTypeRaw == reverseTypeValue }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.isEmpty)
    }

    // MARK: - Duplicate Detection Tests

    @Test("Detect existing reverse card")
    func detectExistingReverseCard() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create forward and reverse cards
        let forwardCard = Flashcard(
            word: "Test",
            definition: "Definition",
            translation: "Тест"
        )
        forwardCard.cardTypeRaw = CardType.forward.rawValue
        context.insert(forwardCard)

        let reverseCard = Flashcard(
            word: "Test",
            definition: "Definition",
            translation: "Тест"
        )
        reverseCard.cardTypeRaw = CardType.reverse.rawValue
        context.insert(reverseCard)

        try context.save()

        // Check if reverse card exists
        let hasReverse = try ReverseCardService.shared.hasReverseCard(
            for: forwardCard,
            context: context
        )

        #expect(hasReverse == true)
    }

    @Test("Prevent duplicate reverse cards")
    func preventDuplicateReverseCards() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create forward card
        let forwardCard = Flashcard(
            word: "Unique",
            definition: "Definition",
            translation: "Уникальный"
        )
        forwardCard.cardTypeRaw = CardType.forward.rawValue
        context.insert(forwardCard)
        try context.save()

        // Generate reverse cards twice
        let count1 = try ReverseCardService.shared.generateReverseCards(
            for: [forwardCard],
            context: context
        )

        let count2 = try ReverseCardService.shared.generateReverseCards(
            for: [forwardCard],
            context: context
        )

        // Verify only one reverse card was created total
        #expect(count1 == 1)
        #expect(count2 == 0) // Second call should detect existing reverse card

        // Verify only one reverse card exists in database
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { $0.cardTypeRaw == reverseTypeValue }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 1)
    }

    // MARK: - Batch Generation Tests

    @Test("Generate reverse cards for multiple flashcards")
    func generateMultipleReverseCards() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create multiple forward cards
        let cards = [
            Flashcard(word: "First", definition: "Def 1", translation: "Первый"),
            Flashcard(word: "Second", definition: "Def 2", translation: "Второй"),
            Flashcard(word: "Third", definition: "Def 3", translation: "Третий")
        ]

        for card in cards {
            card.cardTypeRaw = CardType.forward.rawValue
            context.insert(card)
        }
        try context.save()

        // Generate reverse cards
        let count = try ReverseCardService.shared.generateReverseCards(
            for: cards,
            context: context
        )

        // Verify all three reverse cards were created
        #expect(count == 3)

        // Verify reverse cards have correct types
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { $0.cardTypeRaw == reverseTypeValue }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 3)
    }

    @Test("Filter out cards without translation in batch")
    func filterCardsWithoutTranslationInBatch() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create mixed cards (some with translation, some without)
        let cards = [
            Flashcard(word: "WithTranslation", definition: "Def", translation: "С переводом"),
            Flashcard(word: "WithoutTranslation", definition: "Def", translation: nil),
            Flashcard(word: "AnotherWith", definition: "Def", translation: "Еще один")
        ]

        for card in cards {
            card.cardTypeRaw = CardType.forward.rawValue
            context.insert(card)
        }
        try context.save()

        // Generate reverse cards
        let count = try ReverseCardService.shared.generateReverseCards(
            for: cards,
            context: context
        )

        // Verify only two reverse cards were created (cards with translations)
        #expect(count == 2)

        // Verify reverse cards
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { $0.cardTypeRaw == reverseTypeValue }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 2)
    }

    // MARK: - Card Properties Tests

    @Test("Preserve CEFR level in reverse card")
    func preserveCEFRLevel() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create forward card with CEFR level
        let forwardCard = Flashcard(
            word: "Test",
            definition: "Definition",
            translation: "Тест"
        )
        forwardCard.cardTypeRaw = CardType.forward.rawValue
        forwardCard.cefrLevel = "B2"
        context.insert(forwardCard)
        try context.save()

        // Generate reverse card
        _ = try ReverseCardService.shared.generateReverseCards(
            for: [forwardCard],
            context: context
        )

        // Verify reverse card has same CEFR level
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { card in
            card.cardTypeRaw == reverseTypeValue && card.cefrLevel == "B2"
        }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 1)
    }

    @Test("Copy image data to reverse card")
    func copyImageDataToReverseCard() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create forward card with image
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let forwardCard = Flashcard(
            word: "Visual",
            definition: "Definition",
            translation: "Визуальный",
            imageData: imageData
        )
        forwardCard.cardTypeRaw = CardType.forward.rawValue
        context.insert(forwardCard)
        try context.save()

        // Generate reverse card
        _ = try ReverseCardService.shared.generateReverseCards(
            for: [forwardCard],
            context: context
        )

        // Verify reverse card has image data
        let reverseTypeValue = CardType.reverse.rawValue
        let predicate = #Predicate<Flashcard> { card in
            card.cardTypeRaw == reverseTypeValue
        }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let reverseCards = try context.fetch(descriptor)

        #expect(reverseCards.count == 1)
        #expect(reverseCards.first?.imageData == imageData)
    }

    // MARK: - Empty Input Tests

    @Test("Handle empty flashcard array")
    func handleEmptyArray() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Generate reverse cards from empty array
        let count = try ReverseCardService.shared.generateReverseCards(
            for: [],
            context: context
        )

        #expect(count == 0)
    }

    @Test("Handle array with only cards without translation")
    func handleArrayWithNoTranslations() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create cards without translations
        let cards = [
            Flashcard(word: "First", definition: "Def 1", translation: nil),
            Flashcard(word: "Second", definition: "Def 2", translation: nil)
        ]

        for card in cards {
            context.insert(card)
        }
        try context.save()

        // Generate reverse cards
        let count = try ReverseCardService.shared.generateReverseCards(
            for: cards,
            context: context
        )

        #expect(count == 0)
    }

    // MARK: - Error Handling Tests

    @Test("Handle nil translation gracefully")
    func handleNilTranslationGracefully() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create card with nil translation
        let card = Flashcard(
            word: "Test",
            definition: "Definition",
            translation: nil
        )
        context.insert(card)
        try context.save()

        // Should not throw, just skip
        let count = try ReverseCardService.shared.generateReverseCards(
            for: [card],
            context: context
        )

        #expect(count == 0)
    }
}
