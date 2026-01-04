//
//  DeckListView.swift
//  LexiconFlow
//
//  Lists all decks with card counts and due counts
//

import SwiftUI
import SwiftData

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.order) private var decks: [Deck]
    @State private var showingAddDeck = false

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
                            DeckRowView(deck: deck)
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
            modelContext.delete(decks[index])
        }
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
