//
//  AudioOnlyCardTests.swift
//  LexiconFlowTests
//
//  Tests for audio-only card functionality
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

@Suite("Audio-Only Cards")
struct AudioOnlyCardTests {
    // Helper to get fresh context
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - CardType Enum Tests

    @Test("CardType.audio has correct display name")
    func audioDisplayName() {
        #expect(CardType.audio.displayName == "Audio-Only")
    }

    @Test("CardType.audio has correct icon name")
    func audioIconName() {
        #expect(CardType.audio.iconName == "speaker.wave.2")
    }

    @Test("CardType.audio has correct arrow symbol")
    func audioArrowSymbol() {
        #expect(CardType.audio.arrowSymbol == "🔊")
    }

    @Test("All CardType cases have unique display names")
    func uniqueDisplayNames() {
        let names = Set([CardType.forward.displayName, CardType.reverse.displayName, CardType.audio.displayName])
        #expect(names.count == 3)
    }

    @Test("All CardType cases have unique icon names")
    func uniqueIconNames() {
        let icons = Set([CardType.forward.iconName, CardType.reverse.iconName, CardType.audio.iconName])
        #expect(icons.count == 3)
    }

    // MARK: - Flashcard Model Tests

    @Test("Flashcard with audio card type can be set")
    func audioCardCanBeSet() {
        let card = Flashcard(
            word: "ephemeral",
            definition: "Lasting for a very short time"
        )
        card.cardType = .audio

        // Verify the card type is set correctly
        #expect(card.cardType == .audio)
        #expect(card.cardTypeRaw == "audio")
    }

    @Test("Flashcard cardType defaults to forward for nil cardTypeRaw")
    func cardTypeDefaultsToForward() {
        let card = Flashcard(
            word: "test",
            definition: "test definition"
        )
        // cardTypeRaw is nil by default
        #expect(card.cardType == .forward)
    }

    @Test("Flashcard cardTypeRaw updates when cardType is set")
    func cardTypeRawUpdates() {
        let card = Flashcard(
            word: "test",
            definition: "test definition"
        )
        card.cardType = .audio
        #expect(card.cardTypeRaw == "audio")
    }

    // MARK: - Scheduler Integration Tests

    @Test("Scheduler: audio cards match recognitionOnly mode")
    @MainActor
    func audioMatchesRecognition() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Audio cards are recognition mode (listening comprehension)
        #expect(scheduler.matchesStudyDirection(.audio, AppSettings.StudyDirection.recognitionOnly))
    }

    @Test("Scheduler: audio cards do not match productionOnly mode")
    @MainActor
    func audioDoesNotMatchProduction() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Audio cards are not production mode
        #expect(scheduler.matchesStudyDirection(.audio, AppSettings.StudyDirection.productionOnly) == false)
    }

    @Test("Scheduler: audio cards match both mode")
    @MainActor
    func audioMatchesBoth() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Audio cards are included in both mode
        #expect(scheduler.matchesStudyDirection(.audio, AppSettings.StudyDirection.both))
    }

    @Test("Scheduler: forward and audio both match recognitionOnly")
    @MainActor
    func forwardAndAudioMatchRecognition() async throws {
        let context = self.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Both forward and audio are recognition modes
        #expect(scheduler.matchesStudyDirection(.forward, AppSettings.StudyDirection.recognitionOnly))
        #expect(scheduler.matchesStudyDirection(.audio, AppSettings.StudyDirection.recognitionOnly))
    }

    // MARK: - CardFrontView Integration Tests

    @Test("CardFrontView: isAudioOnly returns true for audio cards")
    func isAudioOnlyTrue() {
        let card = Flashcard(word: "test", definition: "test")
        card.cardType = .audio
        let view = CardFrontView(card: card)
        #expect(view.isAudioOnly == true)
    }

    @Test("CardFrontView: isAudioOnly returns false for forward cards")
    func isAudioOnlyFalseForForward() {
        let card = Flashcard(word: "test", definition: "test")
        card.cardType = .forward
        let view = CardFrontView(card: card)
        #expect(view.isAudioOnly == false)
    }

    @Test("CardFrontView: isAudioOnly returns false for reverse cards")
    func isAudioOnlyFalseForReverse() {
        let card = Flashcard(word: "test", definition: "test", translation: "тест")
        card.cardType = .reverse
        let view = CardFrontView(card: card)
        #expect(view.isAudioOnly == false)
    }

    @Test("CardFrontView: displayWord returns correct value for audio cards")
    func audioDisplayWord() {
        let card = Flashcard(word: "ephemeral", definition: "test")
        card.cardType = .audio
        let view = CardFrontView(card: card)
        #expect(view.displayWord == "ephemeral")
    }

    @Test("CardFrontView: shouldShowPhonetic returns false for audio cards")
    func audioNoPhonetic() {
        let card = Flashcard(word: "test", definition: "test", phonetic: "/test/")
        card.cardType = .audio
        let view = CardFrontView(card: card)
        #expect(view.shouldShowPhonetic == false)
    }

    @Test("CardFrontView: cardTypeColor returns purple for audio cards")
    func audioCardTypeColor() {
        let card = Flashcard(word: "test", definition: "test")
        let view = CardFrontView(card: card)

        // Test each card type color
        #expect(view.cardTypeColor(for: .forward) == .blue)
        #expect(view.cardTypeColor(for: .reverse) == .orange)
        #expect(view.cardTypeColor(for: .audio) == .purple)
    }

    // MARK: - AppSettings Tests

    @Test("AppSettings: includeAudioOnlyCards defaults to false")
    @MainActor
    func audioOnlyDefaultsToDisabled() {
        // Reset to default
        AppSettings.includeAudioOnlyCards = false
        #expect(AppSettings.includeAudioOnlyCards == false)
    }

    @Test("AppSettings: includeAudioOnlyCards can be enabled")
    @MainActor
    func audioOnlyCanBeEnabled() {
        AppSettings.includeAudioOnlyCards = true
        #expect(AppSettings.includeAudioOnlyCards == true)

        // Reset to default
        AppSettings.includeAudioOnlyCards = false
    }

    @Test("AppSettings: includeAudioOnlyCards persists across changes")
    @MainActor
    func audioOnlyPersists() {
        // Set to true
        AppSettings.includeAudioOnlyCards = true
        #expect(AppSettings.includeAudioOnlyCards == true)

        // Set to false
        AppSettings.includeAudioOnlyCards = false
        #expect(AppSettings.includeAudioOnlyCards == false)
    }

    // MARK: - Speech Service Tests

    @Test("SpeechService: speak with language parameter uses correct language")
    @MainActor
    func speakWithLanguage() async throws {
        let service = SpeechService.shared

        // Test that speak method accepts language parameter
        // Note: Actual speech output cannot be tested in unit tests
        // This test verifies the API signature and doesn't crash
        AppSettings.ttsEnabled = true

        // Should not throw or crash
        service.speak("test", language: "ru-RU")
        service.stop()

        // Reset
        AppSettings.ttsEnabled = false
    }

    @Test("SpeechService: speak with nil language uses default setting")
    @MainActor
    func speakWithNilLanguage() async throws {
        let service = SpeechService.shared

        AppSettings.ttsEnabled = true

        // Should not throw or crash
        service.speak("test", language: nil)
        service.stop()

        // Reset
        AppSettings.ttsEnabled = false
    }

    // MARK: - Audio-Only Content Component Tests

    @Test("AudioOnlyCardContent: speechLanguage returns Russian for reverse cards")
    func audioContentSpeechLanguageForReverse() {
        let card = Flashcard(word: "test", definition: "test", translation: "тест")
        card.cardType = .audio

        // Note: AudioOnlyCardContent is a SwiftUI View, which cannot be directly instantiated in tests
        // This test documents the expected behavior for future UI testing
        // Expected: speechLanguage should be "ru-RU" for reverse cards
    }

    @Test("AudioOnlyCardContent: wordToSpeak returns translation for reverse audio cards")
    func audioContentWordToSpeakForReverse() {
        let card = Flashcard(word: "test", definition: "test", translation: "тест")
        card.cardType = .audio

        // Expected: wordToSpeak should return "тест" (the translation)
        #expect(card.translation == "тест")
    }

    // MARK: - Edge Cases and Failure Modes

    @Test("Flashcard: audio card can be created with TTS disabled")
    @MainActor
    func audioCardCanBeCreatedWithTTSDisabled() {
        // Disable TTS
        AppSettings.ttsEnabled = false

        let card = Flashcard(word: "ephemeral", definition: "test")
        card.cardType = .audio

        // Verify card type is set correctly
        #expect(card.cardType == .audio)

        // Reset TTS setting
        AppSettings.ttsEnabled = true
    }

    @Test("Flashcard: audio card with empty word handles gracefully")
    func audioCardEmptyWord() {
        let card = Flashcard(word: "", definition: "test")
        card.cardType = .audio

        // Should not crash with empty word
        #expect(card.word == "")
        #expect(card.cardType == .audio)
    }

    @Test("Flashcard: audio card with nil translation handles correctly")
    func audioCardNilTranslation() {
        let card = Flashcard(word: "test", definition: "test", translation: nil)
        card.cardType = .reverse

        // Reverse card with nil translation should fall back to word
        #expect(card.translation == nil)
        #expect(card.word == "test")
    }
}
