//
//  OrphanedCardsServiceTests.swift
//  LexiconFlowTests
//
//  Tests for orphaned cards service and CRUD operations
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

@Suite(.serialized)
@MainActor
struct OrphanedCardsServiceTests {
    // MARK: - Fetch Orphaned Cards

    @Test("Fetch orphaned cards returns cards without deck")
    func fetchOrphanedCards() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create deck and cards
        let deck = Deck(name: "Test Deck")
        context.insert(deck)

        let card1 = Flashcard(word: "card1", definition: "def1")
        card1.deck = deck
        context.insert(card1)

        let card2 = Flashcard(word: "card2", definition: "def2")
        // card2 has no deck - orphaned
        context.insert(card2)

        let card3 = Flashcard(word: "card3", definition: "def3")
        card3.deck = deck
        context.insert(card3)

        try context.save()

        let orphans = service.fetchOrphanedCards(context: context)
        #expect(orphans.count == 1)
        #expect(orphans.first?.word == "card2")
    }

    @Test("Fetch orphaned cards returns empty when no orphans")
    func fetchOrphanedCardsEmpty() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create deck and card - no orphans
        let deck = Deck(name: "Test Deck")
        context.insert(deck)

        let card = Flashcard(word: "card1", definition: "def1")
        card.deck = deck
        context.insert(card)

        try context.save()

        let orphans = service.fetchOrphanedCards(context: context)
        #expect(orphans.isEmpty)
    }

    @Test("Fetch orphaned cards handles multiple orphans")
    func fetchMultipleOrphans() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create orphaned cards without any deck
        let card1 = Flashcard(word: "orphan1", definition: "def1")
        let card2 = Flashcard(word: "orphan2", definition: "def2")
        let card3 = Flashcard(word: "orphan3", definition: "def3")

        context.insert(card1)
        context.insert(card2)
        context.insert(card3)

        try context.save()

        let orphans = service.fetchOrphanedCards(context: context)
        #expect(orphans.count == 3)
    }

    // MARK: - Reassign Cards

    @Test("Reassign cards moves them to new deck")
    func reassignCards() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create orphaned cards
        let card1 = Flashcard(word: "card1", definition: "def1")
        let card2 = Flashcard(word: "card2", definition: "def2")
        context.insert(card1)
        context.insert(card2)

        // Create target deck
        let deck = Deck(name: "Target Deck")
        context.insert(deck)

        try context.save()

        // Verify cards are orphaned
        #expect(card1.deck == nil)
        #expect(card2.deck == nil)

        // Reassign
        let reassigned = try await service.reassignCards(
            [card1, card2],
            to: deck,
            context: context
        )

        #expect(reassigned == 2)
        #expect(card1.deck?.id == deck.id)
        #expect(card2.deck?.id == deck.id)
    }

    @Test("Reassign empty array returns 0")
    func reassignEmptyArray() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create target deck
        let deck = Deck(name: "Target Deck")
        context.insert(deck)
        try context.save()

        // Reassign empty array
        let reassigned = try await service.reassignCards(
            [],
            to: deck,
            context: context
        )

        #expect(reassigned == 0)
    }

    @Test("Reassign cards invalidates cache")
    func reassignInvalidatesCache() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create orphaned card and deck
        let card = Flashcard(word: "card1", definition: "def1")
        context.insert(card)

        let deck = Deck(name: "Target Deck")
        context.insert(deck)
        try context.save()

        // Set some cache (simulated)
        DeckStatisticsCache.shared.set(DeckStatistics(due: 1, new: 0, total: 1), for: deck.id)
        #expect(DeckStatisticsCache.shared.get(deckID: deck.id) != nil)

        // Reassign should invalidate cache
        _ = try await service.reassignCards([card], to: deck, context: context)

        // Cache should be invalidated
        #expect(DeckStatisticsCache.shared.get(deckID: deck.id) == nil)
    }

    // MARK: - Delete Orphaned Cards

    @Test("Delete orphaned cards removes them from database")
    func deleteOrphanedCards() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create orphaned cards
        let card1 = Flashcard(word: "card1", definition: "def1")
        let card2 = Flashcard(word: "card2", definition: "def2")
        context.insert(card1)
        context.insert(card2)

        try context.save()

        // Verify they exist
        let before = service.fetchOrphanedCards(context: context)
        #expect(before.count == 2)

        // Delete
        let deleted = try await service.deleteOrphanedCards(
            [card1, card2],
            context: context
        )

        #expect(deleted == 2)

        // Verify they're gone
        let after = service.fetchOrphanedCards(context: context)
        #expect(after.count == 0)
    }

    @Test("Delete empty array returns 0")
    func deleteEmptyArray() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        let deleted = try await service.deleteOrphanedCards(
            [],
            context: context
        )

        #expect(deleted == 0)
    }

    @Test("Delete orphaned cards invalidates cache")
    func deleteInvalidatesCache() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create orphaned card and deck
        let card = Flashcard(word: "card1", definition: "def1")
        context.insert(card)

        let deck = Deck(name: "Test Deck")
        context.insert(deck)
        try context.save()

        // Set some cache (simulated)
        DeckStatisticsCache.shared.set(DeckStatistics(due: 1, new: 0, total: 1), for: deck.id)
        #expect(DeckStatisticsCache.shared.get(deckID: deck.id) != nil)

        // Delete should invalidate cache
        _ = try await service.deleteOrphanedCards([card], context: context)

        // Cache should be invalidated
        #expect(DeckStatisticsCache.shared.get(deckID: deck.id) == nil)
    }

    // MARK: - Orphaned Card Count

    @Test("Orphaned card count returns correct number")
    func orphanedCardCount() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Initially zero
        #expect(service.orphanedCardCount(context: context) == 0)

        // Add orphaned cards
        let card1 = Flashcard(word: "card1", definition: "def1")
        let card2 = Flashcard(word: "card2", definition: "def2")
        context.insert(card1)
        context.insert(card2)

        try context.save()

        #expect(service.orphanedCardCount(context: context) == 2)
    }

    @Test("Orphaned card count ignores cards with decks")
    func orphanedCardCountIgnoresAssigned() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create deck with cards
        let deck = Deck(name: "Test Deck")
        context.insert(deck)

        let card1 = Flashcard(word: "card1", definition: "def1")
        card1.deck = deck
        context.insert(card1)

        // Create one orphan
        let card2 = Flashcard(word: "card2", definition: "def2")
        context.insert(card2)

        try context.save()

        #expect(service.orphanedCardCount(context: context) == 1)
    }

    // MARK: - Edge Cases

    @Test("Service handles empty database gracefully")
    func emptyDatabase() {
        let context = TestContainers.freshContext()
        try? context.clearAll()
        let service = OrphanedCardsService.shared

        let orphans = service.fetchOrphanedCards(context: context)
        #expect(orphans.isEmpty)
        #expect(service.orphanedCardCount(context: context) == 0)
    }

    @Test("Service handles mixed cards correctly")
    func mixedCards() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let service = OrphanedCardsService.shared

        // Create deck
        let deck = Deck(name: "Test Deck")
        context.insert(deck)

        // Mix of assigned and orphaned cards
        let card1 = Flashcard(word: "assigned1", definition: "def1")
        card1.deck = deck
        context.insert(card1)

        let card2 = Flashcard(word: "orphan1", definition: "def2")
        context.insert(card2)

        let card3 = Flashcard(word: "assigned2", definition: "def3")
        card3.deck = deck
        context.insert(card3)

        let card4 = Flashcard(word: "orphan2", definition: "def4")
        context.insert(card4)

        try context.save()

        let orphans = service.fetchOrphanedCards(context: context)
        #expect(orphans.count == 2)
        #expect(orphans.allSatisfy { $0.deck == nil })
    }
}
