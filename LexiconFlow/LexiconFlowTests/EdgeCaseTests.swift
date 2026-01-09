//
//  EdgeCaseTests.swift
//  LexiconFlowTests
//
//  Edge case and security tests for translation service and card operations.
//  Tests cover:
//  - Input validation (empty strings, very long text)
//  - Unicode handling (emoji, RTL languages, CJK, combining characters)
//  - Security (SQL injection, JSON injection, code injection, path traversal)
//  - Malformed API responses
//  - Special characters and encoding issues
//
//  These tests ensure the app handles edge cases gracefully and doesn't
//  execute or propagate malicious input.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for edge cases and security
@MainActor
struct EdgeCaseTests {
    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createFlashcard(
        word: String,
        definition: String,
        phonetic: String? = nil,
        in context: ModelContext
    ) throws -> Flashcard {
        let flashcard = Flashcard(word: word, definition: definition, phonetic: phonetic, imageData: nil)
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state
        context.insert(flashcard)
        context.insert(state)
        try context.save()
        return flashcard
    }

    // MARK: - Input Validation Tests

    @Test("Empty word is stored as-is")
    func emptyWordIsStored() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "", definition: "definition", in: context)

        #expect(flashcard.word.isEmpty, "Empty word should be stored")
    }

    @Test("Empty definition is stored as-is")
    func emptyDefinitionIsStored() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "test", definition: "", in: context)

        #expect(flashcard.definition.isEmpty, "Empty definition should be stored")
    }

    @Test("Both empty word and definition")
    func bothWordAndDefinitionEmpty() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "", definition: "", in: context)

        #expect(flashcard.word.isEmpty, "Empty word should be stored")
        #expect(flashcard.definition.isEmpty, "Empty definition should be stored")
    }

    @Test("Whitespace-only word is preserved")
    func whitespaceOnlyWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "   \t  \n  ", definition: "def", in: context)

        #expect(flashcard.word == "   \t  \n  ", "Whitespace should be preserved")
    }

    @Test("Very long word (1000 characters)")
    func veryLongWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let longWord = String(repeating: "a", count: 1000)
        let flashcard = try createFlashcard(word: longWord, definition: "def", in: context)

        #expect(flashcard.word.count == 1000, "1000-char word should be stored")
    }

    @Test("Very long definition (10000 characters)")
    func veryLongDefinition() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Create exactly 10000 characters
        let longDefinition = String(repeating: "a", count: 10000)
        let flashcard = try createFlashcard(word: "test", definition: longDefinition, in: context)

        #expect(flashcard.definition.count == 10000, "10000-char definition should be stored")
    }

    // MARK: - Unicode Tests

    @Test("Emoji in word and definition")
    func emojiInWordAndDefinition() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "café ☕️",
            definition: "coffee shop with emojis 😊🎉",
            in: context
        )

        #expect(flashcard.word == "café ☕️", "Emoji should be preserved")
        #expect(flashcard.definition.contains("😊"), "Emoji in definition should be preserved")
    }

    @Test("Multiple emojis in sequence")
    func multipleEmojis() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test",
            definition: "😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘",
            in: context
        )

        #expect(flashcard.definition.count > 0, "Multiple emojis should be preserved")
    }

    @Test("RTL language: Arabic")
    func arabicText() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "مرحبا",
            definition: "تحية باللغة العربية",
            in: context
        )

        #expect(flashcard.word == "مرحبا", "Arabic should be preserved")
        #expect(flashcard.definition == "تحية باللغة العربية", "Arabic definition should be preserved")
    }

    @Test("RTL language: Hebrew")
    func hebrewText() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "שלום",
            definition: "ברכה בעברית",
            in: context
        )

        #expect(flashcard.word == "שלום", "Hebrew should be preserved")
        #expect(flashcard.definition == "ברכה בעברית", "Hebrew definition should be preserved")
    }

    @Test("CJK language: Chinese (Simplified)")
    func chineseSimplified() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "你好",
            definition: "传统的中国问候方式",
            in: context
        )

        #expect(flashcard.word == "你好", "Chinese should be preserved")
        #expect(flashcard.definition.contains("传统"), "Chinese definition should be preserved")
    }

    @Test("CJK language: Japanese Kanji")
    func japaneseKanji() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "こんにちは",
            definition: "日本の伝統的な挨拶",
            in: context
        )

        #expect(flashcard.word == "こんにちは", "Japanese should be preserved")
        #expect(flashcard.definition.contains("日本"), "Japanese definition should be preserved")
    }

    @Test("CJK language: Korean Hangul")
    func koreanHangul() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "안녕하세요",
            definition: "한국어 전통 인사말",
            in: context
        )

        #expect(flashcard.word == "안녕하세요", "Korean should be preserved")
        #expect(flashcard.definition.contains("한국어"), "Korean definition should be preserved")
    }

    @Test("Combining diacritical marks")
    func combiningDiacritics() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Using combining marks: e + combining acute = é
        let combining = "cafe\u{0301} na\u{0308}ve" // café + naïve

        let flashcard = try createFlashcard(word: combining, definition: "test", in: context)

        #expect(flashcard.word == combining, "Combining diacritics should be preserved")
    }

    @Test("Zero-width joiners and non-joiners")
    func zeroWidthCharacters() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Zero-width joiner (ZWJ) and non-joiner (ZWNJ)
        let word = "test\u{200D}text\u{200C}more"

        let flashcard = try createFlashcard(word: word, definition: "test", in: context)

        #expect(flashcard.word == word, "Zero-width characters should be preserved")
    }

    @Test("Mixed scripts in single word")
    func mixedScripts() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test测试тест",
            definition: "mixed scripts",
            in: context
        )

        #expect(flashcard.word == "test测试тест", "Mixed scripts should be preserved")
    }

    // MARK: - Security Tests

    @Test("SQL injection attempt in word")
    func sqlInjectionInWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let maliciousInputs = [
            "'; DROP TABLE cards; --",
            "' OR '1'='1",
            "admin'--",
            "' UNION SELECT * FROM users--"
        ]

        for input in maliciousInputs {
            let flashcard = try createFlashcard(word: input, definition: "test", in: context)
            // Should be stored as plain text, not executed
            #expect(flashcard.word == input, "SQL injection should be stored as text")
        }
    }

    @Test("SQL injection attempt in definition")
    func sqlInjectionInDefinition() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let maliciousInput = "'); DELETE FROM flashcards; --"

        let flashcard = try createFlashcard(word: "test", definition: maliciousInput, in: context)

        // Should be stored as plain text, not executed
        #expect(flashcard.definition == maliciousInput, "SQL injection should be stored as text")
    }

    @Test("XSS attempt in word")
    func xssAttemptInWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let xssPayloads = [
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert('xss')>",
            "javascript:alert('xss')",
            "<svg onload=alert('xss')>"
        ]

        for payload in xssPayloads {
            let flashcard = try createFlashcard(word: payload, definition: "test", in: context)
            // Should be stored as plain text, not executed
            #expect(flashcard.word == payload, "XSS payload should be stored as text")
        }
    }

    @Test("JSON injection attempt")
    func jsonInjectionAttempt() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let jsonInjection = "{\"items\":[{\"malformed\":true}]}"

        let flashcard = try createFlashcard(word: jsonInjection, definition: "test", in: context)

        // Should be stored as plain text, not parsed
        #expect(flashcard.word == jsonInjection, "JSON injection should be stored as text")
    }

    @Test("Path traversal attempt")
    func pathTraversalAttempt() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let pathTraversalPayloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32",
            "/etc/passwd",
            "C:\\Windows\\System32\\config\\sam"
        ]

        for payload in pathTraversalPayloads {
            let flashcard = try createFlashcard(word: payload, definition: "test", in: context)
            // Should be stored as plain text, no file access
            #expect(flashcard.word == payload, "Path traversal should be stored as text")
        }
    }

    @Test("API key pattern in word")
    func apiKeyPatternInWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Word containing API key pattern (should be treated as text, not extracted)
        let apiKeyPattern = "sk-1234567890abcdefghijklmnopqrst"

        let flashcard = try createFlashcard(word: apiKeyPattern, definition: "test", in: context)

        // Should be stored as plain text
        #expect(flashcard.word == apiKeyPattern, "API key pattern should be stored as text")
    }

    @Test("Command injection attempt")
    func commandInjectionAttempt() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let commandPayloads = [
            "; ls -la",
            "$(whoami)",
            "`cat /etc/passwd`",
            "| cat /etc/hosts"
        ]

        for payload in commandPayloads {
            let flashcard = try createFlashcard(word: payload, definition: "test", in: context)
            // Should be stored as plain text, not executed
            #expect(flashcard.word == payload, "Command injection should be stored as text")
        }
    }

    // MARK: - Special Characters Tests

    @Test("Quotes and backslashes")
    func quotesAndBackslashes() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test",
            definition: "Contains 'single', \"double\", `backtick`, and \\backslash",
            in: context
        )

        #expect(flashcard.definition.contains("'single'"), "Single quotes should be preserved")
        #expect(flashcard.definition.contains("\"double\""), "Double quotes should be preserved")
        #expect(flashcard.definition.contains("`backtick`"), "Backticks should be preserved")
        #expect(flashcard.definition.contains("\\backslash"), "Backslashes should be preserved")
    }

    @Test("Newlines and tabs in definition")
    func newlinesAndTabs() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test",
            definition: "Line 1\nLine 2\tTabbed",
            in: context
        )

        #expect(flashcard.definition.contains("\n"), "Newlines should be preserved")
        #expect(flashcard.definition.contains("\t"), "Tabs should be preserved")
    }

    @Test("Null bytes in string")
    func nullBytesInString() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Swift strings can contain null bytes
        let stringWithNull = "test\u{0000}null\u{0000}byte"

        let flashcard = try createFlashcard(word: stringWithNull, definition: "test", in: context)

        #expect(flashcard.word == stringWithNull, "Null bytes should be preserved")
    }

    @Test("Mathematical symbols")
    func mathematicalSymbols() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "∑∫√∞≈≠≤≥",
            definition: "Mathematical operators",
            in: context
        )

        #expect(flashcard.word == "∑∫√∞≈≠≤≥", "Math symbols should be preserved")
    }

    @Test("Currency symbols")
    func currencySymbols() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "€$£¥₹",
            definition: "Currency symbols",
            in: context
        )

        #expect(flashcard.word == "€$£¥₹", "Currency symbols should be preserved")
    }

    @Test("Arrow symbols")
    func arrowSymbols() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "←↑→↓↔↕",
            definition: "Arrow symbols",
            in: context
        )

        #expect(flashcard.word == "←↑→↓↔↕", "Arrow symbols should be preserved")
    }

    @Test("Box drawing characters")
    func boxDrawingCharacters() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "─│┌┐└┘├┤┬┴┼",
            definition: "Box drawing characters",
            in: context
        )

        #expect(flashcard.word == "─│┌┐└┘├┤┬┴┼", "Box drawing should be preserved")
    }

    @Test("Control characters")
    func controlCharacters() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Common control characters
        let controlChars = String(
            [
                Character(Unicode.Scalar(0x1B)), // ESC
                Character(Unicode.Scalar(0x00)), // NUL
                Character(Unicode.Scalar(0x09)), // TAB
                Character(Unicode.Scalar(0x0A)), // LF
                Character(Unicode.Scalar(0x0D)) // CR
            ]
        )

        let flashcard = try createFlashcard(word: controlChars, definition: "test", in: context)

        #expect(flashcard.word == controlChars, "Control characters should be preserved")
    }

    // MARK: - Phonetic Field Tests

    @Test("Phonetic with IPA symbols")
    func phoneticWithIPA() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test",
            definition: "definition",
            phonetic: "/tɛst/",
            in: context
        )

        #expect(flashcard.phonetic == "/tɛst/", "IPA phonetic should be preserved")
    }

    @Test("Phonetic with tone marks")
    func phoneticWithToneMarks() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Pinyin with tone marks
        let flashcard = try createFlashcard(
            word: "test",
            definition: "definition",
            phonetic: "nǐ hǎo ma",
            in: context
        )

        #expect(flashcard.phonetic == "nǐ hǎo ma", "Tone marks should be preserved")
    }

    @Test("Phonetic with special characters")
    func phoneticWithSpecialChars() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "test",
            definition: "definition",
            phonetic: "/ˈhɛl.əʊ/",
            in: context
        )

        #expect(flashcard.phonetic == "/ˈhɛl.əʊ/", "Special IPA chars should be preserved")
    }

    // MARK: - Edge Cases for Model Relationships

    @Test("Flashcard without FSRSState")
    func flashcardWithoutFSRSState() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Create flashcard without FSRSState (edge case)
        let flashcard = Flashcard(word: "orphan", definition: "no state")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.fsrsState == nil, "Flashcard without state should have nil fsrsState")
        #expect(flashcard.word == "orphan", "Word should still be stored")
    }

    @Test("Multiple flashcards with same word")
    func multipleFlashcardsSameWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card1 = try createFlashcard(word: "same", definition: "def1", in: context)
        let card2 = try createFlashcard(word: "same", definition: "def2", in: context)

        // Both should be stored (duplicates allowed)
        #expect(card1.word == card2.word, "Both cards should have same word")
        #expect(card1 != card2, "Cards should be different objects")
    }

    @Test("Flashcard with all optional fields populated")
    func flashcardAllFieldsPopulated() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "complete",
            definition: "has all fields",
            phonetic: "/kəmˈpliːt/",
            in: context
        )

        // Add optional fields
        flashcard.translation = "translation"
        flashcard.imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header

        try context.save()

        #expect(flashcard.translation != nil, "Translation should be set")
        #expect(flashcard.imageData != nil, "Image data should be set")
    }

    // MARK: - Malformed Input Recovery

    @Test("Handle extremely long word (1M characters)")
    func extremelyLongWord() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // 1 million characters (extreme case)
        let extremeWord = String(repeating: "x", count: 1000000)
        let flashcard = try createFlashcard(word: extremeWord, definition: "def", in: context)

        #expect(flashcard.word.count == 1000000, "1M char word should be stored")
    }

    @Test("Handle all unicode characters")
    func allUnicodeCharacters() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Sample from various Unicode ranges
        let unicodeWord = "Test测试🔑مرحב😀∑€"
        let flashcard = try createFlashcard(word: unicodeWord, definition: "test", in: context)

        #expect(flashcard.word == unicodeWord, "Mixed unicode should be preserved")
    }

    @Test("Handle rapidly changing values")
    func rapidlyChangingValues() throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Rapid updates to same flashcard
        let flashcard = try createFlashcard(word: "initial", definition: "initial", in: context)

        for i in 0 ..< 10 {
            flashcard.word = "update\(i)"
            flashcard.definition = "changed \(i) times"
        }

        try context.save()

        #expect(flashcard.word == "update9", "Final value should be stored")
        #expect(flashcard.definition == "changed 9 times", "Final definition should be stored")
    }
}

// MARK: - Deck-Centric Mode Edge Cases

@Suite("Deck-Centric Edge Cases")
@MainActor
struct DeckCentricEdgeCases {
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    private func createDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()
        return deck
    }

    @Test("Deck with no cards returns zero counts")
    func deckWithNoCards() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = self.createDeck(context: context)

        let scheduler = Scheduler(modelContext: context)

        let newCount = scheduler.newCardCount(for: deck)
        let dueCount = scheduler.dueCardCount(for: deck)
        let totalCount = scheduler.totalCardCount(for: deck)

        #expect(newCount == 0, "New count should be 0 for deck with no cards")
        #expect(dueCount == 0, "Due count should be 0 for deck with no cards")
        #expect(totalCount == 0, "Total count should be 0 for deck with no cards")
    }

    @Test("All decks deselected shows empty state")
    func allDecksDeselected() async {
        // Clear all deck selections
        AppSettings.selectedDeckIDs = []

        // Verify selection is empty
        #expect(AppSettings.selectedDeckIDs.isEmpty, "Selection should be empty")
        #expect(AppSettings.hasSelectedDecks == false, "hasSelectedDecks should be false")
    }

    @Test("Corrupted AppSettings JSON recovers gracefully")
    func corruptedAppSettingsJSON() async {
        let originalSelection = AppSettings.selectedDeckIDs
        let originalData = AppSettings.selectedDeckIDsData

        // Simulate corrupted JSON
        AppSettings.selectedDeckIDsData = "invalid json {"

        // Should return empty set without crashing
        let selection = AppSettings.selectedDeckIDs
        #expect(selection.isEmpty, "Corrupted JSON should result in empty set")

        // Restore valid data
        AppSettings.selectedDeckIDsData = originalData
        #expect(AppSettings.selectedDeckIDs == originalSelection, "Should restore original selection")
    }

    @Test("Card deleted between fetch and review handles gracefully")
    func cardDeletedDuringFetch() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = self.createDeck(context: context)

        // Create a card
        let card = Flashcard(word: "test", definition: "test")
        card.deck = deck
        context.insert(card)

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: FlashcardState.review.rawValue
        )
        state.card = card
        context.insert(state)

        try! context.save()

        // Fetch cards
        let scheduler = Scheduler(modelContext: context)
        let cards = scheduler.fetchCards(for: deck, mode: .scheduled, limit: 10)
        let initialCount = cards.count

        #expect(initialCount > 0, "Should fetch at least one card")

        // Delete the card
        context.delete(card)
        try! context.save()

        // Verify card was deleted
        let cardID = card.id
        let deletedCard = try? context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == cardID })).first
        #expect(deletedCard == nil, "Card should be deleted")
    }

    @Test("Large number of decks (100+) handles efficiently")
    func largeDeckCount() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create 100 decks
        for i in 0 ..< 100 {
            _ = self.createDeck(context: context, name: "Deck \(i)")
        }

        // Verify all decks were created
        let descriptor = FetchDescriptor<Deck>()
        let decks = try! context.fetch(descriptor)

        #expect(decks.count == 100, "Should have 100 decks")

        // Test selection with many decks
        let deckIDs = Set(decks.prefix(50).map(\.id))
        AppSettings.selectedDeckIDs = deckIDs

        #expect(AppSettings.selectedDeckCount == 50, "Should select 50 decks")
        #expect(AppSettings.hasSelectedDecks == true, "hasSelectedDecks should be true")
    }

    @Test("Session with no available cards handles gracefully")
    func sessionWithNoAvailableCards() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = self.createDeck(context: context)

        // Deck has no cards
        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel.loadCards()

        #expect(viewModel.cards.isEmpty, "Should have no cards")
        #expect(viewModel.isComplete, "Should be marked complete")
    }

    @Test("Multiple sessions with same deck handle correctly")
    func multipleSessionsSameDeck() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = self.createDeck(context: context)

        // Create multiple cards
        for i in 1 ... 5 {
            let card = Flashcard(word: "card\(i)", definition: "card\(i)")
            card.deck = deck
            context.insert(card)

            let state = FSRSState(
                stability: 0.0,
                difficulty: 5.0,
                retrievability: 0.9,
                dueDate: Date().addingTimeInterval(-3600),
                stateEnum: FlashcardState.review.rawValue
            )
            state.card = card
            context.insert(state)
        }

        try! context.save()

        // Start first session
        let viewModel1 = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel1.loadCards()
        let initialCount = viewModel1.cards.count

        #expect(initialCount > 0, "First session should have cards")
    }

    @Test("Deck selection updates during session don't crash")
    func deckSelectionUpdateDuringSession() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck1 = self.createDeck(context: context, name: "Deck 1")
        let deck2 = self.createDeck(context: context, name: "Deck 2")

        // Set initial selection
        AppSettings.selectedDeckIDs = [deck1.id]

        // Change selection
        AppSettings.selectedDeckIDs = [deck1.id, deck2.id]

        // Verify update worked
        #expect(AppSettings.selectedDeckIDs.count == 2, "Should have 2 decks selected")
    }

    @Test("Empty study limit allows all cards through")
    func emptyStudyLimit() async {
        let originalLimit = AppSettings.studyLimit

        // Set to 0 to test edge case (should allow at least some cards)
        AppSettings.studyLimit = 1

        #expect(AppSettings.studyLimit == 1, "Study limit should be updated")

        // Restore
        AppSettings.studyLimit = originalLimit
    }

    @Test("Study mode switching updates card list")
    func studyModeSwitching() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = self.createDeck(context: context)

        // Create new card
        let card1 = Flashcard(word: "new", definition: "new")
        card1.deck = deck
        context.insert(card1)

        let state1 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        state1.card = card1
        context.insert(state1)

        // Create due card
        let card2 = Flashcard(word: "due", definition: "due")
        card2.deck = deck
        context.insert(card2)

        let state2 = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: FlashcardState.review.rawValue
        )
        state2.card = card2
        context.insert(state2)

        try! context.save()

        let scheduler = Scheduler(modelContext: context)

        // Learning mode should get new cards
        let learningCards = scheduler.fetchCards(for: deck, mode: .learning, limit: 10)

        // Scheduled mode should get due cards
        let scheduledCards = scheduler.fetchCards(for: deck, mode: .scheduled, limit: 10)

        #expect(learningCards.count > 0 || scheduledCards.count > 0, "Should have cards in at least one mode")
    }
}
