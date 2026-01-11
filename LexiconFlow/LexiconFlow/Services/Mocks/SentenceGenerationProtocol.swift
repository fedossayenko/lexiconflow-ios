//
//  SentenceGenerationProtocol.swift
//  LexiconFlow
//
//  Protocol-based abstraction for sentence generation
//  Enables dependency injection and network mocking for testing
//

import Foundation
import SwiftData

/// Protocol for sentence generation services
///
/// This abstraction enables:
/// - Dependency injection for testability
/// - Mock implementations for integration testing
/// - Network mocking without external dependencies
@MainActor
protocol SentenceGenerationProtocol: Sendable {
    /// Generate sentences for a single flashcard
    ///
    /// - Parameters:
    ///   - word: The vocabulary word
    ///   - definition: The word's definition
    ///   - translation: Optional translation
    ///   - cefrLevel: Optional CEFR level
    ///   - count: Number of sentences to generate (default: 3)
    ///   - config: Generation configuration (AI source preference)
    ///
    /// - Returns: SentenceGenerationResponse with generated sentences
    /// - Throws: SentenceGenerationError if the request fails
    func generateSentences(
        for word: String,
        definition: String,
        translation: String?,
        cefrLevel: String?,
        count: Int,
        config: SentenceGenerationService.GenerationConfig?
    ) async throws -> SentenceGenerationResponse

    /// Batch generate sentences for multiple flashcards
    ///
    /// - Parameters:
    ///   - cards: Array of flashcard data
    ///   - sentencesPerCard: Number of sentences per card (default: 3)
    ///   - maxConcurrency: Maximum concurrent requests (default: 3)
    ///   - progressHandler: Optional progress callback
    ///
    /// - Returns: SentenceBatchResult with success/failure counts
    /// - Throws: SentenceGenerationError if configuration is invalid
    func generateBatch(
        _ cards: [SentenceGenerationService.CardData],
        sentencesPerCard: Int,
        maxConcurrency: Int,
        progressHandler: (@Sendable (SentenceGenerationService.BatchGenerationProgress) -> Void)?
    ) async throws -> SentenceGenerationService.SentenceBatchResult

    /// Cancel any ongoing batch generation
    func cancelBatchGeneration() async
}

// MARK: - Production Implementation

/// Production implementation that wraps SentenceGenerationService
///
/// This is a thin wrapper around the real service that conforms to the protocol.
/// Used in production code and for integration testing with real network calls.
struct ProductionSentenceGenerator: SentenceGenerationProtocol {
    private let service: SentenceGenerationService

    /// Create a new production generator
    /// - Parameter service: The SentenceGenerationService to wrap (defaults to shared)
    init(service: SentenceGenerationService = .shared) {
        self.service = service
    }

    func generateSentences(
        for word: String,
        definition: String,
        translation: String? = nil,
        cefrLevel: String? = nil,
        count: Int = 3,
        config: SentenceGenerationService.GenerationConfig? = nil
    ) async throws -> SentenceGenerationResponse {
        try await self.service.generateSentences(
            cardWord: word,
            cardDefinition: definition,
            cardTranslation: translation,
            cardCEFR: cefrLevel,
            count: count,
            config: config
        )
    }

    func generateBatch(
        _ cards: [SentenceGenerationService.CardData],
        sentencesPerCard: Int = 3,
        maxConcurrency: Int = 3,
        progressHandler: (@Sendable (SentenceGenerationService.BatchGenerationProgress) -> Void)? = nil
    ) async throws -> SentenceGenerationService.SentenceBatchResult {
        try await self.service.generateBatch(
            cards,
            sentencesPerCard: sentencesPerCard,
            maxConcurrency: maxConcurrency,
            progressHandler: progressHandler
        )
    }

    func cancelBatchGeneration() async {
        await self.service.cancelBatchGeneration()
    }
}
