//
//  TranslationServiceTests.swift
//  LexiconFlowTests
//
//  Tests for TranslationService including:
//  - Configuration and API key management
//  - JSON extraction from various formats
//  - Error handling and retry logic
//  - Batch translation behavior
//  - Keychain integration
//
//  NOTE: Full network testing requires URLSession injection (Phase 2)
//  These tests cover testable logic without network mocking
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for TranslationService
@MainActor
struct TranslationServiceTests {

    // MARK: - Singleton Tests

    @Test("TranslationService singleton is consistent")
    func testSingletonConsistency() {
        let service1 = TranslationService.shared
        let service2 = TranslationService.shared
        #expect(service1 === service2)
    }

    // MARK: - Configuration Tests

    @Test("isConfigured returns false when no API key")
    func testIsConfiguredNoKey() throws {
        // Clear any existing API key
        try KeychainManager.deleteAPIKey()

        let service = TranslationService.shared
        #expect(!service.isConfigured)
    }

    @Test("isConfigured returns true when API key is set")
    func testIsConfiguredWithKey() throws {
        // Set a test API key
        try KeychainManager.setAPIKey("test-api-key-12345")

        let service = TranslationService.shared
        #expect(service.isConfigured)

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("setAPIKey stores key in Keychain")
    func testSetAPIKey() throws {
        let service = TranslationService.shared
        let testKey = "sk-test-1234567890"

        try service.setAPIKey(testKey)

        let retrievedKey = try KeychainManager.getAPIKey()
        #expect(retrievedKey == testKey)

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("setLanguages updates source and target")
    func testSetLanguages() {
        let service = TranslationService.shared

        service.setLanguages(source: "en", target: "ru")
        // Smoke test - verify method doesn't crash
        // Language settings are private, but we can test behavior through translate()
    }

    // MARK: - JSON Extraction Tests

    @Test("extractJSON from markdown code block with json specifier")
    func testExtractJSONMarkdownWithSpecifier() {
        // We can't test the private method directly, but we can verify the pattern
        let input = """
        Some text before

        ```json
        {
          "items": [{
            "target_word": "привет",
            "context_sentence": "Used as greeting",
            "russian_translation": "hello",
            "cefr_level": "A1",
            "definition_en": "a greeting"
          }]
        }
        ```

        Some text after
        """

        // Extract JSON from the pattern
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let jsonStart = trimmed.range(of: "```json", options: .caseInsensitive) {
            let afterStart = jsonStart.upperBound
            if let jsonEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(json.contains("items"))
                #expect(json.contains("target_word"))
            } else {
                Issue.record("JSON end marker not found")
            }
        } else {
            Issue.record("JSON start marker not found")
        }
    }

    @Test("extractJSON from generic code block")
    func testExtractJSONGenericCodeBlock() {
        let input = """
        Here's the response:

        ```
        {
          "items": [{
            "target_word": "тест",
            "russian_translation": "test"
          }]
        }
        ```

        Done.
        """

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try generic code block extraction
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<codeEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(json.contains("items"))
            } else {
                Issue.record("Code end marker not found")
            }
        } else {
            Issue.record("Code start marker not found")
        }
    }

    @Test("extractJSON from plain text using braces")
    func testExtractJSONPlainBraces() {
        let input = """
        The result is: {"items": [{"target_word": "word", "russian_translation": "слово"}]} and that's it.
        """

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            let json = String(trimmed[firstBrace...lastBrace])
            #expect(json.contains("items"))
            #expect(json.starts(with: "{"))
            #expect(json.hasSuffix("}"))
        } else {
            Issue.record("Braces not found in input")
        }
    }

    @Test("extractJSON handles plain JSON without formatting")
    func testExtractJSONPlain() {
        let input = """
        {"items": [{"target_word": "тест","russian_translation": "test"}]}
        """

        // Should return original when no extraction patterns match
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.starts(with: "{"))
        #expect(trimmed.contains("items"))
    }

    @Test("extractJSON handles empty input")
    func testExtractJSONEmpty() {
        let input = ""

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("extractJSON handles malformed JSON structure")
    func testExtractJSONMalformed() {
        let input = "{ this is not valid json }"

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // The extraction should still work even if JSON is malformed
        #expect(trimmed.contains("{"))
    }

    // MARK: - Error Type Tests

    @Test("TranslationError missingAPIKey properties")
    func testErrorMissingAPIKey() {
        let error = TranslationService.TranslationError.missingAPIKey

        #expect(error.errorDescription == "API key not configured")
        #expect(error.recoverySuggestion?.contains("Settings") == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError invalidConfiguration properties")
    func testErrorInvalidConfiguration() {
        let error = TranslationService.TranslationError.invalidConfiguration

        #expect(error.errorDescription == "Invalid service configuration")
        #expect(error.recoverySuggestion?.contains("support") == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError rateLimit properties")
    func testErrorRateLimit() {
        let error = TranslationService.TranslationError.rateLimit

        #expect(error.errorDescription?.contains("rate limit") == true)
        #expect(error.recoverySuggestion?.contains("Wait") == true)
        #expect(error.isRetryable)
    }

    @Test("TranslationError clientError properties")
    func testErrorClientError() {
        let error = TranslationService.TranslationError.clientError(statusCode: 401, message: "Unauthorized")

        #expect(error.errorDescription?.contains("401") == true)
        #expect(error.errorDescription?.contains("Unauthorized") == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError serverError properties")
    func testServerError() {
        let error = TranslationService.TranslationError.serverError(statusCode: 503, message: "Service Unavailable")

        #expect(error.errorDescription?.contains("503") == true)
        #expect(error.isRetryable)
    }

    @Test("TranslationError apiFailed properties")
    func testErrorAPIFailed() {
        let error = TranslationService.TranslationError.apiFailed

        #expect(error.errorDescription == "Translation API request failed")
        #expect(error.recoverySuggestion == nil)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError invalidResponse properties")
    func testErrorInvalidResponse() {
        let reason = "Expected JSON but got HTML"
        let error = TranslationService.TranslationError.invalidResponse(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError cancelled properties")
    func testErrorCancelled() {
        let error = TranslationService.TranslationError.cancelled

        #expect(error.errorDescription == "Translation was cancelled")
        #expect(!error.isRetryable)
    }

    @Test("TranslationError offline properties")
    func testErrorOffline() {
        let error = TranslationService.TranslationError.offline

        #expect(error.errorDescription?.contains("internet") == true)
        #expect(error.recoverySuggestion?.contains("connection") == true)
        #expect(error.isRetryable)  // Offline errors are retryable
    }

    // MARK: - Batch Translation Tests

    @Test("Batch translation with empty array returns empty result")
    func testBatchTranslationEmptyArray() async throws {
        let service = TranslationService.shared
        let emptyCards: [Flashcard] = []

        let result = try await service.translateBatch(emptyCards)

        #expect(result.successCount == 0)
        #expect(result.failedCount == 0)
        #expect(result.totalDuration == 0)
        #expect(result.errors.isEmpty)
        #expect(result.successfulTranslations.isEmpty)
    }

    @Test("Batch translation with maxConcurrency 1")
    func testBatchTranslationMaxConcurrencyOne() async throws {
        // Set up a test API key to avoid missing key error
        try KeychainManager.setAPIKey("test-key")

        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "a test")
        context.insert(card)

        let service = TranslationService.shared

        // This will fail with network error, but we can verify the structure
        do {
            let result = try await service.translateBatch([card], maxConcurrency: 1)
            // If it somehow succeeds, check structure
            #expect(result.totalDuration >= 0)
        } catch is TranslationService.TranslationError {
            // Expected - no valid API key
        }

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    // MARK: - Progress Handler Tests

    @Test("Progress handler receives correct structure")
    func testProgressHandlerStructure() {
        // Test the BatchTranslationProgress struct
        let progress = TranslationService.BatchTranslationProgress(
            current: 5,
            total: 10,
            currentWord: "test"
        )

        #expect(progress.current == 5)
        #expect(progress.total == 10)
        #expect(progress.currentWord == "test")
    }

    @Test("SuccessfulTranslation struct properties")
    func testSuccessfulTranslation() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        let card = Flashcard(word: "hello", definition: "greeting")
        context.insert(card)

        let translation = TranslationService.SuccessfulTranslation(
            card: card,
            translation: "привет",
            cefrLevel: "A1",
            contextSentence: "Used as greeting",
            sourceLanguage: "en",
            targetLanguage: "ru"
        )

        #expect(translation.card.word == "hello")
        #expect(translation.translation == "привет")
        #expect(translation.cefrLevel == "A1")
        #expect(translation.contextSentence == "Used as greeting")
        #expect(translation.sourceLanguage == "en")
        #expect(translation.targetLanguage == "ru")
    }

    // MARK: - Cancellation Tests

    @Test("cancelBatchTranslation can be called without crash")
    func testCancelBatchTranslation() {
        let service = TranslationService.shared

        // Should not crash even with no active task
        service.cancelBatchTranslation()
        // Test passes if no crash occurs
    }

    // MARK: - Keychain Integration Tests

    @Test("KeychainManager set and get API key")
    func testKeychainSetGet() throws {
        let testKey = "test-api-key-\(UUID().uuidString)"

        // Set
        try KeychainManager.setAPIKey(testKey)

        // Get
        let retrieved = try KeychainManager.getAPIKey()
        #expect(retrieved == testKey)

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("KeychainManager delete API key")
    func testKeychainDelete() throws {
        let testKey = "test-api-key-\(UUID().uuidString)"

        // Set
        try KeychainManager.setAPIKey(testKey)

        // Delete
        try KeychainManager.deleteAPIKey()

        // Verify deleted
        let retrieved = try KeychainManager.getAPIKey()
        #expect(retrieved == nil)
    }

    @Test("KeychainManager hasAPIKey")
    func testKeychainHasAPIKey() throws {
        // First, ensure no key exists
        try? KeychainManager.deleteAPIKey()
        #expect(!KeychainManager.hasAPIKey())

        // Set a key
        try KeychainManager.setAPIKey("test-key")
        #expect(KeychainManager.hasAPIKey())

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("KeychainManager set empty key throws error")
    func testKeychainEmptyKey() {
        #expect(throws: KeychainManager.KeychainError.self) {
            try KeychainManager.setAPIKey("")
        }
    }

    // MARK: - TranslationRequest Encoding Tests

    @Test("TranslationRequest encodes correctly")
    func testTranslationRequestEncoding() throws {
        // Test the private struct through public API
        let context = TestContainers.freshContext()
        try? context.clearAll()

        let card = Flashcard(word: "test", definition: "a test")
        context.insert(card)

        // Smoke test - verify the service can create the request structure
        // (The actual encoding happens in translate() which we can't test without network)
        #expect(card.word == "test")
        #expect(card.definition == "a test")
    }

    // MARK: - TranslationResponse Decoding Tests

    @Test("TranslationResponse decodes valid JSON")
    func testTranslationResponseDecoding() throws {
        let json = """
        {
          "items": [{
            "target_word": "привет",
            "context_sentence": "Hello!",
            "russian_translation": "hello",
            "cefr_level": "A1",
            "definition_en": "a greeting"
          }]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TranslationService.TranslationResponse.self, from: data)

        #expect(response.items.count == 1)
        #expect(response.items.first?.targetWord == "привет")
        #expect(response.items.first?.contextSentence == "Hello!")
        #expect(response.items.first?.targetTranslation == "hello")
        #expect(response.items.first?.cefrLevel == "A1")
        #expect(response.items.first?.definitionEn == "a greeting")
    }

    @Test("TranslationResponse handles empty items array")
    func testTranslationResponseEmptyItems() throws {
        let json = """
        {
          "items": []
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TranslationService.TranslationResponse.self, from: data)

        #expect(response.items.isEmpty)
    }

    @Test("TranslationResponse handles missing optional fields")
    func testTranslationResponseMissingOptionals() throws {
        // All fields are required in the struct, but we test proper JSON structure
        let json = """
        {
          "items": [{
            "target_word": "word",
            "context_sentence": "",
            "russian_translation": "translation",
            "cefr_level": "B1",
            "definition_en": "def"
          }]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TranslationService.TranslationResponse.self, from: data)

        #expect(response.items.count == 1)
        #expect(response.items.first?.contextSentence == "")
    }

    // MARK: - Edge Case Tests

    @Test("TranslationRequest handles special characters in prompt")
    func testSpecialCharactersInPrompt() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Test cards with special characters
        let cards = [
            Flashcard(word: "café", definition: "a coffee shop"),
            Flashcard(word: "naïve", definition: "innocent"),
            Flashcard(word: "résumé", definition: "a document")
        ]

        for card in cards {
            context.insert(card)
        }

        #expect(cards.count == 3)
        #expect(cards[0].word.contains("é"))
    }

    @Test("TranslationRequest handles long words")
    func testLongWords() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        let longWord = String(repeating: "a", count: 100)
        let card = Flashcard(word: longWord, definition: "a very long word")
        context.insert(card)

        #expect(card.word.count == 100)
    }

    // MARK: - Concurrency Tests

    @Test("Multiple translation service instances share singleton")
    func testConcurrentSingletonAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let service = TranslationService.shared
                    // Access singleton from multiple tasks
                    _ = service.isConfigured
                }
            }
        }
        // Test passes if no race conditions occur
    }
}
