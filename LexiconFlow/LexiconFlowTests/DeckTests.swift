//
//  DeckTests.swift
//  LexiconFlowTests
//
//  Tests for Deck model
//  Covers: Deck creation, relationships, nullify delete behavior (cards persist as orphans)
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for Deck model
@Suite(.serialized)
@MainActor
struct DeckTests {
    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Deck Creation Tests

    @Test("Deck creation with valid name")
    func deckCreationWithValidName() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Spanish Vocabulary", icon: "🇪🇸")
        context.insert(deck)
        try context.save()

        #expect(deck.name == "Spanish Vocabulary")
        #expect(deck.icon == "🇪🇸")
        #expect(deck.id != UUID()) // Has valid UUID
    }

    @Test("Deck creation with empty name is allowed")
    func deckCreationWithEmptyName() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "", icon: "")
        context.insert(deck)
        try context.save()

        // Note: SwiftData doesn't validate by default, so empty strings are allowed
        #expect(deck.name == "")
        #expect(deck.icon == "")
    }

    @Test("Deck creation with unicode characters")
    func deckCreationWithUnicode() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "日本語", icon: "🇯🇵")
        context.insert(deck)
        try context.save()

        #expect(deck.name == "日本語")
        #expect(deck.icon == "🇯🇵")
    }

    // MARK: - Deck-Card Relationship Tests

    @Test("Deck-card relationship: adding cards to deck")
    func deckCardRelationship() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let card1 = Flashcard(word: "hola", definition: "hello")
        card1.deck = deck
        context.insert(card1)

        let card2 = Flashcard(word: "adiós", definition: "goodbye")
        card2.deck = deck
        context.insert(card2)

        try context.save()

        // Verify relationship from cards to deck
        #expect(card1.deck?.name == "Test Deck")
        #expect(card2.deck?.name == "Test Deck")
    }

    @Test("Deck-card relationship: deck.cards is populated")
    func deckCardsArray() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let card1 = Flashcard(word: "hola", definition: "hello")
        card1.deck = deck
        context.insert(card1)

        let card2 = Flashcard(word: "adiós", definition: "goodbye")
        card2.deck = deck
        context.insert(card2)

        try context.save()

        // Fetch deck and verify cards array is populated
        let fetchedDecks = try context.fetch(FetchDescriptor<Deck>())
        #expect(fetchedDecks.count == 1)
        #expect(fetchedDecks.first?.cards.count == 2)
    }

    @Test("Deck-card relationship: card with no deck")
    func cardWithNoDeck() throws {
        let context = self.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "orphan", definition: "has no deck")
        context.insert(card)
        try context.save()

        #expect(card.deck == nil)
    }

    // MARK: - Nullify Delete Tests

    @Test("Nullify delete: deleting deck nullifies cards (creates orphans)")
    func deleteDeckNullifiesCards() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let card = Flashcard(word: "hola", definition: "hello")
        card.deck = deck
        context.insert(card)

        try context.save()

        let deckID = deck.id
        let cardID = card.id

        // Delete the deck
        context.delete(deck)
        try context.save()

        // Verify deck is deleted
        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.count == 0)

        // Verify card still exists but deck is nullified
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 1)
        #expect(cards.first?.id == cardID)
        #expect(cards.first?.deck == nil)
    }

    @Test("Nullify delete: deleting deck with multiple cards (creates multiple orphans)")
    func deleteDeckWithMultipleCards() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        for i in 1 ... 5 {
            let card = Flashcard(word: "word\(i)", definition: "definition\(i)")
            card.deck = deck
            context.insert(card)
        }

        try context.save()

        // Delete the deck
        context.delete(deck)
        try context.save()

        // Verify all cards still exist but deck is nullified
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 5)

        for card in cards {
            #expect(card.deck == nil)
        }
    }

    // MARK: - Deck Query Tests

    @Test("Query: fetch deck by name")
    func fetchDeckByName() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck1 = Deck(name: "Spanish", icon: "🇪🇸")
        context.insert(deck1)

        let deck2 = Deck(name: "French", icon: "🇫🇷")
        context.insert(deck2)

        try context.save()

        // Fetch decks with specific name
        let predicate = #Predicate<Deck> { $0.name == "Spanish" }
        let descriptor = FetchDescriptor<Deck>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.name == "Spanish")
    }

    @Test("Query: fetch all decks sorted by name")
    func fetchAllDecksSorted() throws {
        let context = self.freshContext()
        try context.clearAll()

        context.insert(Deck(name: "Zulu", icon: "🇿🇦"))
        context.insert(Deck(name: "Alpha", icon: "🇦"))
        context.insert(Deck(name: "Bravo", icon: "🇧"))

        try context.save()

        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.name)])
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].name == "Alpha")
        #expect(results[1].name == "Bravo")
        #expect(results[2].name == "Zulu")
    }

    @Test("Query: fetch decks with no cards")
    func fetchEmptyDecks() throws {
        let context = self.freshContext()
        try context.clearAll()

        let emptyDeck = Deck(name: "Empty", icon: "📭")
        context.insert(emptyDeck)

        let fullDeck = Deck(name: "Full", icon: "📚")
        context.insert(fullDeck)

        let card = Flashcard(word: "test", definition: "test")
        card.deck = fullDeck
        context.insert(card)

        try context.save()

        let allDecks = try context.fetch(FetchDescriptor<Deck>())
        let emptyDecks = allDecks.filter(\.cards.isEmpty)

        #expect(emptyDecks.count == 1)
        #expect(emptyDecks.first?.name == "Empty")
    }

    // MARK: - Deck Update Tests

    @Test("Update: change deck name")
    func updateDeckName() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Old Name", icon: "📚")
        context.insert(deck)
        try context.save()

        // Update deck name
        deck.name = "New Name"
        deck.icon = "🆕"
        try context.save()

        // Verify update persisted
        let fetchedDecks = try context.fetch(FetchDescriptor<Deck>())
        #expect(fetchedDecks.count == 1)
        #expect(fetchedDecks.first?.name == "New Name")
        #expect(fetchedDecks.first?.icon == "🆕")
    }

    @Test("Update: move card from one deck to another")
    func moveCardBetweenDecks() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck1 = Deck(name: "Deck 1", icon: "1️⃣")
        context.insert(deck1)

        let deck2 = Deck(name: "Deck 2", icon: "2️⃣")
        context.insert(deck2)

        let card = Flashcard(word: "test", definition: "test")
        card.deck = deck1
        context.insert(card)

        try context.save()

        // Move card to deck2
        card.deck = deck2
        try context.save()

        // Verify move
        let fetchedCard = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(fetchedCard?.deck?.name == "Deck 2")
    }
}
