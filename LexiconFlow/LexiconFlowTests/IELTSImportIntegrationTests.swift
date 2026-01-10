//
//  IELTSImportIntegrationTests.swift
//  LexiconFlowTests
//
//  Integration tests for IELTS vocabulary importer.
//  Tests full import workflow, deck creation, and FSRS state initialization.
//  Tests skip gracefully if vocabulary file is not available.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Integration tests for IELTS vocabulary import workflow
///
/// These tests require the IELTS vocabulary file to be present in the bundle.
/// Tests skip gracefully with a warning if the file is not available.
@MainActor
struct IELTSImportIntegrationTests {
    // MARK: - Test Fixture

    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    /// Helper class to get test bundle
    private class BundleHelper {}

    /// Checks if vocabulary file is available in test bundle
    private func requireVocabularyFile() throws {
        // Use test bundle for unit tests (not Bundle.main which points to test runner)
        let testBundle = Bundle(for: BundleHelper.self as! AnyClass)
        guard let _ = testBundle.url(
            forResource: "ielts-vocabulary-smartool",
            withExtension: "json"
        ) else {
            throw IELTSImportError.fileNotFound
        }
    }

    // MARK: - Full Import Workflow

    @Test("Full import creates all 6 CEFR decks", .disabled("Vocabulary file may not be in test bundle - requires manual setup"))
    func fullImportCreatesAllDecks() async throws {
        // Skip test if vocabulary file is not available
        do {
            try requireVocabularyFile()
        } catch {
            print("⚠️ Skipping IELTS import test: vocabulary file not found in bundle")
            return
        }

        let context = freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        let result = try await importer.importAllVocabulary()

        // Use flexible assertion - count may vary based on source file
        #expect(result.importedCount > 3000, "Should import most SMARTool words")
        #expect(result.levelResults.count == 6, "Should have 6 CEFR levels")

        let decks = try context.fetch(FetchDescriptor<Deck>())
        let ieltsDecks = decks.filter { $0.name.contains("IELTS") }
        #expect(ieltsDecks.count == 6, "Should create 6 IELTS decks")
    }

    @Test("Import assigns correct CEFR levels to cards", .disabled("Vocabulary file may not be in test bundle - requires manual setup"))
    func cEFRLevelsAssignedCorrectly() async throws {
        // Skip test if vocabulary file is not available
        do {
            try requireVocabularyFile()
        } catch {
            print("⚠️ Skipping IELTS import test: vocabulary file not found in bundle")
            return
        }

        let context = freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)
        _ = try await importer.importAllVocabulary()

        // Check A1 level - filter after fetching
        let allDecks = try context.fetch(FetchDescriptor<Deck>())
        let a1Decks = allDecks.filter { $0.name == "IELTS A1" }
        #expect(a1Decks.count == 1, "Should have A1 deck")

        let allCards = try context.fetch(FetchDescriptor<Flashcard>())
        let a1Cards = allCards.filter { $0.deck?.name == "IELTS A1" }
        #expect(!a1Cards.isEmpty, "A1 deck should have cards")

        // Verify all cards in A1 have A1 CEFR level
        for card in a1Cards.prefix(10) {
            #expect(card.cefrLevel == "A1", "A1 deck card should have A1 level")
        }
    }

    @Test("Import creates FSRS state for all cards", .disabled("Vocabulary file may not be in test bundle - requires manual setup"))
    func importCreatesFSRSState() async throws {
        // Skip test if vocabulary file is not available
        do {
            try requireVocabularyFile()
        } catch {
            print("⚠️ Skipping IELTS import test: vocabulary file not found in bundle")
            return
        }

        let context = freshContext()
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

    @Test("Import is idempotent", .disabled("Vocabulary file may not be in test bundle - requires manual setup"))
    func importIsIdempotent() async throws {
        // Skip test if vocabulary file is not available
        do {
            try requireVocabularyFile()
        } catch {
            print("⚠️ Skipping IELTS import test: vocabulary file not found in bundle")
            return
        }

        let context = freshContext()
        try context.clearAll()

        let importer = IELTSVocabularyImporter(modelContext: context)

        // First import
        let result1 = try await importer.importAllVocabulary()
        let firstCount = result1.importedCount

        // Second import should not create duplicates
        let result2 = try await importer.importAllVocabulary()

        #expect(result2.importedCount == 0, "Second import should import 0 (all duplicates)")
    }

    @Test("Import result reports accurate statistics", .disabled("Vocabulary file may not be in test bundle - requires manual setup"))
    func importResultAccuracy() async throws {
        // Skip test if vocabulary file is not available
        do {
            try requireVocabularyFile()
        } catch {
            print("⚠️ Skipping IELTS import test: vocabulary file not found in bundle")
            return
        }

        let context = freshContext()
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
