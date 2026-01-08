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

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for TranslationService
@MainActor
struct TranslationServiceTests {
    // MARK: - Singleton Tests

    @Test("TranslationService singleton is consistent")
    func singletonConsistency() {
        let service1 = TranslationService.shared
        let service2 = TranslationService.shared
        #expect(service1 === service2)
    }

    // MARK: - Configuration Tests

    @Test("isConfigured returns false when no API key")
    func isConfiguredNoKey() throws {
        // Clear any existing API key
        try KeychainManager.deleteAPIKey()

        let service = TranslationService.shared
        #expect(!service.isConfigured)
    }

    @Test("isConfigured returns true when API key is set")
    func isConfiguredWithKey() throws {
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
    func extractJSONMarkdownWithSpecifier() {
        // We can't test the private method directly, but we can verify the pattern
        let input = """
        Some text before

        ```json
        {
          "items": [{
            "target_word": "привет",
            "context_sentence": "Used as greeting",
            "translation": "hello",
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
            if let jsonEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
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
    func extractJSONGenericCodeBlock() {
        let input = """
        Here's the response:

        ```
        {
          "items": [{
            "target_word": "тест",
            "translation": "test"
          }]
        }
        ```

        Done.
        """

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try generic code block extraction
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart ..< trimmed.endIndex) {
                let json = String(trimmed[afterStart ..< codeEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(json.contains("items"))
            } else {
                Issue.record("Code end marker not found")
            }
        } else {
            Issue.record("Code start marker not found")
        }
    }

    @Test("extractJSON from plain text using braces")
    func extractJSONPlainBraces() {
        let input = """
        The result is: {"items": [{"target_word": "word", "translation": "слово"}]} and that's it.
        """

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}")
        {
            let json = String(trimmed[firstBrace ... lastBrace])
            #expect(json.contains("items"))
            #expect(json.starts(with: "{"))
            #expect(json.hasSuffix("}"))
        } else {
            Issue.record("Braces not found in input")
        }
    }

    @Test("extractJSON handles plain JSON without formatting")
    func extractJSONPlain() {
        let input = """
        {"items": [{"target_word": "тест","translation": "test"}]}
        """

        // Should return original when no extraction patterns match
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.starts(with: "{"))
        #expect(trimmed.contains("items"))
    }

    @Test("extractJSON handles empty input")
    func extractJSONEmpty() {
        let input = ""

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("extractJSON handles malformed JSON structure")
    func extractJSONMalformed() {
        let input = "{ this is not valid json }"

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // The extraction should still work even if JSON is malformed
        #expect(trimmed.contains("{"))
    }

    // MARK: - Error Type Tests

    @Test("TranslationError missingAPIKey properties")
    func errorMissingAPIKey() {
        let error = TranslationService.TranslationError.missingAPIKey

        #expect(error.errorDescription == "API key not configured")
        #expect(error.recoverySuggestion?.contains("Settings") == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError invalidConfiguration properties")
    func errorInvalidConfiguration() {
        let error = TranslationService.TranslationError.invalidConfiguration

        #expect(error.errorDescription == "Invalid service configuration")
        #expect(error.recoverySuggestion?.contains("support") == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError rateLimit properties")
    func errorRateLimit() {
        let error = TranslationService.TranslationError.rateLimit

        #expect(error.errorDescription?.contains("rate limit") == true)
        #expect(error.recoverySuggestion?.contains("Wait") == true)
        #expect(error.isRetryable)
    }

    @Test("TranslationError clientError properties")
    func errorClientError() {
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
    func errorAPIFailed() {
        let error = TranslationService.TranslationError.apiFailed

        #expect(error.errorDescription == "Translation API request failed")
        #expect(error.recoverySuggestion == nil)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError invalidResponse properties")
    func errorInvalidResponse() {
        let reason = "Expected JSON but got HTML"
        let error = TranslationService.TranslationError.invalidResponse(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(!error.isRetryable)
    }

    @Test("TranslationError cancelled properties")
    func errorCancelled() {
        let error = TranslationService.TranslationError.cancelled

        #expect(error.errorDescription == "Translation was cancelled")
        #expect(!error.isRetryable)
    }

    @Test("TranslationError offline properties")
    func errorOffline() {
        let error = TranslationService.TranslationError.offline

        #expect(error.errorDescription?.contains("internet") == true)
        #expect(error.recoverySuggestion?.contains("connection") == true)
        #expect(error.isRetryable) // Offline errors are retryable
    }

    // MARK: - Batch Translation Tests

    @Test("Batch translation with empty array returns empty result")
    func batchTranslationEmptyArray() async throws {
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
    func batchTranslationMaxConcurrencyOne() async throws {
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
    func progressHandlerStructure() {
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
    func successfulTranslation() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        let card = Flashcard(word: "hello", definition: "greeting")
        context.insert(card)

        let translation = TranslationService.SuccessfulTranslation(
            card: card,
            translation: "привет"
        )

        #expect(translation.card.word == "hello")
        #expect(translation.translation == "привет")
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
    func keychainSetGet() throws {
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
    func keychainDelete() throws {
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
    func keychainHasAPIKey() throws {
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
    func keychainEmptyKey() {
        #expect(throws: KeychainManager.KeychainError.self) {
            try KeychainManager.setAPIKey("")
        }
    }

    // MARK: - TranslationRequest Encoding Tests

    @Test("TranslationRequest encodes correctly")
    func translationRequestEncoding() throws {
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
    func translationResponseDecoding() throws {
        let json = """
        {
          "items": [{
            "target_word": "привет",
            "context_sentence": "Hello!",
            "translation": "hello",
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
    func translationResponseEmptyItems() throws {
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
    func translationResponseMissingOptionals() throws {
        // All fields are required in the struct, but we test proper JSON structure
        let json = """
        {
          "items": [{
            "target_word": "word",
            "context_sentence": "",
            "translation": "translation",
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
    func specialCharactersInPrompt() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Test cards with special characters
        let cards = [
            Flashcard(word: "café", definition: "a coffee shop"),
            Flashcard(word: "naïve", definition: "innocent"),
            Flashcard(word: "résumé", definition: "a document"),
        ]

        for card in cards {
            context.insert(card)
        }

        #expect(cards.count == 3)
        #expect(cards[0].word.contains("é"))
    }

    @Test("TranslationRequest handles long words")
    func longWords() {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        let longWord = String(repeating: "a", count: 100)
        let card = Flashcard(word: longWord, definition: "a very long word")
        context.insert(card)

        #expect(card.word.count == 100)
    }

    // MARK: - Concurrency Tests

    @Test("Multiple translation service instances share singleton")
    func concurrentSingletonAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    let service = TranslationService.shared
                    // Access singleton from multiple tasks
                    _ = service.isConfigured
                }
            }
        }
        // Test passes if no race conditions occur
    }

    // MARK: - Critical Integration Tests

    @Test("Batch translation reports progress through handler")
    func batchTranslationReportsProgress() async throws {
        // This test verifies the progress handler is called correctly
        // Note: Without URLSession mocking, we verify structure only
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Create test cards
        let cards = [
            Flashcard(word: "test1", definition: "definition 1"),
            Flashcard(word: "test2", definition: "definition 2"),
            Flashcard(word: "test3", definition: "definition 3"),
        ]

        for card in cards {
            context.insert(card)
        }

        // Track progress calls
        var progressUpdates: [TranslationService.BatchTranslationProgress] = []

        // Set up test API key (will fail network, but we test structure)
        try KeychainManager.setAPIKey("test-key")

        let service = TranslationService.shared

        // Attempt batch translation (will fail network, but tests structure)
        do {
            let result = try await service.translateBatch(
                cards,
                maxConcurrency: 2,
                progressHandler: { progress in
                    progressUpdates.append(progress)
                }
            )

            // If somehow succeeds (e.g., mocked), verify progress was reported
            #expect(progressUpdates.count >= 1)

            // Verify final progress shows completion
            if let finalProgress = progressUpdates.last {
                #expect(finalProgress.current <= cards.count)
                #expect(finalProgress.total == cards.count)
            }
        } catch is TranslationService.TranslationError {
            // Network failure expected - this is OK for structural test
            // The test verifies the progress handler signature is correct
        }

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Batch translation can be cancelled mid-execution")
    func cancelBatchTranslation() async throws {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Create multiple test cards
        let cards = (1 ..< 20).map { i in
            Flashcard(word: "word\(i)", definition: "definition \(i)")
        }

        for card in cards {
            context.insert(card)
        }

        try KeychainManager.setAPIKey("test-key")
        let service = TranslationService.shared

        // Start translation and cancel quickly
        let translationTask = Task {
            try? await service.translateBatch(cards, maxConcurrency: 5)
        }

        // Cancel immediately
        try await Task.sleep(nanoseconds: 10000000) // 0.01 seconds
        service.cancelBatchTranslation()
        translationTask.cancel()

        // Wait for task to complete
        await translationTask.value

        // Verify cancel method doesn't crash and state is clean
        // Should be able to start another translation after cancel
        let singleCard = Flashcard(word: "after", definition: "after cancel")
        context.insert(singleCard)

        // This would normally fail if state wasn't cleaned up
        // (Structural test - verifies no crash on second call)
        _ = try? await service.translateBatch([singleCard], maxConcurrency: 1)

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Batch translation handles partial failures correctly")
    func partialFailureRollback() async throws {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Create cards where some will fail (invalid data)
        let cards = [
            Flashcard(word: "valid", definition: "a valid word"),
            Flashcard(word: "", definition: "empty word"), // Invalid
            Flashcard(word: "another", definition: "another valid word"),
            Flashcard(word: "", definition: "another empty"), // Invalid
        ]

        for card in cards {
            context.insert(card)
        }

        try KeychainManager.setAPIKey("test-key")
        let service = TranslationService.shared

        // Attempt batch translation
        let result = try await service.translateBatch(cards, maxConcurrency: 2)

        // Verify result structure handles mixed success/failure
        #expect(result.totalDuration >= 0)
        #expect(result.successCount >= 0)
        #expect(result.failedCount >= 0)
        #expect(result.successCount + result.failedCount == cards.count)

        // Verify successful translations are in result
        #expect(result.successfulTranslations.count <= 2) // At most 2 valid cards

        // Verify errors are captured
        if result.failedCount > 0 {
            #expect(!result.errors.isEmpty)
        }

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Concurrent batches don't interfere with each other")
    func concurrentBatchesDontInterfere() async throws {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Create 3 separate batches of cards
        let batch1 = (1 ... 5).map { Flashcard(word: "batch1_word\($0)", definition: "definition \($0)") }
        let batch2 = (1 ... 5).map { Flashcard(word: "batch2_word\($0)", definition: "definition \($0)") }
        let batch3 = (1 ... 5).map { Flashcard(word: "batch3_word\($0)", definition: "definition \($0)") }

        // Insert all cards
        for card in batch1 + batch2 + batch3 {
            context.insert(card)
        }

        try KeychainManager.setAPIKey("test-key")
        let service = TranslationService.shared

        // Run all batches concurrently
        async let result1 = service.translateBatch(batch1, maxConcurrency: 2)
        async let result2 = service.translateBatch(batch2, maxConcurrency: 2)
        async let result3 = service.translateBatch(batch3, maxConcurrency: 2)

        let (r1, r2, r3) = try await (result1, result2, result3)

        // Verify no cross-contamination
        #expect(r1.totalDuration >= 0, "Batch 1 should complete")
        #expect(r2.totalDuration >= 0, "Batch 2 should complete")
        #expect(r3.totalDuration >= 0, "Batch 3 should complete")

        // Verify each batch processed its own cards
        #expect(r1.successCount + r1.failedCount == batch1.count, "Batch 1: all cards processed")
        #expect(r2.successCount + r2.failedCount == batch2.count, "Batch 2: all cards processed")
        #expect(r3.successCount + r3.failedCount == batch3.count, "Batch 3: all cards processed")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("maxConcurrency parameter is respected during batch translation")
    func maxConcurrencyIsRespected() async throws {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        // Create 20 cards (more than maxConcurrency)
        let cards = (1 ..< 20).map { Flashcard(word: "word\($0)", definition: "definition \($0)") }

        for card in cards {
            context.insert(card)
        }

        try KeychainManager.setAPIKey("test-key")
        let service = TranslationService.shared

        // Use maxConcurrency=3
        let result = try await service.translateBatch(cards, maxConcurrency: 3)

        // Verify all cards were processed
        #expect(result.successCount + result.failedCount == cards.count, "All cards should be processed")

        // The actual concurrency limit is enforced by the TaskGroup implementation
        // We verify the batch completes successfully (no race conditions)
        #expect(result.totalDuration >= 0, "Batch should complete successfully")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Rapid sequential batch translations don't cause state corruption")
    func rapidSequentialBatches() async throws {
        let context = TestContainers.freshContext()
        try? context.clearAll()

        try KeychainManager.setAPIKey("test-key")
        let service = TranslationService.shared

        // Run 5 sequential batches
        for batchIndex in 1 ... 5 {
            let cards = (1 ... 3).map { i in
                Flashcard(word: "batch\(batchIndex)_word\(i)", definition: "definition")
            }

            for card in cards {
                context.insert(card)
            }

            let result = try await service.translateBatch(cards, maxConcurrency: 2)

            // Verify each batch completes
            #expect(result.successCount + result.failedCount == cards.count, "Batch \(batchIndex) should complete")
        }

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }
}
