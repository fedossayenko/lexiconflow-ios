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
    /// **PERFORMANCE**: Uses predicate-based filtering to reduce memory footprint.
    /// 1. Filters by due date at database level (reduces dataset from all states to due states only)
    /// 2. Filters by visible decks in-memory (SwiftData limitation: can't query nested relationships)
    ///
    /// This approach reduces memory from O(all cards) to O(due cards) + O(visible decks),
    /// which is typically 10-100x smaller for large collections.
    ///
    /// - Returns: Dictionary mapping deck IDs to due counts
    private var deckDueCounts: [Deck.ID: Int] {
        let now = Date()
        var counts: [Deck.ID: Int] = [:]

        // PERFORMANCE: Only process states for visible decks
        let visibleDecks = Set(decks.prefix(visibleCount).map(\.id))

        // PERFORMANCE: Filter by due date at DATABASE level (most important optimization)
        // This reduces the dataset from all states to only due states (typically 5-20% of total)
        // SwiftData limitation: Can't filter by card.deck relationship in predicate
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                // Only fetch states that are due (database-level filter)
                state.dueDate <= now && state.stateEnum != "new"
            }
        )

        do {
            let dueStates = try modelContext.fetch(stateDescriptor)

            // Filter by visible decks in-memory (SwiftData limitation)
            // Total complexity: O(due_states) instead of O(all_states)
            for state in dueStates {
                guard let card = state.card,
                      let deck = card.deck,
                      visibleDecks.contains(deck.id)
                else {
                    continue
                }

                counts[deck.id, default: 0] += 1
            }
        } catch {
            // Silently fail on fetch error - counts will be 0
        }

        return counts
    }

    var body: some View {
        NavigationStack {
            List {
                if decks.isEmpty {
                    ContentUnavailableView {
                        Label("No Decks", systemImage: "book.fill")
                    } description: {
                        Text("Create your first deck to get started")
                    } actions: {
                        Button("Create Deck") {
                            showingAddDeck = true
                        }
                    }
                } else {
                    // PERFORMANCE: Use prefix to limit initial rendering
                    ForEach(decks.prefix(visibleCount), id: \.id) { deck in
                        NavigationLink(destination: DeckDetailView(deck: deck)) {
                            DeckRowView(deck: deck, dueCount: deckDueCounts[deck.id, default: 0])
                        }
                        // PERFORMANCE: Load more when reaching end of visible list
                        .onAppear {
                            if deck.id == decks.prefix(visibleCount).last?.id {
                                loadMoreIfNeeded()
                            }
                        }
                    }
                    .onDelete(perform: deleteDecks)
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDeck = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDeck) {
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
        let totalCount = decks.count
        // Don't load more if we're already showing all decks
        guard visibleCount < totalCount else { return }

        // Load 50 more decks (or remaining if less than 50)
        let increment = min(50, totalCount - visibleCount)
        visibleCount += increment
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < decks.count else { continue }
            modelContext.delete(decks[index])
        }
        // Invalidate statistics cache after deck deletion
        StatisticsService.shared.invalidateCache()
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
