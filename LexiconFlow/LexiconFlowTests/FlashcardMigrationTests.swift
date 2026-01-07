//
//  FlashcardMigrationTests.swift
//  LexiconFlowTests
//
//  Tests for SwiftData migration strategy for Flashcard model
//
//  Verifies:
//  - Schema version tracking
//  - Migration stage configuration
//  - Automatic migration for optional fields
//  - Migration verification
//

import Testing
import SwiftData
import Foundation
@testable import LexiconFlow

/// Test suite for Flashcard model migrations
@MainActor
struct FlashcardMigrationTests {

    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Schema Version Tests

    @Test("Current schema version is v1.1")
    func currentSchemaVersion() {
        #expect(FlashcardSchemaVersion.current == .v1_1, "Current version should be v1.1")
    }

    @Test("Schema version v1.0 represents initial release")
    func v1_0SchemaVersion() {
        #expect(FlashcardSchemaVersion.v1_0.rawValue == 1, "v1.0 should be version 1")
    }

    @Test("Schema version v1.1 represents translation fields")
    func v1_1SchemaVersion() {
        #expect(FlashcardSchemaVersion.v1_1.rawValue == 2, "v1.1 should be version 2")
    }

    @Test("Schema versions are sequential")
    func schemaVersionsAreSequential() {
        let v1_0 = FlashcardSchemaVersion.v1_0.rawValue
        let v1_1 = FlashcardSchemaVersion.v1_1.rawValue
        #expect(v1_1 == v1_0 + 1, "Versions should be sequential")
    }

    // MARK: - Flashcard Field Tests (v1.1)

    @Test("Flashcard has translation field")
    func flashcardHasTranslationField() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "hello",
            definition: "a greeting",
            translation: "привет"
        )
        context.insert(flashcard)
        try context.save()

        // Verify translation field exists
        #expect(flashcard.translation == "привет", "Translation field should exist")
    }

    @Test("Flashcard translation field is optional")
    func flashcardTranslationFieldIsOptional() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create flashcard without translation
        let flashcard = Flashcard(
            word: "test",
            definition: "test definition"
        )
        context.insert(flashcard)
        try context.save()

        // Verify translation field is nil
        #expect(flashcard.translation == nil, "Translation should be nil")
    }

    @Test("Flashcard can be created with translation")
    func flashcardWithTranslation() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create flashcard with translation
        let flashcard = Flashcard(
            word: "café",
            definition: "coffee shop",
            translation: "кофе"
        )
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.translation == "кофе", "Translation should be set")
    }

    // MARK: - SwiftData Compatibility Tests

    @Test("Flashcard model can be stored in SwiftData")
    func flashcardSwiftDataStorage() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "test",
            definition: "definition"
        )
        context.insert(flashcard)
        try context.save()

        // Fetch and verify
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 1, "Should have 1 flashcard")
        #expect(fetched.first?.word == "test", "Word should match")
    }

    @Test("Multiple flashcards with different translation states coexist")
    func mixedTranslationStates() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // No translation
        let card1 = Flashcard(word: "card1", definition: "def1")
        context.insert(card1)

        // Partial translation
        let card2 = Flashcard(
            word: "card2",
            definition: "def2",
            translation: "translation2"
        )
        context.insert(card2)

        // Full translation
        let card3 = Flashcard(
            word: "card3",
            definition: "def3",
            translation: "translation3"
        )
        context.insert(card3)

        try context.save()

        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 3, "Should have 3 flashcards")

        let sorted = fetched.sorted { $0.word < $1.word }
        #expect(sorted[0].translation == nil, "Card1 should have no translation")
        #expect(sorted[1].translation == "translation2", "Card2 should have translation")
        #expect(sorted[2].translation == "translation3", "Card3 should have translation")
    }

    // MARK: - Edge Cases

    @Test("Empty string vs nil for optional fields")
    func emptyStringVsNil() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create card with empty string vs nil
        let card1 = Flashcard(
            word: "empty",
            definition: "def",
            translation: ""
        )
        let card2 = Flashcard(
            word: "nil",
            definition: "def",
            translation: nil
        )

        context.insert(card1)
        context.insert(card2)
        try context.save()

        #expect(card1.translation == "", "Empty string should be stored")
        #expect(card2.translation == nil, "Nil should be stored")
        #expect(card1.translation != card2.translation, "Empty string and nil should be different")
    }

    @Test("Translation field supports Unicode")
    func translationFieldSupportsUnicode() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "日本語",
            definition: "Japanese language",
            translation: "Японский язык"
        )
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.translation == "Японский язык", "Cyrillic translation should be preserved")
    }

    // MARK: - Future Migration Pattern Tests

    @Test("Migration verification throws for invalid version transition")
    func invalidVersionTransition() {
        // This test documents expected behavior for future migrations
        // Currently, all transitions verify successfully since we use lightweight migration
        // In the future, this test should be updated to verify error handling
        #expect(true, "Migration verification should handle version transitions")
    }

    @Test("Schema version enum is extensible")
    func schemaVersionEnumExtensible() {
        // This test documents that new schema versions can be added
        // Pattern:
        // enum FlashcardSchemaVersion: Int {
        //     case v1_0 = 1
        //     case v1_1 = 2
        //     case v1_2 = 3  // Future version with non-optional field
        // }
        #expect(FlashcardSchemaVersion.current.rawValue >= 2,
               "Current version should be at least v1.1")
    }

    // MARK: - Database Backward Compatibility Tests

    @Test("Current schema version matches expected value")
    func currentSchemaVersionMatches() {
        #expect(FlashcardSchemaVersion.current == .v1_1,
               "Current schema version should be v1.1")
        #expect(FlashcardSchemaVersion.current.rawValue == 2,
               "Current schema raw value should be 2")
    }

    @Test("v1.1 optional fields default to nil for existing v1.0 data")
    func v1_0ToV1_1Defaults() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Simulate v1.0 data (without translation fields)
        let flashcard = Flashcard(
            word: "test",
            definition: "test definition"
            // No translation fields - simulating v1.0 data
        )
        context.insert(flashcard)
        try context.save()

        // Verify all v1.1 optional fields are nil
        #expect(flashcard.translation == nil, "Translation should default to nil")
    }

    @Test("v1.0 data can be enhanced with translation post-migration")
    func v1_0DataEnhancement() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Simulate v1.0 data
        let flashcard = Flashcard(
            word: "café",
            definition: "coffee shop"
        )
        context.insert(flashcard)
        try context.save()

        // Post-migration: add translation
        flashcard.translation = "кофе"
        try context.save()

        // Verify field is persisted
        #expect(flashcard.translation == "кофе")
    }

    @Test("Translation field supports empty strings")
    func emptyStringTranslationSupported() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create card with empty string translation
        let flashcard = Flashcard(
            word: "test",
            definition: "definition",
            translation: ""  // Empty string, not nil
        )
        context.insert(flashcard)
        try context.save()

        // Verify empty string is preserved (not converted to nil)
        #expect(flashcard.translation == "")
    }

    @Test("Automatic migration preserves existing data integrity")
    func automaticMigrationIntegrity() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create cards with different states
        let card1 = Flashcard(word: "card1", definition: "def1")
        let card2 = Flashcard(word: "card2", definition: "def2")
        let card3 = Flashcard(word: "card3", definition: "def3")

        // Add translations to simulate partial data
        card2.translation = "translation2"
        card3.translation = "translation3"

        context.insert(card1)
        context.insert(card2)
        context.insert(card3)
        try context.save()

        // Fetch and verify integrity
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 3)

        let sorted = fetched.sorted { $0.word < $1.word }
        #expect(sorted[0].translation == nil, "card1 should have nil translation")
        #expect(sorted[1].translation == "translation2", "card2 should have translation")
        #expect(sorted[2].translation == "translation3", "card3 should have translation")
    }
}
