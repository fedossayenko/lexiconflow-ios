//
//  ReverseCardService.swift
//  LexiconFlow
//
//  Service for generating reverse (Production) cards from existing flashcards
//

import OSLog
import SwiftData
import SwiftUI

/// Service for generating reverse (Production) cards for bidirectional learning
///
/// **Pedagogical Basis:**
/// - Recognition (Forward cards): Builds receptive vocabulary (reading, listening)
/// - Production (Reverse cards): Builds productive vocabulary (speaking, writing)
/// - Research: Palmberg (2016), Nation (2001), Webb (2008)
///
/// **Usage:**
/// ```swift
/// let count = try ReverseCardService.shared.generateReverseCards(
///     for: flashcards,
///     context: modelContext
/// )
/// print("Generated \(count) reverse cards")
/// ```
///
/// **Thread Safety:** Service runs on @MainActor to safely mutate SwiftData models.
/// ModelContext must remain on @MainActor per SwiftData thread safety requirements.
@MainActor
final class ReverseCardService {
    /// Singleton instance
    static let shared = ReverseCardService()

    /// Logger for diagnostics
    private let logger = Logger(subsystem: "com.lexiconflow.reversecards", category: "ReverseCardService")

    /// Private initializer for singleton
    private init() {}

    // MARK: - Public API

    /// Generate reverse cards for the given flashcards
    ///
    /// **Process:**
    /// 1. Filters out flashcards without translations (cannot create reverse cards)
    /// 2. Checks if reverse card already exists (same deck, same word, reverse type)
    /// 3. Creates new reverse cards for eligible flashcards
    ///
    /// **Parameters:**
    ///   - flashcards: Array of flashcards to generate reverse cards for
    ///   - context: SwiftData ModelContext for persistence
    ///
    /// **Returns:** Number of reverse cards generated
    ///
    /// **Throws:** SwiftData persistence errors
    func generateReverseCards(
        for flashcards: [Flashcard],
        context: ModelContext
    ) throws -> Int {
        self.logger.info("Starting reverse card generation for \(flashcards.count) flashcards")

        // Filter flashcards that have translations (required for reverse cards)
        let eligibleFlashcards = flashcards.filter { $0.translation != nil }
        self.logger.debug("Found \(eligibleFlashcards.count) flashcards with translations")

        if eligibleFlashcards.isEmpty {
            self.logger.info("No eligible flashcards for reverse card generation")
            return 0
        }

        var generatedCount = 0

        for flashcard in eligibleFlashcards {
            // Skip if already has a reverse card
            if try self.hasReverseCard(for: flashcard, context: context) {
                self.logger.debug("Reverse card already exists for '\(flashcard.word)'")
                continue
            }

            // Create reverse card
            guard let reverseCard = createReverseCard(from: flashcard, context: context) else {
                self.logger.warning("Failed to create reverse card for '\(flashcard.word)'")
                continue
            }
            context.insert(reverseCard)
            generatedCount += 1
            self.logger.debug("Generated reverse card for '\(flashcard.word)'")
        }

        // Save all changes
        try context.save()
        self.logger.info("Successfully generated \(generatedCount) reverse cards")

        return generatedCount
    }

    /// Check if a reverse card already exists for the given flashcard
    ///
    /// **Parameters:**
    ///   - flashcard: The original flashcard to check
    ///   - context: SwiftData ModelContext for querying
    ///
    /// **Returns:** True if a reverse card already exists
    func hasReverseCard(
        for flashcard: Flashcard,
        context: ModelContext
    ) throws -> Bool {
        // Only flashcards with translations can have reverse cards
        guard let translation = flashcard.translation else {
            return false
        }

        // Query for existing reverse card
        // Criteria: Same deck, same word (as translation), reverse type
        // Note: Use string literal instead of CardType.reverse.rawValue to avoid SwiftData key path issues
        let predicate = #Predicate<Flashcard> { card in
            card.cardTypeRaw == "reverse" &&
                card.word == translation &&
                card.translation != nil
        }

        let descriptor = FetchDescriptor<Flashcard>(
            predicate: predicate
        )

        let existingReverseCards = try context.fetch(descriptor)
        return !existingReverseCards.isEmpty
    }

    // MARK: - Private Helpers

    /// Create a reverse card from an existing flashcard
    ///
    /// **Mapping:**
    /// - Forward word → Reverse translation
    /// - Forward translation → Reverse word
    /// - Forward definition → Reverse definition
    /// - Forward phonetic → Not copied (Russian phonetics not available)
    /// - Forward image → Copied (visual learning works for both directions)
    /// - Forward CEFR level → Copied (difficulty remains the same)
    ///
    /// **Parameters:**
    ///   - flashcard: The original forward flashcard
    ///   - context: SwiftData ModelContext
    ///
    /// **Returns:** New reverse flashcard, or nil if flashcard has no translation
    private func createReverseCard(
        from flashcard: Flashcard,
        context _: ModelContext
    ) -> Flashcard? {
        // Validate required fields
        guard let translation = flashcard.translation else {
            self.logger.error("Cannot create reverse card: flashcard '\(flashcard.word)' has no translation")
            return nil
        }

        // Create reverse card
        let reverseCard = Flashcard(
            word: flashcard.word, // Keep English word
            definition: flashcard.definition, // Keep English definition
            translation: translation, // Russian translation (was original)
            phonetic: nil, // No phonetic for reverse (Russian)
            imageData: flashcard.imageData, // Copy image (visual learning)
            createdAt: Date()
        )

        // Set card type to reverse
        reverseCard.cardTypeRaw = CardType.reverse.rawValue

        // Copy CEFR level
        reverseCard.cefrLevel = flashcard.cefrLevel

        // Assign to same deck (if any)
        reverseCard.deck = flashcard.deck

        self.logger.debug("Created reverse card for '\(flashcard.word)' → '\(translation)'")

        return reverseCard
    }
}
