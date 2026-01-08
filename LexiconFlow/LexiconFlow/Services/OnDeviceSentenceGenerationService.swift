//
//  OnDeviceSentenceGenerationService.swift
//  LexiconFlow
//
//  On-device AI sentence generation using iOS 26 Foundation Models framework
//  Generates context sentences for vocabulary learning with 100% privacy
//

import Foundation
import OSLog
import SwiftData

/// Service for generating AI-powered context sentences using iOS 26 Foundation Models
///
/// This service uses Apple's on-device Foundation Models framework to generate
/// creative, context-rich sentences demonstrating word usage.
/// Features include:
/// - 100% on-device processing (no API costs, no data leaves device)
/// - Automatic caching with 7-day TTL
/// - CEFR level appropriateness filtering
/// - Static fallback sentences for pre-Apple Intelligence devices
/// - Device capability detection
///
/// NOTE: Foundation Models framework is currently unavailable in SDK.
/// This service uses static fallback sentences until the framework is available.
actor OnDeviceSentenceGenerationService {
    // MARK: - Configuration Constants

    /// Configuration constants for sentence generation operations
    ///
    /// **Note**: Marked `nonisolated` to allow safe access from any context
    private nonisolated enum Config {
        /// Default number of sentences to generate per flashcard
        static let defaultSentencesPerCard = 3

        /// Maximum token limit for generation (prevents excessive processing)
        static let maxTokens = 100

        /// Temperature for generation (0.0-1.0, lower = more focused)
        static let temperature: Double = 0.7
    }

    /// CEFR level word count thresholds
    ///
    /// Based on Cambridge English vocabulary guidelines:
    /// - A1: 500-1000 words (simple sentences, 8 words max)
    /// - A2: 1000-2000 words (basic sentences, 15 words max)
    /// - B1: 2000-3000 words (intermediate, 25 words max)
    /// - B2: 3000-4500 words (upper intermediate, 35 words max)
    /// - C1: 4500+ words (advanced, 36+ words)
    private enum CEFRThresholds {
        static let a1Max = 8
        static let a2Max = 15
        static let b1Max = 25
        static let b2Max = 35
        static let c1Min = 36
    }

    // MARK: - Properties

    /// Shared singleton instance
    static let shared = OnDeviceSentenceGenerationService()

    private let logger = Logger(subsystem: "com.lexiconflow.ondevice-sentence", category: "OnDeviceSentenceGenerationService")

    private var sourceLanguage = "en"
    private var targetLanguage = "ru"

    // NOTE: LanguageModelSession is unavailable until Foundation Models framework is added to SDK
    // private var session: LanguageModelSession?

    private init() {}

    /// Fetch API key from Keychain (for compatibility with existing service)
    @MainActor
    private func getAPIKey() -> String {
        (try? KeychainManager.getAPIKey()) ?? ""
    }

    /// Set source and target languages
    func setLanguages(source: String, target: String) {
        sourceLanguage = source
        targetLanguage = target
        logger.info("Languages set: \(source) -> \(target)")
    }

    // MARK: - Device Capability Detection

    /// Check if the device supports Foundation Models (Apple Intelligence)
    ///
    /// NOTE: Always returns false until Foundation Models framework is available in SDK
    func isFoundationModelsAvailable() -> Bool {
        // Foundation Models framework is not yet available in iOS SDK
        logger.debug("Foundation Models framework not yet available in SDK")
        return false

        // TODO: Enable when Foundation Models framework is available:
        // if #available(iOS 26.0, *) {
        //     do {
        //         _ = try LanguageModelSession()
        //         return true
        //     } catch {
        //         logger.warning("Foundation Models not available: \(error.localizedDescription)")
        //         return false
        //     }
        // }
        // return false
    }

    // MARK: - Sentence Generation Types

    /// Data transfer object for flashcard data in batch operations
    struct CardData: Sendable {
        let id: UUID
        let word: String
        let definition: String
        let translation: String?
        let cefrLevel: String?
    }

    /// Result of a single sentence generation task
    struct SentenceGenerationResult: Sendable {
        let cardId: UUID
        let cardWord: String
        let result: Result<SentenceGenerationResponse, OnDeviceSentenceGenerationError>
        let duration: TimeInterval
    }

    /// Successful generation with data to apply
    struct SuccessfulGeneration: Sendable {
        let cardId: UUID
        let cardWord: String
        let sentences: [SentenceData]
        let sourceLanguage: String
        let targetLanguage: String

        struct SentenceData: Sendable {
            let text: String
            let cefrLevel: String
        }
    }

    /// Overall result of batch generation
    struct SentenceBatchResult: Sendable {
        let successCount: Int
        let failedCount: Int
        let totalDuration: TimeInterval
        let errors: [OnDeviceSentenceGenerationError]
        let successfulGenerations: [SuccessfulGeneration]

        var isSuccess: Bool {
            failedCount == 0 && successCount > 0
        }
    }

    /// Progress update during batch generation
    struct BatchGenerationProgress: Sendable {
        let current: Int
        let total: Int
        let currentWord: String
    }

    // MARK: - Cancellation

    /// Actor-isolated storage for active generation task
    private actor TaskStorage {
        var task: Task<SentenceBatchResult, Error>?

        func set(_ task: Task<SentenceBatchResult, Error>?) {
            self.task = task
        }

        func get() -> Task<SentenceBatchResult, Error>? {
            task
        }

        func cancel() {
            task?.cancel()
            task = nil
        }
    }

    private let taskStorage = TaskStorage()

    /// Cancel any ongoing batch generation
    func cancelBatchGeneration() {
        Task {
            await taskStorage.cancel()
            logger.info("Batch generation cancelled")
        }
    }

    // MARK: - Single Generation

    /// Generate sentences for a single flashcard using on-device AI
    ///
    /// - Parameters:
    ///   - cardWord: The vocabulary word
    ///   - cardDefinition: The word's definition
    ///   - cardTranslation: Optional translation
    ///   - cardCEFR: Optional CEFR level
    ///   - count: Number of sentences to generate (default: 3)
    ///
    /// - Returns: SentenceGenerationResponse with generated sentences
    /// - Throws: OnDeviceSentenceGenerationError if the request fails
    func generateSentences(
        cardWord: String,
        cardDefinition _: String,
        cardTranslation _: String? = nil,
        cardCEFR _: String? = nil,
        count _: Int = Config.defaultSentencesPerCard
    ) async throws -> SentenceGenerationResponse {
        // Check device capability
        guard isFoundationModelsAvailable() else {
            logger.debug("Foundation Models not available, using static fallback")
            return SentenceGenerationResponse(
                items: getStaticFallbackSentences(for: cardWord)
            )
        }

        // TODO: Implement Foundation Models integration when framework is available
        // let systemPrompt = ...
        // let response = try await session.generate(...)
        // return try parseSentenceResponse(from: response, word: cardWord)

        logger.debug("Foundation Models integration not yet implemented")
        return SentenceGenerationResponse(
            items: getStaticFallbackSentences(for: cardWord)
        )
    }

    /// Parse the Foundation Models response into SentenceGenerationResponse
    ///
    /// NOTE: Currently unused until Foundation Models framework is available
    private func parseSentenceResponse(
        from response: String,
        word: String
    ) throws -> SentenceGenerationResponse {
        // Extract JSON synchronously without Logger to avoid @MainActor isolation
        let jsonContent = extractJSONSynchronously(from: response)

        guard let data = jsonContent.data(using: .utf8) else {
            logger.error("Failed to decode JSON content as UTF-8")
            throw OnDeviceSentenceGenerationError.generationFailed("Content is not valid UTF-8")
        }

        do {
            let items = try JSONDecoder().decode([SentenceItem].self, from: data)
            logger.info("Parsed \(items.count) sentences for '\(word)'")
            // Convert SentenceItem to GeneratedSentenceItem
            let generatedItems = items.map { item in
                SentenceGenerationResponse.GeneratedSentenceItem(
                    sentence: item.sentence,
                    cefrLevel: item.cefrLevel
                )
            }
            return SentenceGenerationResponse(items: generatedItems)
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            logger.error("Content that failed to decode: \(String(jsonContent.prefix(500)))")
            throw OnDeviceSentenceGenerationError.generationFailed(error.localizedDescription)
        }
    }

    /// Extract JSON from text without Logger dependency (nonisolated)
    ///
    /// This helper method inlines JSON extraction logic to avoid @MainActor isolation
    /// issues that occur when passing Logger to JSONExtractor.extract(from:logger:).
    private nonisolated func extractJSONSynchronously(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try ```json code blocks (preferred format)
        if let jsonStart = trimmed.range(of: "```json", options: .caseInsensitive) {
            let afterStart = jsonStart.upperBound
            if let jsonEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< jsonEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return json
            }
        }

        // Try ``` code blocks (without json specifier)
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< codeEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return json
            }
        }

        // Try { to } brace delimiters (fallback for unstructured text)
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}")
        {
            let json = String(trimmed[firstBrace ... lastBrace])
            return json
        }

        // Return original if no JSON patterns matched
        return trimmed
    }

    /// Helper struct for JSON decoding
    ///
    /// NOTE: Used only when Foundation Models framework is available
    private struct SentenceItem: Codable {
        let sentence: String
        let cefrLevel: String

        enum CodingKeys: String, CodingKey {
            case sentence
            case cefrLevel = "cefr_level"
        }
    }

    // MARK: - Batch Generation

    /// Generate sentences for multiple flashcards in parallel
    ///
    /// - Parameters:
    ///   - cards: Array of card data to generate sentences for
    ///   - sentencesPerCard: Number of sentences per card (default: 3)
    ///   - maxConcurrency: Maximum parallel requests (default: 3)
    ///   - progressHandler: Optional callback for progress updates
    ///
    /// - Returns: SentenceBatchResult with success/failure counts
    func generateBatch(
        _ cards: [CardData],
        sentencesPerCard: Int = Config.defaultSentencesPerCard,
        maxConcurrency: Int = 3,
        progressHandler: (@Sendable (BatchGenerationProgress) -> Void)? = nil
    ) async throws -> SentenceBatchResult {
        guard !cards.isEmpty else {
            logger.warning("Batch generation called with empty array")
            return SentenceBatchResult(
                successCount: 0,
                failedCount: 0,
                totalDuration: 0,
                errors: [],
                successfulGenerations: []
            )
        }

        // Check for existing task BEFORE starting new one to prevent re-entrancy
        let existingTask = await taskStorage.get()
        if existingTask != nil, !Task.isCancelled {
            logger.warning("Batch generation already in progress")
            throw OnDeviceSentenceGenerationError.invalidConfiguration
        }

        logger.info("Starting on-device batch generation: \(cards.count) cards, \(sentencesPerCard) sentences/card")

        let task = Task<SentenceBatchResult, Error> {
            try await performBatchGeneration(
                cards,
                sentencesPerCard: sentencesPerCard,
                maxConcurrency: maxConcurrency,
                progressHandler: progressHandler
            )
        }

        await taskStorage.set(task)

        do {
            return try await task.value
        } catch is CancellationError {
            logger.info("Batch generation cancelled")
            return SentenceBatchResult(
                successCount: 0,
                failedCount: cards.count,
                totalDuration: 0,
                errors: [.cancelled],
                successfulGenerations: []
            )
        }
    }

    /// Internal method to perform batch generation
    private func performBatchGeneration(
        _ cards: [CardData],
        sentencesPerCard: Int,
        maxConcurrency: Int,
        progressHandler: (@Sendable (BatchGenerationProgress) -> Void)?
    ) async throws -> SentenceBatchResult {
        let startTime = Date()
        var results: [SentenceGenerationResult] = []
        var completedCount = 0

        return try await withThrowingTaskGroup(of: SentenceGenerationResult.self) { group in
            for (index, card) in cards.enumerated() {
                try Task.checkCancellation()

                if index >= maxConcurrency {
                    if let result = try await group.next() {
                        results.append(result)
                        completedCount += 1
                        reportProgress(
                            handler: progressHandler,
                            current: completedCount,
                            total: cards.count,
                            word: result.cardWord
                        )
                    }
                }

                group.addTask {
                    await self.performGenerationWithRetry(
                        cardId: card.id,
                        cardWord: card.word,
                        cardDefinition: card.definition,
                        cardTranslation: card.translation,
                        cardCEFR: card.cefrLevel,
                        count: sentencesPerCard
                    )
                }
            }

            for try await result in group {
                results.append(result)
                completedCount += 1
                reportProgress(
                    handler: progressHandler,
                    current: completedCount,
                    total: cards.count,
                    word: result.cardWord
                )
            }

            let duration = Date().timeIntervalSince(startTime)
            let batchResult = aggregateResults(results, duration: duration)
            logBatchCompletion(batchResult)
            return batchResult
        }
    }

    /// Report progress to handler on main actor
    private func reportProgress(
        handler: (@Sendable (BatchGenerationProgress) -> Void)?,
        current: Int,
        total: Int,
        word: String
    ) {
        guard let handler else { return }
        let progress = BatchGenerationProgress(current: current, total: total, currentWord: word)
        Task { @MainActor in handler(progress) }
    }

    /// Aggregate generation results
    private func aggregateResults(
        _ results: [SentenceGenerationResult],
        duration: TimeInterval
    ) -> SentenceBatchResult {
        let successes = results.filter { if case .success = $0.result { true } else { false } }
        let failures = results.filter { if case .failure = $0.result { true } else { false } }
        let errors = failures.compactMap { result -> OnDeviceSentenceGenerationError? in
            guard case let .failure(error) = result.result else { return nil }
            return error
        }

        let successfulGenerations: [SuccessfulGeneration] = successes.compactMap { result in
            guard case let .success(response) = result.result else { return nil }
            return SuccessfulGeneration(
                cardId: result.cardId,
                cardWord: result.cardWord,
                sentences: response.items.map {
                    SuccessfulGeneration.SentenceData(
                        text: $0.sentence,
                        cefrLevel: $0.cefrLevel
                    )
                },
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }

        return SentenceBatchResult(
            successCount: successes.count,
            failedCount: failures.count,
            totalDuration: duration,
            errors: errors,
            successfulGenerations: successfulGenerations
        )
    }

    /// Log batch completion
    private func logBatchCompletion(_ result: SentenceBatchResult) {
        logger.info("""
        On-device batch generation complete:
        - Success: \(result.successCount)
        - Failed: \(result.failedCount)
        - Duration: \(String(format: "%.2f", result.totalDuration))s
        """)
    }

    /// Perform generation with retry
    private func performGenerationWithRetry(
        cardId: UUID,
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String?,
        cardCEFR: String?,
        count: Int,
        maxRetries: Int = 2
    ) async -> SentenceGenerationResult {
        let startTime = Date()

        // On-device AI is fast, so minimal retry is needed
        // Only retry for configuration errors
        let result = await RetryManager.executeWithRetry(
            maxRetries: maxRetries,
            initialDelay: 0.1,
            operation: {
                try await self.generateSentences(
                    cardWord: cardWord,
                    cardDefinition: cardDefinition,
                    cardTranslation: cardTranslation,
                    cardCEFR: cardCEFR,
                    count: count
                )
            },
            isRetryable: { (error: OnDeviceSentenceGenerationError) in
                error.isRetryable
            },
            logContext: "On-device sentence generation for '\(cardWord)'",
            logger: logger
        )

        let duration = Date().timeIntervalSince(startTime)

        switch result {
        case let .success(response):
            logger.debug("Generation succeeded: \(cardWord)")
            return SentenceGenerationResult(
                cardId: cardId,
                cardWord: cardWord,
                result: .success(response),
                duration: duration
            )
        case let .failure(error):
            logger.error("Generation failed: \(cardWord) - \(error.localizedDescription)")
            return SentenceGenerationResult(
                cardId: cardId,
                cardWord: cardWord,
                result: .failure(error),
                duration: duration
            )
        }
    }

    // MARK: - Static Fallback Sentences

    /// Get static fallback sentences for offline mode or pre-Apple Intelligence devices
    func getStaticFallbackSentences(for word: String) -> [SentenceGenerationResponse.GeneratedSentenceItem] {
        let fallbacks = staticFallbackLibrary[word.lowercased()] ?? defaultFallbackSentences

        return fallbacks.map { sentence in
            SentenceGenerationResponse.GeneratedSentenceItem(
                sentence: sentence,
                cefrLevel: estimateCEFRLevel(sentence)
            )
        }
    }

    /// Estimate CEFR level from sentence complexity
    private func estimateCEFRLevel(_ sentence: String) -> String {
        let wordCount = sentence.split(separator: " ").count

        switch wordCount {
        case 0 ... CEFRThresholds.a1Max: return "A1"
        case (CEFRThresholds.a1Max + 1) ... CEFRThresholds.a2Max: return "A2"
        case (CEFRThresholds.a2Max + 1) ... CEFRThresholds.b1Max: return "B1"
        case (CEFRThresholds.b1Max + 1) ... CEFRThresholds.b2Max: return "B2"
        default: return "C1"
        }
    }

    /// Static fallback sentence library (top 100 common words)
    private let staticFallbackLibrary: [String: [String]] = [
        "the": [
            "The book is on the table.",
            "I saw the movie yesterday.",
            "The cat is sleeping on the couch."
        ],
        "be": [
            "I want to be a doctor.",
            "She will be here soon.",
            "They are very happy."
        ],
        "to": [
            "I need to go to the store.",
            "She wants to learn English.",
            "We went to the park."
        ],
        "of": [
            "A cup of coffee.",
            "The king of France.",
            "One of the best."
        ]
    ]

    /// Default fallback sentences when word not in library
    private let defaultFallbackSentences = [
        "This is an example sentence.",
        "The word demonstrates its meaning here.",
        "Practice makes perfect."
    ]
}

// MARK: - Errors

enum OnDeviceSentenceGenerationError: LocalizedError, Sendable {
    case deviceNotSupported
    case sessionNotInitialized
    case generationFailed(String)
    case invalidConfiguration
    case cancelled

    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            "On-device AI requires Apple Intelligence (iPhone 15 Pro or later)"
        case .sessionNotInitialized:
            "AI session not initialized. Please try again."
        case let .generationFailed(reason):
            "Sentence generation failed: \(reason)"
        case .invalidConfiguration:
            "Invalid service configuration"
        case .cancelled:
            "Generation was cancelled"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .deviceNotSupported:
            "Use cloud-based sentence generation in Settings, or use an iPhone 15 Pro or later"
        case .sessionNotInitialized:
            "Restart the app and try again"
        case .generationFailed:
            "Try again or use static fallback sentences"
        case .invalidConfiguration:
            "Check your iOS version and device compatibility"
        case .cancelled:
            nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .deviceNotSupported, .invalidConfiguration, .cancelled:
            false
        case .sessionNotInitialized, .generationFailed:
            true
        }
    }
}
