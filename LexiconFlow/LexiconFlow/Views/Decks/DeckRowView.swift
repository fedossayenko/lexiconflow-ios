//
//  DeckRowView.swift
//  LexiconFlow
//
//  Single deck display in list
//
//  Uses glass effect for "Liquid Glass" UI design
//  Performance optimized with .drawingGroup() for 120Hz ProMotion
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        // Apply glass effect for "Liquid Glass" design
        // Performance optimized: .drawingGroup() in GlassEffectModifier caches blurred background as Metal texture
        .glassEffect(.regular, cornerRadius: 12)
    }
}

#Preview {
    let deck = Deck(name: "Sample Deck", icon: "star.fill")
    DeckRowView(deck: deck, dueCount: 5)
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
