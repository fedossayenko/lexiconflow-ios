//
//  FlashcardView.swift
//  LexiconFlow
//
//  Displays card with tap-to-flip animation
//

import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    /// Determines opacity based on FSRS stability.
    ///
    /// Visualizes memory strength through opacity:
    /// - Low opacity (fragile) for low stability (< 10)
    /// - Medium opacity for medium stability (10-50)
    /// - High opacity (stable) for high stability (> 50)
    private var cardOpacity: Double {
        guard let stability = card.fsrsState?.stability else {
            return 0.7 // Default to lower opacity for new cards
        }

        if stability < 10 {
            return 0.7
        } else if stability <= 50 {
            return 0.85
        } else {
            return 0.95
        }
    }

    var body: some View {
        ZStack {
            if isFlipped {
                CardBackView(card: card)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            } else {
                CardFrontView(card: card)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .background(Color(.systemBackground))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .opacity(cardOpacity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10, y: 5)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFlipped.toggle()
            }
        }
        .accessibilityLabel(isFlipped ? "Card back showing definition" : "Card front showing word")
        .accessibilityHint("Double tap to flip card")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("flashcard")
    }
}

#Preview {
    FlashcardView(
        card: Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: "/əˈfem(ə)rəl/"
        ),
        isFlipped: .constant(false)
    )
    .padding()
}
