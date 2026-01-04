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
    let dueCount: Int

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
}

#Preview {
    let deck = Deck(name: "Sample Deck", icon: "star.fill")
    DeckRowView(deck: deck, dueCount: 5)
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
