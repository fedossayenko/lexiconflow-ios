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
    ///
    /// - Returns: SentenceGenerationResponse with generated sentences
    /// - Throws: SentenceGenerationError if the request fails
    func generateSentences(
        for word: String,
        definition: String,
        translation: String?,
        cefrLevel: String?,
        count: Int
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
        count: Int = 3
    ) async throws -> SentenceGenerationResponse {
        try await service.generateSentences(
            cardWord: word,
            cardDefinition: definition,
            cardTranslation: translation,
            cardCEFR: cefrLevel,
            count: count
        )
    }

    func generateBatch(
        _ cards: [SentenceGenerationService.CardData],
        sentencesPerCard: Int = 3,
        maxConcurrency: Int = 3,
        progressHandler: (@Sendable (SentenceGenerationService.BatchGenerationProgress) -> Void)? = nil
    ) async throws -> SentenceGenerationService.SentenceBatchResult {
        try await service.generateBatch(
            cards,
            sentencesPerCard: sentencesPerCard,
            maxConcurrency: maxConcurrency,
            progressHandler: progressHandler
        )
    }

    func cancelBatchGeneration() async {
        await service.cancelBatchGeneration()
    }
}

// MARK: - Mock Implementation

/// Mock implementation for testing
///
/// Features:
/// - Predefined responses for specific words
/// - Configurable failure scenarios
/// - Simulated network delay
/// - Progress simulation for batch operations
@MainActor
class MockSentenceGenerator: SentenceGenerationProtocol {
    /// Predefined responses keyed by word
    var responses: [String: SentenceGenerationResponse] = [:]

    /// Whether to throw errors for all requests
    var shouldFail = false

    /// Specific error to throw (if nil, uses generic error)
    var errorToThrow: SentenceGenerationError?

    /// Simulated network delay in seconds (default: 0)
    var delay: TimeInterval = 0

    /// Progress callback for batch simulation
    var progressHandler: (@Sendable (SentenceGenerationService.BatchGenerationProgress) -> Void)?

    /// Track which words were requested (for testing)
    private(set) var requestedWords: [String] = []

    /// Track batch generation calls
    private(set) var batchCallCount = 0

    /// Create a new mock generator
    ///
    /// - Parameters:
    ///   - responses: Predefined responses for specific words
    ///   - shouldFail: Whether to throw errors
    ///   - errorToThrow: Specific error to throw
    ///   - delay: Simulated network delay
    init(
        responses: [String: SentenceGenerationResponse] = [:],
        shouldFail: Bool = false,
        errorToThrow: SentenceGenerationError? = nil,
        delay: TimeInterval = 0
    ) {
        self.responses = responses
        self.shouldFail = shouldFail
        self.errorToThrow = errorToThrow
        self.delay = delay
    }

    // MARK: - SentenceGenerationProtocol

    func generateSentences(
        for word: String,
        definition: String,
        translation _: String? = nil,
        cefrLevel: String? = nil,
        count _: Int = 3
    ) async throws -> SentenceGenerationResponse {
        // Track request
        requestedWords.append(word)

        // Simulate delay
        if delay > 0 {
            try await Task.sleep(for: .seconds(delay))
        }

        // Check for failure
        if shouldFail {
            throw errorToThrow ?? SentenceGenerationError.apiFailed
        }

        // Return predefined response or default
        if let response = responses[word] {
            return response
        }

        // Generate default response
        return SentenceGenerationResponse(
            items: [
                SentenceGenerationResponse.GeneratedSentenceItem(
                    sentence: "Mock sentence for '\(word)': \(definition).",
                    cefrLevel: cefrLevel ?? "A2"
                ),
            ]
        )
    }

    func generateBatch(
        _ cards: [SentenceGenerationService.CardData],
        sentencesPerCard: Int = 3,
        maxConcurrency _: Int = 3,
        progressHandler: (@Sendable (SentenceGenerationService.BatchGenerationProgress) -> Void)? = nil
    ) async throws -> SentenceGenerationService.SentenceBatchResult {
        batchCallCount += 1

        var successfulGenerations: [SentenceGenerationService.SuccessfulGeneration] = []
        var errors: [SentenceGenerationError] = []
        var successCount = 0
        var failedCount = 0

        for (index, card) in cards.enumerated() {
            // Report progress
            let progress = SentenceGenerationService.BatchGenerationProgress(
                current: index + 1,
                total: cards.count,
                currentWord: card.word
            )
            progressHandler?(progress)
            self.progressHandler?(progress)

            // Simulate delay
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }

            do {
                let response = try await generateSentences(
                    for: card.word,
                    definition: card.definition,
                    translation: card.translation,
                    cefrLevel: card.cefrLevel,
                    count: sentencesPerCard
                )

                successfulGenerations.append(
                    SentenceGenerationService.SuccessfulGeneration(
                        cardId: card.id,
                        cardWord: card.word,
                        sentences: response.items.map { item in
                            SentenceGenerationService.SuccessfulGeneration.SentenceData(
                                text: item.sentence,
                                cefrLevel: item.cefrLevel
                            )
                        },
                        sourceLanguage: "en",
                        targetLanguage: "ru"
                    )
                )
                successCount += 1
            } catch {
                if let error = error as? SentenceGenerationError {
                    errors.append(error)
                }
                failedCount += 1
            }
        }

        return SentenceGenerationService.SentenceBatchResult(
            successCount: successCount,
            failedCount: failedCount,
            totalDuration: delay * Double(cards.count),
            errors: errors,
            successfulGenerations: successfulGenerations
        )
    }

    func cancelBatchGeneration() async {
        // No-op for mock (could add cancellation tracking if needed)
    }

    // MARK: - Test Helpers

    /// Reset tracking state
    func reset() {
        requestedWords.removeAll()
        batchCallCount = 0
    }

    /// Verify a specific word was requested
    /// - Parameter word: The word to check
    /// - Returns: True if the word was in requestedWords
    func wasRequested(_ word: String) -> Bool {
        requestedWords.contains(word)
    }

    /// Get the number of times a word was requested
    /// - Parameter word: The word to check
    /// - Returns: Count of requests for this word
    func requestCount(for word: String) -> Int {
        requestedWords.filter { $0 == word }.count
    }
}

// MARK: - Test Data Builders

/// Convenience builders for test data
extension MockSentenceGenerator {
    /// Create mock responses for common test words
    static func standardTestResponses() -> [String: SentenceGenerationResponse] {
        [
            "ephemeral": SentenceGenerationResponse(items: [
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "The ephemeral beauty of sunset colors fades quickly.", cefrLevel: "B2"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "An ephemeral moment in time.", cefrLevel: "B1"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "Ephemeral pleasures are short-lived.", cefrLevel: "A2"),
            ]),
            "test": SentenceGenerationResponse(items: [
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "This is a test sentence.", cefrLevel: "A1"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "Testing the system.", cefrLevel: "A1"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "A test of emergency systems.", cefrLevel: "A2"),
            ]),
            "hello": SentenceGenerationResponse(items: [
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "Hello, how are you today?", cefrLevel: "A1"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "She said hello to her neighbor.", cefrLevel: "A1"),
                SentenceGenerationResponse.GeneratedSentenceItem(sentence: "A warm hello greeted everyone.", cefrLevel: "A2"),
            ]),
        ]
    }

    /// Create a generator with standard test responses
    static func withStandardResponses() -> MockSentenceGenerator {
        MockSentenceGenerator(responses: standardTestResponses())
    }
}
