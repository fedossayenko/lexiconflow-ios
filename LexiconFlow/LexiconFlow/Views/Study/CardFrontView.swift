//
//  CardFrontView.swift
//  LexiconFlow
//
//  Front of flashcard showing word and phonetic
//

import SwiftUI

struct CardFrontView: View {
    @Bindable var card: Flashcard

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Deck name (if available)
            if let deck = card.deck {
                Text(deck.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Word
            Text(card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Phonetic
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Tap hint
            Text("Tap to reveal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time",
        phonetic: "/əˈfem(ə)rəl/"
    )
    return CardFrontView(card: card)
        .frame(height: 400)
        .background(Color(.systemBackground))
}
