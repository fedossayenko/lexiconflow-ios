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
@MainActor
final class TranslationService {
    /// Shared singleton instance
    static let shared = TranslationService()

    private let apiKey: String
    private let baseURL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "TranslationService")

    private var sourceLanguage = "en"
    private var targetLanguage = "ru"

    private init() {
        // Load API key from UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "zai_api_key") ?? ""
    }

    /// Set or update the API key
    ///
    /// - Parameter key: The Z.ai API key
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "zai_api_key")
        logger.info("API key updated")
    }

    /// Check if API key is configured
    var isConfigured: Bool {
        !apiKey.isEmpty
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
            let russianTranslation: String
            let cefrLevel: String
            let definitionEn: String

            enum CodingKeys: String, CodingKey {
                case targetWord = "target_word"
                case contextSentence = "context_sentence"
                case russianTranslation = "russian_translation"
                case cefrLevel = "cefr_level"
                case definitionEn = "definition_en"
            }
        }
    }

    // MARK: - Cancellation

    private var cancellationTask: Task<Void, Never>?

    /// Cancel any ongoing batch translation
    func cancelBatchTranslation() {
        cancellationTask?.cancel()
        logger.info("Batch translation cancelled")
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

        logger.info("Starting batch translation of \(cards.count) cards with max concurrency: \(maxConcurrency)")

        let startTime = Date()
        var results: [TranslationTaskResult] = []
        var completedCount = 0

        // Create cancellation tracking task
        let currentTask = Task<Void, Never> {}
        self.cancellationTask = currentTask

        // Use TaskGroup for concurrent execution
        return await withTaskGroup(of: TranslationTaskResult.self) { group in
            // Add all tasks to the group
            for (index, card) in cards.enumerated() {
                // Implement semaphore-like concurrency limit
                if index >= maxConcurrency {
                    // Wait for one task to complete before adding more
                    if let result = await group.next() {
                        results.append(result)
                        completedCount += 1

                        // Report progress
                        if let handler = progressHandler {
                            let progress = BatchTranslationProgress(
                                current: completedCount,
                                total: cards.count,
                                currentWord: result.card.word
                            )
                            handler(progress)
                        }
                    }
                }

                // Check for cancellation
                if currentTask.isCancelled {
                    logger.info("Batch translation cancelled at index \(index)")
                    return TranslationBatchResult(
                        successCount: 0,
                        failedCount: cards.count,
                        totalDuration: Date().timeIntervalSince(startTime),
                        errors: [.cancelled],
                        successfulTranslations: []
                    )
                }

                // Add translation task
                group.addTask {
                    await self.performTranslationWithRetry(card: card)
                }
            }

            // Collect remaining results
            for await result in group {
                results.append(result)
                completedCount += 1

                // Report progress for remaining items
                if let handler = progressHandler {
                    let progress = BatchTranslationProgress(
                        current: completedCount,
                        total: cards.count,
                        currentWord: result.card.word
                    )
                    handler(progress)
                }
            }

            // Calculate final result
            let successes = results.filter { result in
                switch result.result {
                case .success: return true
                case .failure: return false
                }
            }
            let failures = results.filter { result in
                switch result.result {
                case .success: return false
                case .failure: return true
                }
            }
            let errors = failures.compactMap { (result) -> TranslationError? in
                switch result.result {
                case .failure(let error): return error
                case .success: return nil
                }
            }

            // Extract successful translations to apply to cards
            let successfulTranslations: [SuccessfulTranslation] = successes.compactMap { result in
                guard case .success(let response) = result.result,
                      let item = response.items.first else {
                    return nil
                }
                return SuccessfulTranslation(
                    card: result.card,
                    translation: item.russianTranslation,
                    cefrLevel: item.cefrLevel,
                    contextSentence: item.contextSentence,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            }

            let duration = Date().timeIntervalSince(startTime)

            let batchResult = TranslationBatchResult(
                successCount: successes.count,
                failedCount: failures.count,
                totalDuration: duration,
                errors: errors,
                successfulTranslations: successfulTranslations
            )

            logger.info("""
                Batch translation complete:
                - Success: \(successes.count)
                - Failed: \(failures.count)
                - Duration: \(String(format: "%.2f", duration))s
                """)

            return batchResult
        }
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

                logger.debug("Translation succeeded for '\(card.word)' after \(attempt + 1) attempt(s)")

                return TranslationTaskResult(
                    card: card,
                    result: .success(result),
                    duration: duration
                )

            } catch let error as TranslationError {
                // Check if it's a rate limit error (HTTP 429)
                if error == .apiFailed {
                    // We'll treat apiFailed as potentially rate-limit related
                    // In production, you'd check the actual HTTP status code
                    attempt += 1

                    if attempt < maxRetries {
                        logger.info("Rate limit hit for '\(card.word)', retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")

                        // Exponential backoff
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        delay *= 2
                        continue
                    }
                }

                // Non-retryable error or max retries exceeded
                let duration = Date().timeIntervalSince(startTime)
                logger.error("Translation failed for '\(card.word)' after \(attempt + 1) attempt(s): \(error.localizedDescription)")

                return TranslationTaskResult(
                    card: card,
                    result: .failure(error),
                    duration: duration
                )
            } catch {
                // Unknown error type
                let duration = Date().timeIntervalSince(startTime)
                let translationError = TranslationError.apiFailed

                logger.error("Unknown error translating '\(card.word)': \(error.localizedDescription)")

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
            "russian_translation": "specific to definition",
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

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        logger.debug("Sending translation request for '\(word)'")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("Translation API error: Invalid HTTP response")
            logger.error("Error body: \(errorBody)")
            throw TranslationError.apiFailed
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            logger.error("Translation API HTTP error: \(httpResponse.statusCode)")
            logger.error("Error body: \(errorBody)")
            throw TranslationError.apiFailed
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
            throw TranslationError.invalidResponse
        }

        do {
            let translation = try JSONDecoder().decode(TranslationResponse.self, from: data)
            logSuccess(word: word, translation: translation)
            return translation
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            logger.error("Content that failed to decode: \(jsonContent)")
            throw TranslationError.invalidResponse
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
            logger.info("Successfully translated '\(word)' -> '\(item.russianTranslation)' (CEFR: \(item.cefrLevel))")
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
        case apiFailed
        case invalidResponse
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API key not configured"
            case .apiFailed:
                return "Translation API request failed"
            case .invalidResponse:
                return "Invalid response from API"
            case .cancelled:
                return "Translation was cancelled"
            }
        }
    }
}
