//
//  TranslationService.swift
//  LexiconFlow
//
//  Service for automatic translation using Z.ai GLM-4.7 API
//

import Foundation
import OSLog

/// Service for translating flashcard content using Z.ai API
///
/// This service provides automatic translation capabilities with metadata
/// including CEFR levels and context-specific translations.
/// Network operations run off the main thread to avoid blocking UI.
final class TranslationService {
    /// Shared singleton instance
    static let shared = TranslationService()

    private let baseURL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "TranslationService")

    private var sourceLanguage = "en"
    private var targetLanguage = "ru"

    private init() {
        // API key is now loaded from Keychain on-demand via computed property
    }

    /// Current API key from Keychain (computed property to ensure fresh reads)
    private var apiKey: String {
        do {
            return (try KeychainManager.getAPIKey()) ?? ""
        } catch {
            logger.error("Failed to read API key from Keychain: \(error.localizedDescription)")
            return ""
        }
    }

    /// Set or update the API key in Keychain
    ///
    /// - Parameter key: The Z.ai API key
    /// - Throws: KeychainError if storage fails
    func setAPIKey(_ key: String) throws {
        try KeychainManager.setAPIKey(key)
        logger.info("API key updated securely in Keychain")
    }

    /// Check if API key is configured
    var isConfigured: Bool {
        do {
            return (try KeychainManager.getAPIKey())?.isEmpty == false
        } catch {
            logger.error("Failed to check API key: \(error.localizedDescription)")
            return false
        }
    }

    /// Set source and target languages
    ///
    /// - Parameters:
    ///   - source: Source language code (e.g., "en")
    ///   - target: Target language code (e.g., "ru")
    func setLanguages(source: String, target: String) {
        self.sourceLanguage = source
        self.targetLanguage = target
        logger.info("Languages set: \(source) -> \(target)")
    }

    /// Validate an API key without storing it to Keychain
    ///
    /// Use this method to validate a new API key before committing it to storage.
    /// Performs a test translation request with the provided key.
    ///
    /// - Parameter key: The API key to validate
    /// - Returns: `true` if the key is valid, `false` otherwise
    /// - Throws: `TranslationError` if the validation request fails
    func validateAPIKey(_ key: String) async throws -> Bool {
        guard !key.isEmpty else {
            logger.error("API key validation failed: key is empty")
            throw TranslationError.missingAPIKey
        }

        let systemPrompt = """
        Translate English vocabulary to \(targetLanguage) with CEFR level.

        Return ONLY raw JSON (no markdown):
        {
          "items": [{
            "target_word": "...",
            "context_sentence": "...",
            "translation": "specific to definition",
            "cefr_level": "A1-C2",
            "definition_en": "..."
          }]
        }

        Rules:
        - Single JSON object
        - Context-specific translation
        - Estimate CEFR level accurately
        """

        let userPrompt = """
        Word: test
        Definition: a trial or test to validate something
        """

        let request = TranslationRequest(
            model: "glm-4.7",
            temperature: 0.1,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        guard let url = URL(string: self.baseURL) else {
            logger.error("Invalid base URL: \(self.baseURL)")
            throw TranslationError.invalidConfiguration
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        logger.debug("Validating API key with test request (URL: \(url.absoluteString))")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("API key validation error: Invalid HTTP response - \(String(errorBody.prefix(200)))")
            throw TranslationError.apiFailed
        }

        switch httpResponse.statusCode {
        case 200:
            // Valid API key - verify response has expected content
            let rawResponse = try JSONDecoder().decode(ZAIResponse.self, from: data)
            let content = rawResponse.choices.first?.message.content ?? ""
            let isValid = !content.isEmpty
            logger.info("API key validation succeeded: isValid=\(isValid)")
            return isValid

        case 401:
            logger.error("API key validation failed: Invalid credentials (401)")
            throw TranslationError.clientError(statusCode: 401, message: "Invalid API key")

        case 429:
            logger.warning("API key validation hit rate limit (429)")
            throw TranslationError.rateLimit

        case 400...499:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("API key validation client error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
            throw TranslationError.clientError(statusCode: httpResponse.statusCode, message: errorBody)

        case 500...599:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("API key validation server error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
            throw TranslationError.serverError(statusCode: httpResponse.statusCode, message: errorBody)

        default:
            logger.error("API key validation unexpected HTTP status: \(httpResponse.statusCode)")
            throw TranslationError.apiFailed
        }
    }

    // MARK: - Batch Translation Types

    /// Result of a single translation task within a batch
    struct TranslationTaskResult: Sendable {
        let card: Flashcard
        let result: Result<TranslationResponse, TranslationError>
        let duration: TimeInterval
    }

    /// Successful translation with data to apply
    struct SuccessfulTranslation: Sendable {
        let card: Flashcard
        let translation: String
        let cefrLevel: String
        let contextSentence: String
        let sourceLanguage: String
        let targetLanguage: String
    }

    /// Overall result of a batch translation operation
    struct TranslationBatchResult: Sendable {
        let successCount: Int
        let failedCount: Int
        let totalDuration: TimeInterval
        let errors: [TranslationError]
        let successfulTranslations: [SuccessfulTranslation]

        var isSuccess: Bool {
            failedCount == 0 && successCount > 0
        }
    }

    /// Progress update during batch translation
    struct BatchTranslationProgress: Sendable {
        let current: Int
        let total: Int
        let currentWord: String
    }

    // MARK: - API Models

    private struct TranslationRequest: Codable {
        let model: String
        let temperature: Double
        let messages: [Message]

        struct Message: Codable {
            let role: String
            let content: String
        }
    }

    /// Translation response from Z.ai API
    struct TranslationResponse: Codable {
        let items: [TranslationItem]

        struct TranslationItem: Codable {
            let targetWord: String
            let contextSentence: String
            let targetTranslation: String  // Generic field for any language
            let cefrLevel: String
            let definitionEn: String

            enum CodingKeys: String, CodingKey {
                case targetWord = "target_word"
                case contextSentence = "context_sentence"
                case targetTranslation = "translation"  // Generic translation key for any target language
                case cefrLevel = "cefr_level"
                case definitionEn = "definition_en"
            }
        }
    }

    // MARK: - Cancellation

    /// Actor-isolated storage for the active translation task
    /// Prevents data races when multiple threads access the task
    private actor TaskStorage {
        var task: Task<TranslationBatchResult, Error>?

        func set(_ task: Task<TranslationBatchResult, Error>?) {
            self.task = task
        }

        func get() -> Task<TranslationBatchResult, Error>? {
            task
        }

        func cancel() {
            task?.cancel()
            task = nil
        }
    }

    private let taskStorage = TaskStorage()

    /// Cancel any ongoing batch translation
    func cancelBatchTranslation() {
        Task {
            await taskStorage.cancel()
            logger.info("Batch translation cancelled")
        }
    }

    // MARK: - Batch Translation

    /// Translates multiple flashcards in parallel with adaptive rate limiting
    ///
    /// - Parameters:
    ///   - cards: Array of flashcards to translate
    ///   - maxConcurrency: Maximum number of parallel API requests (default: 5)
    ///   - progressHandler: Optional callback for progress updates
    ///
    /// - Returns: TranslationBatchResult with success/failure counts and errors
    /// - Throws: TranslationError if all requests fail
    func translateBatch(
        _ cards: [Flashcard],
        maxConcurrency: Int = 5,
        progressHandler: (@Sendable (BatchTranslationProgress) -> Void)? = nil
    ) async throws -> TranslationBatchResult {
        guard !cards.isEmpty else {
            logger.warning("Batch translation called with empty array")
            return TranslationBatchResult(successCount: 0, failedCount: 0, totalDuration: 0, errors: [], successfulTranslations: [])
        }

        logger.info("Starting batch translation: \(cards.count) cards, max concurrency: \(maxConcurrency)")

        // Store active task for cancellation
        let task = Task<TranslationBatchResult, Error> {
            try await performBatchTranslation(
                cards,
                maxConcurrency: maxConcurrency,
                progressHandler: progressHandler
            )
        }

        await taskStorage.set(task)

        do {
            guard let currentTask = await taskStorage.get() else {
                throw TranslationError.invalidConfiguration
            }
            return try await currentTask.value
        } catch is CancellationError {
            logger.info("Batch translation cancelled")
            return TranslationBatchResult(
                successCount: 0,
                failedCount: cards.count,
                totalDuration: 0,
                errors: [.cancelled],
                successfulTranslations: []
            )
        }
    }

    /// Internal method to perform batch translation
    private func performBatchTranslation(
        _ cards: [Flashcard],
        maxConcurrency: Int,
        progressHandler: (@Sendable (BatchTranslationProgress) -> Void)?
    ) async throws -> TranslationBatchResult {
        let startTime = Date()
        var results: [TranslationTaskResult] = []
        var completedCount = 0

        // Use withThrowingTaskGroup to handle cancellation checks
        return try await withThrowingTaskGroup(of: TranslationTaskResult.self) { group in
            // Add all tasks with concurrency control
            for (index, card) in cards.enumerated() {
                try Task.checkCancellation()

                // Wait for task completion if we've reached max concurrency
                if index >= maxConcurrency {
                    if let result = try await group.next() {
                        results.append(result)
                        completedCount += 1
                        await reportProgress(
                            handler: progressHandler,
                            current: completedCount,
                            total: cards.count,
                            word: result.card.word
                        )
                    }
                }

                group.addTask {
                    await self.performTranslationWithRetry(card: card)
                }
            }

            // Collect remaining results
            for try await result in group {
                results.append(result)
                completedCount += 1
                await reportProgress(
                    handler: progressHandler,
                    current: completedCount,
                    total: cards.count,
                    word: result.card.word
                )
            }

            // Aggregate and return results
            let duration = Date().timeIntervalSince(startTime)
            let batchResult = aggregateResults(results, duration: duration)
            logBatchCompletion(batchResult)
            return batchResult
        }
    }

    /// Report progress to handler on main actor
    private func reportProgress(
        handler: (@Sendable (BatchTranslationProgress) -> Void)?,
        current: Int,
        total: Int,
        word: String
    ) async {
        guard let handler = handler else { return }
        let progress = BatchTranslationProgress(current: current, total: total, currentWord: word)
        await MainActor.run { handler(progress) }
    }

    /// Aggregate translation results into final batch result
    private func aggregateResults(
        _ results: [TranslationTaskResult],
        duration: TimeInterval
    ) -> TranslationBatchResult {
        let successes = results.filter { if case .success = $0.result { true } else { false } }
        let failures = results.filter { if case .failure = $0.result { true } else { false } }
        let errors = failures.compactMap { (result) -> TranslationError? in
            guard case .failure(let error) = result.result else { return nil }
            return error
        }

        let successfulTranslations: [SuccessfulTranslation] = successes.compactMap { result in
            guard case .success(let response) = result.result,
                  let item = response.items.first else {
                return nil
            }
            return SuccessfulTranslation(
                card: result.card,
                translation: item.targetTranslation,
                cefrLevel: item.cefrLevel,
                contextSentence: item.contextSentence,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }

        return TranslationBatchResult(
            successCount: successes.count,
            failedCount: failures.count,
            totalDuration: duration,
            errors: errors,
            successfulTranslations: successfulTranslations
        )
    }

    /// Log batch translation completion summary
    private func logBatchCompletion(_ result: TranslationBatchResult) {
        logger.info("""
            Batch translation complete:
            - Success: \(result.successCount)
            - Failed: \(result.failedCount)
            - Duration: \(String(format: "%.2f", result.totalDuration))s
            """)
    }

    /// Performs translation with exponential backoff retry on rate limit errors
    ///
    /// - Parameters:
    ///   - card: The flashcard to translate
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///
    /// - Returns: TranslationTaskResult containing the result or error
    private func performTranslationWithRetry(
        card: Flashcard,
        maxRetries: Int = 3
    ) async -> TranslationTaskResult {
        let startTime = Date()
        var attempt = 0
        var delay: TimeInterval = 0.5

        while attempt < maxRetries {
            do {
                let result = try await translate(
                    word: card.word,
                    definition: card.definition,
                    context: nil
                )
                let duration = Date().timeIntervalSince(startTime)

                logger.debug("Translation succeeded: \(card.word.replacingOccurrences(of: "'", with: "\\'")) (attempt \(attempt + 1))")

                return TranslationTaskResult(
                    card: card,
                    result: .success(result),
                    duration: duration
                )

            } catch let error as TranslationError {
                // Only retry if error is retryable
                guard error.isRetryable else {
                    // Non-retryable error
                    let duration = Date().timeIntervalSince(startTime)
                    logger.error("Translation failed with non-retryable error: \(card.word.replacingOccurrences(of: "'", with: "\\'")) - \(error.localizedDescription)")

                    return TranslationTaskResult(
                        card: card,
                        result: .failure(error),
                        duration: duration
                    )
                }

                // Retryable error
                attempt += 1

                if attempt < maxRetries {
                    logger.info("Retrying translation: \(card.word.replacingOccurrences(of: "'", with: "\\'")) in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")

                    // Exponential backoff
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        logger.warning("Task.sleep interrupted: \(error.localizedDescription)")
                    }
                    delay *= 2
                    continue
                }

                // Max retries exceeded
                let duration = Date().timeIntervalSince(startTime)
                logger.error("Translation failed after max retries: \(card.word.replacingOccurrences(of: "'", with: "\\'")) (\(attempt + 1) attempts) - \(error.localizedDescription)")

                return TranslationTaskResult(
                    card: card,
                    result: .failure(error),
                    duration: duration
                )
            } catch {
                // Unknown error type
                let duration = Date().timeIntervalSince(startTime)
                let translationError = TranslationError.apiFailed

                logger.error("Translation failed with unknown error: \(card.word.replacingOccurrences(of: "'", with: "\\'")) - \(error.localizedDescription)")

                return TranslationTaskResult(
                    card: card,
                    result: .failure(translationError),
                    duration: duration
                )
            }
        }

        // Should never reach here, but handle gracefully
        let duration = Date().timeIntervalSince(startTime)
        return TranslationTaskResult(
            card: card,
            result: .failure(.apiFailed),
            duration: duration
        )
    }

    // MARK: - Single Translation

    /// Translate a word with its definition
    ///
    /// - Parameters:
    ///   - word: The vocabulary word to translate
    ///   - definition: The definition/context for the word
    ///   - context: Optional additional context sentence
    ///
    /// - Returns: TranslationResponse with translation and metadata
    /// - Throws: TranslationError if the request fails
    func translate(word: String, definition: String, context: String? = nil) async throws -> TranslationResponse {
        guard !apiKey.isEmpty else {
            logger.error("Translation failed: API key not configured")
            throw TranslationError.missingAPIKey
        }

        let systemPrompt = """
        Translate English vocabulary to \(targetLanguage) with CEFR level.

        Return ONLY raw JSON (no markdown):
        {
          "items": [{
            "target_word": "...",
            "context_sentence": "...",
            "translation": "specific to definition",
            "cefr_level": "A1-C2",
            "definition_en": "..."
          }]
        }

        Rules:
        - Single JSON object
        - Context-specific translation
        - Estimate CEFR level accurately
        """

        let userPrompt = """
        Word: \(word)
        Definition: \(definition)
        \(context.map { "Context: \($0)" } ?? "")
        """

        let request = TranslationRequest(
            model: "glm-4.7",
            temperature: 0.1,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        guard let url = URL(string: self.baseURL) else {
            logger.error("Invalid base URL: \(self.baseURL)")
            throw TranslationError.invalidConfiguration
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        logger.debug("Sending translation request for '\(word)' (URL: \(url.absoluteString), model: glm-4.7)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("Translation API error: Invalid HTTP response - \(String(errorBody.prefix(200)))")
            throw TranslationError.apiFailed
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"

            switch httpResponse.statusCode {
            case 429:
                logger.warning("Rate limit hit for '\(word.replacingOccurrences(of: "'", with: "\\'"))'")
                throw TranslationError.rateLimit

            case 400...499:
                logger.error("Client error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
                throw TranslationError.clientError(statusCode: httpResponse.statusCode, message: errorBody)

            case 500...599:
                logger.error("Server error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
                throw TranslationError.serverError(statusCode: httpResponse.statusCode, message: errorBody)

            default:
                logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
                throw TranslationError.apiFailed
            }
        }

        // Log raw response for debugging
        logger.debug("Raw response data: \(String(data: data, encoding: .utf8)?.prefix(1000) ?? "Unable to decode")")

        let rawResponse = try JSONDecoder().decode(ZAIResponse.self, from: data)
        let content = rawResponse.choices.first?.message.content ?? ""

        // Log the extracted content before processing
        logger.debug("Extracted content (first 500 chars): \(content.prefix(500))")

        // Extract JSON from content (handle markdown code blocks)
        let jsonContent = extractJSON(from: content)
        logger.debug("Extracted JSON: \(jsonContent.prefix(500))")

        guard let data = jsonContent.data(using: .utf8) else {
            logger.error("Failed to decode JSON content as UTF-8")
            throw TranslationError.invalidResponse(reason: "Content is not valid UTF-8")
        }

        do {
            let translation = try JSONDecoder().decode(TranslationResponse.self, from: data)
            logSuccess(word: word, translation: translation)
            return translation
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            logger.error("Content that failed to decode: \(String(jsonContent.prefix(500)))")
            throw TranslationError.invalidResponse(reason: error.localizedDescription)
        }
    }

    // MARK: - JSON Extraction

    /// Extract JSON from text, handling markdown code blocks
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract from ```json code blocks
        if let jsonStart = trimmed.range(of: "```json", options: .caseInsensitive) {
            let afterStart = jsonStart.upperBound
            if let jsonEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Extracted JSON from markdown code block")
                return json
            }
        }

        // Try to extract from ``` code blocks (without json specifier)
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<codeEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Extracted JSON from generic code block")
                return json
            }
        }

        // Try to extract JSON from { to } (first complete JSON object)
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            let json = String(trimmed[firstBrace...lastBrace])
            logger.debug("Extracted JSON from brace delimiters")
            return json
        }

        // Return original if no JSON found
        logger.debug("No JSON extraction patterns matched, using original text")
        return trimmed
    }

    /// Process successful translation result
    private func logSuccess(word: String, translation: TranslationResponse) {
        if let item = translation.items.first {
            logger.info("Successfully translated '\(word.replacingOccurrences(of: "'", with: "\\'"))' -> '\(item.targetTranslation.replacingOccurrences(of: "'", with: "\\'"))' (CEFR: \(item.cefrLevel))")
        }
    }

    // MARK: - Response Models

    private struct ZAIResponse: Codable {
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message

            struct Message: Codable {
                let content: String
            }
        }
    }

    // MARK: - Errors

    enum TranslationError: LocalizedError {
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
            case .clientError(let code, let message):
                if let msg = message {
                    return "Request failed (HTTP \(code)): \(msg)"
                }
                return "Request failed (HTTP \(code))"
            case .serverError(let code, _):
                return "Server is experiencing issues (HTTP \(code)). Please try again later."
            case .apiFailed:
                return "Translation API request failed"
            case .invalidResponse(let reason):
                if let r = reason {
                    return "Invalid response from translation API: \(r)"
                }
                return "Invalid response from translation API"
            case .cancelled:
                return "Translation was cancelled"
            case .offline:
                return "No internet connection. Please check your network and try again."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .missingAPIKey:
                return "Add your API key in Settings > Translation > Z.ai API Configuration"
            case .rateLimit:
                return "Wait a few seconds, then try again"
            case .offline:
                return "Check your WiFi or cellular connection"
            case .invalidConfiguration:
                return "Please contact support"
            default:
                return nil
            }
        }

        /// Whether this error is retryable with exponential backoff
        var isRetryable: Bool {
            switch self {
            case .rateLimit, .serverError, .offline:
                return true
            default:
                return false
            }
        }
    }
}
