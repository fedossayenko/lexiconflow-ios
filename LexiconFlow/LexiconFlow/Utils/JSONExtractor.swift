//
//  JSONExtractor.swift
//  LexiconFlow
//
//  Utility for extracting JSON from AI responses
//  Handles markdown code blocks and brace delimiters
//

import Foundation
import OSLog

/// Utility for extracting JSON from AI-generated text
///
/// AI responses often wrap JSON in markdown code blocks or include extra text.
/// This utility extracts clean JSON from various response formats.
enum JSONExtractor {

    /// Extract JSON from text, handling markdown code blocks and brace delimiters
    ///
    /// - Parameters:
    ///   - text: The text to extract JSON from (typically an AI response)
    ///   - logger: Logger instance for debug output
    ///
    /// - Returns: Clean JSON string, or original text if no patterns matched
    ///
    /// **Extraction Order:**
    /// 1. ````json` code blocks - preferred format
    /// 2. ````` code blocks - generic markdown
    /// 3. `{` to `}` brace delimiters - fallback for unstructured text
    /// 4. Original text - if no patterns matched
    ///
    /// **Example:**
    /// ```swift
    /// let aiResponse = """
    /// Here's your translation:
    /// ```json
    /// {"word": "hello", "translation": "привет"}
    /// ```
    /// """
    ///
    /// let clean = JSONExtractor.extract(from: aiResponse, logger: logger)
    /// // Result: {"word": "hello", "translation": "привет"}
    /// ```
    static func extract(from text: String, logger: Logger) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try ```json code blocks (preferred format)
        if let jsonStart = trimmed.range(of: "```json", options: .caseInsensitive) {
            let afterStart = jsonStart.upperBound
            if let jsonEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<jsonEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Extracted JSON from markdown code block (```json)")
                return json
            }
        }

        // Try ``` code blocks (without json specifier)
        if let codeStart = trimmed.range(of: "```", options: .caseInsensitive) {
            let afterStart = codeStart.upperBound
            if let codeEnd = trimmed.range(of: "```", range: afterStart..<trimmed.endIndex) {
                let json = String(trimmed[afterStart..<codeEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Extracted JSON from generic code block (```)")
                return json
            }
        }

        // Try { to } brace delimiters (fallback for unstructured text)
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            let json = String(trimmed[firstBrace...lastBrace])
            logger.debug("Extracted JSON from brace delimiters ({...})")
            return json
        }

        // Return original if no JSON patterns matched
        logger.debug("No JSON extraction patterns matched, using original text")
        return trimmed
    }
}
