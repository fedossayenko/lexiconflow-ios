//
//  CachedTranslationTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for CachedTranslation model including:
//  - Model validation (empty strings, language codes, TTL)
//  - Computed properties (isExpired, daysUntilExpiration)
//  - SwiftData integration (insert, fetch, index)
//  - Error handling (all CachedTranslationError cases)
//  - Edge cases (whitespace trimming, TTL boundaries)
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for CachedTranslation
///
/// Tests verify:
/// - SwiftData model with #Index optimization
/// - Input validation and trimming
/// - Expiration calculation
/// - Error types with proper descriptions
@Suite
@MainActor
struct CachedTranslationTests {
    // MARK: - Test Helpers

    /// Create in-memory test container
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            CachedTranslation.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// Create valid cached translation with defaults
    private func createValidTranslation(
        sourceWord: String = "test",
        translatedText: String = "prueba",
        sourceLanguage: String = "en",
        targetLanguage: String = "es",
        ttlDays: Int = 30
    ) throws -> CachedTranslation {
        try CachedTranslation(
            sourceWord: sourceWord,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            ttlDays: ttlDays
        )
    }

    // MARK: - Model Validation Tests

    @Test("init creates valid CachedTranslation with all fields")
    func initCreatesValidTranslation() throws {
        let cached = try createValidTranslation(
            sourceWord: "hello",
            translatedText: "hola",
            sourceLanguage: "en",
            targetLanguage: "es",
            ttlDays: 30
        )

        #expect(cached.sourceWord == "hello")
        #expect(cached.translatedText == "hola")
        #expect(cached.sourceLanguage == "en")
        #expect(cached.targetLanguage == "es")
        #expect(cached.id != UUID()) // Unique ID generated
    }

    @Test("init trims whitespace from source word")
    func initTrimsWhitespaceFromSourceWord() throws {
        let cached = try createValidTranslation(
            sourceWord: "  test  ",
            translatedText: "prueba"
        )

        #expect(cached.sourceWord == "test")
    }

    @Test("init trims whitespace from translated text")
    func initTrimsWhitespaceFromTranslatedText() throws {
        let cached = try createValidTranslation(
            sourceWord: "test",
            translatedText: "  prueba  "
        )

        #expect(cached.translatedText == "prueba")
    }

    @Test("init trims whitespace from language codes")
    func initTrimsWhitespaceFromLanguageCodes() throws {
        let cached = try createValidTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "  en  ",
            targetLanguage: "  es  "
        )

        #expect(cached.sourceLanguage == "en")
        #expect(cached.targetLanguage == "es")
    }

    @Test("init calculates expiresAt correctly with default TTL")
    func initCalculatesExpiresAtCorrectly() throws {
        let cached = try createValidTranslation(ttlDays: 30)

        let expectedExpiry = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: 30,
            to: cached.cachedAt
        )

        #expect(cached.expiresAt == expectedExpiry)
    }

    // MARK: - Error Handling Tests

    @Test("init throws emptySourceWord for empty string")
    func initThrowsForEmptySourceWord() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
        }

        #expect(error == .emptySourceWord)
    }

    @Test("init throws emptySourceWord for whitespace-only source word")
    func initThrowsForWhitespaceOnlySourceWord() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "   ",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
        }

        #expect(error == .emptySourceWord)
    }

    @Test("init throws emptyTranslatedText for empty string")
    func initThrowsForEmptyTranslatedText() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
        }

        #expect(error == .emptyTranslatedText)
    }

    @Test("init throws emptyTranslatedText for whitespace-only translation")
    func initThrowsForWhitespaceOnlyTranslatedText() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "   ",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
        }

        #expect(error == .emptyTranslatedText)
    }

    @Test("init throws invalidLanguageCode for empty source language")
    func initThrowsForEmptySourceLanguage() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "prueba",
                sourceLanguage: "",
                targetLanguage: "es"
            )
        }

        #expect(error == .invalidLanguageCode)
    }

    @Test("init throws invalidLanguageCode for empty target language")
    func initThrowsForEmptyTargetLanguage() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: ""
            )
        }

        #expect(error == .invalidLanguageCode)
    }

    @Test("init throws invalidTTL for zero")
    func initThrowsForZeroTTL() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 0
            )
        }

        #expect(error == .invalidTTL(0))
    }

    @Test("init throws invalidTTL for negative value")
    func initThrowsForNegativeTTL() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: -1
            )
        }

        #expect(error == .invalidTTL(-1))
    }

    @Test("init throws invalidTTL for value greater than 365")
    func initThrowsForExcessiveTTL() {
        let error = #expect(throws: CachedTranslationError.self) {
            try CachedTranslation(
                sourceWord: "test",
                translatedText: "prueba",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 366
            )
        }

        #expect(error == .invalidTTL(366))
    }

    // MARK: - Computed Properties Tests

    @Test("isExpired returns false for fresh entry")
    func isExpiredReturnsFalseForFreshEntry() throws {
        let cached = try createValidTranslation(ttlDays: 30)

        #expect(cached.isExpired == false)
    }

    @Test("isExpired returns true for expired entry")
    func isExpiredReturnsTrueForExpiredEntry() throws {
        let cached = try CachedTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es",
            cachedAt: Date().addingTimeInterval(-31 * 24 * 60 * 60), // 31 days ago
            ttlDays: 30
        )

        #expect(cached.isExpired == true)
    }

    @Test("isExpired returns false exactly at expiration time")
    func isExpiredReturnsFalseAtExpirationTime() throws {
        let now = Date()
        let cached = try CachedTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es",
            cachedAt: now.addingTimeInterval(-30 * 24 * 60 * 60), // Exactly 30 days ago
            ttlDays: 30
        )

        #expect(cached.isExpired == false)
    }

    @Test("daysUntilExpiration returns positive value for fresh entry")
    func daysUntilExpirationPositiveForFresh() throws {
        let cached = try createValidTranslation(ttlDays: 30)

        let daysRemaining = cached.daysUntilExpiration
        #expect(daysRemaining > 0)
        #expect(daysRemaining <= 30)
    }

    @Test("daysUntilExpiration returns negative value for expired entry")
    func daysUntilExpirationNegativeForExpired() throws {
        let cached = try CachedTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es",
            cachedAt: Date().addingTimeInterval(-35 * 24 * 60 * 60), // 35 days ago
            ttlDays: 30
        )

        let daysRemaining = cached.daysUntilExpiration
        #expect(daysRemaining < 0)
    }

    @Test("daysUntilExpiration returns zero at expiration boundary")
    func daysUntilExpirationZeroAtBoundary() throws {
        let now = Date()
        let cached = try CachedTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es",
            cachedAt: now.addingTimeInterval(-30 * 24 * 60 * 60), // Exactly 30 days ago
            ttlDays: 30
        )

        // At exact boundary, may be 0 or 1 depending on timing
        let daysRemaining = cached.daysUntilExpiration
        #expect(daysRemaining >= 0 && daysRemaining <= 1)
    }

    // MARK: - SwiftData Integration Tests

    @Test("model can be inserted and retrieved from SwiftData")
    func modelPersistsToSwiftData() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let cached = try createValidTranslation()
        context.insert(cached)
        try context.save()

        // Fetch all translations
        let descriptor = FetchDescriptor<CachedTranslation>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.sourceWord == "test")
        #expect(results.first?.translatedText == "prueba")
    }

    @Test("model uses generated UUID as primary key")
    func modelUsesUniqueID() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let cached1 = try createValidTranslation(sourceWord: "test1")
        let cached2 = try createValidTranslation(sourceWord: "test2")

        context.insert(cached1)
        context.insert(cached2)
        try context.save()

        #expect(cached1.id != cached2.id)
    }

    @Test("model fetch by compound predicate works")
    func modelFetchByCompoundPredicate() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let cached = try createValidTranslation(
            sourceWord: "hello",
            translatedText: "hola",
            sourceLanguage: "en",
            targetLanguage: "es"
        )
        context.insert(cached)
        try context.save()

        // Fetch using compound predicate (simulating cache lookup)
        let predicate = #Predicate<CachedTranslation> { translation in
            translation.sourceWord == "hello" &&
                translation.sourceLanguage == "en" &&
                translation.targetLanguage == "es"
        }

        let descriptor = FetchDescriptor<CachedTranslation>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.translatedText == "hola")
    }

    @Test("model can be deleted from SwiftData")
    func modelCanBeDeleted() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let cached = try createValidTranslation()
        context.insert(cached)
        try context.save()

        // Verify inserted
        var descriptor = FetchDescriptor<CachedTranslation>()
        var results = try context.fetch(descriptor)
        #expect(results.count == 1)

        // Delete
        context.delete(cached)
        try context.save()

        // Verify deleted
        results = try context.fetch(descriptor)
        #expect(results.count == 0)
    }

    // MARK: - Error Properties Tests

    @Test("CachedTranslationError provides errorDescription")
    func errorProvidesDescription() {
        let errors: [CachedTranslationError] = [
            .emptySourceWord,
            .emptyTranslatedText,
            .invalidLanguageCode,
            .invalidTTL(500)
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("CachedTranslationError provides failureReason")
    func errorProvidesFailureReason() {
        let errors: [CachedTranslationError] = [
            .emptySourceWord,
            .emptyTranslatedText,
            .invalidLanguageCode,
            .invalidTTL(500)
        ]

        for error in errors {
            #expect(error.failureReason != nil)
        }
    }

    @Test("CachedTranslationError provides recoverySuggestion")
    func errorProvidesRecoverySuggestion() {
        let errors: [CachedTranslationError] = [
            .emptySourceWord,
            .emptyTranslatedText,
            .invalidLanguageCode,
            .invalidTTL(500)
        ]

        for error in errors {
            #expect(error.recoverySuggestion != nil)
        }
    }

    @Test("CachedTranslationError is Equatable")
    func errorIsEquatable() {
        #expect(CachedTranslationError.emptySourceWord == CachedTranslationError.emptySourceWord)
        #expect(CachedTranslationError.emptySourceWord != CachedTranslationError.emptyTranslatedText)
        #expect(CachedTranslationError.invalidTTL(5) == CachedTranslationError.invalidTTL(5))
        #expect(CachedTranslationError.invalidTTL(5) != CachedTranslationError.invalidTTL(10))
    }

    // MARK: - Edge Cases Tests

    @Test("init accepts minimum valid TTL of 1 day")
    func initAcceptsMinimumTTL() throws {
        let cached = try createValidTranslation(ttlDays: 1)

        #expect(cached.expiresAt > cached.cachedAt)
        #expect(cached.isExpired == false)
    }

    @Test("init accepts maximum valid TTL of 365 days")
    func initAcceptsMaximumTTL() throws {
        let cached = try createValidTranslation(ttlDays: 365)

        let expectedExpiry = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: 365,
            to: cached.cachedAt
        )

        #expect(cached.expiresAt == expectedExpiry)
    }

    @Test("init handles special characters in source word")
    func initHandlesSpecialCharactersInSourceWord() throws {
        let specialWords = ["café", "naïve", "日本語", "مرحبا", "😀test"]

        for word in specialWords {
            let cached = try createValidTranslation(sourceWord: word)
            #expect(cached.sourceWord == word)
        }
    }

    @Test("init handles special characters in translated text")
    func initHandlesSpecialCharactersInTranslatedText() throws {
        let specialTranslations = ["café", "наивный", "こんにちは", "مرحبا", "test😀"]

        for translation in specialTranslations {
            let cached = try createValidTranslation(translatedText: translation)
            #expect(cached.translatedText == translation)
        }
    }

    @Test("init handles extremely long source word")
    func initHandlesLongSourceWord() throws {
        let longWord = String(repeating: "a", count: 1000)
        let cached = try createValidTranslation(sourceWord: longWord)

        #expect(cached.sourceWord == longWord)
    }

    @Test("cachedAt defaults to current date")
    func cachedAtDefaultsToNow() throws {
        let before = Date()
        let cached = try createValidTranslation()
        let after = Date()

        #expect(cached.cachedAt >= before)
        #expect(cached.cachedAt <= after)
    }

    @Test("id can be explicitly provided")
    func idCanBeProvided() throws {
        let customID = UUID()
        let cached = try CachedTranslation(
            id: customID,
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es"
        )

        #expect(cached.id == customID)
    }

    @Test("cachedAt can be explicitly provided")
    func cachedAtCanBeProvided() throws {
        let customDate = Date().addingTimeInterval(-86400) // 1 day ago
        let cached = try CachedTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es",
            cachedAt: customDate,
            ttlDays: 30
        )

        #expect(cached.cachedAt == customDate)
    }

    @Test("model handles same word with different language pairs")
    func modelHandlesDifferentLanguagePairs() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let cached1 = try createValidTranslation(
            sourceWord: "test",
            translatedText: "prueba",
            sourceLanguage: "en",
            targetLanguage: "es"
        )

        let cached2 = try createValidTranslation(
            sourceWord: "test",
            translatedText: "teste",
            sourceLanguage: "en",
            targetLanguage: "pt"
        )

        context.insert(cached1)
        context.insert(cached2)
        try context.save()

        let descriptor = FetchDescriptor<CachedTranslation>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
    }
}
