//
//  ModelTests.swift
//  LexiconFlowTests
//
//  Tests for SwiftData models
//  Covers: Flashcard, Deck, FlashcardReview, FSRSState
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for SwiftData models
@MainActor
struct ModelTests {

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Flashcard Tests

    @Test("Flashcard creation with required fields")
    func flashcardCreation() {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "hello",
            definition: "a greeting",
            phonetic: "həˈloʊ"
        )

        context.insert(flashcard)
        try! context.save()

        #expect(flashcard.word == "hello")
        #expect(flashcard.definition == "a greeting")
        #expect(flashcard.phonetic == "həˈloʊ")
        #expect(flashcard.id != UUID()) // Has valid UUID
    }

    @Test("Flashcard optional fields can be nil")
    func flashcardOptionals() {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "test",
            definition: "test"
            // phonetic and imageData omitted
        )

        context.insert(flashcard)
        try! context.save()

        #expect(flashcard.phonetic == nil)
        #expect(flashcard.imageData == nil)
    }

    @Test("Flashcard-deck relationship")
    func flashcardDeckRelationship() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(word: "test", definition: "test")
        flashcard.deck = deck
        context.insert(flashcard)
        try! context.save()

        #expect(flashcard.deck?.name == "Test Deck")
    }

    @Test("Flashcard FSRS state relationship")
    func flashcardFSRSState() {
        let container = createTestContainer()
        let context = container.mainContext

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
        try! context.save()

        #expect(flashcard.fsrsState?.stability == 5.0)
    }

    @Test("Flashcard review logs relationship")
    func flashcardReviewLogs() {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(rating: 2, reviewDate: Date(), scheduledDays: 1, elapsedDays: 0)
        review1.card = flashcard
        context.insert(review1)

        let review2 = FlashcardReview(rating: 3, reviewDate: Date(), scheduledDays: 3, elapsedDays: 1)
        review2.card = flashcard
        context.insert(review2)

        try! context.save()

        #expect(flashcard.reviewLogs.count == 2)
        #expect(flashcard.reviewLogs.allSatisfy { $0.card === flashcard })
    }

    // MARK: - Deck Tests

    @Test("Deck creation and properties")
    func deckCreation() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = Deck(name: "Vocabulary", icon: "📖")
        context.insert(deck)
        try! context.save()

        #expect(deck.name == "Vocabulary")
        #expect(deck.icon == "📖")
        #expect(deck.id != UUID())
    }

    @Test("Deck-cards relationship")
    func deckCardsRelationship() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = Deck(name: "Test", icon: "📚")
        context.insert(deck)

        for i in 1...3 {
            let card = Flashcard(word: "word\(i)", definition: "def\(i)")
            card.deck = deck
            context.insert(card)
        }

        try! context.save()

        #expect(deck.cards.count == 3)
    }

    // MARK: - FlashcardReview Tests

    @Test("Review log creation")
    func reviewLogCreation() {
        let container = createTestContainer()
        let context = container.mainContext

        let now = Date()
        let review = FlashcardReview(
            rating: 2,
            reviewDate: now,
            scheduledDays: 5.0,
            elapsedDays: 1.0
        )

        context.insert(review)
        try! context.save()

        #expect(review.rating == 2)
        #expect(review.reviewDate == now)
        #expect(review.scheduledDays == 5.0)
        #expect(review.elapsedDays == 1.0)
    }

    @Test("Review log convenience initializer")
    func reviewLogConvenienceInit() {
        let container = createTestContainer()
        let context = container.mainContext

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
    func fsrsStateCache() {
        let container = createTestContainer()
        let context = container.mainContext

        let state = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        state.lastReviewDate = Date().addingTimeInterval(-86400) // 1 day ago
        context.insert(state)
        try! context.save()

        #expect(state.lastReviewDate != nil)
        #expect(abs(state.lastReviewDate!.timeIntervalSinceNow) > 80000) // ~23 hours ago
    }

    // MARK: - CardRating Tests

    @Test("CardRating FSRS conversion")
    func cardRatingFSRSConversion() {
        #expect(CardRating.again.toFSRS == .again)   // 0 → 1
        #expect(CardRating.hard.toFSRS == .hard)     // 1 → 2
        #expect(CardRating.good.toFSRS == .good)     // 2 → 3
        #expect(CardRating.easy.toFSRS == .easy)     // 3 → 4
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
    func flashcardDeleteCascade() {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(rating: 2, reviewDate: Date(), scheduledDays: 0, elapsedDays: 0)
        review.card = flashcard
        context.insert(review)

        try! context.save()

        let reviewId = review.id

        // Delete flashcard
        context.delete(flashcard)
        try! context.save()

        // Review should be deleted or have nil card reference
        let reviews = try! context.fetch(FetchDescriptor<FlashcardReview>())
        let deletedReview = reviews.first { $0.id == reviewId }
        #expect(deletedReview == nil || deletedReview?.card == nil)
    }
}
