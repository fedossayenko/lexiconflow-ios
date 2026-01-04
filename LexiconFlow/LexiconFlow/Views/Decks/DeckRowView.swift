//
//  DeckRowView.swift
//  LexiconFlow
//
//  Single deck display in list
//

import SwiftUI
import SwiftData

struct DeckRowView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var modelContext
    @Query private var states: [FSRSState]

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon
            Image(systemName: deck.icon ?? "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(deck.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if dueCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)

                        Text("\(dueCount) due")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }
            }

            Spacer()
        }
    }

    /// Computed property that calculates due count reactively
    private var dueCount: Int {
        let now = Date()
        return states.filter { state in
            // Check if this state belongs to a card in this deck
            guard let card = state.card,
                  card.deck?.id == deck.id else {
                return false
            }
            // Check if card is due and not new
            return state.dueDate <= now && state.stateEnum != FlashcardState.new.rawValue
        }.count
    }
}

#Preview {
    let deck = Deck(name: "Sample Deck", icon: "star.fill")
    DeckRowView(deck: deck)
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
