//
//  CardFrontView.swift
//  LexiconFlow
//
//  Front of flashcard showing word and phonetic
//

import SwiftUI

struct CardFrontView: View {
    @Bindable var card: Flashcard

    // MARK: - Animation State

    /// Controls the blur radius for the blur-into-glass effect
    @State private var blurRadius: CGFloat = 0

    /// Controls the content opacity for smooth morphing transitions
    @State private var contentOpacity: Double = 1

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
                    .accessibilityLabel("Deck: \(deck.name)")
            }

            // Word
            Text(card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Word: \(card.word)")

            // Phonetic
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pronunciation: \(phonetic)")
            }

            Spacer()

            // Tap hint
            Text("Tap to reveal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .blur(radius: blurRadius)
        .opacity(contentOpacity)
        .onAppear {
            // Animate from glass blur to clear on appearance
            withAnimation(.easeOut(duration: 0.4)) {
                blurRadius = 0
                contentOpacity = 1
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card front")
    }

    // MARK: - Transition Animation

    /// Prepares the view for the blur-into-glass transition effect.
    ///
    /// When the card is about to be removed (flipped to back), this method
    /// animates the blur radius and opacity to create a morphing effect where
    /// the content blurs into glass before disappearing.
    func prepareForTransition() {
        withAnimation(.easeIn(duration: 0.3)) {
            blurRadius = 20
            contentOpacity = 0.6
        }
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
