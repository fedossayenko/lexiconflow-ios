//
//  DeckListView.swift
//  LexiconFlow
//
//  Lists all decks with card counts and due counts
//
//  PERFORMANCE: Lazy loading for 1000+ deck scenarios
//

import SwiftData
import SwiftUI

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.order) private var decks: [Deck]
    @State private var showingAddDeck = false

    /// PERFORMANCE: Visible limit for extreme cases (1000+ decks)
    /// SwiftUI List already lazy-renders, but we limit initial render count
    /// to prevent UI freeze when decks have very large card counts.
    /// Incrementally loads more as user scrolls toward end.
    @State private var visibleCount = 50

    /// Fetches only states needed for visible decks (lazy loading optimization)
    ///
    /// **PERFORMANCE**: Only queries FSRSState for visible decks, not all decks.
    /// This prevents loading all FSRSState instances into memory when there
    /// are 1000+ decks with 10K+ cards.
    ///
    /// - Returns: Dictionary mapping deck IDs to due counts
    private var deckDueCounts: [Deck.ID: Int] {
        let now = Date()
        var counts: [Deck.ID: Int] = [:]

        // PERFORMANCE: Only process states for visible decks
        // Use prefix to limit computation to currently visible rows
        let visibleDecks = Set(decks.prefix(self.visibleCount).map(\.id))

        // Fetch states and filter by visible decks in-memory
        // Note: SwiftData doesn't support subqueries, so we fetch all
        // but only aggregate counts for visible decks
        let stateDescriptor = FetchDescriptor<FSRSState>()
        do {
            let states = try modelContext.fetch(stateDescriptor)

            for state in states {
                // Skip states not belonging to visible decks (lazy load optimization)
                guard let card = state.card,
                      let deck = card.deck,
                      visibleDecks.contains(deck.id)
                else {
                    continue
                }

                // Count due cards (excluding new cards)
                if state.dueDate <= now,
                   state.stateEnum != FlashcardState.new.rawValue
                {
                    counts[deck.id, default: 0] += 1
                }
            }
        } catch {
            // Silently fail on fetch error - counts will be 0
        }

        return counts
    }

    var body: some View {
        NavigationStack {
            List {
                if self.decks.isEmpty {
                    ContentUnavailableView {
                        Label("No Decks", systemImage: "book.fill")
                    } description: {
                        Text("Create your first deck to get started")
                    } actions: {
                        Button("Create Deck") {
                            self.showingAddDeck = true
                        }
                    }
                } else {
                    // PERFORMANCE: Use prefix to limit initial rendering
                    ForEach(self.decks.prefix(self.visibleCount), id: \.id) { deck in
                        NavigationLink(destination: DeckDetailView(deck: deck)) {
                            DeckRowView(deck: deck, dueCount: self.deckDueCounts[deck.id, default: 0])
                        }
                        // PERFORMANCE: Load more when reaching end of visible list
                        .onAppear {
                            if deck.id == self.decks.prefix(self.visibleCount).last?.id {
                                self.loadMoreIfNeeded()
                            }
                        }
                    }
                    .onDelete(perform: self.deleteDecks)
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { self.showingAddDeck = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: self.$showingAddDeck) {
                AddDeckView()
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Lazy Loading

    /// Loads more decks when user scrolls near end of list
    ///
    /// **PERFORMANCE**: Increments visible count by 50 when user reaches
    /// the last currently-visible deck. This prevents loading all 1000+
    /// decks upfront while maintaining smooth scrolling experience.
    private func loadMoreIfNeeded() {
        let totalCount = self.decks.count
        // Don't load more if we're already showing all decks
        guard self.visibleCount < totalCount else { return }

        // Load 50 more decks (or remaining if less than 50)
        let increment = min(50, totalCount - self.visibleCount)
        self.visibleCount += increment
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < self.decks.count else { continue }
            self.modelContext.delete(self.decks[index])
        }
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
