//
//  IELTSImportIntegrationTests.swift
//  LexiconFlowTests
//
//  Integration tests for IELTS vocabulary import workflow
//
//  NOTE: These tests require the IELTS vocabulary JSON file to be available in the bundle.
//  In the test environment, the file may not be accessible, so tests will be skipped gracefully.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

@Suite("IELTS Import Workflow Integration Tests")
@MainActor
final class IELTSImportIntegrationTests {
    // MARK: - Test Context Setup

    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    /// Checks if vocabulary file is available and skips test if not
    private func requireVocabularyFile() throws {
        let context = self.freshContext()
        let importer = IELTSVocabularyImporter(modelContext: context)
        guard importer.vocabularyFileExists() else {
            throw IELTSImportError.fileNotFound
        }
    }

    // MARK: - Full Import Workflow

    @Test("Full import creates all 6 CEFR decks")
    func fullImportCreatesAllDecks() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let result = try await importer.importAllVocabulary()

        #expect(result.importedCount == 3545, "Should import all SMARTool words")
        #expect(result.levelResults.count == 6, "Should have 6 CEFR levels")

        let decks = try context.fetch(FetchDescriptor<Deck>())
        let ieltsDecks = decks.filter { $0.name.contains("IELTS") }
        #expect(ieltsDecks.count == 6, "Should create 6 IELTS decks")
    }

    @Test("Import assigns correct CEFR levels to cards")
    func cEFRLevelsAssignedCorrectly() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        _ = try await importer.importAllVocabulary()

        // Verify A1 deck has A1 cards
        let a1Deck = try context.fetch(
            FetchDescriptor<Deck>(predicate: #Predicate<Deck> { deck in
                deck.name.contains("A1")
            })
        ).first

        #expect(a1Deck != nil, "Should have A1 deck")

        // Get all cards and filter for A1 deck
        let allCards = try context.fetch(FetchDescriptor<Flashcard>())
        let a1Cards = allCards.filter { $0.deck?.id == a1Deck!.id }

        #expect(a1Cards.count > 0, "A1 deck should have cards")

        for card in a1Cards {
            #expect(card.cefrLevel == "A1", "All cards in A1 deck should be A1 level")
        }
    }

    @Test("Russian translations are populated")
    func russianTranslationsPopulated() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        _ = try await importer.importAllVocabulary()

        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        let cardsWithTranslations = cards.filter { $0.translation != nil && !$0.translation!.isEmpty }

        #expect(cardsWithTranslations.count == cards.count, "All cards should have Russian translations")
    }

    @Test("Import has correct word counts per level")
    func wordCountsPerLevel() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let result = try await importer.importAllVocabulary()

        // SMARTool dataset has specific word counts
        let expectedCounts = [
            "A1": 494,
            "A2": 490,
            "B1": 809,
            "B2": 1752,
            "C1": 0,
            "C2": 0
        ]

        for (level, expectedCount) in expectedCounts {
            let levelResult = result.levelResults[level]
            #expect(levelResult != nil, "Should have result for \(level)")
            #expect(levelResult?.importedCount == expectedCount, "\(level) should have \(expectedCount) words")
        }
    }

    // MARK: - Progress Tracking

    @Test("Progress handler called for each batch")
    func progressTracking() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let collector = IELTSProgressCollector()

        _ = try await importer.importAllVocabulary(
            progressHandler: { progress in
                Task { await collector.add(progress) }
            }
        )

        // Small delay to ensure all progress updates complete
        try await Task.sleep(nanoseconds: 500000000) // 0.5s

        let updates = await collector.allUpdates
        #expect(updates.count > 0, "Should receive progress updates")
        #expect(updates.last?.overallProgress == 3545, "Final progress should show all words")
    }

    @Test("Progress is monotonically increasing")
    func progressMonotonic() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let collector = IELTSProgressCollector()

        _ = try await importer.importAllVocabulary(
            progressHandler: { progress in
                Task { await collector.add(progress) }
            }
        )

        try await Task.sleep(nanoseconds: 500000000)

        let updates = await collector.allUpdates
        #expect(updates.count > 1, "Should have multiple progress updates")

        for i in 1 ..< updates.count {
            let prevProgress = updates[i - 1].overallProgress
            let currProgress = updates[i].overallProgress
            #expect(
                currProgress >= prevProgress,
                "Progress should be monotonically increasing (step \(i)): \(prevProgress) -> \(currProgress)"
            )
        }
    }

    @Test("Progress includes current word and level")
    func progressIncludesCurrentWordAndLevel() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let collector = IELTSProgressCollector()

        _ = try await importer.importAllVocabulary(
            progressHandler: { progress in
                Task { await collector.add(progress) }
            }
        )

        try await Task.sleep(nanoseconds: 500000000)

        let updates = await collector.allUpdates
        #expect(updates.count > 0, "Should receive progress updates")

        // Verify progress updates contain expected fields
        for progress in updates {
            #expect(!progress.currentWord.isEmpty, "Progress should include current word")
            #expect(!progress.currentLevel.isEmpty, "Progress should include current level")
            #expect(progress.overallTotal > 0, "Progress should include total count")
        }
    }

    // MARK: - Re-import Behavior

    @Test("Re-import skips duplicate words")
    func reImportSkipsDuplicates() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)

        // First import
        let result1 = try await importer.importAllVocabulary()
        #expect(result1.importedCount == 3545, "First import should succeed")

        // Get card count before second import
        let cardCountBefore = try context.fetchCount(FetchDescriptor<Flashcard>())

        // Second import should skip all
        let result2 = try await importer.importAllVocabulary()
        #expect(result2.importedCount == 0, "Re-import should skip all duplicates")

        let cardCountAfter = try context.fetchCount(FetchDescriptor<Flashcard>())
        #expect(cardCountBefore == cardCountAfter, "No new cards should be created")
    }

    @Test("Re-import does not create duplicate cards")
    func reImportDoesNotCreateDuplicateCards() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)

        // First import
        _ = try await importer.importAllVocabulary()

        let cardsBefore = try context.fetch(FetchDescriptor<Flashcard>())
        let uniqueWordsBefore = Set(cardsBefore.map(\.word))

        // Second import
        _ = try await importer.importAllVocabulary()

        let cardsAfter = try context.fetch(FetchDescriptor<Flashcard>())
        let uniqueWordsAfter = Set(cardsAfter.map(\.word))

        #expect(uniqueWordsBefore.count == uniqueWordsAfter.count, "No new unique words should be added")
    }

    // MARK: - Deck Creation

    @Test("IELTSDeckManager creates all decks")
    func deckManagerCreatesAllDecks() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deckManager = IELTSDeckManager(modelContext: context)
        let decks = try deckManager.createAllDecks()

        #expect(decks.count == 6, "Should create 6 decks")

        let expectedNames = ["IELTS A1", "IELTS A2", "IELTS B1", "IELTS B2", "IELTS C1", "IELTS C2"]
        for expectedName in expectedNames {
            let exists = decks.values.contains { deck in deck.name == expectedName }
            #expect(exists, "Should have deck named \(expectedName)")
        }
    }

    @Test("IELTSDeckManager returns existing deck on second call")
    func deckManagerReturnsExistingDeck() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deckManager = IELTSDeckManager(modelContext: context)

        // First call creates deck
        let deck1 = try deckManager.getDeck(for: "A1")

        // Second call should return same deck
        let deck2 = try deckManager.getDeck(for: "A1")

        #expect(deck1.id == deck2.id, "Should return same deck instance")

        // Should only have one IELTS A1 deck
        let decks = try context.fetch(FetchDescriptor<Deck>())
        let a1Decks = decks.filter { $0.name == "IELTS A1" }
        #expect(a1Decks.count == 1, "Should only have one IELTS A1 deck")
    }

    // MARK: - Performance

    @Test("Import completes in reasonable time")
    func importPerformance() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)

        let start = Date()
        let result = try await importer.importAllVocabulary()
        let duration = Date().timeIntervalSince(start)

        #expect(result.importedCount == 3545, "Should import all words")
        #expect(duration < 60.0, "Full import should complete in under 60 seconds (took \(String(format: "%.2f", duration))s)")
    }

    @Test("Single level import is fast")
    func singleLevelImportPerformance() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)

        let start = Date()
        let result = try await importer.importLevel("A1")
        let duration = Date().timeIntervalSince(start)

        #expect(result.importedCount == 494, "Should import A1 words")
        #expect(duration < 10.0, "Single level import should be fast (took \(String(format: "%.2f", duration))s)")
    }

    // MARK: - Data Integrity

    @Test("All imported cards have valid structure")
    func importedCardsHaveValidStructure() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        _ = try await importer.importAllVocabulary()

        let cards = try context.fetch(FetchDescriptor<Flashcard>())

        for card in cards {
            // Word should not be empty
            #expect(!card.word.isEmpty, "Card should have a word")

            // Definition should not be empty
            #expect(!card.definition.isEmpty, "Card should have a definition")

            // CEFR level should be valid
            #expect(["A1", "A2", "B1", "B2"].contains(card.cefrLevel), "Card should have valid CEFR level")

            // Should have a deck
            #expect(card.deck != nil, "Card should belong to a deck")

            // Should have FSRS state
            #expect(card.fsrsState != nil, "Card should have FSRS state")
        }
    }

    @Test("FSRS states are initialized correctly")
    func fSRSStatesInitializedCorrectly() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        _ = try await importer.importAllVocabulary()

        let cards = try context.fetch(FetchDescriptor<Flashcard>())

        for card in cards {
            let state = card.fsrsState
            #expect(state != nil, "Card should have FSRS state")

            // New cards should have initial state
            #expect(state?.stability == 0, "New card stability should be 0")
            #expect(state?.difficulty == 5, "New card difficulty should be 5")
            #expect(state?.retrievability == 0.9, "New card retrievability should be 0.9")
            #expect(state?.stateEnum == FlashcardState.new.rawValue, "New card state should be 'new'")
        }
    }

    @Test("Import result reports accurate statistics")
    func importResultAccuracy() async throws {
        try self.requireVocabularyFile()

        let context = self.freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let result = try await importer.importAllVocabulary()

        // Verify result structure
        #expect(result.importedCount > 0, "Should have imported cards")
        #expect(result.failedCount == 0, "Should have no failures for valid data")
        #expect(result.duration > 0, "Should report duration")

        // Verify level results
        var totalLevelCount = 0
        for (_, levelResult) in result.levelResults {
            totalLevelCount += levelResult.importedCount
            #expect(levelResult.failedCount == 0, "Level should have no failures")
        }

        #expect(totalLevelCount == result.importedCount, "Level counts should sum to total")
    }
}

// MARK: - Test Helpers

/// Actor-isolated collector for IELTS progress tracking
actor IELTSProgressCollector {
    private var updates: [IELTSVocabularyImporter.Progress] = []

    func add(_ progress: IELTSVocabularyImporter.Progress) {
        self.updates.append(progress)
    }

    var allUpdates: [IELTSVocabularyImporter.Progress] {
        self.updates
    }

    var count: Int {
        self.updates.count
    }
}
