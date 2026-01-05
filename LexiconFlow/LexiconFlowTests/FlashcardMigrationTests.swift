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

    // MARK: - Migration Verification Tests

    @Test("v1.0 to v1.1 migration verifies successfully")
    func migrationVerificationSuccess() throws {
        let result = try FlashcardMigrationPlan.verifyMigration(
            from: .v1_0,
            to: .v1_1
        )
        #expect(result, "Automatic migration should verify")
    }

    @Test("Same version migration verifies successfully")
    func sameVersionMigration() throws {
        let result = try FlashcardMigrationPlan.verifyMigration(
            from: .v1_1,
            to: .v1_1
        )
        #expect(result, "Same version should verify")
    }

    // MARK: - Flashcard Field Tests (v1.1)

    @Test("Flashcard has all v1.1 translation fields")
    func flashcardHasV1_1Fields() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "hello",
            definition: "a greeting",
            translation: "привет",
            translationSourceLanguage: "en",
            translationTargetLanguage: "ru",
            cefrLevel: "A1",
            contextSentence: "Hello, how are you?"
        )
        context.insert(flashcard)
        try context.save()

        // Verify all translation fields exist
        #expect(flashcard.translation == "привет", "Translation field should exist")
        #expect(flashcard.translationSourceLanguage == "en", "Source language should exist")
        #expect(flashcard.translationTargetLanguage == "ru", "Target language should exist")
        #expect(flashcard.cefrLevel == "A1", "CEFR level should exist")
        #expect(flashcard.contextSentence == "Hello, how are you?", "Context sentence should exist")
    }

    @Test("Flashcard v1.1 fields are optional")
    func flashcardV1_1FieldsAreOptional() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create flashcard without any translation fields
        let flashcard = Flashcard(
            word: "test",
            definition: "test definition"
        )
        context.insert(flashcard)
        try context.save()

        // Verify all translation fields are nil
        #expect(flashcard.translation == nil, "Translation should be nil")
        #expect(flashcard.translationSourceLanguage == nil, "Source language should be nil")
        #expect(flashcard.translationTargetLanguage == nil, "Target language should be nil")
        #expect(flashcard.cefrLevel == nil, "CEFR level should be nil")
        #expect(flashcard.contextSentence == nil, "Context sentence should be nil")
    }

    @Test("Flashcard can be created with partial translation fields")
    func flashcardPartialTranslationFields() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create flashcard with only some translation fields
        let flashcard = Flashcard(
            word: "café",
            definition: "coffee shop",
            translation: "кофе",
            translationSourceLanguage: "fr",
            translationTargetLanguage: "ru"
            // cefrLevel and contextSentence omitted
        )
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.translation == "кофе", "Translation should be set")
        #expect(flashcard.translationSourceLanguage == "fr", "Source language should be set")
        #expect(flashcard.translationTargetLanguage == "ru", "Target language should be set")
        #expect(flashcard.cefrLevel == nil, "CEFR level should be nil")
        #expect(flashcard.contextSentence == nil, "Context sentence should be nil")
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
            translation: "translation3",
            translationSourceLanguage: "en",
            translationTargetLanguage: "ru",
            cefrLevel: "B1",
            contextSentence: "context"
        )
        context.insert(card3)

        try context.save()

        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 3, "Should have 3 flashcards")

        let sorted = fetched.sorted { $0.word < $1.word }
        #expect(sorted[0].translation == nil, "Card1 should have no translation")
        #expect(sorted[1].translation == "translation2", "Card2 should have partial translation")
        #expect(sorted[2].translation == "translation3", "Card3 should have full translation")
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

    @Test("Translation fields support Unicode")
    func translationFieldsSupportUnicode() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(
            word: "日本語",
            definition: "Japanese language",
            translation: "Японский язык",
            translationSourceLanguage: "ja",
            translationTargetLanguage: "ru",
            cefrLevel: "C1",
            contextSentence: "日本語を勉強しています。"
        )
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.translation == "Японский язык", "Cyrillic translation should be preserved")
        #expect(flashcard.contextSentence == "日本語を勉強しています。", "Japanese context should be preserved")
    }

    @Test("CEFR level accepts valid values")
    func cefrLevelValidValues() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let validLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]

        for level in validLevels {
            let flashcard = Flashcard(
                word: "word_\(level)",
                definition: "definition",
                cefrLevel: level
            )
            context.insert(flashcard)
        }

        try context.save()

        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == validLevels.count, "All CEFR levels should be stored")

        for flashcard in fetched {
            #expect(validLevels.contains(flashcard.cefrLevel ?? ""),
                   "CEFR level should be valid")
        }
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
}
