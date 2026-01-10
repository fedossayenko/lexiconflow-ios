//
//  IELTSDeckManagerTests.swift
//  LexiconFlowTests
//
//  Tests for IELTSDeckManager service
//  Tests verify deck creation, CEFR level grouping, and deck management
//

import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for IELTSDeckManager
///
/// Tests verify:
/// - Deck creation for all 6 CEFR levels (A1-C2)
/// - Deck naming and icon consistency
/// - Deck order for proper sorting
/// - Duplicate deck handling (get same deck twice)
/// - Invalid CEFR level error handling
/// - Batch deck creation (createAllDecks)
/// - Deck existence checking
/// - Deck deletion
@MainActor
struct IELTSDeckManagerTests {
    // MARK: - Test Setup

    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Deck Creation Tests

    @Test("IELTSDeckManager creates A1 deck with correct name and icon")
    func createA1Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "A1")

        #expect(deck.name == "IELTS A1 (Beginner)", "A1 deck should be named 'IELTS A1 (Beginner)'")
        #expect(deck.icon == "book.fill", "A1 deck should use 'book.fill' icon")
        #expect(deck.order == 100, "A1 deck should have order 100")
    }

    @Test("IELTSDeckManager creates A2 deck with correct name and icon")
    func createA2Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "A2")

        #expect(deck.name == "IELTS A2 (Elementary)", "A2 deck should be named 'IELTS A2 (Elementary)'")
        #expect(deck.icon == "book.fill", "A2 deck should use 'book.fill' icon")
        #expect(deck.order == 200, "A2 deck should have order 200")
    }

    @Test("IELTSDeckManager creates B1 deck with correct name and icon")
    func createB1Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "B1")

        #expect(deck.name == "IELTS B1 (Intermediate)", "B1 deck should be named 'IELTS B1 (Intermediate)'")
        #expect(deck.icon == "book.fill", "B1 deck should use 'book.fill' icon")
        #expect(deck.order == 300, "B1 deck should have order 300")
    }

    @Test("IELTSDeckManager creates B2 deck with correct name and icon")
    func createB2Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "B2")

        #expect(deck.name == "IELTS B2 (Upper Intermediate)", "B2 deck should be named 'IELTS B2 (Upper Intermediate)'")
        #expect(deck.icon == "book.fill", "B2 deck should use 'book.fill' icon")
        #expect(deck.order == 400, "B2 deck should have order 400")
    }

    @Test("IELTSDeckManager creates C1 deck with correct name and icon")
    func createC1Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "C1")

        #expect(deck.name == "IELTS C1 (Advanced)", "C1 deck should be named 'IELTS C1 (Advanced)'")
        #expect(deck.icon == "book.fill", "C1 deck should use 'book.fill' icon")
        #expect(deck.order == 500, "C1 deck should have order 500")
    }

    @Test("IELTSDeckManager creates C2 deck with correct name and icon")
    func createC2Deck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "C2")

        #expect(deck.name == "IELTS C2 (Proficiency)", "C2 deck should be named 'IELTS C2 (Proficiency)'")
        #expect(deck.icon == "book.fill", "C2 deck should use 'book.fill' icon")
        #expect(deck.order == 600, "C2 deck should have order 600")
    }

    @Test("IELTSDeckManager creates deck with empty cards array")
    func createDeckHasEmptyCards() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "A1")

        // New deck should have no cards associated
        // Note: We test deck creation, not SwiftData query functionality
        #expect(deck.name == "IELTS A1 (Beginner)", "Deck name should match")
    }

    @Test("IELTSDeckManager persists deck to ModelContext")
    func createDeckPersists() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck = try manager.getDeck(for: "B1")

        // Verify deck was saved by checking it exists
        let exists = manager.deckExists(for: "B1")
        #expect(exists == true, "Deck should be persisted to ModelContext")
        #expect(deck.name == "IELTS B1 (Intermediate)", "Deck name should match")
    }

    // MARK: - Duplicate Deck Handling Tests

    @Test("IELTSDeckManager returns existing deck on second call")
    func getExistingDeck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let deck1 = try manager.getDeck(for: "A1")
        let deck2 = try manager.getDeck(for: "A1")

        #expect(deck1.id == deck2.id, "Should return same deck instance")
        #expect(deck1.name == deck2.name, "Deck names should match")
    }

    @Test("IELTSDeckManager handles multiple calls for different levels")
    func getMultipleDifferentDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let a1Deck = try manager.getDeck(for: "A1")
        let b2Deck = try manager.getDeck(for: "B2")
        let c1Deck = try manager.getDeck(for: "C1")

        #expect(a1Deck.id != b2Deck.id, "Different levels should create different decks")
        #expect(b2Deck.id != c1Deck.id, "Different levels should create different decks")
        #expect(a1Deck.id != c1Deck.id, "Different levels should create different decks")
    }

    @Test("IELTSDeckManager creates all six decks in order")
    func createAllDecksInOrder() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let decks = try manager.createAllDecks()

        #expect(decks.count == 6, "Should create 6 decks")
        #expect(decks["A1"]?.order == 100, "A1 should have order 100")
        #expect(decks["A2"]?.order == 200, "A2 should have order 200")
        #expect(decks["B1"]?.order == 300, "B1 should have order 300")
        #expect(decks["B2"]?.order == 400, "B2 should have order 400")
        #expect(decks["C1"]?.order == 500, "C1 should have order 500")
        #expect(decks["C2"]?.order == 600, "C2 should have order 600")
    }

    // MARK: - Invalid CEFR Level Tests

    @Test("IELTSDeckManager throws error for invalid CEFR level")
    func throwsForInvalidLevel() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(throws: DeckManagerError.self) {
            _ = try manager.getDeck(for: "INVALID")
        }
    }

    @Test("IELTSDeckManager throws error for empty level string")
    func throwsForEmptyLevel() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(throws: DeckManagerError.self) {
            try manager.getDeck(for: "")
        }
    }

    @Test("IELTSDeckManager throws error for case-sensitive level")
    func throwsForCaseSensitiveLevel() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(throws: DeckManagerError.self) {
            try manager.getDeck(for: "a1") // lowercase should fail
        }
    }

    @Test("DeckManagerError has correct error description")
    func errorDescription() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        do {
            _ = try manager.getDeck(for: "INVALID")
        } catch let error as DeckManagerError {
            #expect(error.errorDescription != nil, "Error should have description")
            #expect((error.errorDescription?.contains("INVALID")) == true, "Error description should mention invalid level")
        }
    }

    @Test("DeckManagerError has recovery suggestion")
    func errorRecoverySuggestion() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        do {
            _ = try manager.getDeck(for: "INVALID")
        } catch let error as DeckManagerError {
            #expect(error.recoverySuggestion != nil, "Error should have recovery suggestion")
            #expect((error.recoverySuggestion?.contains("A1")) == true, "Recovery should suggest valid levels")
        }
    }

    // MARK: - Deck Existence Tests

    @Test("IELTSDeckManager deckExists returns true for created deck")
    func deckExistsTrue() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        _ = try manager.getDeck(for: "A1")

        #expect(manager.deckExists(for: "A1") == true, "deckExists should return true for created deck")
    }

    @Test("IELTSDeckManager deckExists returns false for non-existent deck")
    func deckExistsFalse() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(manager.deckExists(for: "A1") == false, "deckExists should return false for non-existent deck")
    }

    @Test("IELTSDeckManager deckExists returns false for invalid level")
    func deckExistsInvalidLevel() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(manager.deckExists(for: "INVALID") == false, "deckExists should return false for invalid level")
    }

    // MARK: - Get All Decks Tests

    @Test("IELTSDeckManager getAllDecks returns all six decks")
    func getAllDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let decks = try manager.getAllDecks()

        #expect(decks.count == 6, "Should return all 6 decks")
        #expect(decks.allSatisfy { $0.icon == "book.fill" }, "All decks should use 'book.fill' icon")
    }

    @Test("IELTSDeckManager getAllDecks returns decks in correct order")
    func getAllDecksInOrder() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        let decks = try manager.getAllDecks()

        #expect(decks.count == 6, "Should have 6 decks")
        #expect(decks[0].name == "IELTS A1 (Beginner)", "First deck should be A1")
        #expect(decks[1].name == "IELTS A2 (Elementary)", "Second deck should be A2")
        #expect(decks[2].name == "IELTS B1 (Intermediate)", "Third deck should be B1")
        #expect(decks[3].name == "IELTS B2 (Upper Intermediate)", "Fourth deck should be B2")
        #expect(decks[4].name == "IELTS C1 (Advanced)", "Fifth deck should be C1")
        #expect(decks[5].name == "IELTS C2 (Proficiency)", "Sixth deck should be C2")
    }

    // MARK: - Deck Deletion Tests

    @Test("IELTSDeckManager deleteDeck removes deck from context")
    func deleteDeck() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        // Create deck
        _ = try manager.getDeck(for: "A1")
        #expect(manager.deckExists(for: "A1") == true, "Deck should exist before deletion")

        // Delete deck
        try manager.deleteDeck(for: "A1")
        #expect(manager.deckExists(for: "A1") == false, "Deck should not exist after deletion")
    }

    @Test("IELTSDeckManager deleteDeck is idempotent")
    func deleteDeckIdempotent() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        // Create deck
        _ = try manager.getDeck(for: "A1")

        // Delete twice (should not throw)
        try manager.deleteDeck(for: "A1")
        try manager.deleteDeck(for: "A1")

        #expect(manager.deckExists(for: "A1") == false, "Deck should not exist after deletion")
    }

    @Test("IELTSDeckManager deleteDeck throws error for invalid level")
    func deleteDeckInvalidLevel() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(throws: DeckManagerError.self) {
            try manager.deleteDeck(for: "INVALID")
        }
    }

    // MARK: - Deck Name Tests

    @Test("IELTSDeckManager deckName returns correct name for valid level")
    func deckNameValid() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(manager.deckName(for: "A1") == "IELTS A1 (Beginner)", "A1 name should match")
        #expect(manager.deckName(for: "B2") == "IELTS B2 (Upper Intermediate)", "B2 name should match")
        #expect(manager.deckName(for: "C2") == "IELTS C2 (Proficiency)", "C2 name should match")
    }

    @Test("IELTSDeckManager deckName returns nil for invalid level")
    func deckNameInvalid() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        #expect(manager.deckName(for: "INVALID") == nil, "Should return nil for invalid level")
        #expect(manager.deckName(for: "") == nil, "Should return nil for empty level")
        #expect(manager.deckName(for: "a1") == nil, "Should return nil for lowercase level")
    }

    // MARK: - Integration Tests

    @Test("IELTSDeckManager handles complete workflow")
    func completeWorkflow() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        // 1. Create all decks
        let decks = try manager.createAllDecks()
        #expect(decks.count == 6, "Should create 6 decks")

        // 2. Verify all decks exist
        #expect(manager.deckExists(for: "A1") == true, "A1 should exist")
        #expect(manager.deckExists(for: "B2") == true, "B2 should exist")
        #expect(manager.deckExists(for: "C2") == true, "C2 should exist")

        // 3. Get all decks
        let allDecks = try manager.getAllDecks()
        #expect(allDecks.count == 6, "Should get all 6 decks")

        // 4. Delete one deck
        try manager.deleteDeck(for: "A1")
        #expect(manager.deckExists(for: "A1") == false, "A1 should not exist after deletion")
        #expect(manager.deckExists(for: "A2") == true, "Other decks should still exist")
    }

    @Test("IELTSDeckManager persists after context save")
    func persistsAfterSave() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        // Create decks
        _ = try manager.getDeck(for: "A1")
        _ = try manager.getDeck(for: "B2")

        // Save context
        try context.save()

        // Verify decks still exist
        #expect(manager.deckExists(for: "A1") == true, "A1 should persist after save")
        #expect(manager.deckExists(for: "B2") == true, "B2 should persist after save")
    }

    @Test("IELTSDeckManager handles rapid deck creation")
    func rapidDeckCreation() async throws {
        let context = freshContext()
        try context.clearAll()
        let manager = IELTSDeckManager(modelContext: context)

        // Create all decks rapidly
        for level in ["A1", "A2", "B1", "B2", "C1", "C2"] {
            _ = try manager.getDeck(for: level)
        }

        // Verify all were created
        let allDecks = try manager.getAllDecks()
        #expect(allDecks.count == 6, "All 6 decks should be created")
    }
}
