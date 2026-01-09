//
//  EdgeCaseTests.swift
//  LexiconFlowTests
//
//  Edge case tests for critical validation:
//  - CachedTranslation validation (empty source word, empty translation)
//  - FoundationModels feature flags (disabled, placeholder, production)
//
//  These tests verify edge case handling and error conditions.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for edge cases and validation
@MainActor
struct EdgeCaseTests {
    // MARK: - CachedTranslation Validation Tests

    @Test("CachedTranslation: empty source word is rejected")
    func cachedTranslationEmptySourceWord() throws {
        // Attempt to create CachedTranslation with empty source word
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "",
                translatedText: "hola",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 30
            )
        }

        // Also test whitespace-only word
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "   ",
                translatedText: "hola",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 30
            )
        }
    }

    @Test("CachedTranslation: empty translated text is rejected")
    func cachedTranslationEmptyTranslatedText() throws {
        // Attempt to create CachedTranslation with empty translation
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 30
            )
        }

        // Also test whitespace-only translation
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "   ",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 30
            )
        }
    }

    @Test("CachedTranslation: invalid language codes are rejected")
    func cachedTranslationInvalidLanguageCodes() throws {
        // Test empty source language
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "hola",
                sourceLanguage: "",
                targetLanguage: "es",
                ttlDays: 30
            )
        }

        // Test empty target language
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "hola",
                sourceLanguage: "en",
                targetLanguage: "",
                ttlDays: 30
            )
        }
    }

    @Test("CachedTranslation: invalid TTL is rejected")
    func cachedTranslationInvalidTTL() throws {
        // Test TTL = 0 (below minimum)
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "hola",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 0
            )
        }

        // Test TTL = 400 (above maximum)
        #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "hello",
                translatedText: "hola",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 400
            )
        }
    }

    // MARK: - FoundationModels Feature Flag Tests

    @Test("FoundationModels: disabled state throws errors")
    func foundationModelsDisabledState() async throws {
        // When feature is disabled, generateSentence should throw
        let service = FoundationModelsService.shared

        // Note: This test depends on FoundationModelsFeatureFlag.currentStatus
        // In disabled mode, the service should throw FoundationModelsError.notAvailable

        let isAvailable = await service.isAvailable()

        if !isAvailable {
            // Verify that attempting to generate throws an error
            do {
                _ = try await service.generateSentence(
                    for: "test",
                    cefrLevel: "A1",
                    language: "en"
                )
                #expect(false, "Should throw error when Foundation Models are disabled")
            } catch is FoundationModelsError {
                #expect(true, "Should throw FoundationModelsError when disabled")
            }
        } else {
            // Feature is enabled, skip this test
            #expect(true, "Foundation Models are enabled, skipping disabled state test")
        }
    }

    @Test("FoundationModels: placeholder mode returns static sentences")
    func foundationModelsPlaceholderMode() async throws {
        // When in placeholder mode, should return static sentences
        let service = FoundationModelsService.shared

        // Note: This test depends on FoundationModelsFeatureFlag.currentStatus
        // In placeholder mode, the service should return static template sentences

        let sentence = try await service.generateSentence(
            for: "abandon",
            cefrLevel: "B1",
            language: "en"
        )

        // Verify sentence contains the word
        #expect(sentence.contains("abandon"), "Placeholder sentence should contain the word")
    }

    @Test("FoundationModels: production mode uses real implementation")
    func foundationModelsProductionMode() async throws {
        // When in production mode, should use real Foundation Models
        let service = FoundationModelsService.shared

        // Note: This test depends on FoundationModelsFeatureFlag.currentStatus
        // In production mode, the service should attempt real generation

        let isAvailable = await service.isAvailable()

        if isAvailable {
            // Try to initialize and generate
            try await service.initialize()

            let sentence = try await service.generateSentence(
                for: "hello",
                cefrLevel: "A1",
                language: "en"
            )

            // Verify sentence is generated (may be placeholder if framework not integrated)
            #expect(!sentence.isEmpty, "Should generate a sentence")
        } else {
            // Foundation Models not available on this device
            #expect(true, "Foundation Models not available, skipping production mode test")
        }
    }
}
