//
//  DeckStudyListView.swift
//  LexiconFlow
//
//  Deck-centric study view: Lists all decks with study statistics
//

import SwiftData
import SwiftUI

struct DeckStudyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.order, animation: .default) private var decks: [Deck]

    @State private var deckStats: [Deck.ID: DeckStudyStats] = [:]
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if self.decks.isEmpty {
                    self.emptyStateView
                } else {
                    self.deckList
                }
            }
            .navigationTitle("Decks")
            .task {
                self.isLoading = true
                await self.refreshDeckStats()
                self.isLoading = false
            }
            .overlay {
                if self.isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Decks", systemImage: "square.stack.3d.up")
        } description: {
            Text("Create a deck to start learning vocabulary")
        } actions: {
            NavigationLink("Create Deck") {
                AddDeckView()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var deckList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(self.decks) { deck in
                    NavigationLink(value: deck) {
                        DeckStudyRow(
                            deck: deck,
                            stats: self.deckStats[deck.id] ?? DeckStudyStats()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Deck.self) { deck in
            DeckStudyDetailView(deck: deck)
        }
    }

    private func refreshDeckStats() async {
        let scheduler = Scheduler(modelContext: modelContext)

        for deck in self.decks {
            let newCount = scheduler.newCardCount(for: deck)
            let dueCount = scheduler.dueCardCount(for: deck)
            let totalCount = scheduler.totalCardCount(for: deck)

            self.deckStats[deck.id] = DeckStudyStats(
                newCount: newCount,
                dueCount: dueCount,
                totalCount: totalCount
            )
        }
    }
}

// MARK: - Supporting Types

struct DeckStudyRow: View {
    let deck: Deck
    let stats: DeckStudyStats

    // MARK: - Computed Properties

    /// Calculate progress ratio (due/total), clamped to 0-1
    private var progressRatio: Double {
        guard self.stats.totalCount > 0 else { return 0 }
        return min(max(Double(self.stats.dueCount) / Double(self.stats.totalCount), 0), 1)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon with progress ring (UNIFIED)
            Image(systemName: self.deck.icon ?? "folder.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
                .glassEffectUnion(
                    progress: self.progressRatio,
                    thickness: .regular,
                    iconSize: 50
                )
                .accessibilityLabel("Deck: \(self.deck.name)")
                .accessibilityValue("\(self.stats.dueCount) of \(self.stats.totalCount) cards due")

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(self.deck.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Label("\(self.stats.newCount) new", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Label("\(self.stats.dueCount) due", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(self.stats.dueCount > 0 ? .orange : .secondary)
                }
            }

            Spacer()

            // Total count badge (reduced emphasis since progress is now visual)
            Text("\(self.stats.totalCount)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deck: \(self.deck.name)")
        .accessibilityHint("Tap to view deck details")
        .accessibilityValue("\(self.stats.totalCount) cards, \(self.stats.newCount) new, \(self.stats.dueCount) due")
    }
}

#Preview {
    DeckStudyListView()
        .modelContainer(for: [Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
