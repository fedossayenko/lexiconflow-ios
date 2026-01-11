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
    @Query(filter: #Predicate<Flashcard> { $0.deck == nil }) private var orphanedCards: [Flashcard]
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

    /// PERFORMANCE: Memoized scheduler to avoid repeated allocations during rapid scrolling
    @State private var scheduler: Scheduler?

    /// Deck deletion confirmation state
    @State private var deckToDelete: Deck?
    @State private var showingDeleteConfirmation = false

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
                            guard let lastVisibleDeck = decks.prefix(visibleCount).last,
                                  deck.id == lastVisibleDeck.id else { return }
                            self.loadMoreIfNeeded()
                        }
                    }
                    .onDelete(perform: self.initiateDeckDeletion)

                    // Orphaned Cards Section (shown when orphans exist)
                    if !self.orphanedCards.isEmpty {
                        Section {
                            NavigationLink(destination: OrphanedCardsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.badge.questionmark")
                                        .foregroundStyle(.orange)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Orphaned Cards")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("\(self.orphanedCards.count) card\(self.orphanedCards.count == 1 ? "" : "s") need reassignment")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text("Unassigned Cards")
                        }
                    }
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
            .onAppear {
                self.loadDeckDueCounts()
            }
            .onChange(of: self.decks) { _, _ in
                self.loadDeckDueCounts()
            }
            .alert("Delete Deck?", isPresented: self.$showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    self.deckToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete {
                        self.performDeckDeletion(deck)
                        self.deckToDelete = nil
                    }
                }
            } message: {
                if let deck = deckToDelete {
                    let cardCount = deck.cards.count
                    if cardCount > 0 {
                        Text("Deleting ") + Text("\(deck.name)").bold() + Text(" will create \(cardCount) orphaned card\(cardCount == 1 ? "" : "s"). Cards will NOT be deleted and will appear in the Orphaned Cards section.")
                    } else {
                        Text("Delete ") + Text("\(deck.name)").bold() + Text("? This action cannot be undone.")
                    }
                }
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

        // Reuse scheduler instance for performance (memoization)
        if self.scheduler == nil {
            self.scheduler = Scheduler(modelContext: self.modelContext)
        }

        let visibleDecksArray = Array(decks.prefix(self.visibleCount))
        let allStats = self.scheduler?.fetchDeckStatistics(for: visibleDecksArray) ?? [:]

        // Extract only due counts
        self.deckDueCounts = allStats.mapValues { $0.due }
        self.countsTimestamp = Date()
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

        // Reload counts when loading more decks
        self.loadDeckDueCounts()
    }

    // MARK: - Deck Deletion

    /// Initiates deck deletion by showing confirmation dialog
    ///
    /// This replaces the immediate deletion behavior with a user-facing
    /// confirmation dialog that explains orphaned card creation.
    private func initiateDeckDeletion(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        guard index >= 0, index < self.decks.count else { return }

        self.deckToDelete = self.decks[index]
        self.showingDeleteConfirmation = true
    }

    /// Performs the actual deck deletion after confirmation
    ///
    /// Deletes the deck and invalidates caches. Cards are preserved as
    /// orphans due to .nullify delete rule.
    private func performDeckDeletion(_ deck: Deck) {
        self.modelContext.delete(deck)

        do {
            try self.modelContext.save()
        } catch {
            Analytics.trackError("deck_deletion", error: error)
        }

        // Invalidate statistics cache after deck deletion
        DeckStatisticsCache.shared.invalidate()
        StatisticsService.shared.invalidateCache()

        Analytics.trackEvent("deck_deleted", metadata: [
            "card_count": String(deck.cards.count),
            "orphaned_created": String(deck.cards.count)
        ])
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
