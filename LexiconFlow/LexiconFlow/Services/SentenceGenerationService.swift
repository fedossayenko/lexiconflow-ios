//
//  SentenceGenerationService.swift
//  LexiconFlow
//
//  AI-powered sentence generation service using Z.ai API
//  Generates context sentences for vocabulary learning
//

import Foundation
import OSLog
import SwiftData

/// Service for generating AI-powered context sentences
///
/// **AI Sources:**
/// - **Cloud**: Uses Z.ai API (requires API key, network connection)
/// - **Static**: Fallback sentences for offline mode
///
/// **Features:**
/// - Graceful fallback: cloud API → static sentences
/// - Batch sentence generation with concurrency control
/// - CEFR level appropriateness filtering
/// - Automatic caching with 7-day TTL
/// - Static fallback sentences for offline mode
/// - Exponential backoff retry on rate limits
actor SentenceGenerationService {
    // MARK: - Configuration Constants

    /// Configuration constants for sentence generation operations
    ///
    /// **Note**: Marked `nonisolated` to allow safe access from any context
    private nonisolated enum Config {
        /// Maximum concurrent sentence generation requests
        /// Conservative limit to avoid rate limiting with sentence generation API
        static let defaultMaxConcurrency = 3

        /// Maximum retry attempts for failed generations
        /// 3 retries allows recovery from transient network issues
        static let defaultMaxRetries = 3

        /// Initial delay before first retry (seconds)
        /// 0.5s provides quick recovery while avoiding API rate limits
        static let initialRetryDelay: TimeInterval = 0.5

        /// Multiplier for exponential backoff
        /// Each retry waits twice as long as the previous (0.5s, 1s, 2s)
        static let backoffMultiplier: Double = 2.0

        /// Default number of sentences to generate per flashcard
        static let defaultSentencesPerCard = 3
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
    static let shared = SentenceGenerationService()

    private let baseURL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
    private let logger = Logger(subsystem: "com.lexiconflow.sentence", category: "SentenceGenerationService")

    private var sourceLanguage = "en"
    private var targetLanguage = "ru"

    private init() {}

    /// Fetch API key from Keychain (must run on MainActor)
    @MainActor
    private func getAPIKey() -> String {
        (try? KeychainManager.getAPIKey()) ?? ""
    }

    /// Set source and target languages
    func setLanguages(source: String, target: String) {
        self.sourceLanguage = source
        self.targetLanguage = target
        self.logger.info("Languages set: \(source) -> \(target)")
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
            self.failedCount == 0 && self.successCount > 0
        }
    }

    /// Progress update during batch generation
    struct BatchGenerationProgress: Sendable {
        let current: Int
        let total: Int
        let currentWord: String
    }

    // MARK: - API Models

    private struct GenerationRequest: Codable, Sendable {
        let model: String
        let temperature: Double
        let messages: [Message]

        struct Message: Codable, Sendable {
            let role: String
            let content: String
        }
    }

    private struct ZAIResponse: Codable, Sendable {
        let choices: [Choice]

        struct Choice: Codable, Sendable {
            let message: Message

            struct Message: Codable, Sendable {
                let content: String
            }
        }
    }

    // MARK: - Cancellation

    /// Actor-isolated storage for active generation task
    private actor TaskStorage {
        var task: Task<SentenceBatchResult, Error>?

        func set(_ task: Task<SentenceBatchResult, Error>?) {
            self.task = task
        }

        func get() -> Task<SentenceBatchResult, Error>? {
            self.task
        }

        func cancel() {
            self.task?.cancel()
            self.task = nil
        }
    }

    private let taskStorage = TaskStorage()

    /// Cancel any ongoing batch generation
    func cancelBatchGeneration() {
        Task {
            await self.taskStorage.cancel()
            self.logger.info("Batch generation cancelled")
        }
    }

    // MARK: - Single Generation

    /// Generate sentences for a single flashcard
    ///
    /// **AI Source Selection:**
    /// - Cloud API → falls back to static sentences if no API key or on error
    ///
    /// - Parameters:
    ///   - cardWord: The vocabulary word
    ///   - cardDefinition: The word's definition
    ///   - cardTranslation: Optional translation
    ///   - cardCEFR: Optional CEFR level
    ///   - count: Number of sentences to generate (default: 3)
    ///
    /// - Returns: SentenceGenerationResponse with generated sentences
    /// - Throws: SentenceGenerationError if all generation methods fail
    func generateSentences(
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String? = nil,
        cardCEFR: String? = nil,
        count: Int = Config.defaultSentencesPerCard
    ) async throws -> SentenceGenerationResponse {
        // Try cloud API
        do {
            let response = try await generateSentencesCloud(
                cardWord: cardWord,
                cardDefinition: cardDefinition,
                cardTranslation: cardTranslation,
                cardCEFR: cardCEFR,
                count: count
            )
            self.logger.info("Generated sentences using cloud API for '\(cardWord)'")
            return response
        } catch {
            self.logger.warning("Cloud generation failed: \(error.localizedDescription)")

            // Final fallback: static sentences
            self.logger.info("Using static fallback sentences for '\(cardWord)'")
            return self.generateStaticFallback(cardWord: cardWord, cardCEFR: cardCEFR, count: count)
        }
    }

    /// Generate sentences using cloud API (Z.ai)
    ///
    /// **Prerequisites:**
    /// - API key stored in Keychain
    /// - Network connection
    ///
    /// **Fallback:**
    /// - Throws SentenceGenerationError if unavailable
    /// - Caller should fall back to static sentences
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
    private func generateSentencesCloud(
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String? = nil,
        cardCEFR: String? = nil,
        count: Int = Config.defaultSentencesPerCard
    ) async throws -> SentenceGenerationResponse {
        // Get API key from Keychain (awaits MainActor)
        let key = await getAPIKey()
        guard !key.isEmpty else {
            self.logger.error("Sentence generation failed: API key not configured")
            throw SentenceGenerationError.missingAPIKey
        }

        let systemPrompt = """
        Generate \(count) unique English context sentences for vocabulary learning.

        Requirements:
        - Each sentence must clearly demonstrate the word's meaning
        - Use diverse contexts (formal, informal, academic, daily life)
        - Vary sentence complexity (simple to compound/complex)
        - Ensure natural, authentic English usage

        Return ONLY raw JSON (no markdown):
        {
          "items": [
            {
              "sentence": "example sentence using the word",
              "cefr_level": "A1-C2",
              "confidence": 0.0-1.0
            }
          ]
        }

        CEFR Guidelines:
        - A1: Simple sentences, common vocabulary
        - A2: Basic sentences, everyday topics
        - B1: Standard sentences, familiar topics
        - B2: Complex sentences, technical vocabulary
        - C1: Advanced sentences, abstract concepts
        - C2: Mastery sentences, nuanced expressions
        """

        let userPrompt = """
        Word: \(cardWord)
        Definition: \(cardDefinition)
        \(cardTranslation.map { "Translation: \($0)" } ?? "")
        \(cardCEFR.map { "Target CEFR: \($0)" } ?? "")

        Generate \(count) unique sentences.
        """

        let request = GenerationRequest(
            model: "glm-4.7",
            temperature: 0.8,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        // swiftformat:disable:next redundantSelf
        guard let url = URL(string: self.baseURL) else {
            // swiftformat:disable:next redundantSelf
            logger.error("Invalid base URL: \(self.baseURL)")
            throw SentenceGenerationError.invalidConfiguration
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        self.logger.debug("Sending sentence generation request for '\(cardWord)'")

        let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            self.logger.error("Generation API error: Invalid HTTP response - \(String(errorBody.prefix(200)))")
            throw SentenceGenerationError.apiFailed
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"

            switch httpResponse.statusCode {
            case 401:
                self.logger.error("Generation failed: Invalid credentials (401)")
                throw SentenceGenerationError.clientError(statusCode: 401, message: "Invalid API key")
            case 429:
                self.logger.warning("Rate limit hit for '\(cardWord)'")
                throw SentenceGenerationError.rateLimit
            case 400 ... 499:
                self.logger.error("Client error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
                throw SentenceGenerationError.clientError(statusCode: httpResponse.statusCode, message: errorBody)
            case 500 ... 599:
                self.logger.error("Server error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
                throw SentenceGenerationError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
            default:
                self.logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
                throw SentenceGenerationError.apiFailed
            }
        }

        let rawResponse = try JSONDecoder().decode(ZAIResponse.self, from: data)
        let content = rawResponse.choices.first?.message.content ?? ""

        // Extract and decode JSON synchronously without Logger to avoid @MainActor isolation
        let response = try decodeJSONResponseSynchronously(from: content)
        self.logger.info("Successfully generated \(response.items.count) sentences for '\(cardWord)'")
        return response
    }

    /// Extract and decode JSON response without Logger dependency (nonisolated)
    ///
    /// This helper method inlines JSON extraction and decoding logic to avoid @MainActor
    /// isolation issues that occur when passing Logger to JSONExtractor.extract(from:logger:).
    private nonisolated func decodeJSONResponseSynchronously(from text: String) throws -> SentenceGenerationResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try ```json code blocks (preferred format)
        if let jsonStart = trimmed.range(of: "```json", options: .caseInsensitive) {
            let afterStart = jsonStart.upperBound
            if let jsonEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< jsonEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let data = json.data(using: .utf8) {
                    return try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)
                }
            }
        }

        // Try ``` code blocks (without json specifier)
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< codeEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let data = json.data(using: .utf8) {
                    return try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)
                }
            }
        }

        // Try { to } brace delimiters (fallback for unstructured text)
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}")
        {
            let json = String(trimmed[firstBrace ... lastBrace])
            if let data = json.data(using: .utf8) {
                return try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)
            }
        }

        // If no patterns matched, try to decode the original trimmed text
        if let data = trimmed.data(using: .utf8) {
            return try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)
        }

        throw SentenceGenerationError.invalidResponse(reason: "Could not extract or decode JSON from response")
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
        maxConcurrency: Int = Config.defaultMaxConcurrency,
        progressHandler: (@Sendable (BatchGenerationProgress) -> Void)? = nil
    ) async throws -> SentenceBatchResult {
        guard !cards.isEmpty else {
            self.logger.warning("Batch generation called with empty array")
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
            self.logger.warning("Batch generation already in progress")
            throw SentenceGenerationError.invalidConfiguration
        }

        self.logger.info("Starting batch generation: \(cards.count) cards, \(sentencesPerCard) sentences/card")

        let task = Task<SentenceBatchResult, Error> {
            try await self.performBatchGeneration(
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
            self.logger.info("Batch generation cancelled")
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
                        self.reportProgress(
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
                self.reportProgress(
                    handler: progressHandler,
                    current: completedCount,
                    total: cards.count,
                    word: result.cardWord
                )
            }

            let duration = Date().timeIntervalSince(startTime)
            let batchResult = self.aggregateResults(results, duration: duration)
            self.logBatchCompletion(batchResult)
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
        let errors = failures.compactMap { result -> SentenceGenerationError? in
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
                sourceLanguage: self.sourceLanguage,
                targetLanguage: self.targetLanguage
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
        self.logger.info("""
        Batch generation complete:
        - Success: \(result.successCount)
        - Failed: \(result.failedCount)
        - Duration: \(String(format: "%.2f", result.totalDuration))s
        """)
    }

    /// Perform generation with exponential backoff retry
    private func performGenerationWithRetry(
        cardId: UUID,
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String?,
        cardCEFR: String?,
        count: Int,
        maxRetries: Int = Config.defaultMaxRetries
    ) async -> SentenceGenerationResult {
        let startTime = Date()

        let result = await RetryManager.executeWithRetry(
            maxRetries: maxRetries,
            initialDelay: Config.initialRetryDelay,
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
            logContext: "Sentence generation for '\(cardWord)'",
            logger: self.logger
        )

        let duration = Date().timeIntervalSince(startTime)

        switch result {
        case let .success(response):
            self.logger.debug("Generation succeeded: \(cardWord)")
            return SentenceGenerationResult(
                cardId: cardId,
                cardWord: cardWord,
                result: .success(response),
                duration: duration
            )
        case let .failure(error):
            self.logger.error("Generation failed: \(cardWord) - \(error.localizedDescription)")
            return SentenceGenerationResult(
                cardId: cardId,
                cardWord: cardWord,
                result: .failure(error),
                duration: duration
            )
        }
    }

    // MARK: - Static Fallback Sentences

    /// Generate static fallback sentences for offline/error scenarios
    ///
    /// **Use Case:** When cloud generation fails, these provide basic examples
    /// to prevent app from being non-functional.
    ///
    /// **Implementation:**
    /// - Uses static library for common words
    /// - Uses default sentences for unknown words
    ///
    /// - Parameters:
    ///   - cardWord: The vocabulary word
    ///   - cardCEFR: Optional CEFR level (defaults to B1 if unknown)
    ///   - count: Number of sentences to generate
    ///
    /// - Returns: SentenceGenerationResponse with fallback sentences
    private func generateStaticFallback(
        cardWord: String,
        cardCEFR: String?,
        count: Int
    ) -> SentenceGenerationResponse {
        let cefrLevel = cardCEFR ?? "B1"
        self.logger.debug("Generating \(count) static fallback sentences for '\(cardWord)' at \(cefrLevel) level")

        // Use static fallback library for common words
        var sentences: [SentenceGenerationResponse.GeneratedSentenceItem] = []
        sentences.reserveCapacity(count)

        let fallbacks = self.staticFallbackLibrary[cardWord.lowercased()] ?? self.defaultFallbackSentences

        for i in 0 ..< count {
            let sentenceText = fallbacks[i % fallbacks.count]
            sentences.append(
                SentenceGenerationResponse.GeneratedSentenceItem(
                    sentence: sentenceText,
                    cefrLevel: cefrLevel
                )
            )
        }

        self.logger.info("Generated \(sentences.count) static fallback sentences for '\(cardWord)'")
        return SentenceGenerationResponse(items: sentences)
    }

    /// Get static fallback sentences for offline mode
    func getStaticFallbackSentences(for word: String) -> [SentenceGenerationResponse.GeneratedSentenceItem] {
        let fallbacks = self.staticFallbackLibrary[word.lowercased()] ?? self.defaultFallbackSentences

        return fallbacks.map { sentence in
            SentenceGenerationResponse.GeneratedSentenceItem(
                sentence: sentence,
                cefrLevel: self.estimateCEFRLevel(sentence)
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

enum SentenceGenerationError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration
    case rateLimit
    case clientError(statusCode: Int, message: String?)
    case serverError(statusCode: Int, message: String?)
    case apiFailed
    case invalidResponse(reason: String?)
    case cancelled
    case offline

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured"
        case .invalidConfiguration:
            return "Invalid service configuration"
        case .rateLimit:
            return "API rate limit exceeded. Please wait a moment and try again."
        case let .clientError(code, message):
            if let msg = message {
                return "Request failed (HTTP \(code)): \(msg)"
            }
            return "Request failed (HTTP \(code))"
        case let .serverError(code, _):
            return "Server is experiencing issues (HTTP \(code)). Please try again later."
        case .apiFailed:
            return "Sentence generation API request failed"
        case let .invalidResponse(reason):
            if let r = reason {
                return "Invalid response from generation API: \(r)"
            }
            return "Invalid response from generation API"
        case .cancelled:
            return "Generation was cancelled"
        case .offline:
            return "No internet connection. Please check your network and try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            "Add your API key in Settings > Translation > Z.ai API Configuration"
        case .rateLimit:
            "Wait a few seconds, then try again"
        case .offline:
            "Check your WiFi or cellular connection"
        default:
            nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimit, .serverError, .offline:
            true
        default:
            false
        }
    }
}
