//
//  JSONExtractorTests.swift
//  LexiconFlowTests
//
//  Tests for JSON extraction utility
//

import Testing
import Foundation
import OSLog
@testable import LexiconFlow

/// Test suite for JSONExtractor
///
/// Tests verify:
/// - Extraction from ```json code blocks
/// - Extraction from generic ``` code blocks
/// - Extraction from brace delimiters
/// - Handling of malformed input
/// - Preservation of original text when no patterns match
struct JSONExtractorTests {

    let logger = Logger(subsystem: "com.lexiconflow.test", category: "JSONExtractorTests")

    // MARK: - Markdown Code Block Tests

    @Test("Extract JSON from ```json code block")
    func extractFromJsonCodeBlock() {
        let input = """
        Here's your translation:
        ```json
        {"word": "hello", "translation": "привет"}
        ```
        Hope this helps!
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"word\": \"hello\", \"translation\": \"привет\"}", "Should extract JSON from ```json block")
    }

    @Test("Extract JSON from ```json code block with whitespace")
    func extractFromJsonCodeBlockWithWhitespace() {
        let input = """
        ```json

        {"word": "hello"}

        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"word\": \"hello\"}", "Should trim whitespace from extracted JSON")
    }

    @Test("Extract JSON from ```json with case insensitive match")
    func extractFromJsonCodeBlockCaseInsensitive() {
        let input = """
        ```JSON
        {"word": "test"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"word\": \"test\"}", "Should match ```JSON case-insensitively")
    }

    @Test("Extract JSON from generic ``` code block")
    func extractFromGenericCodeBlock() {
        let input = """
        Here's the data:
        ```
        {"word": "hello", "translation": "привет"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"word\": \"hello\", \"translation\": \"привет\"}", "Should extract from generic ``` block")
    }

    @Test("Prefer ```json over generic ``` block")
    func preferJsonBlockOverGeneric() {
        let input = """
        ```
        {"first": "value1"}
        ```
        ```json
        {"second": "value2"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"second\": \"value2\""), "Should prefer ```json block")
    }

    // MARK: - Brace Delimiter Tests

    @Test("Extract JSON from brace delimiters")
    func extractFromBraceDelimiters() {
        let input = "Some text here {\"word\": \"hello\"} and more text"

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"word\": \"hello\"}", "Should extract from brace delimiters")
    }

    @Test("Extract JSON from nested braces")
    func extractFromNestedBraces() {
        let input = "Prefix text {\"outer\": {\"inner\": \"value\"}} suffix"

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"outer\": {\"inner\": \"value\"}}", "Should extract outermost braces")
    }

    @Test("Extract JSON with array in braces")
    func extractFromArrayInBraces() {
        let input = "Text {\"items\": [1, 2, 3]} more text"

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "{\"items\": [1, 2, 3]}", "Should extract JSON with arrays")
    }

    // MARK: - Fallback Tests

    @Test("Return original text when no patterns match")
    func returnOriginalWhenNoMatch() {
        let input = "Just plain text without any JSON"

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result == "Just plain text without any JSON", "Should return original text")
    }

    @Test("Handle empty string")
    func handleEmptyString() {
        let result = JSONExtractor.extract(from: "", logger: logger)

        #expect(result == "", "Should handle empty string")
    }

    @Test("Handle whitespace only")
    func handleWhitespaceOnly() {
        let result = JSONExtractor.extract(from: "   \n\t   ", logger: logger)

        #expect(result.isEmpty, "Should trim to empty string")
    }

    // MARK: - Complex Scenarios

    @Test("Extract JSON with special characters")
    func extractJsonWithSpecialCharacters() {
        let input = """
        ```json
        {"emoji": "🎉", "newline": "line1\\nline2", "quote": "test \"quote\""}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"emoji\": \"🎉\""), "Should preserve emoji")
        #expect(result.contains("\"newline\": \"line1\\nline2\""), "Should preserve escape sequences")
        #expect(result.contains("\"quote\": \"test \\\"quote\\\"\""), "Should preserve escaped quotes")
    }

    @Test("Extract JSON with unicode characters")
    func extractJsonWithUnicode() {
        let input = """
        ```json
        {"russian": "Привет", "japanese": "こんにちは", "chinese": "你好"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"russian\": \"Привет\""), "Should preserve Cyrillic")
        #expect(result.contains("\"japanese\": \"こんにちは\""), "Should preserve Hiragana")
        #expect(result.contains("\"chinese\": \"你好\""), "Should preserve Chinese characters")
    }

    @Test("Extract complex nested JSON")
    func extractComplexNestedJson() {
        let input = """
        ```json
        {
            "user": {
                "name": "Test User",
                "profile": {
                    "age": 25,
                    "city": "Tokyo"
                }
            },
            "tags": ["learning", "vocab"]
        }
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"name\": \"Test User\""), "Should extract nested objects")
        #expect(result.contains("\"tags\": [\"learning\", \"vocab\"]"), "Should extract arrays")
    }

    @Test("Extract JSON from multiline response")
    func extractFromMultilineResponse() {
        let input = """
        I've generated the translation for you:

        ```json
        {
            "word": "ephemeral",
            "translation": "мимолетный",
            "context": "short-lived"
        }
        ```

        Let me know if you need anything else!
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"word\": \"ephemeral\""), "Should extract from multiline response")
        #expect(result.contains("\"translation\": \"мимолетный\""), "Should preserve all fields")
    }

    // MARK: - Edge Cases

    @Test("Handle unclosed code block")
    func handleUnclosedCodeBlock() {
        let input = """
        ```json
        {"word": "test"}
        No closing backticks
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        // Should fall back to brace extraction
        #expect(result.contains("\"word\": \"test\""), "Should fall back to brace extraction")
    }

    @Test("Handle code block with language specifier only")
    func handleCodeBlockWithLanguageOnly() {
        let input = """
        ```python
        {"word": "test"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        // Generic ``` block should still extract
        #expect(result == "{\"word\": \"test\"}", "Should extract from any ``` block")
    }

    @Test("Handle multiple code blocks")
    func handleMultipleCodeBlocks() {
        let input = """
        ```json
        {"first": "value1"}
        ```
        Some text
        ```
        {"second": "value2"}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        // Should extract first ```json block found
        #expect(result.contains("\"first\": \"value1\""), "Should extract first JSON block")
    }

    @Test("Handle JSON with trailing commas")
    func handleJsonWithTrailingCommas() {
        let input = """
        ```json
        {"word": "test", "items": [1, 2, 3,],}
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        // Extractor returns raw JSON, validation happens later
        #expect(result.contains("\"word\": \"test\""), "Should extract JSON with trailing comma")
    }

    @Test("Handle malformed JSON")
    func handleMalformedJson() {
        let input = """
        ```json
        {"word": "test", "incomplete":
        ```
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        // Extractor returns what it finds, validation happens during JSON decoding
        #expect(result.contains("\"word\": \"test\""), "Should extract even if malformed")
    }

    // MARK: - Real-World Scenarios

    @Test("Extract from typical AI translation response")
    func extractFromTranslationResponse() {
        let input = """
        Here's the translation you requested:

        ```json
        {
            "word": "epiphany",
            "translation": "озарение",
            "partOfSpeech": "noun",
            "examples": [
                "She had an epiphany about her career.",
                "It was a moment of epiphany."
            ]
        }
        ```

        This word comes from Greek and means a sudden realization.
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"word\": \"epiphany\""), "Should extract word field")
        #expect(result.contains("\"translation\": \"озарение\""), "Should extract translation")
        #expect(result.contains("\"examples\""), "Should extract examples array")
    }

    @Test("Extract from AI sentence generation response")
    func extractFromSentenceGeneration() {
        let input = """
        Here are 3 example sentences for "ephemeral":

        ```json
        {
            "sentences": [
                {
                    "text": "The ephemeral beauty of sunset colors fades quickly.",
                    "cefrLevel": "B2"
                },
                {
                    "text": "Fame can be ephemeral in the entertainment industry.",
                    "cefrLevel": "C1"
                }
            ]
        }
        ```

        Hope these help with your vocabulary learning!
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"sentences\""), "Should extract sentences array")
        #expect(result.contains("\"cefrLevel\": \"B2\""), "Should extract nested fields")
    }

    @Test("Extract from offline fallback response")
    func extractFromOfflineResponse() {
        let input = """
        You're offline, so here's a static example:

        ```json
        {"text": "The ephemeral joy of childhood memories.", "cefrLevel": "B2", "source": "static"}
        ```

        Connect to the internet for AI-generated examples.
        """

        let result = JSONExtractor.extract(from: input, logger: logger)

        #expect(result.contains("\"text\": \"The ephemeral joy"), "Should extract offline sentence")
        #expect(result.contains("\"source\": \"static\""), "Should extract source field")
    }

    // MARK: - Performance Tests

    @Test("Handle large JSON efficiently")
    func handleLargeJson() {
        var items: [String] = []
        for i in 0..<100 {
            items.append("{\"id\": \(i), \"value\": \"item_\(i)\"}")
        }

        let largeJson = "{\"items\": [\(items.joined(separator: ","))]}"

        let input = """
        ```json
        \(largeJson)
        ```
        """

        let start = Date()
        let result = JSONExtractor.extract(from: input, logger: logger)
        let duration = Date().timeIntervalSince(start)

        #expect(result.contains("\"items\": ["), "Should extract large JSON")
        #expect(duration < 0.1, "Should complete extraction quickly")
    }

    @Test("Handle response with multiple code blocks efficiently")
    func handleMultipleBlocksEfficiently() {
        var blocks: [String] = []
        for i in 0..<50 {
            blocks += ["```json", "{\"block\": \(i)}", "```"]
        }

        let input = blocks.joined(separator: "\n")

        let start = Date()
        let result = JSONExtractor.extract(from: input, logger: logger)
        let duration = Date().timeIntervalSince(start)

        #expect(result.contains("\"block\":"), "Should extract from first block")
        #expect(duration < 0.1, "Should handle multiple blocks efficiently")
    }
}
