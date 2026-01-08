//
//  ModelTests.swift
//  LexiconFlowTests
//
//  Tests for SwiftData models
//  Covers: Flashcard, Deck, FlashcardReview, FSRSState
//

import Foundation
import FSRS
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for SwiftData models
/// Uses shared container for performance - each test clears context before use
@MainActor
struct ModelTests {
    /// Get a fresh isolated context for testing
    /// Caller should call clearAll() before use to ensure test isolation
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Flashcard Tests

    @Test("Flashcard creation with required fields")
    func flashcardCreation() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "hello",
            definition: "a greeting",
            phonetic: "həˈloʊ"
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.word == "hello")
        #expect(flashcard.definition == "a greeting")
        #expect(flashcard.phonetic == "həˈloʊ")
        #expect(flashcard.id != UUID()) // Has valid UUID
    }

    @Test("Flashcard optional fields can be nil")
    func flashcardOptionals() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "test"
            // phonetic and imageData omitted
        )

        context.insert(flashcard)
        try context.save()

        #expect(flashcard.phonetic == nil)
        #expect(flashcard.imageData == nil)
    }

    @Test("Flashcard-deck relationship")
    func flashcardDeckRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(word: "test", definition: "test")
        flashcard.deck = deck
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.deck?.name == "Test Deck")
    }

    @Test("Flashcard FSRS state relationship")
    func flashcardFSRSState() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        let state = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)
        flashcard.fsrsState = state
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.fsrsState?.stability == 5.0)
    }

    @Test("Flashcard review logs relationship")
    func flashcardReviewLogs() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(rating: 2, reviewDate: Date(), scheduledDays: 1, elapsedDays: 0)
        review1.card = flashcard
        context.insert(review1)

        let review2 = FlashcardReview(rating: 3, reviewDate: Date(), scheduledDays: 3, elapsedDays: 1)
        review2.card = flashcard
        context.insert(review2)

        try context.save()

        #expect(flashcard.reviewLogs.count == 2)
        #expect(flashcard.reviewLogs.allSatisfy { $0.card === flashcard })
    }

    @Test("Flashcard-generatedSentences relationship")
    func flashcardGeneratedSentencesRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test")
        context.insert(flashcard)

        let sentence1 = try GeneratedSentence(
            sentenceText: "First sentence.",
            cefrLevel: "A1"
        )
        sentence1.flashcard = flashcard
        context.insert(sentence1)

        let sentence2 = try GeneratedSentence(
            sentenceText: "Second sentence.",
            cefrLevel: "A2"
        )
        sentence2.flashcard = flashcard
        context.insert(sentence2)

        try context.save()

        #expect(flashcard.generatedSentences.count == 2)
        // Sort by generatedAt since SwiftData doesn't guarantee insertion order
        let sortedSentences = flashcard.generatedSentences.sorted { $0.generatedAt < $1.generatedAt }
        #expect(sortedSentences[0].sentenceText == "First sentence.")
        #expect(sortedSentences[1].sentenceText == "Second sentence.")
    }

    @Test("Flashcard has empty sentences array by default")
    func flashcardEmptySentencesDefault() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.generatedSentences.isEmpty)
    }

    @Test("Flashcard cascade delete deletes all sentences")
    func flashcardCascadeDeleteSentences() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test")
        context.insert(flashcard)

        for i in 1 ... 5 {
            let sentence = try GeneratedSentence(
                sentenceText: "Sentence \(i)",
                cefrLevel: "A1"
            )
            sentence.flashcard = flashcard
            context.insert(sentence)
        }
        try context.save()

        #expect(flashcard.generatedSentences.count == 5)

        // Delete flashcard (should cascade delete all sentences)
        context.delete(flashcard)
        try context.save()

        // Verify all sentences are deleted
        let descriptor = FetchDescriptor<GeneratedSentence>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("Flashcard sentence backfill works correctly")
    func flashcardSentenceBackfill() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test")
        context.insert(flashcard)

        // Add initial sentences
        for i in 1 ... 2 {
            let sentence = try GeneratedSentence(
                sentenceText: "Old sentence \(i)",
                cefrLevel: "A1"
            )
            sentence.flashcard = flashcard
            context.insert(sentence)
        }
        try context.save()

        let initialCount = flashcard.generatedSentences.count
        #expect(initialCount == 2)

        // Add new sentences (simulating regeneration)
        for i in 1 ... 3 {
            let sentence = try GeneratedSentence(
                sentenceText: "New sentence \(i)",
                cefrLevel: "A2"
            )
            sentence.flashcard = flashcard
            context.insert(sentence)
        }

        // Delete old sentences
        for sentence in flashcard.generatedSentences.filter({ $0.cefrLevel == "A1" }) {
            context.delete(sentence)
        }

        try context.save()

        #expect(flashcard.generatedSentences.count == 3)
        #expect(flashcard.generatedSentences.allSatisfy { $0.cefrLevel == "A2" })
    }

    // MARK: - Deck Tests

    @Test("Deck creation and properties")
    func deckCreation() throws {
        let context = freshContext()
        try context.clearAll()

        let deck = Deck(name: "Vocabulary", icon: "📖")
        context.insert(deck)
        try context.save()

        #expect(deck.name == "Vocabulary")
        #expect(deck.icon == "📖")
        #expect(deck.id != UUID())
    }

    @Test("Deck-cards relationship")
    func deckCardsRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        for i in 1 ... 3 {
            let card = Flashcard(word: "word\(i)", definition: "def\(i)")
            card.deck = deck
            context.insert(card)
        }

        try context.save()

        #expect(deck.cards.count == 3)
    }

    // MARK: - FlashcardReview Tests

    @Test("Review log creation")
    func reviewLogCreation() throws {
        let context = freshContext()
        try context.clearAll()

        let now = Date()
        let review = FlashcardReview(
            rating: 2,
            reviewDate: now,
            scheduledDays: 5.0,
            elapsedDays: 1.0
        )

        context.insert(review)
        try context.save()

        #expect(review.rating == 2)
        #expect(review.reviewDate == now)
        #expect(review.scheduledDays == 5.0)
        #expect(review.elapsedDays == 1.0)
    }

    @Test("Review log convenience initializer")
    func reviewLogConvenienceInit() {
        // This test doesn't need context - just tests initializer
        let review = FlashcardReview(
            rating: 1,
            scheduledDays: 2.5,
            elapsedDays: 0.5
        )

        #expect(review.rating == 1)
        #expect(review.scheduledDays == 2.5)
        #expect(review.elapsedDays == 0.5)
        // reviewDate should default to now
        #expect(abs(review.reviewDate.timeIntervalSinceNow) < 1.0)
    }

    // MARK: - FSRSState Tests

    @Test("FSRS state computed property")
    func fsrsStateComputedProperty() {
        // This test doesn't need context - just tests computed properties
        let state = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.8,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )

        #expect(state.state == .review)
        #expect(state.stateEnum == FlashcardState.review.rawValue)
    }

    @Test("FSRS state setter updates raw value")
    func fsrsStateSetter() {
        // This test doesn't need context - just tests setter
        let state = FSRSState(
            stability: 0,
            difficulty: 5,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )

        state.state = .learning

        #expect(state.stateEnum == FlashcardState.learning.rawValue)
    }

    @Test("FSRS state with lastReviewDate cache")
    func fsrsStateCache() throws {
        let context = freshContext()
        try context.clearAll()

        let state = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        state.lastReviewDate = Date().addingTimeInterval(-86400) // 1 day ago
        context.insert(state)
        try context.save()

        #expect(state.lastReviewDate != nil)
        #expect(abs(state.lastReviewDate!.timeIntervalSinceNow) > 80000) // ~23 hours ago
    }

    // MARK: - CardRating Tests

    @Test("CardRating FSRS conversion")
    func cardRatingFSRSConversion() {
        #expect(CardRating.again.toFSRS == .again) // 0 → 1
        #expect(CardRating.hard.toFSRS == .hard) // 1 → 2
        #expect(CardRating.good.toFSRS == .good) // 2 → 3
        #expect(CardRating.easy.toFSRS == .easy) // 3 → 4
    }

    @Test("CardRating from FSRS")
    func cardRatingFromFSRS() {
        #expect(CardRating.from(fsrs: .again) == .again)
        #expect(CardRating.from(fsrs: .hard) == .hard)
        #expect(CardRating.from(fsrs: .good) == .good)
        #expect(CardRating.from(fsrs: .easy) == .easy)
    }

    @Test("CardRating validation")
    func cardRatingValidation() {
        #expect(CardRating.validate(0) == .again)
        #expect(CardRating.validate(1) == .hard)
        #expect(CardRating.validate(2) == .good)
        #expect(CardRating.validate(3) == .easy)
        #expect(CardRating.validate(99) == .good) // Invalid defaults to good
        #expect(CardRating.validate(-1) == .good)
    }

    @Test("CardRating UI properties")
    func cardRatingUIProperties() {
        #expect(CardRating.again.label == "Again")
        #expect(CardRating.again.color == "red")
        #expect(CardRating.again.iconName == "xmark.circle.fill")

        #expect(CardRating.easy.label == "Easy")
        #expect(CardRating.easy.color == "green")
        #expect(CardRating.easy.iconName == "star.fill")
    }

    // MARK: - Cascade Delete Tests

    @Test("Deleting flashcard cascades to reviews")
    func flashcardDeleteCascade() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(rating: 2, reviewDate: Date(), scheduledDays: 0, elapsedDays: 0)
        review.card = flashcard
        context.insert(review)

        try context.save()

        let reviewId = review.id

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Review should be deleted or have nil card reference
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        let deletedReview = reviews.first { $0.id == reviewId }
        #expect(deletedReview == nil || deletedReview?.card == nil)
    }
}
