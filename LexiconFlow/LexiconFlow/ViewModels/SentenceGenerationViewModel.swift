//
//  SentenceGenerationViewModel.swift
//  LexiconFlow
//
//  Manages AI sentence generation state and operations
//

import SwiftUI
import SwiftData
import OSLog
import Combine

/// ViewModel for managing AI sentence generation for flashcards
@MainActor
final class SentenceGenerationViewModel: ObservableObject {
    /// Logger for sentence generation
    private let logger = Logger(subsystem: "com.lexiconflow.sentences", category: "SentenceGenerationViewModel")

    // MARK: - Published State

    /// Currently generated sentences for display
    @Published var generatedSentences: [GeneratedSentence] = []

    /// Whether sentences are currently being generated
    @Published var isGenerating = false

    /// Current generation message
    @Published var generationMessage: String?

    /// Error message if generation failed
    @Published var errorMessage: String?

    /// Number of sentences to generate per card
    var sentencesPerCard: Int = 3

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let generator: any SentenceGenerationProtocol
    private let service = SentenceGenerationService.shared

    // MARK: - Computed Properties

    /// Whether this card has any generated sentences
    var hasSentences: Bool {
        !generatedSentences.isEmpty
    }

    /// Non-expired sentences (filtered)
    ///
    /// Thread-safe: Captures current date once for consistent filtering
    var validSentences: [GeneratedSentence] {
        let now = Date()
        return generatedSentences.filter { $0.expiresAt > now }
    }

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        generator: (any SentenceGenerationProtocol)? = nil
    ) {
        self.modelContext = modelContext
        self.generator = generator ?? ProductionSentenceGenerator()
    }

    // MARK: - Sentence Generation

    /// Generate sentences for a flashcard
    ///
    /// - Parameter card: The flashcard to generate sentences for
    func generateSentences(for card: Flashcard) async {
        isGenerating = true
        generationMessage = "Generating sentences..."
        errorMessage = nil

        do {
            // Call the sentence generation protocol
            // Note: CEFR level is no longer stored on Flashcard, generator will infer it
            let response = try await generator.generateSentences(
                for: card.word,
                definition: card.definition,
                translation: card.translation,
                cefrLevel: nil,  // Generator will infer CEFR level
                count: sentencesPerCard
            )

            // Store existing sentences for deletion after successful generation
            let existingSentences = card.generatedSentences

            // Create new GeneratedSentence records
            var newSentences: [GeneratedSentence] = []
            for item in response.items {
                let sentence = try GeneratedSentence(
                    sentenceText: item.sentence,
                    cefrLevel: item.cefrLevel,
                    generatedAt: Date(),
                    ttlDays: 7,
                    isFavorite: false,
                    source: .aiGenerated
                )
                sentence.flashcard = card
                modelContext.insert(sentence)
                newSentences.append(sentence)
            }

            // Delete old sentences only after new ones are created successfully
            for sentence in existingSentences {
                modelContext.delete(sentence)
            }

            // Save to SwiftData
            try modelContext.save()

            // Update published state
            generatedSentences = newSentences
            generationMessage = "Generated \(newSentences.count) sentences"

            logger.info("Successfully generated and saved \(newSentences.count) sentences for '\(card.word)'")

        } catch let error as SentenceGenerationError {
            errorMessage = error.localizedDescription
            generationMessage = nil
            logger.error("Sentence generation failed: \(error.localizedDescription)")

            // Fall back to static sentences if offline
            if case .offline = error {
                await useStaticFallbackSentences(for: card)
            }

        } catch {
            errorMessage = error.localizedDescription
            generationMessage = nil
            logger.error("Unexpected error during sentence generation: \(error.localizedDescription)")
            Analytics.trackError("sentence_generation_unexpected", error: error)
        }

        isGenerating = false
    }

    /// Use static fallback sentences (offline mode)
    private func useStaticFallbackSentences(for card: Flashcard) async {
        let fallbacks = await service.getStaticFallbackSentences(for: card.word)

        // Clear existing and create static sentences
        let existingSentences = card.generatedSentences
        for sentence in existingSentences {
            modelContext.delete(sentence)
        }

        var newSentences: [GeneratedSentence] = []
        for fallback in fallbacks {
            do {
                let sentence = try GeneratedSentence(
                    sentenceText: fallback.sentence,
                    cefrLevel: fallback.cefrLevel,
                    generatedAt: Date(),
                    ttlDays: 7,
                    isFavorite: false,
                    source: .staticFallback
                )
                sentence.flashcard = card
                modelContext.insert(sentence)
                newSentences.append(sentence)
            } catch {
                logger.error("Failed to create fallback sentence: \(error.localizedDescription)")
                // Skip invalid sentence and continue
                continue
            }
        }

        do {
            try modelContext.save()
            generatedSentences = newSentences
            generationMessage = "\(newSentences.count) offline sentences (no API)"
            errorMessage = "Offline mode - using fallback sentences"
            logger.info("Used \(newSentences.count) static fallback sentences for '\(card.word)'")
        } catch {
            logger.error("Failed to save fallback sentences: \(error.localizedDescription)")
            errorMessage = "Failed to save offline sentences"
            Analytics.trackError("save_fallback_sentences_failed", error: error)
        }
    }

    // MARK: - Sentence Management

    /// Toggle favorite status of a sentence
    ///
    /// - Parameter sentence: The sentence to toggle
    func toggleFavorite(_ sentence: GeneratedSentence) {
        let oldValue = sentence.isFavorite
        sentence.isFavorite.toggle()

        do {
            try modelContext.save()
        } catch {
            // ROLLBACK on failure - UI and database must stay in sync
            sentence.isFavorite = oldValue
            errorMessage = "Failed to save: \(error.localizedDescription)"
            logger.error("Failed to save sentence favorite: \(error.localizedDescription)")
            Analytics.trackError("toggle_favorite_failed", error: error)
        }
    }

    /// Delete a sentence
    ///
    /// - Parameter sentence: The sentence to delete
    func deleteSentence(_ sentence: GeneratedSentence) {
        // Save for error tracking (can't rollback delete)
        let sentenceID = sentence.id

        modelContext.delete(sentence)

        do {
            try modelContext.save()
            generatedSentences.removeAll { $0.id == sentenceID }
        } catch {
            // Can't rollback delete, but should log and notify user
            logger.error("Failed to delete sentence \(sentenceID): \(error.localizedDescription)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            Analytics.trackError("delete_sentence_failed", error: error)
        }
    }

    /// Clean up expired sentences
    func cleanupExpiredSentences(for card: Flashcard) {
        let expired = card.generatedSentences.filter { $0.isExpired }
        for sentence in expired {
            modelContext.delete(sentence)
        }
        do {
            try modelContext.save()
            generatedSentences.removeAll { $0.isExpired }
            logger.info("Cleaned up \(expired.count) expired sentences for '\(card.word)'")
        } catch {
            logger.error("Failed to cleanup expired sentences: \(error.localizedDescription)")
            Analytics.trackError("cleanup_expired_sentences_failed", error: error)
        }
    }

    /// Load existing sentences for a card
    ///
    /// - Parameter card: The flashcard to load sentences for
    func loadSentences(for card: Flashcard) {
        // Capture timestamp once for consistent filtering
        let now = Date()
        let valid = card.generatedSentences.filter { $0.expiresAt > now }
            .sorted { $0.generatedAt > $1.generatedAt }

        // If all expired, clean them up
        if valid.isEmpty && !card.generatedSentences.isEmpty {
            cleanupExpiredSentences(for: card)
        }

        generatedSentences = valid
    }
}
