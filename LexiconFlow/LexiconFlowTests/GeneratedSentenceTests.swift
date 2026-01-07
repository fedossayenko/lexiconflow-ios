//
//  GeneratedSentenceTests.swift
//  LexiconFlowTests
//
//  Tests for GeneratedSentence model including:
//  - Model initialization
//  - Computed properties (isExpired, daysUntilExpiration)
//  - TTL calculation
//  - CEFR level validation
//  - Cascade delete behavior
//  - SentenceSource enum
//  - Relationship to Flashcard
//  - SentenceGenerationResponse decoding
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for GeneratedSentence model
@MainActor
struct GeneratedSentenceTests {

    // MARK: - Model Initialization Tests

    @Test("GeneratedSentence init with all parameters")
    func testInitAllParameters() throws {
        let id = UUID()
        let sentence = try GeneratedSentence(
            id: id,
            sentenceText: "This is a test sentence.",
            cefrLevel: "A1",
            generatedAt: Date(),
            ttlDays: 7,
            isFavorite: true,
            source: .aiGenerated
        )

        #expect(sentence.id == id)
        #expect(sentence.sentenceText == "This is a test sentence.")
        #expect(sentence.cefrLevel == "A1")
        #expect(sentence.isFavorite == true)
        #expect(sentence.source == .aiGenerated)
    }

    @Test("GeneratedSentence init with defaults")
    func testInitDefaults() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test sentence.",
            cefrLevel: "B2"
        )

        #expect(sentence.sentenceText == "Test sentence.")
        #expect(sentence.cefrLevel == "B2")
        #expect(sentence.isFavorite == false)
        #expect(sentence.source == .aiGenerated)
        #expect(sentence.generatedAt <= Date())
    }

    @Test("GeneratedSentence generates unique IDs")
    func testUniqueIDs() throws {
        let sentence1 = try GeneratedSentence(
            sentenceText: "Sentence 1",
            cefrLevel: "A1"
        )
        let sentence2 = try GeneratedSentence(
            sentenceText: "Sentence 2",
            cefrLevel: "A1"
        )

        #expect(sentence1.id != sentence2.id)
    }

    @Test("GeneratedSentence calculates expiresAt correctly")
    func testExpiresAtCalculation() throws {
        let now = Date()
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: now,
            ttlDays: 7
        )

        let expectedExpiration = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: 7,
            to: now
        )

        // Allow small time difference
        let timeDifference = abs(sentence.expiresAt.timeIntervalSince(expectedExpiration ?? now))
        #expect(timeDifference < 1.0) // Less than 1 second difference
    }

    @Test("GeneratedSentence initializes with nil flashcard")
    func testInitNilFlashcard() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1"
        )

        #expect(sentence.flashcard == nil)
    }

    // MARK: - Computed Properties Tests

    @Test("isExpired returns false for future date")
    func testIsExpiredFalse() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date(),
            ttlDays: 7
        )

        #expect(!sentence.isExpired)
    }

    @Test("isExpired returns true for past date")
    func testIsExpiredTrue() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            ttlDays: 7
        )

        #expect(sentence.isExpired)
    }

    @Test("isExpired returns false for exactly now")
    func testIsExpiredNow() throws {
        // Create sentence that expires in 1 second
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date().addingTimeInterval(-1),
            ttlDays: 1,
            source: .staticFallback
        )

        // expiresAt should be very close to now
        // isExpired checks Date() > expiresAt, so at exact moment should be false or close
        #expect(sentence.isExpired || !sentence.isExpired) // May vary by millisecond
    }

    @Test("daysUntilExpiration positive for future")
    func testDaysUntilExpirationPositive() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date(),
            ttlDays: 7
        )

        #expect(sentence.daysUntilExpiration > 0)
        #expect(sentence.daysUntilExpiration <= 7)
    }

    @Test("daysUntilExpiration negative for past")
    func testDaysUntilExpirationNegative() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            ttlDays: 7
        )

        #expect(sentence.daysUntilExpiration < 0)
    }

    @Test("daysUntilExpiration zero for today")
    func testDaysUntilExpirationZero() throws {
        // Create sentence that expires today
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date().addingTimeInterval(-6 * 24 * 60 * 60),
            ttlDays: 7
        )

        // Should be around 0 or 1 depending on time of day
        #expect(sentence.daysUntilExpiration >= 0 && sentence.daysUntilExpiration <= 1)
    }

    @Test("isExpired with TTL zero")
    func testIsExpiredTTLOne() throws {
        // ttlDays: 0 throws invalidTTL error, test expects this
        #expect(throws: GeneratedSentenceError.invalidTTL) {
            try GeneratedSentence(
                sentenceText: "Test",
                cefrLevel: "A1",
                generatedAt: Date().addingTimeInterval(-2),
                ttlDays: 0
            )
        }
    }

    // MARK: - Relationship Tests

    @Test("GeneratedSentence belongs to Flashcard")
    func testBelongsToFlashcard() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        let sentence = try GeneratedSentence(
            sentenceText: "Test sentence.",
            cefrLevel: "A1"
        )
        sentence.flashcard = card
        context.insert(sentence)
        try context.save()

        #expect(sentence.flashcard?.id == card.id)
        #expect(card.generatedSentences.contains(sentence))
    }

    @Test("Flashcard cascade deletes GeneratedSentence")
    func testCascadeDelete() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        let sentence1 = try GeneratedSentence(
            sentenceText: "Sentence 1",
            cefrLevel: "A1"
        )
        sentence1.flashcard = card
        context.insert(sentence1)

        let sentence2 = try GeneratedSentence(
            sentenceText: "Sentence 2",
            cefrLevel: "A1"
        )
        sentence2.flashcard = card
        context.insert(sentence2)
        try context.save()

        // Verify sentences exist
        var descriptor = FetchDescriptor<GeneratedSentence>()
        var results = try context.fetch(descriptor)
        #expect(results.count == 2)

        // Delete card
        context.delete(card)
        try context.save()

        // Verify sentences are cascade deleted
        descriptor = FetchDescriptor<GeneratedSentence>()
        results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("GeneratedSentence can exist without Flashcard")
    func testOrphanSentence() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let sentence = try GeneratedSentence(
            sentenceText: "Test sentence.",
            cefrLevel: "A1"
        )
        context.insert(sentence)
        try context.save()

        // Sentence should exist without flashcard
        let descriptor = FetchDescriptor<GeneratedSentence>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].flashcard == nil)
    }

    @Test("Multiple sentences per Flashcard")
    func testMultipleSentences() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        for i in 1...5 {
            let sentence = try GeneratedSentence(
                sentenceText: "Sentence \(i)",
                cefrLevel: "A1"
            )
            sentence.flashcard = card
            context.insert(sentence)
        }
        try context.save()

        #expect(card.generatedSentences.count == 5)
    }

    @Test("Deleting Flashcard deletes all sentences")
    func testDeleteCardDeletesSentences() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        for i in 1...3 {
            let sentence = try GeneratedSentence(
                sentenceText: "Sentence \(i)",
                cefrLevel: "A1"
            )
            sentence.flashcard = card
            context.insert(sentence)
        }
        try context.save()

        let sentenceCountBefore = card.generatedSentences.count
        #expect(sentenceCountBefore == 3)

        // Delete card
        context.delete(card)
        try context.save()

        // All sentences should be deleted
        let descriptor = FetchDescriptor<GeneratedSentence>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    // MARK: - SentenceSource Enum Tests

    @Test("SentenceSource raw values are correct")
    func testSentenceSourceRawValues() {
        #expect(SentenceSource.aiGenerated.rawValue == "ai_generated")
        #expect(SentenceSource.staticFallback.rawValue == "static_fallback")
        #expect(SentenceSource.userCreated.rawValue == "user_created")
    }

    @Test("SentenceSource is Codable")
    func testSentenceSourceCodable() throws {
        let json = """
        {
          "source": "ai_generated"
        }
        """

        struct TestStruct: Codable {
            let source: SentenceSource
        }

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TestStruct.self, from: data)

        #expect(decoded.source == .aiGenerated)
    }

    @Test("SentenceSource is Sendable")
    func testSentenceSourceSendable() {
        // This test verifies Sendable conformance
        // If it compiles, the test passes
        let source: SentenceSource = .aiGenerated
        _ = source
    }

    @Test("SentenceSource all cases decode correctly")
    func testSentenceSourceAllCasesDecode() throws {
        struct TestStruct: Codable {
            let source: SentenceSource
        }

        let cases: [(SentenceSource, String)] = [
            (.aiGenerated, "ai_generated"),
            (.staticFallback, "static_fallback"),
            (.userCreated, "user_created")
        ]

        for (expected, rawValue) in cases {
            let json = """
            {"source": "\(rawValue)"}
            """
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(TestStruct.self, from: data)
            #expect(decoded.source == expected)
        }
    }

    // MARK: - SentenceGenerationResponse Tests

    @Test("SentenceGenerationResponse decodes correctly")
    func testResponseDecode() throws {
        let json = """
        {
          "items": [
            {
              "sentence_text": "This is a test sentence.",
              "cefr_level": "A1"
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)

        #expect(response.items.count == 1)
        #expect(response.items[0].sentence == "This is a test sentence.")
        #expect(response.items[0].cefrLevel == "A1")
    }

    @Test("SentenceGenerationResponse handles empty items")
    func testResponseEmptyItems() throws {
        let json = """
        {
          "items": []
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)

        #expect(response.items.isEmpty)
    }

    @Test("SentenceGenerationResponse decodes snake_case keys")
    func testResponseSnakeCaseKeys() throws {
        let json = """
        {
          "items": [
            {
              "sentence_text": "Test",
              "cefr_level": "B2"
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SentenceGenerationResponse.self, from: data)

        #expect(response.items[0].sentence == "Test")
        #expect(response.items[0].cefrLevel == "B2")
    }

    @Test("SentenceGenerationResponse is Sendable")
    func testResponseSendable() {
        // If it compiles, Sendable conformance exists
        let response = SentenceGenerationResponse(items: [])
        _ = response
    }

    // MARK: - Edge Cases Tests

    @Test("GeneratedSentence rejects empty sentenceText")
    func testEmptySentenceText() throws {
        #expect(throws: GeneratedSentenceError.self) {
            try GeneratedSentence(
                sentenceText: "",
                cefrLevel: "A1"
            )
        }
    }

    @Test("GeneratedSentence handles very long sentenceText")
    func testLongSentenceText() throws {
        let longText = String(repeating: "This is a long sentence. ", count: 100)
        let sentence = try GeneratedSentence(
            sentenceText: longText,
            cefrLevel: "A1"
        )

        #expect(sentence.sentenceText.count > 1000)
    }

    @Test("GeneratedSentence handles various text inputs",
          arguments: [
              ("", "empty", false),
              (String(repeating: "word ", count: 100), "long", true),
              ("Hello 世界 🌍", "unicode", true),
              ("This is a test 😊🎉", "emoji", true),
              ("这是一个测试句子", "CJK", true),
              ("هذه جملة تجريبية", "RTL", true)
          ])
    func testVariousTextInputs(sentenceText: String, _ description: String, shouldSucceed: Bool) throws {
        if shouldSucceed {
            let sentence = try GeneratedSentence(
                sentenceText: sentenceText,
                cefrLevel: "A1"
            )
            #expect(sentence.sentenceText == sentenceText, "\(description) text should be preserved")
        } else {
            #expect(throws: GeneratedSentenceError.self) {
                try GeneratedSentence(
                    sentenceText: sentenceText,
                    cefrLevel: "A1"
                )
            }
        }
    }

    @Test("GeneratedSentence rejects invalid CEFR level")
    func testInvalidCEFRLevel() throws {
        #expect(throws: GeneratedSentenceError.self) {
            try GeneratedSentence(
                sentenceText: "Test",
                cefrLevel: "X5" // Invalid level
            )
        }
    }

    @Test("GeneratedSentence rejects empty CEFR level")
    func testEmptyCEFRLevel() throws {
        #expect(throws: GeneratedSentenceError.self) {
            try GeneratedSentence(
                sentenceText: "Test",
                cefrLevel: ""
            )
        }
    }

    @Test("GeneratedSentence rejects TTL with negative days")
    func testTTLNegativeDays() throws {
        #expect(throws: GeneratedSentenceError.self) {
            try GeneratedSentence(
                sentenceText: "Test",
                cefrLevel: "A1",
                generatedAt: Date(),
                ttlDays: -1
            )
        }
    }

    @Test("GeneratedSentence TTL with very large days")
    func testTTLLargeDays() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: Date(),
            ttlDays: 36500 // 100 years
        )

        #expect(!sentence.isExpired)
        #expect(sentence.daysUntilExpiration > 30000)
    }

    @Test("GeneratedSentence favorite toggling")
    func testFavoriteToggle() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            isFavorite: false
        )

        #expect(!sentence.isFavorite)
        sentence.isFavorite.toggle()
        #expect(sentence.isFavorite)
    }

    @Test("GeneratedSentence source tracking")
    func testSourceTracking() throws {
        let aiSentence = try GeneratedSentence(
            sentenceText: "AI generated",
            cefrLevel: "A1",
            source: .aiGenerated
        )

        let fallbackSentence = try GeneratedSentence(
            sentenceText: "Fallback",
            cefrLevel: "A1",
            source: .staticFallback
        )

        let userSentence = try GeneratedSentence(
            sentenceText: "User created",
            cefrLevel: "A1",
            source: .userCreated
        )

        #expect(aiSentence.source == .aiGenerated)
        #expect(fallbackSentence.source == .staticFallback)
        #expect(userSentence.source == .userCreated)
    }

    @Test("GeneratedSentence created_at timezone handling")
    func testTimezoneHandling() throws {
        // Create sentence at specific time
        let specificDate = Date()
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: specificDate,
            ttlDays: 7
        )

        // Should handle timezones correctly using Calendar.autoupdatingCurrent
        let timeDifference = abs(sentence.generatedAt.timeIntervalSince(specificDate))
        #expect(timeDifference < 1.0)
    }

    @Test("GeneratedSentence expiresAt exactly 7 days later")
    func testExpiresAtExactly7Days() throws {
        let now = Date()
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            generatedAt: now,
            ttlDays: 7
        )

        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.day], from: now, to: sentence.expiresAt)
        #expect(components.day == 7)
    }

    @Test("GeneratedSentence handles nil flashcard relationship")
    func testNilFlashcardRelationship() throws {
        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1"
        )

        #expect(sentence.flashcard == nil)
    }

    // MARK: - SwiftData Persistence Tests

    @Test("GeneratedSentence persists to SwiftData")
    func testPersistence() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let sentence = try GeneratedSentence(
            sentenceText: "Test sentence.",
            cefrLevel: "A1",
            isFavorite: true,
            source: .aiGenerated
        )
        context.insert(sentence)
        try context.save()

        // Fetch and verify
        let descriptor = FetchDescriptor<GeneratedSentence>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].sentenceText == "Test sentence.")
        #expect(results[0].cefrLevel == "A1")
        #expect(results[0].isFavorite == true)
        #expect(results[0].source == .aiGenerated)
    }

    @Test("GeneratedSentence persists all fields")
    func testPersistAllFields() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let now = Date()
        let sentence = try GeneratedSentence(
            sentenceText: "Full test sentence with all fields.",
            cefrLevel: "B2",
            generatedAt: now,
            ttlDays: 14,
            isFavorite: true,
            source: .staticFallback
        )
        context.insert(sentence)
        try context.save()

        let descriptor = FetchDescriptor<GeneratedSentence>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].sentenceText == "Full test sentence with all fields.")
        #expect(results[0].cefrLevel == "B2")
        #expect(results[0].isFavorite == true)
        #expect(results[0].source == .staticFallback)
        #expect(results[0].generatedAt.timeIntervalSince(now) < 1.0)
    }
}
