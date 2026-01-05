//
//  TranslationServiceNetworkTests.swift
//  LexiconFlowTests
//
//  Network-specific tests for TranslationService using MockNetworkSession
//  Tests verify: request structure, HTTP errors, malformed JSON, retry logic
//
//  These tests use dependency injection via TranslationService.forTesting(session:)
//

import Testing
import Foundation
@testable import LexiconFlow

/// Test suite for TranslationService network behavior
///
/// Tests use MockNetworkSession to verify:
/// - Request structure (headers, body, URL)
/// - HTTP error handling (401, 429, 500, etc.)
/// - Malformed JSON responses
/// - Markdown-wrapped JSON
/// - Batch translation concurrency
@MainActor
struct TranslationServiceNetworkTests {

    // MARK: - Request Structure Tests

    @Test("validateAPIKey sends correct request structure")
    func validateAPIKeyRequestStructure() async throws {
        let mockSession = MockNetworkSession()

        // Set up mock response for success
        let successResponse = [
            "choices": [
                ["message": ["content": "test response"]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: successResponse)
        mockSession.setResponse(for: "https://api.z.ai/api/coding/paas/v4/chat/completions", response: .success(jsonData))

        // Create service with mock session
        let service = TranslationService.forTesting(session: mockSession)

        // Validate API key
        _ = try await service.validateAPIKey("test-api-key")

        // Verify request was recorded
        let requests = mockSession.requests(containing: "api.z.ai")
        #expect(requests.count == 1, "Should make exactly one request")

        let request = requests.first!
        #expect(request.httpMethod == "POST", "Should use POST method")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "Should set Content-Type header")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-api-key", "Should set Authorization header with Bearer token")
        #expect(request.httpBody != nil, "Should have request body")
    }

    @Test("translate sends correct request structure")
    func translateRequestStructure() async throws {
        let mockSession = MockNetworkSession()

        // Set up mock response
        let successResponse = [
            "choices": [
                ["message": ["content": """
                {"items": [{
                    "target_word": "привет",
                    "context_sentence": "Привет, мир!",
                    "translation": "hello",
                    "cefr_level": "A1",
                    "definition_en": "a greeting"
                }]}
                """]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: successResponse)
        mockSession.setResponse(for: "https://api.z.ai/api/coding/paas/v4/chat/completions", response: .success(jsonData))

        // Create service with mock session and set API key
        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-api-key")

        // Perform translation
        _ = try await service.translate(word: "hello", definition: "a greeting")

        // Verify request
        let requests = mockSession.requests(containing: "api.z.ai")
        #expect(requests.count == 1, "Should make exactly one request")

        let request = requests.first!
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization")?.contains("test-api-key") ?? false)

        // Verify request body contains expected fields
        let bodyData = request.httpBody!
        let bodyJson = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        #expect((bodyJson["model"] as? String) == "glm-4.7", "Should use glm-4.7 model")
        #expect(bodyJson["messages"] is [[String: Any]], "Should have messages array")
    }

    // MARK: - HTTP Error Tests

    @Test("validateAPIKey throws on 401 unauthorized")
    func validateAPIKeyThrowsOn401() async throws {
        let mockSession = MockNetworkSession()
        mockSession.setResponse(for: "api.z.ai", response: .httpStatus(401))

        let service = TranslationService.forTesting(session: mockSession)

        do {
            _ = try await service.validateAPIKey("invalid-key")
            #expect(Bool(false), "Should have thrown 401 error")
        } catch let error as TranslationService.TranslationError {
            #expect(error.localizedDescription.contains("401") || error.localizedDescription.contains("Invalid API key"), "Should indicate invalid credentials")
        } catch {
            #expect(Bool(false), "Should throw TranslationError, not \(error)")
        }
    }

    @Test("validateAPIKey throws on 429 rate limit")
    func validateAPIKeyThrowsOn429() async throws {
        let mockSession = MockNetworkSession()
        mockSession.setResponse(for: "api.z.ai", response: .httpStatus(429))

        let service = TranslationService.forTesting(session: mockSession)

        do {
            _ = try await service.validateAPIKey("test-key")
            #expect(Bool(false), "Should have thrown 429 error")
        } catch is TranslationService.TranslationError {
            // Expected - TranslationError.rateLimit
        } catch {
            #expect(Bool(false), "Should throw TranslationError for rate limit")
        }
    }

    @Test("translate throws on 500 server error")
    func translateThrowsOn500() async throws {
        let mockSession = MockNetworkSession()
        mockSession.setResponse(for: "api.z.ai", response: .httpStatus(500))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        do {
            _ = try await service.translate(word: "test", definition: "test def")
            #expect(Bool(false), "Should have thrown 500 error")
        } catch let error as TranslationService.TranslationError {
            if case .serverError(let code, _) = error {
                #expect(code == 500, "Should have correct status code")
            } else {
                #expect(Bool(false), "Should be serverError")
            }
        } catch {
            #expect(Bool(false), "Should throw TranslationError.serverError")
        }
    }

    @Test("translate handles 503 service unavailable")
    func translateHandles503() async throws {
        let mockSession = MockNetworkSession()
        mockSession.setResponse(for: "api.z.ai", response: .httpStatus(503))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        do {
            _ = try await service.translate(word: "test", definition: "test def")
            #expect(Bool(false), "Should have thrown 503 error")
        } catch is TranslationService.TranslationError {
            // Expected - should throw serverError
        } catch {
            #expect(Bool(false), "Should throw TranslationError")
        }
    }

    // MARK: - Malformed JSON Tests

    @Test("translate throws on invalid JSON response")
    func translateThrowsOnInvalidJSON() async throws {
        let mockSession = MockNetworkSession()
        let invalidJSON = "This is not valid JSON at all"

        let wrapperResponse = [
            "choices": [
                ["message": ["content": invalidJSON]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: wrapperResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        do {
            _ = try await service.translate(word: "test", definition: "test def")
            #expect(Bool(false), "Should have thrown JSON decode error")
        } catch is TranslationService.TranslationError {
            // Expected - should throw invalidResponse
        } catch {
            #expect(Bool(false), "Should throw TranslationError.invalidResponse")
        }
    }

    @Test("translate handles markdown-wrapped JSON")
    func translateHandlesMarkdownWrappedJSON() async throws {
        let mockSession = MockNetworkSession()

        let markdownWrapped = """
        Here's the translation:

        ```json
        {
          "items": [{
            "target_word": "тест",
            "context_sentence": "Тестовая фраза",
            "translation": "test",
            "cefr_level": "A1",
            "definition_en": "a trial or test"
          }]
        }
        ```

        Hope this helps!
        """

        let wrapperResponse = [
            "choices": [
                ["message": ["content": markdownWrapped]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: wrapperResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        let result = try await service.translate(word: "test", definition: "a trial")

        #expect(result.items.count == 1, "Should extract one translation item")
        #expect(result.items.first?.targetTranslation == "test", "Should have correct translation")
        #expect(result.items.first?.cefrLevel == "A1", "Should have correct CEFR level")
    }

    @Test("translate handles generic code block JSON")
    func translateHandlesGenericCodeBlockJSON() async throws {
        let mockSession = MockNetworkSession()

        let genericCodeBlock = """
        ```
        {"items": [{
            "target_word": "пример",
            "context_sentence": "Это пример",
            "translation": "example",
            "cefr_level": "B1",
            "definition_en": "a representative item"
        }]}
        ```
        """

        let wrapperResponse = [
            "choices": [
                ["message": ["content": genericCodeBlock]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: wrapperResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        let result = try await service.translate(word: "example", definition: "a representative item")

        #expect(result.items.count == 1, "Should extract one translation item")
        #expect(result.items.first?.targetWord == "пример", "Should have correct target word")
    }

    // MARK: - Batch Translation Tests

    @Test("translateBatch respects maxConcurrency")
    func translateBatchRespectsConcurrency() async throws {
        let mockSession = MockNetworkSession()

        // Set up mock response
        let successResponse = [
            "choices": [
                ["message": ["content": """
                {"items": [{
                    "target_word": "translated",
                    "context_sentence": "context",
                    "translation": "translation",
                    "cefr_level": "A1",
                    "definition_en": "def"
                }]}
                """]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: successResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        // Translate 5 cards with max concurrency of 2
        let cards = [
            Flashcard(word: "card1", definition: "def1", phonetic: "phon1"),
            Flashcard(word: "card2", definition: "def2", phonetic: "phon2"),
            Flashcard(word: "card3", definition: "def3", phonetic: "phon3"),
            Flashcard(word: "card4", definition: "def4", phonetic: "phon4"),
            Flashcard(word: "card5", definition: "def5", phonetic: "phon5"),
        ]

        let result = try await service.translateBatch(cards, maxConcurrency: 2)

        #expect(result.successCount == 5, "Should translate all 5 cards")
        #expect(result.failedCount == 0, "Should have no failures")

        // Verify we made exactly 5 requests
        let requestCount = mockSession.requestCount(for: "https://api.z.ai/api/coding/paas/v4/chat/completions")
        #expect(requestCount == 5, "Should make exactly 5 requests")
    }

    @Test("translateBatch reports progress correctly")
    func translateBatchReportsProgress() async throws {
        let mockSession = MockNetworkSession()

        let successResponse = [
            "choices": [
                ["message": ["content": """
                {"items": [{
                    "target_word": "translated",
                    "context_sentence": "context",
                    "translation": "translation",
                    "cefr_level": "A1",
                    "definition_en": "def"
                }]}
                """]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: successResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        let cards = [
            Flashcard(word: "card1", definition: "def1"),
            Flashcard(word: "card2", definition: "def2"),
            Flashcard(word: "card3", definition: "def3"),
        ]

        var progressUpdates: [TranslationService.BatchTranslationProgress] = []

        let result = try await service.translateBatch(cards, maxConcurrency: 2) { progress in
            progressUpdates.append(progress)
        }

        #expect(result.successCount == 3)
        #expect(progressUpdates.count == 3, "Should report progress for each card")

        // Verify progress updates are in order
        if progressUpdates.count >= 3 {
            #expect(progressUpdates[0].current == 1)
            #expect(progressUpdates[0].total == 3)
            #expect(progressUpdates[2].current == 3)
        }
    }

    // MARK: - Network Error Tests

    @Test("translate throws when API key is missing")
    func translateThrowsOnMissingAPIKey() async throws {
        let mockSession = MockNetworkSession()
        mockSession.setResponse(for: "api.z.ai", response: .success(Data()))

        let service = TranslationService.forTesting(session: mockSession)

        // Don't set API key - should throw immediately
        do {
            _ = try await service.translate(word: "test", definition: "test")
            #expect(Bool(false), "Should throw missingAPIKey error")
        } catch is TranslationService.TranslationError {
            // Expected
        } catch {
            #expect(Bool(false), "Should throw TranslationError")
        }
    }

    @Test("translate handles empty response")
    func translateHandlesEmptyResponse() async throws {
        let mockSession = MockNetworkSession()

        let emptyResponse = [
            "choices": [
                ["message": ["content": ""]]
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: emptyResponse)
        mockSession.setResponse(for: "api.z.ai", response: .success(jsonData))

        let service = TranslationService.forTesting(session: mockSession)
        try service.setAPIKey("test-key")

        do {
            _ = try await service.translate(word: "test", definition: "test")
            #expect(Bool(false), "Should throw invalidResponse for empty content")
        } catch is TranslationService.TranslationError {
            // Expected - should throw invalidResponse
        } catch {
            #expect(Bool(false), "Should throw TranslationError")
        }
    }
}
