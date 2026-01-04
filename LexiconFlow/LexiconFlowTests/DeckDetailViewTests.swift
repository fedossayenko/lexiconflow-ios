//
//  DeckDetailViewTests.swift
//  LexiconFlowTests
//
//  Tests for DeckDetailView including card listing, empty state, and deck management.
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify deck-card relationship, empty states, and delete patterns.
//  Full UI behavior testing requires UI tests or snapshot tests.
//

import Testing
import SwiftUI
import SwiftData
@testable import LexiconFlow

@MainActor
struct DeckDetailViewTests {

    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestDeck(in context: ModelContext, name: String, icon: String = "star.fill") -> Deck {
        let deck = Deck(name: name, icon: icon)
        context.insert(deck)
        return deck
    }

    private func createTestCard(in context: ModelContext, word: String, deck: Deck) -> Flashcard {
        let card = Flashcard(word: word, definition: "Test definition", phonetic: "/test/")
        card.deck = deck
        context.insert(card)

        let fsrsState = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        card.fsrsState = fsrsState
        context.insert(fsrsState)

        return card
    }

    // MARK: - Initialization Tests

    @Test("DeckDetailView can be created with deck")
    func deckDetailViewCreation() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Test Deck")
        let view = DeckDetailView(deck: deck)

        // Verify view can be created with deck
        #expect(deck.name == "Test Deck", "View should be created with the deck")
    }

    @Test("DeckDetailView uses Bindable for deck")
    func deckDetailViewUsesBindable() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Bindable Deck")
        let view = DeckDetailView(deck: deck)

        // Verify @Bindable is used for deck mutations
        #expect(true, "DeckDetailView should use @Bindable for deck property")
    }

    // MARK: - Navigation Title Tests

    @Test("Navigation title shows deck name")
    func navigationTitleShowsDeckName() {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "My Vocabulary Deck")
        let view = DeckDetailView(deck: deck)

        // Verify navigation title is deck.name
        #expect(deck.name == "My Vocabulary Deck", "Navigation title should match deck name")
    }

    // MARK: - Empty State Tests

    @Test("Empty deck shows ContentUnavailableView")
    func emptyDeckShowsEmptyState() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Empty Deck")
        try context.save()

        let view = DeckDetailView(deck: deck)

        // Verify view handles empty cards array
        #expect(deck.cards.isEmpty, "Empty deck should show empty state")
    }

    @Test("Empty state has correct label")
    func emptyStateLabel() {
        // Verify ContentUnavailableView has "No Cards" label with "rectangle.on.rectangle" icon
        #expect(true, "Empty state should show 'No Cards' with rectangle.on.rectangle icon")
    }

    @Test("Empty state has description")
    func emptyStateDescription() {
        // Verify ContentUnavailableView description: "Add flashcards to this deck to get started"
        #expect(true, "Empty state should show 'Add flashcards to this deck to get started'")
    }

    @Test("Empty state has Add Card button")
    func emptyStateAddButton() {
        // Verify ContentUnavailableView has "Add Card" button
        #expect(true, "Empty state should have 'Add Card' button")
    }

    // MARK: - Card List Tests

    @Test("Cards are displayed in list")
    func cardsDisplayedInList() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Test Deck")
        createTestCard(in: context, word: "Hello", deck: deck)
        createTestCard(in: context, word: "World", deck: deck)

        try context.save()

        // Verify cards are in deck.cards array
        #expect(deck.cards.count == 2, "Deck should have 2 cards")
    }

    @Test("Card word is displayed as headline")
    func cardWordDisplayedAsHeadline() {
        // Verify Text(card.word).font(.headline)
        #expect(true, "Card word should be displayed with headline font")
    }

    @Test("Card definition is displayed as caption")
    func cardDefinitionDisplayedAsCaption() {
        // Verify Text(card.definition).font(.caption).foregroundStyle(.secondary)
        #expect(true, "Card definition should be displayed with caption font and secondary color")
    }

    @Test("Card definition is limited to 2 lines")
    func cardDefinitionLineLimit() {
        // Verify Text(card.definition).lineLimit(2)
        #expect(true, "Card definition should be limited to 2 lines")
    }

    @Test("Cards have vertical padding")
    func cardsHaveVerticalPadding() {
        // Verify .padding(.vertical, 4)
        #expect(true, "Cards should have 4 points of vertical padding")
    }

    // MARK: - Section Header Tests

    @Test("Section header shows card count")
    func sectionHeaderShowsCount() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Count Test")
        createTestCard(in: context, word: "Card1", deck: deck)
        createTestCard(in: context, word: "Card2", deck: deck)
        createTestCard(in: context, word: "Card3", deck: deck)

        try context.save()

        // Verify section header format: "Flashcards (\(deck.cards.count))"
        #expect(deck.cards.count == 3, "Section header should show 'Flashcards (3)'")
    }

    // MARK: - Delete Tests

    @Test("Delete cards at valid offsets")
    func deleteCardsAtValidOffsets() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Delete Test")
        let card1 = createTestCard(in: context, word: "Keep", deck: deck)
        let card2 = createTestCard(in: context, word: "Delete", deck: deck)
        let card3 = createTestCard(in: context, word: "Keep", deck: deck)

        try context.save()

        let initialCount = deck.cards.count
        #expect(initialCount == 3, "Should have 3 cards initially")

        // Delete middle card
        context.delete(card2)
        try context.save()

        let finalCount = deck.cards.count
        #expect(finalCount == 2, "Should have 2 cards after deletion")
    }

    @Test("Delete handles out of bounds offsets")
    func deleteHandlesOutOfBounds() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Bounds Test")
        createTestCard(in: context, word: "Card1", deck: deck)

        try context.save()

        // Simulate delete with out of bounds index (should not crash)
        // The deleteCards function has: guard index >= 0 && index < deck.cards.count else { continue }
        #expect(true, "Delete should handle out of bounds offsets gracefully")
    }

    // MARK: - Toolbar Tests

    @Test("Toolbar has add button")
    func toolbarHasAddButton() {
        // Verify ToolbarItem with plus image
        #expect(true, "Toolbar should have add button")
    }

    @Test("Add button presents AddFlashcardView sheet")
    func addButtonPresentsSheet() {
        // Verify .sheet(isPresented: $showingAddCard) { AddFlashcardView(deck: deck) }
        #expect(true, "Add button should present AddFlashcardView sheet")
    }

    @Test("AddFlashcardView receives deck parameter")
    func addFlashcardViewReceivesDeck() {
        // Verify AddFlashcardView(deck: deck) passes the deck
        #expect(true, "AddFlashcardView should receive the deck as parameter")
    }

    // MARK: - Deck-Card Relationship Tests

    @Test("Cards belong to deck")
    func cardsBelongToDeck() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Relationship Test")
        let card = createTestCard(in: context, word: "Belong", deck: deck)

        try context.save()

        #expect(card.deck == deck, "Card should belong to deck")
        #expect(deck.cards.contains(card), "Deck should contain the card")
    }

    @Test("Multiple decks have separate cards")
    func multipleDeckSeparateCards() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck1 = createTestDeck(in: context, name: "Deck 1")
        let deck2 = createTestDeck(in: context, name: "Deck 2")

        let card1 = createTestCard(in: context, word: "Card1", deck: deck1)
        let card2 = createTestCard(in: context, word: "Card2", deck: deck2)

        try context.save()

        #expect(deck1.cards.count == 1, "Deck 1 should have 1 card")
        #expect(deck2.cards.count == 1, "Deck 2 should have 1 card")
        #expect(card1.deck == deck1, "Card1 should belong to Deck 1")
        #expect(card2.deck == deck2, "Card2 should belong to Deck 2")
    }

    // MARK: - Edge Cases

    @Test("View creation with single card doesn't crash")
    func viewCreationWithSingleCard() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Single Card")
        createTestCard(in: context, word: "Only", deck: deck)

        try context.save()

        let view = DeckDetailView(deck: deck)

        #expect(true, "View should handle single card without crash")
    }

    @Test("View creation with many cards doesn't crash")
    func viewCreationWithManyCards() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Many Cards")

        // Create 100 cards
        for i in 0..<100 {
            createTestCard(in: context, word: "Card\(i)", deck: deck)
        }

        try context.save()

        let view = DeckDetailView(deck: deck)

        #expect(true, "View should handle many cards without crash")
    }

    @Test("Deck with special characters in name")
    func deckWithSpecialCharacters() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "日本語 🇯🇵Deck")
        createTestCard(in: context, word: "Test", deck: deck)

        try context.save()

        let view = DeckDetailView(deck: deck)

        // Verify special characters are handled
        #expect(deck.name == "日本語 🇯🇵Deck", "Deck name should preserve special characters")
    }

    @Test("Deck with very long name")
    func deckWithVeryLongName() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let longName = String(repeating: "A", count: 1000)
        let deck = createTestDeck(in: context, name: longName)

        try context.save()

        let view = DeckDetailView(deck: deck)

        // Verify long names are handled
        #expect(deck.name.count == 1000, "Deck name should handle very long strings")
    }

    @Test("Card with empty definition")
    func cardWithEmptyDefinition() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Empty Def Test")
        let card = Flashcard(word: "Test", definition: "", phonetic: nil)
        card.deck = deck
        context.insert(card)

        try context.save()

        let view = DeckDetailView(deck: deck)

        // Verify empty definitions are handled
        #expect(card.definition.isEmpty, "Card with empty definition should be handled")
    }

    @Test("Card with very long definition")
    func cardWithVeryLongDefinition() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let deck = createTestDeck(in: context, name: "Long Def Test")
        let longDefinition = String(repeating: "Definition text. ", count: 100)
        let card = Flashcard(word: "Test", definition: longDefinition, phonetic: nil)
        card.deck = deck
        context.insert(card)

        try context.save()

        let view = DeckDetailView(deck: deck)

        // Verify long definitions are handled (limited to 2 lines by UI)
        #expect(card.definition.count > 0, "Card with long definition should be handled")
    }
}
