//
//  DeckListView.swift
//  LexiconFlow
//
//  Lists all decks with card counts and due counts
//

import SwiftData
import SwiftUI

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.order) private var decks: [Deck]
    @Query private var states: [FSRSState]
    @State private var showingAddDeck = false

    /// Pre-computed due counts for each deck (O(n) total vs O(n*m) per row)
    private var deckDueCounts: [Deck.ID: Int] {
        let now = Date()
        var counts: [Deck.ID: Int] = [:]

        for state in states {
            guard let card = state.card,
                  let deck = card.deck,
                  state.dueDate <= now,
                  state.stateEnum != FlashcardState.new.rawValue
            else {
                continue
            }
            counts[deck.id, default: 0] += 1
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
                    ForEach(decks) { deck in
                        NavigationLink(destination: DeckDetailView(deck: deck)) {
                            DeckRowView(deck: deck, dueCount: deckDueCounts[deck.id, default: 0])
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
            }
        }
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < decks.count else { continue }
            modelContext.delete(decks[index])
        }
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
