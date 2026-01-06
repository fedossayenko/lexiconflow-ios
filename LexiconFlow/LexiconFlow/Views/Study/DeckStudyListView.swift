//
//  DeckStudyListView.swift
//  LexiconFlow
//
//  Deck-centric study view: Lists all decks with study statistics
//

import SwiftUI
import SwiftData

struct DeckStudyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.order, animation: .default) private var decks: [Deck]

    @State private var deckStats: [Deck.ID: DeckStudyStats] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyStateView
                } else {
                    deckList
                }
            }
            .navigationTitle("Decks")
            .onAppear {
                refreshDeckStats()
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
                ForEach(decks) { deck in
                    NavigationLink(value: deck) {
                        DeckStudyRow(
                            deck: deck,
                            stats: deckStats[deck.id] ?? DeckStudyStats()
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

    private func refreshDeckStats() {
        let scheduler = Scheduler(modelContext: modelContext)

        for deck in decks {
            let newCount = scheduler.newCardCount(for: deck)
            let dueCount = scheduler.dueCardCount(for: deck)
            let totalCount = scheduler.totalCardCount(for: deck)

            deckStats[deck.id] = DeckStudyStats(
                newCount: newCount,
                dueCount: dueCount,
                totalCount: totalCount
            )
        }
    }
}

// MARK: - Supporting Types

struct DeckStudyStats {
    var newCount: Int = 0
    var dueCount: Int = 0
    var totalCount: Int = 0
}

struct DeckStudyRow: View {
    let deck: Deck
    let stats: DeckStudyStats

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon
            Image(systemName: deck.icon ?? "folder.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: .circle)

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Label("\(stats.newCount) new", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Label("\(stats.dueCount) due", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(stats.dueCount > 0 ? .orange : .secondary)
                }
            }

            Spacer()

            // Total count badge
            Text("\(stats.totalCount)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    DeckStudyListView()
        .modelContainer(for: [Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
