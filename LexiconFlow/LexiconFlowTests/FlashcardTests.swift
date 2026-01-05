//
//  FlashcardTests.swift
//  LexiconFlowTests
//
//  Tests for Flashcard model
//  Covers: Flashcard creation, relationships, external storage, cascade delete
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for Flashcard model
@MainActor
struct FlashcardTests {

    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    // MARK: - Flashcard Creation Tests

    @Test("Flashcard creation with all fields")
    func flashcardCreationWithAllFields() throws {
        let context = freshContext()
        try context.clearAll()

        let imageData = Data("test image data".utf8)

        let flashcard = Flashcard(
            word: "ephemeral",
            definition: "lasting for a very short time",
            phonetic: "ɪˈfem(ə)rəl",
            translation: "efímero",
            translationSourceLanguage: "en",
            translationTargetLanguage: "es",
            cefrLevel: "C2",
            contextSentence: "The ephemeral beauty of cherry blossoms",
            imageData: imageData
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "ephemeral")
        #expect(flashcard.definition == "lasting for a very short time")
        #expect(flashcard.phonetic == "ɪˈfem(ə)rəl")
        #expect(flashcard.translation == "efímero")
        #expect(flashcard.translationSourceLanguage == "en")
        #expect(flashcard.translationTargetLanguage == "es")
        #expect(flashcard.cefrLevel == "C2")
        #expect(flashcard.contextSentence == "The ephemeral beauty of cherry blossoms")
        #expect(flashcard.imageData == imageData)
    }

    @Test("Flashcard creation with minimal fields")
    func flashcardCreationWithMinimalFields() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "test definition"
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "test")
        #expect(flashcard.definition == "test definition")
        #expect(flashcard.phonetic == nil)
        #expect(flashcard.translation == nil)
        #expect(flashcard.translationSourceLanguage == nil)
        #expect(flashcard.translationTargetLanguage == nil)
        #expect(flashcard.cefrLevel == nil)
        #expect(flashcard.contextSentence == nil)
        #expect(flashcard.imageData == nil)
    }

    @Test("Flashcard has unique UUID")
    func flashcardUniqueUUID() throws {
        let context = freshContext()
        try context.clearAll()

        let card1 = Flashcard(word: "test1", definition: "def1")
        let card2 = Flashcard(word: "test2", definition: "def2")

        context.insert(card1)
        context.insert(card2)
        try context.save()

        #expect(card1.id != card2.id)
        #expect(card1.id != UUID()) // Valid UUID
        #expect(card2.id != UUID()) // Valid UUID
    }

    @Test("Flashcard createdAt is set automatically")
    func flashcardCreatedAt() throws {
        let context = freshContext()
        try context.clearAll()

        let beforeCreation = Date()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)
        try context.save()

        let afterCreation = Date()

        #expect(flashcard.createdAt >= beforeCreation)
        #expect(flashcard.createdAt <= afterCreation)
    }

    // MARK: - External Storage Tests

    @Test("Flashcard image data with external storage")
    func flashcardImageExternalStorage() throws {
        let context = freshContext()
        try context.clearAll()

        // Create large image data to trigger external storage
        let largeImageData = Data(repeating: 0xFF, count: 1024 * 100) // 100KB

        let flashcard = Flashcard(
            word: "imageTest",
            definition: "test with image",
            imageData: largeImageData
        )

        context.insert(flashcard)
        try context.save()

        // Verify image data persisted
        let fetchedCards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(fetchedCards.count == 1)
        #expect(fetchedCards.first?.imageData == largeImageData)
    }

    @Test("Flashcard with no image data")
    func flashcardNoImageData() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "noImage",
            definition: "test without image"
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.imageData == nil)
    }

    // MARK: - Translation Fields Tests

    @Test("Flashcard translation fields are persisted")
    func flashcardTranslationFields() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "hello",
            definition: "greeting",
            translation: "hola",
            translationSourceLanguage: "en",
            translationTargetLanguage: "es",
            cefrLevel: "A1"
        )

        context.insert(flashcard)
        try context.save()

        // Fetch and verify
        let fetchedCards = try context.fetch(FetchDescriptor<Flashcard>())
        let fetched = fetchedCards.first

        #expect(fetched?.translation == "hola")
        #expect(fetched?.translationSourceLanguage == "en")
        #expect(fetched?.translationTargetLanguage == "es")
        #expect(fetched?.cefrLevel == "A1")
    }

    @Test("Flashcard with context sentence")
    func flashcardContextSentence() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "run",
            definition: "move at a speed faster than walking",
            contextSentence: "She runs every morning for exercise."
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.contextSentence?.contains("runs") == true)
    }

    // MARK: - Flashcard-Deck Relationship Tests

    @Test("Flashcard-deck relationship")
    func flashcardDeckRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let deck = Deck(name: "Spanish", icon: "🇪🇸")
        context.insert(deck)

        let flashcard = Flashcard(word: "hola", definition: "hello")
        flashcard.deck = deck
        context.insert(flashcard)

        try context.save()

        #expect(flashcard.deck?.name == "Spanish")
        #expect(flashcard.deck?.icon == "🇪🇸")
    }

    @Test("Flashcard with no deck")
    func flashcardNoDeck() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "orphan", definition: "no deck")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.deck == nil)
    }

    // MARK: - Flashcard-FSRSState Relationship Tests

    @Test("Flashcard-FSRSState relationship")
    func flashcardFSRSStateRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let state = FSRSState(
            stability: 1.5,
            difficulty: 6.0,
            retrievability: 0.85,
            dueDate: Date().addingTimeInterval(86400),
            stateEnum: FlashcardState.review.rawValue
        )
        flashcard.fsrsState = state
        context.insert(state)

        try context.save()

        #expect(flashcard.fsrsState?.stability == 1.5)
        #expect(flashcard.fsrsState?.difficulty == 6.0)
        #expect(flashcard.fsrsState?.retrievability == 0.85)
        #expect(flashcard.fsrsState?.state == .review)
    }

    @Test("Flashcard with no FSRSState")
    func flashcardNoFSRSState() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "new", definition: "new card")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.fsrsState == nil)
    }

    // MARK: - Flashcard-ReviewLogs Relationship Tests

    @Test("Flashcard-reviewLogs relationship")
    func flashcardReviewLogsRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review1)

        let review2 = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 3.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 5.5
        )
        context.insert(review2)

        try context.save()

        #expect(flashcard.reviewLogs.count == 2)
        #expect(flashcard.reviewLogs.first?.rating == 3)
        #expect(flashcard.reviewLogs.last?.rating == 2)
    }

    @Test("Flashcard with no review logs")
    func flashcardNoReviewLogs() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "new", definition: "new card")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.reviewLogs.isEmpty == true)
    }

    // MARK: - Cascade Delete Tests

    @Test("Cascade delete: deleting flashcard deletes FSRSState")
    func deleteFlashcardDeletesFSRSState() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state
        context.insert(state)

        try context.save()

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Verify FSRSState is also deleted
        let states = try context.fetch(FetchDescriptor<FSRSState>())
        #expect(states.count == 0)
    }

    @Test("Cascade delete: deleting flashcard deletes review logs")
    func deleteFlashcardDeletesReviewLogs() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review)

        try context.save()

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Verify review logs are also deleted
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        #expect(reviews.count == 0)
    }

    @Test("Cascade delete: deleting flashcard with full relationships")
    func deleteFlashcardWithFullRelationships() throws {
        let context = freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(word: "test", definition: "test")
        flashcard.deck = deck
        context.insert(flashcard)

        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state
        context.insert(state)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review)

        try context.save()

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Verify cascade behavior
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        let states = try context.fetch(FetchDescriptor<FSRSState>())
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        let decks = try context.fetch(FetchDescriptor<Deck>())

        #expect(cards.count == 0)  // Flashcard deleted
        #expect(states.count == 0)  // FSRSState deleted (cascade)
        #expect(reviews.count == 0) // Reviews deleted (cascade)
        #expect(decks.count == 1)   // Deck preserved (nullify)
        #expect(decks.first?.cards.isEmpty == true) // Card removed from deck
    }

    // MARK: - Query Tests

    @Test("Query: fetch flashcards by word")
    func fetchFlashcardsByWord() throws {
        let context = freshContext()
        try context.clearAll()

        context.insert(Flashcard(word: "hello", definition: "greeting"))
        context.insert(Flashcard(word: "world", definition: "earth"))
        context.insert(Flashcard(word: "hello", definition: "greeting again"))

        try context.save()

        let predicate = #Predicate<Flashcard> { $0.word == "hello" }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
    }

    @Test("Query: fetch flashcards with translation")
    func fetchFlashcardsWithTranslation() throws {
        let context = freshContext()
        try context.clearAll()

        let card1 = Flashcard(word: "hello", definition: "greeting")
        context.insert(card1)

        let card2 = Flashcard(word: "hola", definition: "greeting", translation: "hello")
        context.insert(card2)

        try context.save()

        // Fetch all and filter
        let allCards = try context.fetch(FetchDescriptor<Flashcard>())
        let cardsWithTranslation = allCards.filter { $0.translation != nil }

        #expect(cardsWithTranslation.count == 1)
        #expect(cardsWithTranslation.first?.word == "hola")
    }

    @Test("Query: fetch flashcards by deck")
    func fetchFlashcardsByDeck() throws {
        let context = freshContext()
        try context.clearAll()

        let deck1 = Deck(name: "Deck 1", icon: "1️⃣")
        context.insert(deck1)

        let deck2 = Deck(name: "Deck 2", icon: "2️⃣")
        context.insert(deck2)

        let card1 = Flashcard(word: "in deck1", definition: "test")
        card1.deck = deck1
        context.insert(card1)

        let card2 = Flashcard(word: "in deck2", definition: "test")
        card2.deck = deck2
        context.insert(card2)

        try context.save()

        // Fetch cards for deck1
        let predicate = #Predicate<Flashcard> { $0.deck?.name == "Deck 1" }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.word == "in deck1")
    }

    // MARK: - Unicode Tests

    @Test("Flashcard with emoji in word")
    func flashcardWithEmoji() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "👋", definition: "waving hand")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "👋")
    }

    @Test("Flashcard with CJK characters")
    func flashcardWithCJK() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "こんにちは", definition: "hello")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "こんにちは")
    }

    @Test("Flashcard with RTL script")
    func flashcardWithRTL() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "مرحبا", definition: "hello")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "مرحبا")
    }

    @Test("Flashcard with very long word")
    func flashcardWithLongWord() throws {
        let context = freshContext()
        try context.clearAll()

        let longWord = String(repeating: "a", count: 1000)
        let flashcard = Flashcard(word: longWord, definition: "very long word")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word.count == 1000)
    }
}
