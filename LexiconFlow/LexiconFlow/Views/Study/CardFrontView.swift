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
            Text(card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Word: \(card.word)")

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
                            speakWord()
                        } label: {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .symbolEffect(.pulse, options: .repeating, isActive: isSpeaking)
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
        isSpeaking = true
        SpeechService.shared.speak(card.word)

        // Reset after estimated duration (roughly 0.1s per character)
        let estimatedDuration = Double(card.word.count) * 0.1
        Task {
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1000000000))
            await MainActor.run {
                isSpeaking = false
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
