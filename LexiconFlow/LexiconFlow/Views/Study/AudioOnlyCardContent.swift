//
//  AudioOnlyCardContent.swift
//  LexiconFlow
//
//  Audio-only card content component for listening comprehension
//

import SwiftUI

/// Audio-only card content that hides text initially and reveals it after TTS playback
///
/// **Pedagogical Purpose**: Trains listening comprehension without visual crutch
/// **Cognitive Target**: Auditory cortex (Heschl's gyrus) → Wernicke's area
///
/// **User Flow**:
/// 1. Card appears with animated speaker icon
/// 2. TTS speaks the word
/// 3. Text fades in after audio completes
/// 4. User can rate their recall
struct AudioOnlyCardContent: View {
    // MARK: - TTS Timing Constants

    /// Time (seconds) per character for TTS duration estimation
    /// Based on average speech rate of ~130-150 words per minute
    private static let secondsPerCharacter: Double = 0.12

    /// Buffer time (seconds) added to TTS duration for natural pause
    /// Accounts for voice pauses and synthesis latency
    private static let bufferSeconds: Double = 0.5

    // MARK: - Properties

    let card: Flashcard
    @State private var revealText = false
    @State private var isSpeaking = false

    /// Detect language based on card type
    /// - Reverse cards use Russian, others use user's TTS setting
    private var speechLanguage: String {
        switch self.card.cardType {
        case .reverse:
            "ru-RU" // Russian for reverse cards
        case .forward, .audio:
            AppSettings.ttsVoiceLanguage // User setting for forward/audio
        }
    }

    /// The word to speak (direction-aware)
    private var wordToSpeak: String {
        switch self.card.cardType {
        case .forward:
            self.card.word
        case .reverse:
            self.card.translation ?? self.card.word
        case .audio:
            self.card.word
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Card type badge
            HStack(spacing: 6) {
                Image(systemName: self.card.cardType.iconName)
                    .font(.caption2)
                Text(self.card.cardType.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Card type: \(self.card.cardType.displayName)")

            // Speaker icon with animation
            Image(systemName: self.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .font(.system(size: 60))
                .symbolEffect(.pulse, options: .repeating, isActive: self.isSpeaking)
                .foregroundStyle(.secondary)

            // Text (reveals after audio completes)
            if self.revealText {
                Text(self.wordToSpeak)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityLabel("Word: \(self.wordToSpeak)")
            }

            // Audio indicator badge
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                Text("Audio-Only")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.secondary.opacity(0.1))
            .clipShape(Capsule())

            Spacer()

            // Tap hint (only after text revealed)
            if self.revealText {
                Text("Tap to reveal answer")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            self.playAudio()
        }
    }

    // MARK: - Audio Playback

    /// Play audio and reveal text after completion
    private func playAudio() {
        guard AppSettings.ttsEnabled else {
            // If TTS is disabled, reveal text immediately
            withAnimation(.easeInOut(duration: 0.3)) {
                self.revealText = true
            }
            return
        }

        self.isSpeaking = true
        SpeechService.shared.speak(self.wordToSpeak, language: self.speechLanguage)

        // Calculate duration and reveal text (TTS timing constants)
        let duration = Double(self.wordToSpeak.count) * Self.secondsPerCharacter + Self.bufferSeconds

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.revealText = true
                    self.isSpeaking = false
                }
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
    card.cardType = .audio

    return AudioOnlyCardContent(card: card)
        .frame(height: 400)
        .background(Color(.systemBackground))
}
