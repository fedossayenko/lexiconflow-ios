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
        .cornerRadius(20)
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
