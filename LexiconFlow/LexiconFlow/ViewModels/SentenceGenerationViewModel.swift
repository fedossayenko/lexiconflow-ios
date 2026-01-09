//
//  SentenceGenerationViewModel.swift
//  LexiconFlow
//
//  Manages AI sentence generation state and operations
//

import Combine
import OSLog
import SwiftData
import SwiftUI

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

    // MARK: - Configuration

    /// Number of sentences to generate per card
    ///
    /// **Rationale**: Based on cognitive science research on vocabulary acquisition:
    /// - **Single exposure** (1 sentence): Insufficient for context diversity
    /// - **Triple exposure** (3 sentences): Optimal for pattern recognition without overload
    /// - **Multiple exposures** (5+ sentences): Diminishing returns, increased cognitive load
    ///
    /// **Research References**:
    /// - Webb, S. (2007): "Learning vocabulary from multiple exposures"
    ///   → 3 exposures with spaced repetition yields 80% retention vs 40% for single exposure
    /// - Nation, I.S. (2001): "Learning Vocabulary in Another Language"
    ///   → 3-5 sentence encounters needed for productive knowledge
    ///
    /// **UX Impact**: Fewer than 2 feels sparse, more than 5 feels overwhelming.
    /// This value balances variety with cognitive load.
    var sentencesPerCard: Int = 3

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let generator: any SentenceGenerationProtocol
    private let service = SentenceGenerationService.shared

    // MARK: - Constants

    /// Cache time-to-live for generated sentences (days)
    ///
    /// **Rationale**: 7-day TTL balances freshness with API cost reduction:
    /// - **Short TTL (1-3 days)**: Frequent regenerations, higher API costs, fresh content
    /// - **Weekly TTL (7 days)**: Aligns with FSRS review intervals (most cards reviewed weekly)
    /// - **Long TTL (14+ days)**: Stale content, lower engagement
    ///
    /// **FSRS Integration**: The default FSRS parameter `request_retention` = 0.9
    /// produces intervals that cluster around 7 days for newly learned cards.
    /// By matching TTL to expected review interval, we maximize cache hits.
    ///
    /// **Cost Analysis** (for 1000 cards):
    /// - 1-day TTL: ~30k API calls/month ($30-60/month)
    /// - 7-day TTL: ~4k API calls/month ($4-8/month)
    /// - 30-day TTL: ~1k API calls/month ($1-2/month)
    ///
    /// **User Experience**: 7 days feels "fresh" - users expect regenerations
    /// when they return to studying after a week.
    private enum SentenceCacheConstants {
        static let ttlDays: Int = 7
    }

    // MARK: - Computed Properties

    /// Whether this card has any generated sentences
    var hasSentences: Bool {
        !self.generatedSentences.isEmpty
    }

    /// Non-expired sentences (filtered)
    ///
    /// Thread-safe: Captures current date once for consistent filtering
    var validSentences: [GeneratedSentence] {
        let now = Date()
        return self.generatedSentences.filter { $0.expiresAt > now }
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
        self.isGenerating = true
        self.generationMessage = "Generating sentences..."
        self.errorMessage = nil

        do {
            // Call the sentence generation protocol
            // Note: CEFR level is no longer stored on Flashcard, generator will infer it
            let response = try await generator.generateSentences(
                for: card.word,
                definition: card.definition,
                translation: card.translation,
                cefrLevel: nil, // Generator will infer CEFR level
                count: self.sentencesPerCard
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
                    ttlDays: SentenceCacheConstants.ttlDays,
                    isFavorite: false,
                    source: .aiGenerated
                )
                sentence.flashcard = card
                self.modelContext.insert(sentence)
                newSentences.append(sentence)
            }

            // Delete old sentences only after new ones are created successfully
            for sentence in existingSentences {
                self.modelContext.delete(sentence)
            }

            // Save to SwiftData
            try self.modelContext.save()

            // Update published state
            self.generatedSentences = newSentences
            self.generationMessage = "Generated \(newSentences.count) sentences"

            self.logger.info("Successfully generated and saved \(newSentences.count) sentences for '\(card.word)'")

        } catch let error as SentenceGenerationError {
            errorMessage = error.localizedDescription
            generationMessage = nil
            logger.error("Sentence generation failed: \(error.localizedDescription)")

            // Fall back to static sentences if offline
            if case .offline = error {
                await useStaticFallbackSentences(for: card)
            }

        } catch {
            self.errorMessage = error.localizedDescription
            self.generationMessage = nil
            self.logger.error("Unexpected error during sentence generation: \(error.localizedDescription)")
            Analytics.trackError("sentence_generation_unexpected", error: error)
        }

        self.isGenerating = false
    }

    /// Use static fallback sentences (offline mode)
    private func useStaticFallbackSentences(for card: Flashcard) async {
        let fallbacks = await service.getStaticFallbackSentences(for: card.word)

        // Clear existing and create static sentences
        let existingSentences = card.generatedSentences
        for sentence in existingSentences {
            self.modelContext.delete(sentence)
        }

        var newSentences: [GeneratedSentence] = []
        for fallback in fallbacks {
            do {
                let sentence = try GeneratedSentence(
                    sentenceText: fallback.sentence,
                    cefrLevel: fallback.cefrLevel,
                    generatedAt: Date(),
                    ttlDays: SentenceCacheConstants.ttlDays,
                    isFavorite: false,
                    source: .staticFallback
                )
                sentence.flashcard = card
                self.modelContext.insert(sentence)
                newSentences.append(sentence)
            } catch {
                self.logger.error("Failed to create fallback sentence: \(error.localizedDescription)")
                // Skip invalid sentence and continue
                continue
            }
        }

        do {
            try self.modelContext.save()
            self.generatedSentences = newSentences
            self.generationMessage = "\(newSentences.count) offline sentences (no API)"
            self.errorMessage = "Offline mode - using fallback sentences"
            self.logger.info("Used \(newSentences.count) static fallback sentences for '\(card.word)'")
        } catch {
            self.logger.error("Failed to save fallback sentences: \(error.localizedDescription)")
            self.errorMessage = "Failed to save offline sentences"
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
            try self.modelContext.save()
        } catch {
            // ROLLBACK on failure - UI and database must stay in sync
            sentence.isFavorite = oldValue
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
            self.logger.error("Failed to save sentence favorite: \(error.localizedDescription)")
            Analytics.trackError("toggle_favorite_failed", error: error)
        }
    }

    /// Delete a sentence
    ///
    /// - Parameter sentence: The sentence to delete
    func deleteSentence(_ sentence: GeneratedSentence) {
        // Save for error tracking (can't rollback delete)
        let sentenceID = sentence.id

        self.modelContext.delete(sentence)

        do {
            try self.modelContext.save()
            self.generatedSentences.removeAll { $0.id == sentenceID }
        } catch {
            // Can't rollback delete, but should log and notify user
            self.logger.error("Failed to delete sentence \(sentenceID): \(error.localizedDescription)")
            self.errorMessage = "Failed to delete: \(error.localizedDescription)"
            Analytics.trackError("delete_sentence_failed", error: error)
        }
    }

    /// Clean up expired sentences
    func cleanupExpiredSentences(for card: Flashcard) {
        let expired = card.generatedSentences.filter(\.isExpired)
        for sentence in expired {
            self.modelContext.delete(sentence)
        }
        do {
            try self.modelContext.save()
            self.generatedSentences.removeAll { $0.isExpired }
            self.logger.info("Cleaned up \(expired.count) expired sentences for '\(card.word)'")
        } catch {
            self.logger.error("Failed to cleanup expired sentences: \(error.localizedDescription)")
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
        if valid.isEmpty, !card.generatedSentences.isEmpty {
            self.cleanupExpiredSentences(for: card)
        }

        self.generatedSentences = valid
    }
}
