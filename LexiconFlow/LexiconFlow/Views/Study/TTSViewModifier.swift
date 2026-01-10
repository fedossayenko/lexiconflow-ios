//
//  TTSViewModifier.swift
//  LexiconFlow
//
//  Shared Text-to-Speech timing logic for flashcard views.
//
//  This view modifier encapsulates the TTS auto-play behavior based on user's
//  timing preference, eliminating code duplication across FlashcardView and
//  FlashcardMatchedView.
//
//  **Timing Modes:**
//  - `.onView`: Play pronunciation when card front appears
//  - `.onFlip`: Play pronunciation when card flips to back
//  - `.manual`: Never auto-play (speaker button only)
//
//  **Usage:**
//  ```swift
//  FlashcardView(card: card, isFlipped: $isFlipped)
//      .ttsTiming(for: card, isFlipped: $isFlipped)
//  ```
//

import SwiftData
import SwiftUI

/// View modifier that applies TTS timing logic to any flashcard view
///
/// **Behavior:**
/// - **`.onView`**: Plays when card appears (if front) and when returning to front
/// - **`.onFlip`**: Plays when flipping to back only
/// - **`.manual`**: Never auto-plays
///
/// **Integration:**
/// - Respects `AppSettings.ttsEnabled` master toggle
/// - Uses `SpeechService.shared.speak()` for playback
/// - Safe to call multiple times (idempotent)
struct TTSViewModifier: ViewModifier {
    /// The flashcard containing the word to speak
    let card: Flashcard

    /// Binding to track flip state (determines when to speak)
    @Binding var isFlipped: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                self.handleOnAppear()
            }
            .onChange(of: self.isFlipped) { _, newValue in
                self.handleFlipChange(to: newValue)
            }
    }

    // MARK: - Private Handlers

    /// Handles TTS playback when view appears
    ///
    /// **Logic:**
    /// - Only speaks if TTS is enabled
    /// - Only speaks if viewing front (not flipped)
    /// - Only speaks for `.onView` timing mode
    private func handleOnAppear() {
        guard AppSettings.ttsEnabled else { return }
        guard !self.isFlipped else { return }

        switch AppSettings.ttsTiming {
        case .onView:
            SpeechService.shared.speak(self.card.word)
        case .onFlip, .manual:
            break
        }
    }

    /// Handles TTS playback when flip state changes
    ///
    /// **Logic:**
    /// - Only speaks if TTS is enabled
    /// - `.onView`: Plays when returning to front (isFlipped = false)
    /// - `.onFlip`: Plays when flipping to back (isFlipped = true)
    /// - `.manual`: Never auto-plays
    private func handleFlipChange(to newValue: Bool) {
        guard AppSettings.ttsEnabled else { return }

        switch AppSettings.ttsTiming {
        case .onView:
            // Play when returning to front
            if !newValue {
                SpeechService.shared.speak(self.card.word)
            }
        case .onFlip:
            // Play when flipping to back
            if newValue {
                SpeechService.shared.speak(self.card.word)
            }
        case .manual:
            // Never auto-play
            break
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies TTS timing logic to a flashcard view
    ///
    /// **Parameters:**
    /// - `card`: The flashcard containing the word to speak
    /// - `isFlipped`: Binding to track flip state
    ///
    /// **Returns:** A view with TTS timing modifiers applied
    ///
    /// **Example:**
    /// ```swift
    /// CardFrontView(card: card)
    ///     .ttsTiming(for: card, isFlipped: $isFlipped)
    /// ```
    @MainActor
    func ttsTiming(for card: Flashcard, isFlipped: Binding<Bool>) -> some View {
        self.modifier(TTSViewModifier(card: card, isFlipped: isFlipped))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isFlipped = false

        let card = Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: "/əˈfem(ə)rəl/"
        )

        var body: some View {
            VStack(spacing: 40) {
                Text("TTS Timing Modifier Preview")
                    .font(.title)

                VStack(spacing: 20) {
                    Text("Current Timing: \(AppSettings.ttsTiming.displayName)")
                        .font(.caption)
                    Text("TTS Enabled: \(AppSettings.ttsEnabled ? "Yes" : "No")")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 200)
                    .overlay {
                        Text(isFlipped ? "Back" : "Front")
                            .font(.title)
                    }
                    .ttsTiming(for: card, isFlipped: $isFlipped)

                Button("Toggle Flip") {
                    withAnimation {
                        isFlipped.toggle()
                    }
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
