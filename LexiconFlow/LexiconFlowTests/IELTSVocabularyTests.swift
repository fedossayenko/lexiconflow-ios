//
//  IELTSVocabularyTests.swift
//  LexiconFlowTests
//
//  Tests for IELTS vocabulary feature including:
//  - CEFR level validation on Flashcard
//  - Russian translation storage
//  - IELTSDeckManager deck creation
//  - DataImporter with new fields
//  - CEFR color mapping
//

import Foundation
import SwiftData
import Testing

@testable import LexiconFlow

/// Tests for IELTS vocabulary feature
///
/// **Test Coverage:**
/// - CEFR level validation on Flashcard model
/// - IELTSDeckManager service functionality
/// - DataImporter with CEFR and translation fields
/// - CEFR color mapping in Theme utility
///
/// **Note:** Tests use in-memory ModelContainer for isolation.
/// All tests are MainActor-isolated due to IELTSDeckManager requiring MainActor.
@Suite("IELTS Vocabulary Tests")
@MainActor
final class IELTSVocabularyTests {
    /// Shared model container for all tests
    ///
    /// **Note:** Using in-memory storage for test isolation.
    /// Each test gets a fresh container.
    private var modelContainer: ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
            GeneratedSentence.self,
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }

    // MARK: - CEFR Level Validation Tests

    @Test("CEFR level validation - accepts valid levels")
    func testCEFRValidationValid() throws {
        let card = Flashcard(word: "test", definition: "test")

        // Test all valid CEFR levels
        let validLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]

        for level in validLevels {
            try card.setCEFRLevel(level)
            #expect(card.cefrLevel == level, "CEFR level should be set to \(level)")
        }
    }

    @Test("CEFR level validation - accepts nil to clear")
    func testCEFRValidationNil() throws {
        let card = Flashcard(word: "test", definition: "test")

        // Set a level
        try card.setCEFRLevel("B2")
        #expect(card.cefrLevel == "B2")

        // Clear it
        try card.setCEFRLevel(nil)
        #expect(card.cefrLevel == nil, "CEFR level should be nil after clearing")
    }

    @Test("CEFR level validation - rejects invalid levels")
    func testCEFRValidationInvalid() {
        let card = Flashcard(word: "test", definition: "test")

        let invalidLevels = ["X1", "A0", "C3", "B", "A", "", "ABC", "123"]

        for invalidLevel in invalidLevels {
            do {
                try card.setCEFRLevel(invalidLevel)
                #expect(Bool(false), "Should have thrown FlashcardError.invalidCEFRLevel")
            } catch FlashcardError.invalidCEFRLevel {
                // Expected error
            } catch {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test("CEFR level validation - case sensitive")
    func testCEFRValidationCaseSensitive() {
        let card = Flashcard(word: "test", definition: "test")

        // Lowercase should be rejected
        do {
            try card.setCEFRLevel("a1")
            #expect(Bool(false), "Should have thrown error for lowercase")
        } catch FlashcardError.invalidCEFRLevel {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }

        // Mixed case should be rejected (testing with lowercase "b2" not uppercase "B2")
        do {
            try card.setCEFRLevel("b2")
            #expect(Bool(false), "Should have thrown error for lowercase")
        } catch FlashcardError.invalidCEFRLevel {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Flashcard initialization without CEFR level")
    func testFlashcardInitWithoutCEFR() {
        let card = Flashcard(word: "test", definition: "test definition")

        #expect(card.cefrLevel == nil, "New cards should have nil CEFR level")
    }

    // MARK: - IELTSDeckManager Tests

    @Test("IELTSDeckManager - create deck for valid CEFR level")
    func testDeckManagerCreateDeck() throws {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        // Create deck for B2
        let deck = try manager.getDeck(for: "B2")

        #expect(deck.name == "IELTS B2 (Upper Intermediate)")
        #expect(deck.icon == "book.fill")
    }

    @Test("IELTSDeckManager - throws error for invalid CEFR level")
    func testDeckManagerInvalidLevel() {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        var errorThrown = false
        do {
            _ = try manager.getDeck(for: "X1")
        } catch DeckManagerError.invalidCEFRLevel {
            errorThrown = true
        } catch {
            // Wrong error type
        }

        #expect(errorThrown, "Should have thrown DeckManagerError.invalidCEFRLevel")
    }

    @Test("IELTSDeckManager - returns existing deck")
    func testDeckManagerExistingDeck() throws {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        // Create deck first time
        let deck1 = try manager.getDeck(for: "A1")

        // Get deck second time - should be the same deck
        let deck2 = try manager.getDeck(for: "A1")

        #expect(deck1.name == deck2.name)
    }

    @Test("IELTSDeckManager - create all decks")
    func testDeckManagerCreateAllDecks() throws {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        let decks = try manager.createAllDecks()

        #expect(decks.count == 6, "Should create 6 decks")

        let expectedLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        for level in expectedLevels {
            #expect(decks[level] != nil, "Should have deck for level \(level)")
        }
    }

    @Test("IELTSDeckManager - get all decks")
    func testDeckManagerGetAllDecks() throws {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        let decks = try manager.getAllDecks()

        #expect(decks.count == 6, "Should have 6 decks")

        // Verify deck names
        let expectedNames = [
            "IELTS A1 (Beginner)",
            "IELTS A2 (Elementary)",
            "IELTS B1 (Intermediate)",
            "IELTS B2 (Upper Intermediate)",
            "IELTS C1 (Advanced)",
            "IELTS C2 (Proficiency)"
        ]

        let actualNames = decks.map(\.name).sorted()
        #expect(actualNames == expectedNames.sorted())
    }

    @Test("IELTSDeckManager - deck exists check")
    func testDeckManagerDeckExists() {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        // Deck should not exist initially
        #expect(manager.deckExists(for: "B1") == false)

        // Create deck
        _ = try? manager.getDeck(for: "B1")

        // Deck should exist now
        #expect(manager.deckExists(for: "B1") == true)
    }

    @Test("IELTSDeckManager - deck name helper")
    func testDeckManagerDeckName() {
        let context = ModelContext(modelContainer)
        let manager = IELTSDeckManager(modelContext: context)

        #expect(manager.deckName(for: "A1") == "IELTS A1 (Beginner)")
        #expect(manager.deckName(for: "B2") == "IELTS B2 (Upper Intermediate)")
        #expect(manager.deckName(for: "C2") == "IELTS C2 (Proficiency)")
        #expect(manager.deckName(for: "X1") == nil, "Invalid level should return nil")
    }

    // MARK: - DataImporter with CEFR Tests

    @Test("DataImporter - import with CEFR level")
    func testDataImporterWithCEFR() async throws {
        let context = ModelContext(modelContainer)
        let importer = DataImporter(modelContext: context)

        // Create deck
        let deck = Deck(name: "Test Deck", icon: "folder.fill")
        context.insert(deck)

        // Create card data with CEFR level
        let cards = [
            FlashcardData(
                word: "examine",
                definition: "To inspect or investigate",
                phonetic: "/ɪɡˈzæmɪn/",
                imageData: nil,
                cefrLevel: "B2",
                russianTranslation: "изучать"
            ),
        ]

        // Import cards
        let result = await importer.importCards(cards, into: deck, batchSize: 10)

        #expect(result.importedCount == 1)
        #expect(result.skippedCount == 0)
        #expect(result.errors.isEmpty)

        // Verify imported card has CEFR level
        let descriptor = FetchDescriptor<Flashcard>()
        let importedCards = try context.fetch(descriptor)

        #expect(importedCards.count == 1)
        #expect(importedCards.first?.cefrLevel == "B2")
        #expect(importedCards.first?.translation == "изучать")
    }

    @Test("DataImporter - import with invalid CEFR level logs warning")
    func testDataImporterWithInvalidCEFR() async throws {
        let context = ModelContext(modelContainer)
        let importer = DataImporter(modelContext: context)

        // Create deck
        let deck = Deck(name: "Test Deck", icon: "folder.fill")
        context.insert(deck)

        // Create card data with invalid CEFR level
        let cards = [
            FlashcardData(
                word: "test",
                definition: "Test definition",
                phonetic: nil,
                imageData: nil,
                cefrLevel: "X1",  // Invalid
                russianTranslation: nil
            ),
        ]

        // Import should succeed but skip the CEFR level
        let result = await importer.importCards(cards, into: deck, batchSize: 10)

        #expect(result.importedCount == 1, "Card should still be imported")

        // Verify card was imported but without CEFR level
        let descriptor = FetchDescriptor<Flashcard>()
        let importedCards = try context.fetch(descriptor)

        #expect(importedCards.count == 1)
        #expect(importedCards.first?.cefrLevel == nil, "Invalid CEFR level should not be set")
    }

    @Test("DataImporter - import with Russian translation")
    func testDataImporterWithTranslation() async throws {
        let context = ModelContext(modelContainer)
        let importer = DataImporter(modelContext: context)

        // Create deck
        let deck = Deck(name: "Test Deck", icon: "folder.fill")
        context.insert(deck)

        // Create card data with Russian translation
        let cards = [
            FlashcardData(
                word: "hello",
                definition: "A greeting",
                phonetic: "/hɛˈləʊ/",
                imageData: nil,
                cefrLevel: "A1",
                russianTranslation: "привет"
            ),
        ]

        // Import cards
        let result = await importer.importCards(cards, into: deck, batchSize: 10)

        #expect(result.importedCount == 1)

        // Verify translation was stored
        let descriptor = FetchDescriptor<Flashcard>()
        let importedCards = try context.fetch(descriptor)

        #expect(importedCards.first?.translation == "привет")
    }

    // MARK: - Integration Tests

    @Test("Integration - full IELTS vocabulary import workflow")
    func testFullIELTSImportWorkflow() async throws {
        let context = ModelContext(modelContainer)

        // Create deck manager
        let deckManager = IELTSDeckManager(modelContext: context)
        let deck = try deckManager.getDeck(for: "B2")

        // Create importer
        let importer = DataImporter(modelContext: context)

        // Sample IELTS vocabulary data
        let cards = [
            FlashcardData(
                word: "analyze",
                definition: "To examine methodically and in detail",
                phonetic: "/ˈænəlaɪz/",
                imageData: nil,
                cefrLevel: "B2",
                russianTranslation: "анализировать"
            ),
            FlashcardData(
                word: "significant",
                definition: "Sufficiently great or important to be worthy of attention",
                phonetic: "/sɪɡˈnɪfɪkənt/",
                imageData: nil,
                cefrLevel: "B2",
                russianTranslation: "значительный"
            ),
            FlashcardData(
                word: "evaluate",
                definition: "To form an idea of the amount, number, or value of",
                phonetic: "/ɪˈvæljueɪt/",
                imageData: nil,
                cefrLevel: "C1",
                russianTranslation: "оценивать"
            ),
        ]

        // Import all cards
        let result = await importer.importCards(cards, into: deck, batchSize: 10)

        #expect(result.importedCount == 3)
        #expect(result.isSuccess)

        // Verify all cards were imported with correct CEFR levels
        let descriptor = FetchDescriptor<Flashcard>()
        let importedCards = try context.fetch(descriptor)

        #expect(importedCards.count == 3)

        // Check B2 cards
        let b2Cards = importedCards.filter { $0.cefrLevel == "B2" }
        #expect(b2Cards.count == 2)

        // Check C1 card
        let c1Cards = importedCards.filter { $0.cefrLevel == "C1" }
        #expect(c1Cards.count == 1)

        // Verify Russian translations
        for card in importedCards {
            #expect(card.translation != nil, "All cards should have translations")
        }
    }

    @Test("Integration - duplicate detection across CEFR levels")
    func testDuplicateDetectionAcrossCEFRLevels() async throws {
        let context = ModelContext(modelContainer)

        let deckManager = IELTSDeckManager(modelContext: context)
        let deckA2 = try deckManager.getDeck(for: "A2")
        let deckB1 = try deckManager.getDeck(for: "B1")

        let importer = DataImporter(modelContext: context)

        // Import same word to A2 deck
        let cardsA2 = [
            FlashcardData(
                word: "achieve",
                definition: "To successfully bring about or reach a desired objective",
                phonetic: "/əˈtʃiːv/",
                imageData: nil,
                cefrLevel: "A2",
                russianTranslation: "достигать"
            ),
        ]

        let result1 = await importer.importCards(cardsA2, into: deckA2, batchSize: 10)
        #expect(result1.importedCount == 1)

        // Try to import same word to B1 deck - should be skipped
        let cardsB1 = [
            FlashcardData(
                word: "achieve",  // Same word
                definition: "Different definition",
                phonetic: nil,
                imageData: nil,
                cefrLevel: "B1",
                russianTranslation: "another translation"
            ),
        ]

        let result2 = await importer.importCards(cardsB1, into: deckB1, batchSize: 10)
        #expect(result2.skippedCount == 1, "Duplicate word should be skipped")
        #expect(result2.importedCount == 0)

        // Verify only one card exists
        let descriptor = FetchDescriptor<Flashcard>()
        let allCards = try context.fetch(descriptor)
        #expect(allCards.count == 1)
    }
}
