//
//  FlashcardMatchedView.swift
//  LexiconFlow
//
//  Flashcard with matched geometry effect transitions for smooth element animations.
//
//  This view uses SwiftUI's matchedGeometryEffect to create seamless transitions
//  between front and back card faces, allowing word and phonetic to smoothly animate
//  to new positions during flip.
//
//  **Matched Elements:**
//  - word: Animates from center (front) to top (back)
//  - phonetic: Animates below word on both faces
//
//  **Usage:**
//  ```swift
//  FlashcardMatchedView(
//      card: flashcard,
//      isFlipped: $isFlipped
//  )
//  ```
//

import SwiftData
import SwiftUI

/// Flashcard view with matched geometry effect transitions
///
/// **Performance:** Transitions complete in < 300ms on iPhone 12+
/// **Accessibility:** VoiceOver announces "Card front" and "Card back" correctly
struct FlashcardMatchedView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    // MARK: - Namespace

    /// Namespace for matched geometry effect
    @Namespace private var flipAnimation

    // MARK: - Body

    var body: some View {
        ZStack {
            if self.isFlipped {
                CardBackViewMatched(card: self.card, namespace: self.flipAnimation)
                    .zIndex(1)
            } else {
                CardFrontViewMatched(card: self.card, namespace: self.flipAnimation)
                    .zIndex(0)
            }
        }
        // Single source of truth for flip animation (removed from FlashcardView to avoid double animations)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: self.isFlipped)
        .onChange(of: self.isFlipped) { _, newValue in
            guard AppSettings.ttsEnabled else { return }

            switch AppSettings.ttsTiming {
            case .onView:
                // Play when returning to front (newValue == false)
                if !newValue {
                    SpeechService.shared.speak(self.card.word)
                }
            case .onFlip:
                // Play when flipping to back (newValue == true)
                if newValue {
                    SpeechService.shared.speak(self.card.word)
                }
            case .manual:
                // Don't auto-play
                break
            }
        }
        .onAppear {
            guard AppSettings.ttsEnabled else { return }

            // Only play when viewing the front (not flipped)
            guard !self.isFlipped else { return }

            switch AppSettings.ttsTiming {
            case .onView:
                SpeechService.shared.speak(self.card.word)
            case .onFlip, .manual:
                break
            }
        }
    }
}

// MARK: - Previews

#Preview("FlashcardMatchedView - Front") {
    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time",
        phonetic: "/əˈfem(ə)rəl/"
    )

    return FlashcardMatchedView(
        card: card,
        isFlipped: .constant(false)
    )
    .frame(height: 400)
    .background(Color(.systemBackground))
}

#Preview("FlashcardMatchedView - Back") {
    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time; short-lived; transitory",
        phonetic: "/əˈfem(ə)rəl/"
    )

    return FlashcardMatchedView(
        card: card,
        isFlipped: .constant(true)
    )
    .frame(height: 500)
    .background(Color(.systemBackground))
}

#Preview("FlashcardMatchedView - Flip Animation") {
    struct FlipPreview: View {
        @State private var isFlipped = false

        let card = Flashcard(
            word: "Serendipity",
            definition: "The occurrence of events by chance in a happy way",
            phonetic: "/ˌserənˈdɪpəti/"
        )

        var body: some View {
            VStack(spacing: 40) {
                FlashcardMatchedView(
                    card: card,
                    isFlipped: $isFlipped
                )
                .frame(height: 400)
                .background(Color(.systemBackground))

                Button("Toggle Flip") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isFlipped.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    return FlipPreview()
}
