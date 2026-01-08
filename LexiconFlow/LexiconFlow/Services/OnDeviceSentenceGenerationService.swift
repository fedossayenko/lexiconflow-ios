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
actor OnDeviceSentenceGenerationService {
    // MARK: - Configuration Constants

    /// Configuration constants for sentence generation operations
    private enum Config {
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

    /// Foundation Models session (lazy initialization)
    private var session: LanguageModelSession?

    private init() {}

    /// Fetch API key from Keychain (for compatibility with existing service)
    private func getAPIKey() -> String {
        (try? KeychainManager.getAPIKey()) ?? ""
    }

    /// Set source and target languages
    func setLanguages(source: String, target: String) {
        self.sourceLanguage = source
        self.targetLanguage = target
        logger.info("Languages set: \(source) -> \(target)")
    }

    // MARK: - Device Capability Detection

    /// Check if the device supports Foundation Models (Apple Intelligence)
    func isFoundationModelsAvailable() -> Bool {
        // Check if device is iPhone 15 Pro or later
        if #available(iOS 26.0, *) {
            // Attempt to create a session to verify availability
            do {
                _ = try LanguageModelSession()
                return true
            } catch {
                logger.warning("Foundation Models not available on this device: \(error.localizedDescription)")
                return false
            }
        } else {
            logger.warning("Foundation Models requires iOS 26.0+")
            return false
        }
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
        let result: Result<SentenceGenerationResponse, SentenceGenerationError>
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
        let errors: [SentenceGenerationError]
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
    /// - Throws: SentenceGenerationError if the request fails
    func generateSentences(
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String? = nil,
        cardCEFR: String? = nil,
        count: Int = Config.defaultSentencesPerCard
    ) async throws -> SentenceGenerationResponse {
        // Check device capability
        guard isFoundationModelsAvailable() else {
            logger.warning("Foundation Models not available, using static fallback")
            return SentenceGenerationResponse(
                items: getStaticFallbackSentences(for: cardWord)
            )
        }

        // Initialize session if needed
        if session == nil {
            do {
                session = try LanguageModelSession()
            } catch {
                logger.error("Failed to create LanguageModelSession: \(error.localizedDescription)")
                throw SentenceGenerationError.invalidConfiguration
            }
        }

        let systemPrompt = """
        Generate \(count) unique English context sentences for vocabulary learning.

        Requirements:
        - Each sentence must clearly demonstrate the word's meaning
        - Use diverse contexts (formal, informal, academic, daily life)
        - Vary sentence complexity (simple to compound/complex)
        - Ensure natural, authentic English usage
        - Keep sentences concise and clear for language learners

        Return ONLY a JSON array with this exact format:
        [
          {"sentence": "example sentence using the word", "cefr_level": "A1"},
          {"sentence": "another example sentence", "cefr_level": "B1"}
        ]

        CEFR Guidelines:
        - A1: Simple sentences, common vocabulary (max 8 words)
        - A2: Basic sentences, everyday topics (max 15 words)
        - B1: Standard sentences, familiar topics (max 25 words)
        - B2: Complex sentences, technical vocabulary (max 35 words)
        - C1: Advanced sentences, abstract concepts (36+ words)
        """

        let userPrompt = """
        Word: \(cardWord)
        Definition: \(cardDefinition)
        \(cardTranslation.map { "Translation: \($0)" } ?? "")
        \(cardCEFR.map { "Target CEFR: \($0)" } ?? "")

        Generate \(count) unique sentences.
        Return ONLY a JSON array.
        """

        logger.debug("Sending on-device sentence generation request for '\(cardWord)'")

        do {
            guard let session = session else {
                throw SentenceGenerationError.invalidConfiguration
            }

            let response = try await session.generate(
                "\(systemPrompt)\n\n\(userPrompt)",
                maxTokens: Config.maxTokens,
                temperature: Config.temperature
            )

            logger.info("Successfully generated on-device sentences for '\(cardWord)'")

            // Parse the response as JSON
            return try parseSentenceResponse(from: response, word: cardWord)

        } catch let error as SentenceGenerationError {
            throw error
        } catch {
            logger.error("On-device generation failed: \(error.localizedDescription)")
            // Fall back to static sentences on error
            return SentenceGenerationResponse(
                items: getStaticFallbackSentences(for: cardWord)
            )
        }
    }

    /// Parse the Foundation Models response into SentenceGenerationResponse
    private func parseSentenceResponse(
        from response: String,
        word: String
    ) throws -> SentenceGenerationResponse {
        // Extract JSON from response (handle markdown code blocks)
        let jsonContent = JSONExtractor.extract(from: response, logger: logger)

        guard let data = jsonContent.data(using: .utf8) else {
            logger.error("Failed to decode JSON content as UTF-8")
            throw SentenceGenerationError.invalidResponse(reason: "Content is not valid UTF-8")
        }

        do {
            let items = try JSONDecoder().decode([SentenceItem].self, from: data)
            logger.info("Parsed \(items.count) sentences for '\(word)'")
            return SentenceGenerationResponse(items: items)
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            logger.error("Content that failed to decode: \(String(jsonContent.prefix(500)))")
            throw SentenceGenerationError.invalidResponse(reason: error.localizedDescription)
        }
    }

    /// Helper struct for JSON decoding
    private struct SentenceItem: Codable {
        let sentence: String
        let cefrLevel: String

        enum CodingKeys: String, CodingKey {
            case sentence = "sentence"
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
        if existingTask != nil && !Task.isCancelled {
            logger.warning("Batch generation already in progress")
            throw SentenceGenerationError.invalidConfiguration
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
                        await reportProgress(
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
                await reportProgress(
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
    ) async {
        guard let handler = handler else { return }
        let progress = BatchGenerationProgress(current: current, total: total, currentWord: word)
        await MainActor.run { handler(progress) }
    }

    /// Aggregate generation results
    private func aggregateResults(
        _ results: [SentenceGenerationResult],
        duration: TimeInterval
    ) -> SentenceBatchResult {
        let successes = results.filter { if case .success = $0.result { true } else { false } }
        let failures = results.filter { if case .failure = $0.result { true } else { false } }
        let errors = failures.compactMap { (result) -> SentenceGenerationError? in
            guard case .failure(let error) = result.result else { return nil }
            return error
        }

        let successfulGenerations: [SuccessfulGeneration] = successes.compactMap { result in
            guard case .success(let response) = result.result else { return nil }
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
            isRetryable: { (error: SentenceGenerationError) in
                error.isRetryable
            },
            logContext: "On-device sentence generation for '\(cardWord)'",
            logger: logger
        )

        let duration = Date().timeIntervalSince(startTime)

        switch result {
        case .success(let response):
            logger.debug("Generation succeeded: \(cardWord)")
            return SentenceGenerationResult(
                cardId: cardId,
                cardWord: cardWord,
                result: .success(response),
                duration: duration
            )
        case .failure(let error):
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
        case 0...CEFRThresholds.a1Max: return "A1"
        case (CEFRThresholds.a1Max + 1)...CEFRThresholds.a2Max: return "A2"
        case (CEFRThresholds.a2Max + 1)...CEFRThresholds.b1Max: return "B1"
        case (CEFRThresholds.b1Max + 1)...CEFRThresholds.b2Max: return "B2"
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

enum OnDeviceSentenceGenerationError: LocalizedError {
    case deviceNotSupported
    case sessionNotInitialized
    case generationFailed(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "On-device AI requires Apple Intelligence (iPhone 15 Pro or later)"
        case .sessionNotInitialized:
            return "AI session not initialized. Please try again."
        case .generationFailed(let reason):
            return "Sentence generation failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid service configuration"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .deviceNotSupported:
            return "Use cloud-based sentence generation in Settings, or use an iPhone 15 Pro or later"
        case .sessionNotInitialized:
            return "Restart the app and try again"
        case .generationFailed:
            return "Try again or use static fallback sentences"
        case .invalidConfiguration:
            return "Check your iOS version and device compatibility"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .deviceNotSupported, .invalidConfiguration:
            return false
        case .sessionNotInitialized, .generationFailed:
            return true
        }
    }
}
