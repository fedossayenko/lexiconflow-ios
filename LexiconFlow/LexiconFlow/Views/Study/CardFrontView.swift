//
//  CardFrontView.swift
//  LexiconFlow
//
//  Front of flashcard showing word and phonetic
//

import SwiftUI

struct CardFrontView: View {
    @Bindable var card: Flashcard
    @State private var isSpeaking = false

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
            Text(self.card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Word: \(self.card.word)")

            // Phonetic with speaker button
            if let phonetic = card.phonetic {
                HStack(spacing: 8) {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pronunciation: \(phonetic)")

                    // Speaker button
                    if AppSettings.ttsEnabled {
                        Button {
                            self.speakWord()
                        } label: {
                            Image(systemName: self.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .symbolEffect(.pulse, options: .repeating, isActive: self.isSpeaking)
                        }
                        .accessibilityLabel("Play pronunciation")
                    }
                }
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card front")
    }

    // MARK: - Speech Handlers

    /// Speak the word using text-to-speech
    private func speakWord() {
        self.isSpeaking = true
        SpeechService.shared.speak(self.card.word)

        // Reset after estimated duration (roughly 0.1s per character)
        let estimatedDuration = Double(self.card.word.count) * 0.1
        Task {
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1000000000))
            await MainActor.run {
                self.isSpeaking = false
            }
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
