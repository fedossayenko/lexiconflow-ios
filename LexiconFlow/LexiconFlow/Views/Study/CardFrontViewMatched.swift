//
//  CardFrontViewMatched.swift
//  LexiconFlow
//
//  Front of flashcard with matched geometry effect IDs.
//
//  This view uses matchedGeometryEffect to allow word and phonetic
//  to smoothly animate to new positions when the card flips.
//

import SwiftUI

/// Front of flashcard with matched geometry effect transitions
///
/// **Matched Elements:**
/// - word: Large centered text (animates to top-right on back)
/// - phonetic: Pronunciation below word (stays in similar position on back)
struct CardFrontViewMatched: View {
    @Bindable var card: Flashcard
    var namespace: Namespace.ID

    // MARK: - Matched Geometry IDs

    /// Matched geometry effect identifiers for element transitions
    private enum MatchedID: String {
        case word
        case phonetic
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Deck name (no match - static, doesn't animate)
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

            // Word (matched - moves to top-right on back)
            Text(self.card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .matchedGeometryEffect(id: MatchedID.word.rawValue, in: self.namespace)
                .accessibilityLabel("Word: \(self.card.word)")

            // Phonetic (matched - stays in similar position on back)
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: MatchedID.phonetic.rawValue, in: self.namespace)
                    .accessibilityLabel("Pronunciation: \(phonetic)")
            }

            Spacer()

            // Tap hint (no match - static)
            Text("Tap to reveal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card front")
    }
}

// MARK: - Previews

#Preview("CardFrontViewMatched") {
    struct PreviewWrapper: View {
        @Namespace private var namespace

        let card = Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: "/əˈfem(ə)rəl/"
        )

        var body: some View {
            CardFrontViewMatched(card: card, namespace: namespace)
                .frame(height: 400)
                .background(Color(.systemBackground))
        }
    }

    return PreviewWrapper()
}
