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

    // MARK: - Computed Properties

    /// The word to display based on card type
    /// - Forward (Recognition): English word
    /// - Reverse (Production): Russian translation
    /// - Audio (Audio-Only): English word (hidden initially)
    var displayWord: String {
        switch self.card.cardType {
        case .forward:
            self.card.word
        case .reverse:
            self.card.translation ?? self.card.word
        case .audio:
            self.card.word
        }
    }

    /// The phonetic pronunciation to display (only for forward cards)
    var displayPhonetic: String? {
        self.card.cardType == .forward ? self.card.phonetic : nil
    }

    /// Whether to show phonetic (only for forward cards)
    var shouldShowPhonetic: Bool {
        self.card.cardType == .forward && self.card.phonetic != nil
    }

    /// Whether to show audio-only content
    var isAudioOnly: Bool {
        self.card.cardType == .audio
    }

    var body: some View {
        if self.isAudioOnly {
            AudioOnlyCardContent(card: self.card)
        } else {
            self.standardCardContent
        }
    }

    // MARK: - Standard Card Content

    /// Standard card content for forward and reverse cards
    private var standardCardContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Card type badge (above deck name)
            HStack(spacing: 6) {
                Image(systemName: self.card.cardType.iconName)
                    .font(.caption2)
                Text(self.card.cardType.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(self.cardTypeColor(for: self.card.cardType))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(self.cardTypeColor(for: self.card.cardType).opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Card type: \(self.card.cardType.displayName)")

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

            // Word (direction-aware)
            Text(self.displayWord)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Word: \(self.displayWord)")

            // Phonetic with speaker button (forward cards only)
            if self.shouldShowPhonetic, let phonetic = displayPhonetic {
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
    /// - Forward cards: Speak English word
    /// - Reverse cards: Speak Russian translation
    private func speakWord() {
        self.isSpeaking = true

        // Detect language for reverse cards (Russian)
        let language = self.card.cardType == .reverse ? "ru-RU" : nil
        SpeechService.shared.speak(self.displayWord, language: language)

        // Reset after estimated duration (roughly 0.1s per character)
        let estimatedDuration = Double(displayWord.count) * 0.1
        Task {
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1000000000))
            await MainActor.run {
                self.isSpeaking = false
            }
        }
    }

    // MARK: - Helper Functions

    /// Color for card type badge
    /// Internal for testability
    func cardTypeColor(for type: CardType) -> Color {
        switch type {
        case .forward:
            .blue
        case .reverse:
            .orange
        case .audio:
            .purple
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
