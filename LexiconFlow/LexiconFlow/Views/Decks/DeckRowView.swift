//
//  DeckRowView.swift
//  LexiconFlow
//
//  Single deck display in list
//

import SwiftData
import SwiftUI

struct DeckRowView: View {
    @Bindable var deck: Deck
    let dueCount: Int

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon
            Image(systemName: self.deck.icon ?? "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(self.deck.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(self.deck.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if self.dueCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)

                        Text("\(self.dueCount) due")
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
