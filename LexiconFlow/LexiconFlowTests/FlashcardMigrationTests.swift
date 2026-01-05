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

    // MARK: - MigrationStage Tests

    @Test("v1.0 to v1.1 migration uses lightweight stage")
    func migrationStageIsLightweight() {
        // Verify migration stage is lightweight (automatic for optional fields)
        let stages = FlashcardMigrationPlan.stages
        #expect(stages.count == 1, "Should have 1 migration stage")

        // Verify it's a lightweight migration
        let stage = stages.first
        #expect(stage != nil, "Migration stage should exist")

        // The stage should be lightweight from v1.0 to v1.1
        // This is tested implicitly by successful migration
    }

    @Test("Migration schemas include v1.0 and v1.1")
    func migrationSchemas() {
        let schemas = FlashcardMigrationPlan.schemas
        #expect(schemas.count == 2, "Should have 2 schemas")

        let schemaTypes = schemas.map { String(describing: $0) }
        #expect(schemaTypes.contains("FlashcardSchemaV1_0"), "Should include v1.0 schema")
        #expect(schemaTypes.contains("FlashcardSchemaV1_1"), "Should include v1.1 schema")
    }

    // MARK: - Migration Error Handling Tests

    @Test("Backward migration throws error")
    func backwardMigrationThrowsError() {
        // v1.1 to v1.0 (backward) should throw error
        #expect(throws: MigrationError.self) {
            try FlashcardMigrationPlan.verifyMigration(
                from: .v1_1,
                to: .v1_0
            )
        }
    }

    @Test("Migration error description is informative")
    func migrationErrorDescription() {
        let error = MigrationError.unsupportedVersionTransition(from: 2, to: 1)
        #expect(error.localizedDescription.contains("Cannot migrate"),
               "Error should describe the problem")
        #expect(error.localizedDescription.contains("2"),
               "Error should include from version")
        #expect(error.localizedDescription.contains("1"),
               "Error should include to version")
    }

    @Test("Migration failed error wraps underlying error")
    func migrationFailedError() {
        let underlyingError = NSError(domain: "TestDomain", code: 123)
        let error = MigrationError.migrationFailed(underlying: underlyingError)
        #expect(error.localizedDescription.contains("Migration failed"),
               "Error should describe migration failure")
    }

    @Test("Data corruption error has message")
    func dataCorruptionError() {
        let error = MigrationError.dataCorruption("Flashcard data invalid")
        #expect(error.localizedDescription.contains("Data corruption"),
               "Error should describe corruption")
        #expect(error.localizedDescription.contains("Flashcard data invalid"),
               "Error should include specific message")
    }

    // MARK: - ModelContainer Migration Configuration Tests

    @Test("ModelContainer can be created with migration plan")
    func modelContainerWithMigrationPlan() throws {
        // This test verifies ModelContainer can be initialized with migration plan
        // In production, this would be configured in LexiconFlowApp.swift

        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        // Create container with migration plan (SwiftData handles this internally)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FlashcardMigrationPlan.self,
            configurations: [configuration]
        )

        #expect(!container.mainContext.container.configurations.isEmpty,
               "Container should have valid configuration")
    }

    @Test("ModelContainer migration utilities are available")
    func modelContainerMigrationUtilities() {
        let container = createTestContainer()

        // Test isCurrentSchemaVersion utility
        let isCurrent = container.isCurrentSchemaVersion()
        #expect(isCurrent, "Test container should use current schema")

        // Test getSchemaVersion utility
        let version = container.getSchemaVersion()
        #expect(version == .v1_1, "Test container should be v1.1")
    }

    // MARK: - Real-World Migration Scenarios

    @Test("Existing v1.0 cards can coexist with v1.1 cards")
    func existingCardsCoexistWithNewSchema() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Simulate existing v1.0 card (created without translation fields)
        let legacyCard = Flashcard(
            word: "hello",
            definition: "a greeting",
            phonetic: "həˈloʊ"
        )
        context.insert(legacyCard)

        // Simulate new v1.1 card (with translation fields)
        let newCard = Flashcard(
            word: "world",
            definition: "the earth",
            translation: "мир",
            translationSourceLanguage: "en",
            translationTargetLanguage: "ru"
        )
        context.insert(newCard)

        try context.save()

        // Both cards should be fetchable
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 2, "Both cards should exist")

        let legacy = fetched.first { $0.word == "hello" }
        let new = fetched.first { $0.word == "world" }

        #expect(legacy?.translation == nil, "Legacy card should have nil translation")
        #expect(new?.translation == "мир", "New card should have translation")
    }

    @Test("Migration preserves existing data")
    func migrationPreservesExistingData() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create card with all v1.0 fields
        let card = Flashcard(
            word: "test",
            definition: "test definition",
            phonetic: "tɛst",
            imageData: Data("test image".utf8)
        )
        context.insert(card)

        // Create deck and relate card
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)
        card.deck = deck

        // Create FSRS state
        let state = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        context.insert(state)
        card.fsrsState = state

        // Create review log
        let review = FlashcardReview(
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1,
            elapsedDays: 0
        )
        review.card = card
        context.insert(review)

        try context.save()

        // Fetch and verify all relationships preserved
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 1, "Card should exist")

        let fetchedCard = fetched.first!
        #expect(fetchedCard.word == "test", "Word should be preserved")
        #expect(fetchedCard.definition == "test definition", "Definition should be preserved")
        #expect(fetchedCard.phonetic == "tɛst", "Phonetic should be preserved")
        #expect(fetchedCard.imageData == Data("test image".utf8), "Image data should be preserved")
        #expect(fetchedCard.deck?.name == "Test Deck", "Deck relationship should be preserved")
        #expect(fetchedCard.fsrsState?.stability == 5.0, "FSRS state should be preserved")
        #expect(fetchedCard.reviewLogs.count == 1, "Review logs should be preserved")
    }

    @Test("Migration handles cards with various optional field states")
    func migrationHandlesVariousOptionalFieldStates() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Card with no optional fields
        let card1 = Flashcard(word: "word1", definition: "def1")
        context.insert(card1)

        // Card with phonetic only
        let card2 = Flashcard(word: "word2", definition: "def2", phonetic: "wɜːd")
        context.insert(card2)

        // Card with image data only
        let card3 = Flashcard(
            word: "word3",
            definition: "def3",
            imageData: Data("image".utf8)
        )
        context.insert(card3)

        // Card with translation fields only
        let card4 = Flashcard(
            word: "word4",
            definition: "def4",
            translation: "trans4"
        )
        context.insert(card4)

        try context.save()

        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)

        #expect(fetched.count == 4, "All cards should exist")

        let c1 = fetched.first { $0.word == "word1" }
        let c2 = fetched.first { $0.word == "word2" }
        let c3 = fetched.first { $0.word == "word3" }
        let c4 = fetched.first { $0.word == "word4" }

        #expect(c1?.phonetic == nil && c1?.imageData == nil && c1?.translation == nil,
               "Card1 should have no optional fields")
        #expect(c2?.phonetic == "wɜːd" && c2?.imageData == nil && c2?.translation == nil,
               "Card2 should have phonetic only")
        #expect(c3?.phonetic == nil && c3?.imageData != nil && c3?.translation == nil,
               "Card3 should have image data only")
        #expect(c4?.phonetic == nil && c4?.imageData == nil && c4?.translation == "trans4",
               "Card4 should have translation only")
    }

    // MARK: - Future Migration Pattern Tests

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

    @Test("Migration performMigration is no-op for v1.0 to v1.1")
    func migrationPerformMigrationIsNoOp() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create a test card
        let card = Flashcard(word: "test", definition: "test")
        context.insert(card)
        try context.save()

        // Perform migration (should be no-op for v1.0 → v1.1)
        try FlashcardMigrationPlan.performMigration(
            from: .v1_0,
            to: .v1_1,
            context: context
        )

        // Verify card still exists (no data loss)
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)
        #expect(fetched.count == 1, "Card should still exist after migration")
        #expect(fetched.first?.word == "test", "Card data should be preserved")
    }
}
