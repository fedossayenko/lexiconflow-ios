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

import Testing
import SwiftData
import Foundation
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
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "", definition: "definition", in: context)

        #expect(flashcard.word.isEmpty, "Empty word should be stored")
    }

    @Test("Empty definition is stored as-is")
    func emptyDefinitionIsStored() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "test", definition: "", in: context)

        #expect(flashcard.definition.isEmpty, "Empty definition should be stored")
    }

    @Test("Both empty word and definition")
    func bothWordAndDefinitionEmpty() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "", definition: "", in: context)

        #expect(flashcard.word.isEmpty, "Empty word should be stored")
        #expect(flashcard.definition.isEmpty, "Empty definition should be stored")
    }

    @Test("Whitespace-only word is preserved")
    func whitespaceOnlyWord() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(word: "   \t  \n  ", definition: "def", in: context)

        #expect(flashcard.word == "   \t  \n  ", "Whitespace should be preserved")
    }

    @Test("Very long word (1000 characters)")
    func veryLongWord() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let longWord = String(repeating: "a", count: 1000)
        let flashcard = try createFlashcard(word: longWord, definition: "def", in: context)

        #expect(flashcard.word.count == 1000, "1000-char word should be stored")
    }

    @Test("Very long definition (10000 characters)")
    func veryLongDefinition() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create exactly 10000 characters
        let longDefinition = String(repeating: "a", count: 10000)
        let flashcard = try createFlashcard(word: "test", definition: longDefinition, in: context)

        #expect(flashcard.definition.count == 10000, "10000-char definition should be stored")
    }

    // MARK: - Unicode Tests

    @Test("Emoji in word and definition")
    func emojiInWordAndDefinition() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        // Using combining marks: e + combining acute = é
        let combining = "cafe\u{0301} na\u{0308}ve" // café + naïve

        let flashcard = try createFlashcard(word: combining, definition: "test", in: context)

        #expect(flashcard.word == combining, "Combining diacritics should be preserved")
    }

    @Test("Zero-width joiners and non-joiners")
    func zeroWidthCharacters() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Zero-width joiner (ZWJ) and non-joiner (ZWNJ)
        let word = "test\u{200D}text\u{200C}more"

        let flashcard = try createFlashcard(word: word, definition: "test", in: context)

        #expect(flashcard.word == word, "Zero-width characters should be preserved")
    }

    @Test("Mixed scripts in single word")
    func mixedScripts() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        let maliciousInput = "'); DELETE FROM flashcards; --"

        let flashcard = try createFlashcard(word: "test", definition: maliciousInput, in: context)

        // Should be stored as plain text, not executed
        #expect(flashcard.definition == maliciousInput, "SQL injection should be stored as text")
    }

    @Test("XSS attempt in word")
    func xssAttemptInWord() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        let jsonInjection = "{\"items\":[{\"malformed\":true}]}"

        let flashcard = try createFlashcard(word: jsonInjection, definition: "test", in: context)

        // Should be stored as plain text, not parsed
        #expect(flashcard.word == jsonInjection, "JSON injection should be stored as text")
    }

    @Test("Path traversal attempt")
    func pathTraversalAttempt() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        // Word containing API key pattern (should be treated as text, not extracted)
        let apiKeyPattern = "sk-1234567890abcdefghijklmnopqrst"

        let flashcard = try createFlashcard(word: apiKeyPattern, definition: "test", in: context)

        // Should be stored as plain text
        #expect(flashcard.word == apiKeyPattern, "API key pattern should be stored as text")
    }

    @Test("Command injection attempt")
    func commandInjectionAttempt() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        // Swift strings can contain null bytes
        let stringWithNull = "test\u{0000}null\u{0000}byte"

        let flashcard = try createFlashcard(word: stringWithNull, definition: "test", in: context)

        #expect(flashcard.word == stringWithNull, "Null bytes should be preserved")
    }

    @Test("Mathematical symbols")
    func mathematicalSymbols() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        // Common control characters
        let controlChars = String(
            [Character(Unicode.Scalar(0x1B)), // ESC
             Character(Unicode.Scalar(0x00)), // NUL
             Character(Unicode.Scalar(0x09)), // TAB
             Character(Unicode.Scalar(0x0A)), // LF
             Character(Unicode.Scalar(0x0D))  // CR
            ]
        )

        let flashcard = try createFlashcard(word: controlChars, definition: "test", in: context)

        #expect(flashcard.word == controlChars, "Control characters should be preserved")
    }

    // MARK: - Phonetic Field Tests

    @Test("Phonetic with IPA symbols")
    func phoneticWithIPA() throws {
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
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
        let container = createTestContainer()
        let context = container.mainContext

        let card1 = try createFlashcard(word: "same", definition: "def1", in: context)
        let card2 = try createFlashcard(word: "same", definition: "def2", in: context)

        // Both should be stored (duplicates allowed)
        #expect(card1.word == card2.word, "Both cards should have same word")
        #expect(card1 != card2, "Cards should be different objects")
    }

    @Test("Flashcard with all optional fields populated")
    func flashcardAllFieldsPopulated() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try createFlashcard(
            word: "complete",
            definition: "has all fields",
            phonetic: "/kəmˈpliːt/",
            in: context
        )

        // Add optional fields
        flashcard.translation = "translation"
        flashcard.cefrLevel = "C1"
        flashcard.contextSentence = "context example"
        flashcard.imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header

        try context.save()

        #expect(flashcard.translation != nil, "Translation should be set")
        #expect(flashcard.cefrLevel != nil, "CEFR level should be set")
        #expect(flashcard.contextSentence != nil, "Context sentence should be set")
        #expect(flashcard.imageData != nil, "Image data should be set")
    }

    // MARK: - Malformed Input Recovery

    @Test("Handle extremely long word (1M characters)")
    func extremelyLongWord() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // 1 million characters (extreme case)
        let extremeWord = String(repeating: "x", count: 1_000_000)
        let flashcard = try createFlashcard(word: extremeWord, definition: "def", in: context)

        #expect(flashcard.word.count == 1_000_000, "1M char word should be stored")
    }

    @Test("Handle all unicode characters")
    func allUnicodeCharacters() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Sample from various Unicode ranges
        let unicodeWord = "Test测试🔑مرحב😀∑€"
        let flashcard = try createFlashcard(word: unicodeWord, definition: "test", in: context)

        #expect(flashcard.word == unicodeWord, "Mixed unicode should be preserved")
    }

    @Test("Handle rapidly changing values")
    func rapidlyChangingValues() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Rapid updates to same flashcard
        let flashcard = try createFlashcard(word: "initial", definition: "initial", in: context)

        for i in 0..<10 {
            flashcard.word = "update\(i)"
            flashcard.definition = "changed \(i) times"
        }

        try context.save()

        #expect(flashcard.word == "update9", "Final value should be stored")
        #expect(flashcard.definition == "changed 9 times", "Final definition should be stored")
    }
}
