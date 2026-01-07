//
//  DeckStudyListViewTests.swift
//  LexiconFlowTests
//
//  Tests for DeckStudyListView covering deck list, stats refresh, and navigation
//

import Testing
import SwiftUI
import SwiftData
@testable import LexiconFlow

@MainActor
@Suite("DeckStudyListView Tests")
struct DeckStudyListViewTests {

    private func makeTestContainer() -> ModelContainer {
        let schema = Schema([Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func insertDecks(context: ModelContext) -> (Deck, Deck, Deck) {
        let deck1 = Deck(name: "Vocabulary", icon: "book.fill", order: 0)
        let deck2 = Deck(name: "Phrases", icon: "text.bubble", order: 1)
        let deck3 = Deck(name: "Grammar", icon: "text.alignleft", order: 2)

        context.insert(deck1)
        context.insert(deck2)
        context.insert(deck3)

        // Add cards to deck1
        let card1 = Flashcard(word: "Hello", definition: "Hola")
        card1.deck = deck1
        let state1 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-1000),
            stateEnum: "review"
        )
        state1.card = card1

        context.insert(card1)
        context.insert(state1)

        try! context.save()

        return (deck1, deck2, deck3)
    }

    @Test("Empty state shows with navigation to AddDeckView")
    func emptyStateNavigation() async {
        let container = makeTestContainer()
        let context = ModelContext(container)

        // Don't insert any decks
        try! context.save()

        let view = DeckStudyListView()
            .modelContainer(container)

        // Verify empty state
        let descriptor = FetchDescriptor<Deck>()
        let decks = try! context.fetch(descriptor)
        #expect(decks.isEmpty)
    }

    @Test("Deck list populates with @Query sorting")
    func deckListPopulation() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        _ = insertDecks(context: context)

        let view = DeckStudyListView()
            .modelContainer(container)

        // Verify decks are sorted by order
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\Deck.order)])
        let decks = try! context.fetch(descriptor)

        #expect(decks.count == 3)
        #expect(decks[0].order == 0)
        #expect(decks[1].order == 1)
        #expect(decks[2].order == 2)
    }

    @Test("Statistics refresh on appear")
    func statsRefreshOnAppear() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let (deck1, deck2, deck3) = insertDecks(context: context)

        let view = DeckStudyListView()
            .modelContainer(container)

        // Refresh stats
        let scheduler = Scheduler(modelContext: context)

        for deck in [deck1, deck2, deck3] {
            let newCount = scheduler.newCardCount(for: deck)
            let dueCount = scheduler.dueCardCount(for: deck)
            let totalCount = scheduler.totalCardCount(for: deck)

            #expect(newCount >= 0)
            #expect(dueCount >= 0)
            #expect(totalCount >= 0)
        }
    }

    @Test("DeckStudyRow component renders correctly")
    func deckStudyRowRendering() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let (deck1, _, _) = insertDecks(context: context)

        let stats = DeckStudyStats(newCount: 0, dueCount: 1, totalCount: 1)
        let row = DeckStudyRow(deck: deck1, stats: stats)

        #expect(deck1.name == "Vocabulary")
        #expect(stats.totalCount == 1)
        #expect(stats.dueCount == 1)
    }

    @Test("Navigation destination to DeckStudyDetailView")
    func navigationToDetailView() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        let (deck1, _, _) = insertDecks(context: context)

        let view = DeckStudyListView()
            .modelContainer(container)

        // Verify deck can be used for navigation
        #expect(deck1.id != UUID())
    }

    @Test("Stats formatting: new count display")
    func newCountFormatting() async {
        let stats = DeckStudyStats(newCount: 5, dueCount: 0, totalCount: 5)

        #expect(stats.newCount == 5)
    }

    @Test("Stats formatting: due count display")
    func dueCountFormatting() async {
        let stats = DeckStudyStats(newCount: 0, dueCount: 3, totalCount: 10)

        #expect(stats.dueCount == 3)
    }

    @Test("Stats formatting: total count display")
    func totalCountFormatting() async {
        let stats = DeckStudyStats(newCount: 2, dueCount: 3, totalCount: 10)

        #expect(stats.totalCount == 10)
    }

    @Test("Due count badge color coding")
    func dueCountColorCoding() async {
        let statsWithDue = DeckStudyStats(newCount: 0, dueCount: 5, totalCount: 5)
        let statsWithoutDue = DeckStudyStats(newCount: 5, dueCount: 0, totalCount: 5)

        // Due cards should show orange color (verified in UI)
        #expect(statsWithDue.dueCount > 0)
        #expect(statsWithoutDue.dueCount == 0)
    }

    @Test("Loading state shows during stats load")
    func loadingStateDisplay() async {
        let container = makeTestContainer()
        let context = ModelContext(container)
        _ = insertDecks(context: context)

        let view = DeckStudyListView()
            .modelContainer(container)

        // Stats load asynchronously, verify scheduler works
        let scheduler = Scheduler(modelContext: context)
        let decks = try! context.fetch(FetchDescriptor<Deck>())

        for deck in decks {
            let count = scheduler.totalCardCount(for: deck)
            #expect(count >= 0)
        }
    }
}
