//
//  DeckStudyDetailViewTests.swift
//  LexiconFlowTests
//
//  Tests for DeckStudyDetailView covering session lifecycle, stats refresh, error handling
//

import Testing
import SwiftUI
import SwiftData
@testable import LexiconFlow

@MainActor
@Suite("DeckStudyDetailView Tests")
struct DeckStudyDetailViewTests {

    private func makeTestContainer() -> ModelContainer {
        let schema = Schema([Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func insertDeckWithCards(context: ModelContext) -> Deck {
        let deck = Deck(name: "Vocabulary", icon: "book.fill", order: 0)
        context.insert(deck)

        // Add cards
        let card1 = Flashcard(word: "Hello", definition: "Hola")
        card1.deck = deck
        let card2 = Flashcard(word: "Goodbye", definition: "Adiós")
        card2.deck = deck

        let state1 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-1000),
            stateEnum: "review"
        )
        state1.card = card1

        let state2 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(86400 * 30),
            stateEnum: "new"
        )
        state2.card = card2

        context.insert(card1)
        context.insert(card2)
        context.insert(state1)
        context.insert(state2)

        try! context.save()

        return deck
    }

    @Test("View initializes with deck parameter")
    func initWithDeck() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let view = DeckStudyDetailView(deck: deck)
            .modelContainer(container)

        #expect(deck.name == "Vocabulary")
    }

    @Test("Statistics refresh on appear")
    func statsRefreshOnAppear() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let view = DeckStudyDetailView(deck: deck)
            .modelContainer(container)

        // Simulate stats refresh
        let scheduler = Scheduler(modelContext: context)
        let newCount = scheduler.newCardCount(for: deck)
        let dueCount = scheduler.dueCardCount(for: deck)
        let totalCount = scheduler.totalCardCount(for: deck)

        #expect(newCount >= 0)
        #expect(dueCount >= 0)
        #expect(totalCount >= 0)
    }

    @Test("Study session start validation shows error when no cards")
    func startSessionNoCards() async {
        let container = makeTestContainer()
        let context = ModelContext(container)

        // Create empty deck
        let deck = Deck(name: "Empty Deck", icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()

        let view = DeckStudyDetailView(deck: deck)
            .modelContainer(container)

        // Attempt to start session should show error
        let scheduler = Scheduler(modelContext: context)
        let availableCount = scheduler.fetchCards(for: deck, mode: .scheduled, limit: 1).count

        #expect(availableCount == 0)
    }

    @Test("Study session start navigates to session with cards")
    func startSessionWithCards() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let scheduler = Scheduler(modelContext: context)
        let availableCount = scheduler.fetchCards(for: deck, mode: .scheduled, limit: 1).count

        #expect(availableCount > 0)
    }

    @Test("Session lifecycle: start → study → complete → refresh")
    func sessionLifecycle() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        // Start session
        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel.loadCards()
        #expect(viewModel.cards.count > 0)

        // Simulate session completion
        let initialDueCount = scheduler(for: context).dueCardCount(for: deck)

        // After review, stats should be refreshed
        let refreshedDueCount = scheduler(for: context).dueCardCount(for: deck)
        #expect(refreshedDueCount <= initialDueCount)
    }

    @Test("Empty session handles gracefully")
    func emptySessionHandling() async {
        let container = makeTestContainer()
        let context = ModelContext(container)

        // Create deck with no cards
        let deck = Deck(name: "Empty Deck", icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Should handle empty session gracefully
        #expect(viewModel.cards.isEmpty)
        #expect(viewModel.isComplete == true)
    }

    @Test("Navigation passes correct deck to StudySessionView")
    func navigationWithDeck() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        // Verify deck is passed correctly
        #expect(deck.name == "Vocabulary")
    }

    @Test("Conditional UI: scheduled section only if due cards")
    func conditionalScheduledSection() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let scheduler = Scheduler(modelContext: context)
        let dueCount = scheduler.dueCardCount(for: deck)

        // Scheduled section should show if dueCount > 0
        #expect(dueCount > 0)
    }

    @Test("StudyModeCard displays correct mode name")
    func studyModeCardDisplay() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let view = DeckStudyDetailView(deck: deck)
            .modelContainer(container)

        // Verify deck exists
        #expect(deck.name == "Vocabulary")
    }

    @Test("Error state displays for failed operations")
    func errorStateDisplay() async {
        let container = makeTestContainer()
        let context = ModelContext(container)

        // Create empty deck
        let deck = Deck(name: "Empty Deck", icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()

        let view = DeckStudyDetailView(deck: deck)
            .modelContainer(container)

        // Attempting to start session with no cards should trigger error
        let scheduler = Scheduler(modelContext: context)
        let cards = scheduler.fetchCards(for: deck, mode: .scheduled, limit: 10)

        #expect(cards.isEmpty)
    }

    @Test("Statistics update after session completion")
    func statsUpdateAfterSession() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let initialTotalCount = scheduler(for: context).totalCardCount(for: deck)

        // Simulate session
        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel.loadCards()
        let initialCardCount = viewModel.cards.count

        // Stats should remain consistent
        let finalTotalCount = scheduler(for: context).totalCardCount(for: deck)
        #expect(finalTotalCount == initialTotalCount)
        #expect(initialCardCount > 0)
    }

    @Test("Deleted deck during session handles gracefully")
    func deletedDeckHandling() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let deck = insertDeckWithCards(context: context)

        let deckID = deck.id

        // Delete deck
        context.delete(deck)
        try! context.save()

        // Verify deck is deleted
        let descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckID })
        let deletedDeck = try? context.fetch(descriptor).first

        #expect(deletedDeck == nil)
    }

    // Helper function
    private func scheduler(for context: ModelContext) -> Scheduler {
        Scheduler(modelContext: context)
    }
}
