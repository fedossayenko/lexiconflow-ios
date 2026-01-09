//
//  FoundationModelsService.swift
//  LexiconFlow
//
//  On-device AI sentence generation using Apple's Foundation Models framework
//  Provides private, offline-capable sentence generation for vocabulary cards
//

import Foundation
import OSLog

// MARK: - FoundationModelsError

/// Errors that can occur during Foundation Models operations
enum FoundationModelsError: LocalizedError, Sendable {
    case notAvailable
    case sessionNotInitialized
    case languageNotSupported(String)
    case generationFailed(underlying: String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Foundation Models are not available on this device"
        case .sessionNotInitialized:
            "Foundation Models session not initialized"
        case let .languageNotSupported(language):
            "Language '\(language)' is not supported by Foundation Models"
        case let .generationFailed(message):
            "Failed to generate sentence: \(message)"
        case let .invalidInput(message):
            "Invalid input: \(message)"
        }
    }

    var failureReason: String? {
        switch self {
        case .notAvailable:
            "Device doesn't support Foundation Models (requires iOS 26+)"
        case .sessionNotInitialized:
            "Session must be initialized before generating sentences"
        case .languageNotSupported:
            "Foundation Models framework doesn't support this language"
        case .generationFailed:
            "Underlying framework error during sentence generation"
        case .invalidInput:
            "Input validation failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            "Ensure you're running iOS 26 or later on a compatible device"
        case .sessionNotInitialized:
            "Call initialize() before using generation methods"
        case .languageNotSupported:
            "Use a supported language (en, es, fr, de, etc.) or fall back to cloud API"
        case .generationFailed:
            "Try again. If the problem persists, use cloud API as fallback"
        case .invalidInput:
            "Check your input parameters and try again"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notAvailable, .sessionNotInitialized, .languageNotSupported, .invalidInput:
            false
        case .generationFailed:
            true
        }
    }
}

/// On-device AI sentence generation using Apple's Foundation Models framework
///
/// **Features:**
/// - Private, on-device processing (no cloud connection)
/// - Offline-capable after initialization
/// - Supports multiple languages
/// - Graceful fallback to cloud API when unavailable
///
/// **Architecture:**
/// - Actor-isolated for thread safety
/// - Singleton pattern for shared instance
/// - Lazy session initialization
/// - Comprehensive error handling
///
/// **Example:**
/// ```swift
/// let service = FoundationModelsService.shared
///
/// // Initialize (checks availability)
/// if await service.isAvailable() {
///     do {
///         let sentence = try await service.generateSentence(
///             for: "hello",
///             cefrLevel: "A1"
///         )
///         print("Generated: \(sentence)")
///     } catch {
///         // Handle error or fall back to cloud API
///     }
/// }
/// ```
final actor FoundationModelsService {
    // MARK: - Singleton

    static let shared = FoundationModelsService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.lexiconflow.ai", category: "FoundationModelsService")

    /// Foundation Models session (lazily initialized)
    private var session: Any?

    /// Supported languages for sentence generation
    private let supportedLanguages: Set<String> = [
        "en", // English
        "es", // Spanish
        "fr", // French
        "de", // German
        "it", // Italian
        "pt", // Portuguese
        "ru", // Russian
        "ja", // Japanese
        "ko", // Korean
        "zh-Hans", // Chinese Simplified
        "zh-Hant", // Chinese Traditional
        "ar", // Arabic
        "hi" // Hindi
    ]

    // MARK: - Initialization

    private init() {
        self.logger.info("FoundationModelsService initialized")
    }

    // MARK: - Availability

    /// Check if Foundation Models are available on this device
    ///
    /// **Requirements:**
    /// - iOS 26.0 or later
    /// - Compatible device (Apple Silicon or recent iPhone)
    /// - Foundation Models framework present
    ///
    /// - Returns: `true` if Foundation Models are available for use
    func isAvailable() -> Bool {
        // Check for Foundation Models framework availability at runtime
        // This is a placeholder - actual implementation would use NSClassFromString
        // or check for specific Foundation Models APIs

        // For now, return false since Foundation Models requires iOS 26
        // and we need to verify framework availability
        #if arch(arm64)
            if #available(iOS 26.0, *) {
                // Check if Foundation Models framework is available
                let actorClass = object_getClass(self)
                let className = actorClass.map { NSStringFromClass($0) } ?? "Unknown"
                self.logger.debug("Checking Foundation Models availability on iOS 26+ (actor: \(className))")
                // TODO: Implement actual availability check using LanguageModelSession availability
                // This requires the Foundation Models framework to be linked
                return false // Will be updated when framework is integrated
            } else {
                self.logger.debug("Foundation Models not available: iOS < 26.0")
                return false
            }
        #else
            self.logger.debug("Foundation Models not available: non-arm64 architecture")
            return false
        #endif
    }

    /// Validate that a specific language is supported
    ///
    /// - Parameter language: ISO 639-1 language code (e.g., "en", "es")
    /// - Throws: `FoundationModelsError.languageNotSupported` if language is not supported
    func validateLanguageAvailability(_ language: String) async throws {
        guard self.supportedLanguages.contains(language) else {
            self.logger.error("Language '\(language)' not supported by Foundation Models")
            throw FoundationModelsError.languageNotSupported(language)
        }
        self.logger.debug("Language '\(language)' is supported")
    }

    // MARK: - Session Management

    /// Initialize the Foundation Models session
    ///
    /// **Preconditions:**
    /// - Device must support Foundation Models
    /// - App must have necessary permissions
    ///
    /// **Throws:**
    /// - `FoundationModelsError.notAvailable` if device doesn't support Foundation Models
    /// - `FoundationModelsError.generationFailed` if session initialization fails
    func initialize() async throws {
        guard self.isAvailable() else {
            self.logger.error("Cannot initialize: Foundation Models not available")
            throw FoundationModelsError.notAvailable
        }

        // TODO: Initialize actual LanguageModelSession
        // This is a placeholder for when Foundation Models framework is integrated
        self.logger.info("Foundation Models session initialization (placeholder)")

        // Example of what actual implementation would look like:
        // self.session = try await LanguageModelSession()
        // logger.info("Foundation Models session initialized successfully")
    }

    /// Ensure the session is initialized before use
    ///
    /// - Throws: `FoundationModelsError.sessionNotInitialized` if session is not ready
    private func ensureSessionInitialized() throws {
        guard self.session != nil else {
            self.logger.error("Session not initialized")
            throw FoundationModelsError.sessionNotInitialized
        }
    }

    // MARK: - Sentence Generation

    /// Generate a single context sentence for a vocabulary word
    ///
    /// **Parameters:**
    ///   - word: The vocabulary word to generate a sentence for
    ///   - cefrLevel: Target CEFR level (A1, A2, B1, B2, C1, C2)
    ///   - language: ISO 639-1 language code (default: "en")
    ///
    /// **Returns: A generated sentence appropriate for the target CEFR level**
    ///
    /// **Throws:**
    ///   - `FoundationModelsError.sessionNotInitialized` if session not ready
    ///   - `FoundationModelsError.languageNotSupported` if language unavailable
    ///   - `FoundationModelsError.invalidInput` if word is empty
    ///   - `FoundationModelsError.generationFailed` if generation fails
    ///
    /// **Example:**
    /// ```swift
    /// let sentence = try await service.generateSentence(
    ///     for: "abandon",
    ///     cefrLevel: "B1"
    /// )
    /// // Returns: "She had to abandon her car in the flood."
    /// ```
    func generateSentence(
        for word: String,
        cefrLevel: String,
        language: String = "en"
    ) async throws -> String {
        // Validate input
        guard !word.isEmpty else {
            self.logger.error("Cannot generate sentence for empty word")
            throw FoundationModelsError.invalidInput("Word cannot be empty")
        }

        // Validate language support
        try await self.validateLanguageAvailability(language)

        // Ensure session is ready
        try self.ensureSessionInitialized()

        self.logger.info("Generating sentence for '\(word)' at \(cefrLevel) level in \(language)")

        // TODO: Implement actual Foundation Models generation
        // This is a placeholder that returns a static sentence
        // When Foundation Models framework is integrated, this would use:
        // let prompt = constructPrompt(for: word, cefrLevel: cefrLevel, language: language)
        // let result = try await session.generate(prompt: prompt)
        // return result

        // Placeholder implementation
        let placeholderSentence = "This is a placeholder sentence for '\(word)' at \(cefrLevel) level."
        self.logger.debug("Generated placeholder sentence: \(placeholderSentence)")

        return placeholderSentence
    }

    /// Generate multiple sentences for a vocabulary word
    ///
    /// **Parameters:**
    ///   - word: The vocabulary word to generate sentences for
    ///   - cefrLevel: Target CEFR level (A1, A2, B1, B2, C1, C2)
    ///   - count: Number of sentences to generate (default: 3, range: 1-5)
    ///   - language: ISO 639-1 language code (default: "en")
    ///
    /// **Returns: Array of generated sentences appropriate for the target CEFR level**
    ///
    /// **Throws:**
    ///   - `FoundationModelsError.invalidInput` if count is out of range
    ///   - Other errors from `generateSentence(for:cefrLevel:language:)`
    ///
    /// **Example:**
    /// ```swift
    /// let sentences = try await service.generateSentences(
    ///     for: "abandon",
    ///     cefrLevel: "B1",
    ///     count: 3
    /// )
    /// // Returns: ["She had to abandon...", "The project was...", ...]
    /// ```
    func generateSentences(
        for word: String,
        cefrLevel: String,
        count: Int = 3,
        language: String = "en"
    ) async throws -> [String] {
        // Validate count
        guard (1 ... 5).contains(count) else {
            self.logger.error("Invalid count: \(count). Must be between 1 and 5.")
            throw FoundationModelsError.invalidInput("Count must be between 1 and 5, got \(count)")
        }

        self.logger.info("Generating \(count) sentences for '\(word)' at \(cefrLevel) level")

        var sentences: [String] = []
        sentences.reserveCapacity(count)

        // Generate sentences sequentially (could be parallelized if performance is needed)
        for index in 0 ..< count {
            do {
                let sentence = try await generateSentence(
                    for: word,
                    cefrLevel: cefrLevel,
                    language: language
                )
                sentences.append(sentence)
                self.logger.debug("Generated sentence \(index + 1)/\(count)")
            } catch {
                self.logger.error("Failed to generate sentence \(index + 1)/\(count): \(error)")
                throw error
            }
        }

        self.logger.info("Successfully generated \(sentences.count) sentences for '\(word)'")
        return sentences
    }

    // MARK: - Prompt Construction

    /// Construct a prompt for sentence generation
    ///
    /// **Parameters:**
    ///   - word: The vocabulary word
    ///   - cefrLevel: Target CEFR level
    ///   - language: Target language
    ///
    /// **Returns: A formatted prompt string for the Foundation Models API**
    private func constructPrompt(
        for word: String,
        cefrLevel: String,
        language _: String
    ) -> String {
        // Construct a prompt that guides the model to generate appropriate sentences
        // This follows best practices for prompt engineering with Foundation Models

        let prompt = """
        Generate a single, natural English sentence using the word "\(word)" appropriate for \(cefrLevel) level learners.

        Requirements:
        - Use the word "\(word)" in a natural context
        - Keep sentence complexity appropriate for \(cefrLevel) level
        - Avoid archaic or highly technical usage
        - Make the sentence clear and educational
        - Return only the sentence, no explanations

        Example output format:
        The word "abandon" at B1 level: "She had to abandon her car in the flood."
        """

        return prompt
    }

    /// Get the full language name from ISO code
    ///
    /// - Parameter code: ISO 639-1 language code
    /// - Returns: Full language name in English
    private func languageName(for code: String) -> String {
        let names: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "ja": "Japanese",
            "ko": "Korean",
            "zh-Hans": "Simplified Chinese",
            "zh-Hant": "Traditional Chinese",
            "ar": "Arabic",
            "hi": "Hindi"
        ]
        return names[code] ?? code
    }

    // MARK: - Static Fallback Sentences

    /// Provide static fallback sentences for offline/error scenarios
    ///
    /// **Use Case:** When Foundation Models are unavailable or fail,
    /// these provide basic examples to prevent app from being non-functional
    ///
    /// **Parameters:**
    ///   - word: The vocabulary word
    ///   - cefrLevel: Target CEFR level
    ///
    /// **Returns: A generic sentence template using the word**
    nonisolated static func fallbackSentence(for word: String, cefrLevel: String) -> String {
        // These are generic templates that work for most words
        // They're not ideal but prevent the app from being completely non-functional

        let templates: [String: [String]] = [
            "A1": [
                "This is a sentence with the word '\(word)'.",
                "I learn the word '\(word)'.",
                "The word '\(word)' is important."
            ],
            "A2": [
                "I want to learn more about the word '\(word)'.",
                "The word '\(word)' can be used in many ways.",
                "She studied the word '\(word)' for her test."
            ],
            "B1": [
                "Using the word '\(word)' correctly is important for communication.",
                "The meaning of '\(word)' becomes clearer with practice.",
                "He encountered the word '\(word)' while reading the article."
            ],
            "B2": [
                "The word '\(word)' has several nuances depending on context.",
                "Understanding '\(word)' requires knowledge of its usage patterns.",
                "She demonstrated proper use of '\(word)' in her presentation."
            ],
            "C1": [
                "The word '\(word)' exemplifies complex linguistic principles.",
                "Mastery of '\(word)' distinguishes advanced learners from intermediates.",
                "The etymology of '\(word)' reveals interesting historical patterns."
            ],
            "C2": [
                "The word '\(word)' embodies sophisticated semantic subtleties.",
                "Nuanced understanding of '\(word)' requires extensive contextual exposure.",
                "The pragmatic implications of '\(word)' vary across discourse communities."
            ]
        ]

        // Get templates for CEFR level, default to B1 if unknown
        let levelTemplates = templates[cefrLevel.uppercased()] ?? templates["B1"] ?? []

        // Return a random template from the appropriate level
        return levelTemplates.randomElement() ?? "This is a sentence with the word '\(word)'."
    }
}
