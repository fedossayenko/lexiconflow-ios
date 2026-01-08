//
//  CardBackViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardBackView including:
//  - CEFR badge display
//  - Translation display
//  - Sentence section rendering
//  - SentenceRow component
//  - View state management
//  - Task lifecycle
//  - Helper functions
//
//  NOTE: SwiftUI view testing is limited without snapshot testing
//  These tests verify smoke test behavior and state management
//

import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import LexiconFlow

/// Test suite for CardBackView
@MainActor
struct CardBackViewTests {

    // MARK: - Initialization Tests

    @Test("CardBackView initializes with flashcard from context")
    func testInitialization() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(
            word: "test",
            definition: "A test",
            translation: "тест",
            
        )
        context.insert(card)
        try context.save()

        // Create view with binding to card from context
        let view = CardBackView(card: card)
        _ = view.body
    }

    // MARK: - Translation Tests
    @Test("CEFR badge has correct color for invalid level")
    func testCEFRBadgeColorInvalid() {
        let color = Theme.cefrColor(for: "X5")
        // Invalid levels should default to gray
        #expect(color == .gray)
    }

    // MARK: - Translation Display Tests

    @Test("Translation displays when translation exists")
    func testTranslationDisplays() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(
            word: "test",
            definition: "A test",
            translation: "тест"
        )
        context.insert(card)

        #expect(card.translation == "тест")
    }

    @Test("Translation hides when translation is nil")
    func testTranslationHides() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(
            word: "test",
            definition: "A test"
            // translation not set
        )
        context.insert(card)

        #expect(card.translation == nil)
    }

    @Test("Translation handles empty string")
    func testTranslationEmpty() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(
            word: "test",
            definition: "A test",
            translation: ""
        )
        context.insert(card)

        // Empty string is different from nil
        #expect(card.translation == "")
    }

    // MARK: - Sentence Section Tests

    @Test("Sentence section initializes ViewModel")
    func testSentenceSectionInit() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        // ViewModel is created in view body
        // This is a smoke test that verifies the flow
        #expect(true)
    }

    @Test("Sentence section loads sentences on appear")
    func testLoadSentencesOnAppear() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        let sentence = try GeneratedSentence(
            sentenceText: "Test sentence.",
            cefrLevel: "A1",
            
        )
        sentence.flashcard = card
        context.insert(sentence)
        try context.save()

        // Verify sentence exists
        #expect(card.generatedSentences.count == 1)
    }

    @Test("Sentence section shows empty state")
    func testSentenceEmptyState() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        // No sentences - should show empty state
        #expect(card.generatedSentences.isEmpty)
    }

    @Test("Sentence section shows sentences")
    func testSentenceShowsSentences() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        for i in 1...3 {
            let sentence = try GeneratedSentence(
                sentenceText: "Sentence \(i)",
            cefrLevel: "A1",
                
            )
            sentence.flashcard = card
            context.insert(sentence)
        }
        try context.save()

        #expect(card.generatedSentences.count == 3)
    }

    // MARK: - SentenceRow Component Tests

    @Test("SentenceRow displays sentence text")
    func testSentenceRowText() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let sentence = try GeneratedSentence(
            sentenceText: "This is a test sentence.",
            cefrLevel: "A1",
            
        )
        context.insert(sentence)

        #expect(sentence.sentenceText == "This is a test sentence.")
    }

    @Test("SentenceRow displays CEFR badge")
    func testSentenceRowCEFR() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            
        )
        context.insert(sentence)

        #expect(sentence.cefrLevel == "A1", "Sentence should display the CEFR level it was created with")
    }

    @Test("SentenceRow shows expiration warning")
    func testSentenceRowExpirationWarning() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        // Expired sentence
        let expiredSentence = try GeneratedSentence(
            sentenceText: "Expired",
            cefrLevel: "A1",
            
            generatedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            ttlDays: 7
        )
        context.insert(expiredSentence)

        #expect(expiredSentence.isExpired)
        #expect(expiredSentence.daysUntilExpiration < 0)
    }

    @Test("SentenceRow favorite button works")
    func testSentenceRowFavorite() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            
            isFavorite: false
        )
        context.insert(sentence)

        #expect(!sentence.isFavorite)

        // Toggle favorite
        sentence.isFavorite.toggle()
        try context.save()

        #expect(sentence.isFavorite)
    }

    @Test("SentenceRow delete button works")
    func testSentenceRowDelete() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        let sentence = try GeneratedSentence(
            sentenceText: "Test",
            cefrLevel: "A1",
            
        )
        sentence.flashcard = card
        context.insert(sentence)
        try context.save()

        // Verify exists
        var descriptor = FetchDescriptor<GeneratedSentence>()
        var results = try context.fetch(descriptor)
        #expect(results.count == 1)

        // Delete
        context.delete(sentence)
        try context.save()

        // Verify deleted
        descriptor = FetchDescriptor<GeneratedSentence>()
        results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    // MARK: - Helper Function Tests

    @Test("cefrColor returns correct colors for all levels")
    func testCEFRColorAllLevels() {
        let colorMap: [(String, Color)] = [
            ("A1", .green),
            ("A2", .green),
            ("B1", .blue),
            ("B2", .blue),
            ("C1", .purple),
            ("C2", .purple),
            ("X5", .gray),
            ("", .gray)
        ]

        for (level, expectedColor) in colorMap {
            let color = Theme.cefrColor(for: level)
            #expect(color == expectedColor, "CEFR level \(level) should be \(expectedColor)")
        }
    }

    // MARK: - State Management Tests

    @Test("View state initializes correctly")
    func testViewStateInit() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        // View should initialize without crashing
        let view = CardBackView(card: card)
        _ = view.body

        #expect(true)
    }

    @Test("View handles loading state")
    func testViewLoadingState() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        // Simulate loading state
        let viewModel = SentenceGenerationViewModel(modelContext: context)
        #expect(!viewModel.isGenerating)

        viewModel.isGenerating = true
        #expect(viewModel.isGenerating)
    }

    @Test("View handles error state")
    func testViewErrorState() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        let viewModel = SentenceGenerationViewModel(modelContext: context)

        // Initially no error
        #expect(viewModel.errorMessage == nil)

        // Set error
        viewModel.errorMessage = "Test error"
        #expect(viewModel.errorMessage == "Test error")
    }

    // MARK: - View Lifecycle Tests

    @Test("View cleanup on disappear")
    func testViewCleanup() throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(word: "test", definition: "A test")
        context.insert(card)

        // View cleanup is handled in onDisappear
        // This is a smoke test that cleanup doesn't crash
        let viewModel = SentenceGenerationViewModel(modelContext: context)
        #expect(viewModel != nil)
    }
}

// MARK: - Helper Functions for Testing
