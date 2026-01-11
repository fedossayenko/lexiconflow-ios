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

    /// PERFORMANCE: Cached due counts to avoid running database query on every view render
    /// This is critical for preventing "System gesture gate timed out" errors during scrolling
    @State private var deckDueCounts: [Deck.ID: Int] = [:]
    @State private var countsTimestamp: Date?

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
            .onAppear {
                loadDeckDueCounts()
            }
            .onChange(of: decks) { _, _ in
                loadDeckDueCounts()
            }
        }
    }

    // MARK: - Due Counts Loading

    /// Loads due counts for visible decks with debouncing
    ///
    /// **PERFORMANCE**: Only reloads if 1 second has passed since last load.
    /// This prevents excessive database queries during rapid animations or gestures.
    /// Uses Scheduler.fetchDeckStatistics for efficient batch loading with caching.
    private func loadDeckDueCounts() {
        // Debounce: only reload if 1 second has passed (or on first load)
        if let timestamp = countsTimestamp,
           Date().timeIntervalSince(timestamp) < 1.0
        {
            return
        }

        // Use Scheduler for batch loading with cache support
        let scheduler = Scheduler(modelContext: modelContext)
        let visibleDecksArray = Array(decks.prefix(visibleCount))
        let allStats = scheduler.fetchDeckStatistics(for: visibleDecksArray)

        // Extract only due counts
        deckDueCounts = allStats.mapValues { $0.due }
        countsTimestamp = Date()
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

        // Reload counts when loading more decks
        loadDeckDueCounts()
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < decks.count else { continue }
            modelContext.delete(decks[index])
        }
        // Invalidate statistics cache after deck deletion
        DeckStatisticsCache.shared.invalidate()
        StatisticsService.shared.invalidateCache()
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
