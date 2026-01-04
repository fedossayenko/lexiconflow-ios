//
//  DeckDetailView.swift
//  LexiconFlow
//
//  Shows deck details and lists all cards in the deck
//

import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddCard = false

    var body: some View {
        List {
            if deck.cards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle")
                } description: {
                    Text("Add flashcards to this deck to get started")
                } actions: {
                    Button("Add Card") {
                        showingAddCard = true
                    }
                }
            } else {
                Section {
                    ForEach(deck.cards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.word)
                                .font(.headline)

                            Text(card.definition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteCards)
                } header: {
                    Text("Flashcards (\(deck.cards.count))")
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddCard = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddFlashcardView(deck: deck)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0 && index < deck.cards.count else { continue }
            modelContext.delete(deck.cards[index])
        }
    }
}

#Preview("Deck Detail") {
    NavigationStack {
        DeckDetailView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
    }
    .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
