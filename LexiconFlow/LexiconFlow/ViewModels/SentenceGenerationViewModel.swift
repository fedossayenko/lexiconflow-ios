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
    private let service = SentenceGenerationService.shared

    // MARK: - Computed Properties

    /// Whether this card has any generated sentences
    var hasSentences: Bool {
        !generatedSentences.isEmpty
    }

    /// Non-expired sentences (filtered)
    var validSentences: [GeneratedSentence] {
        generatedSentences.filter { !$0.isExpired }
    }

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            // Call the sentence generation service
            let response = try await service.generateSentences(
                cardWord: card.word,
                cardDefinition: card.definition,
                cardTranslation: card.translation,
                cardCEFR: card.cefrLevel,
                count: sentencesPerCard
            )

            // Store existing sentences for deletion after successful generation
            let existingSentences = card.generatedSentences

            // Create new GeneratedSentence records
            var newSentences: [GeneratedSentence] = []
            for item in response.items {
                let sentence = GeneratedSentence(
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
            let sentence = GeneratedSentence(
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
        }
    }

    // MARK: - Sentence Management

    /// Toggle favorite status of a sentence
    ///
    /// - Parameter sentence: The sentence to toggle
    func toggleFavorite(_ sentence: GeneratedSentence) {
        sentence.isFavorite.toggle()
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            logger.error("Failed to save sentence favorite: \(error.localizedDescription)")
        }
    }

    /// Delete a sentence
    ///
    /// - Parameter sentence: The sentence to delete
    func deleteSentence(_ sentence: GeneratedSentence) {
        modelContext.delete(sentence)
        do {
            try modelContext.save()
            generatedSentences.removeAll { $0.id == sentence.id }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            logger.error("Failed to delete sentence: \(error.localizedDescription)")
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
        }
    }

    /// Load existing sentences for a card
    ///
    /// - Parameter card: The flashcard to load sentences for
    func loadSentences(for card: Flashcard) {
        // Filter out expired sentences
        let valid = card.generatedSentences.filter { !$0.isExpired }
            .sorted { $0.generatedAt > $1.generatedAt }

        // If all expired, clean them up
        if valid.isEmpty && !card.generatedSentences.isEmpty {
            cleanupExpiredSentences(for: card)
        }

        generatedSentences = valid
    }
}
