//
//  PerformanceTestDataGenerator.swift
//  LexiconFlow
//
//  Utility for generating test data for performance testing
//  Creates 50+ cards with glass effects for scrolling performance verification
//

import Foundation
import SwiftData
import OSLog

/// Utility for generating performance test data
///
/// **Usage**:
/// ```swift
/// let generator = PerformanceTestDataGenerator(modelContext: context)
/// let deck = try await generator.createPerformanceTestDeck(cardCount: 50)
/// ```
@MainActor
final class PerformanceTestDataGenerator {
    private static let logger = Logger(subsystem: "com.lexiconflow.performance", category: "TestDataGenerator")

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Test Data Generation

    /// Creates a performance test deck with specified number of cards
    ///
    /// **Performance Testing**: Use this to generate 50+ cards for testing scroll performance
    /// with glass effects. Glass effects use `.drawingGroup()` which promotes rendering to Metal
    /// for smooth 120fps animations on ProMotion displays.
    ///
    /// **Testing Procedure**:
    /// 1. Generate test deck with 50+ cards
    /// 2. Navigate to DeckDetailView and scroll through all cards
    /// 3. Verify scrolling is smooth (no visible lag or stuttering)
    /// 4. Check that glass effects render correctly on all cards
    ///
    /// - Parameters:
    ///   - cardCount: Number of cards to generate (default: 50)
    ///   - deckName: Name for the test deck (default: "Performance Test Deck")
    /// - Returns: The created deck with cards
    /// - Throws: SwiftData save errors
    func createPerformanceTestDeck(
        cardCount: Int = 50,
        deckName: String = "Performance Test Deck"
    ) throws -> Deck {
        Self.logger.info("Creating performance test deck with \(cardCount) cards")

        // Create deck
        let deck = Deck(
            name: deckName,
            icon: "speedometer",
            order: 999  // Place at bottom of list
        )
        modelContext.insert(deck)

        // Generate cards
        let cards = generatePerformanceTestCards(count: cardCount)

        // Insert cards with FSRS state
        for cardData in cards {
            let flashcard = Flashcard(
                word: cardData.word,
                definition: cardData.definition,
                phonetic: cardData.phonetic,
                imageData: nil  // No images for performance testing
            )

            // Associate with deck
            flashcard.deck = deck

            // Create FSRS state
            let state = FSRSState(
                stability: 0,
                difficulty: 5,
                retrievability: 0.9,
                dueDate: Date(),
                stateEnum: FlashcardState.new.rawValue
            )
            modelContext.insert(state)
            flashcard.fsrsState = state

            modelContext.insert(flashcard)
        }

        // Save all changes
        try modelContext.save()

        Self.logger.info("✅ Successfully created performance test deck with \(cardCount) cards")

        return deck
    }

    /// Creates multiple performance test decks with varying card counts
    ///
    /// **Stress Testing**: Creates decks with different sizes to test performance scaling:
    /// - Small deck: 10 cards (baseline)
    /// - Medium deck: 50 cards (target)
    /// - Large deck: 100 cards (stress test)
    ///
    /// - Parameter cardCounts: Array of card counts for each deck
    /// - Returns: Array of created decks
    /// - Throws: SwiftData save errors
    func createMultiplePerformanceTestDecks(
        cardCounts: [Int] = [10, 50, 100]
    ) throws -> [Deck] {
        var decks: [Deck] = []

        for (index, count) in cardCounts.enumerated() {
            let deck = try createPerformanceTestDeck(
                cardCount: count,
                deckName: "Performance Test \(count) Cards"
            )
            decks.append(deck)

            Self.logger.info("Created deck \(index + 1)/\(cardCounts.count) with \(count) cards")
        }

        return decks
    }

    /// Clears all performance test data from the database
    ///
    /// **Cleanup**: Removes all decks with "Performance Test" in the name
    /// and their associated cards and FSRS states.
    ///
    /// - Throws: SwiftData fetch/delete errors
    func clearPerformanceTestData() throws {
        Self.logger.info("Clearing performance test data")

        // Fetch all decks with "Performance Test" in name
        let descriptor = FetchDescriptor<Deck>()
        let allDecks = try modelContext.fetch(descriptor)

        let testDecks = allDecks.filter { $0.name.contains("Performance Test") }

        for deck in testDecks {
            // Delete deck (cascade deletes cards and FSRS states)
            modelContext.delete(deck)
            Self.logger.info("Deleted test deck: \(deck.name)")
        }

        try modelContext.save()

        Self.logger.info("✅ Cleared \(testDecks.count) performance test decks")
    }

    // MARK: - Test Data Generation Helpers

    /// Generates performance test card data
    ///
    /// **Data Quality**: Uses diverse vocabulary words to simulate real-world usage.
    /// Words are sourced from academic English to provide meaningful test content.
    ///
    /// - Parameter count: Number of cards to generate
    /// - Returns: Array of flashcard data
    private func generatePerformanceTestCards(count: Int) -> [FlashcardData] {
        // Academic vocabulary for realistic test data
        let vocabularyWords = [
            ("Aberration", "A departure from what is normal or expected"),
            ("Benevolent", "Well-meaning and kindly"),
            ("Cacophony", "A harsh, discordant mixture of sounds"),
            ("Dichotomy", "A division into two contrasting things"),
            ("Ephemeral", "Lasting for a very short time"),
            ("Fortuitous", "Happening by chance or accident"),
            ("Gregarious", "Fond of company; sociable"),
            ("Hyperbolic", "Exaggerated remarks or claims"),
            ("Iconoclast", "A person who attacks cherished beliefs"),
            ("Juxtaposition", "Placing things close together for contrasting effect"),
            ("Kinetic", "Relating to motion and energy"),
            ("Luminous", "Full of or shedding light"),
            ("Meticulous", "Showing great attention to detail"),
            ("Nebulous", "Vague or ill-defined"),
            ("Obfuscate", "Render obscure or unclear"),
            ("Pragmatic", "Dealing with things practically rather than ideologically"),
            ("Quintessential", "Representing the perfect example of a quality"),
            ("Recalcitrant", "Having an obstinately uncooperative attitude"),
            ("Serenity", "Calmness and peace of mind"),
            ("Tangible", "Perceptible by touch"),
            ("Ubiquitous", "Present everywhere at the same time"),
            ("Vicarious", "Experienced through another person"),
            ("Wanderlust", "Strong desire to travel"),
            ("Xenophile", "Attracted to foreign peoples or cultures"),
            ("Yield", "Produce or provide"),
            ("Zenith", "The highest point or peak"),
            ("Ambivalent", "Having mixed feelings about something"),
            ("Brevity", "Concise and exact use of words"),
            ("Coherent", "Logical and consistent"),
            ("Diligent", "Hardworking and conscientious"),
            ("Eloquent", "Fluent and persuasive in speaking"),
            ("Empathy", "Ability to understand others' feelings"),
            ("Frugal", "Sparing or economical with money"),
            ("Genuine", "Truly what something appears to be"),
            ("Harmony", "Agreement or concord"),
            ("Integrity", "Quality of being honest and moral"),
            ("Judicious", "Having good sense and judgment"),
            ("Keen", "Having or showing eagerness"),
            ("Lucid", "Clear and easy to understand"),
            ("Modest", "Unassuming or moderate in estimation"),
            ("Novel", "New or unusual"),
            ("Optimistic", "Hopeful and confident about the future"),
            ("Pragmatic", "Dealing with things sensibly"),
            ("Resilient", "Able to recover quickly from difficulties"),
            ("Sincere", "Free from pretense or deceit"),
            ("Tenacious", "Holding firmly to something"),
            ("Unique", "Being the only one of its kind"),
            ("Versatile", "Able to adapt to many functions"),
            ("Wisdom", "Quality of having experience and knowledge"),
            ("Yearning", "Feeling of intense longing"),
            ("Zealous", "Having great energy or enthusiasm"),
            ("Aesthetic", "Concerned with beauty or art"),
            ("Buoyant", "Cheerful and optimistic"),
            ("Candid", "Truthful and straightforward"),
            ("Dynamic", "Characterized by constant change"),
            ("Empower", "Give someone power or confidence")
        ]

        var cards: [FlashcardData] = []

        for i in 0..<count {
            let wordIndex = i % vocabularyWords.count
            let (word, definition) = vocabularyWords[wordIndex]

            // Add number to duplicate words to ensure uniqueness
            let uniqueWord = count > vocabularyWords.count
                ? "\(word) \(i / vocabularyWords.count + 1)"
                : word

            let card = FlashcardData(
                word: uniqueWord,
                definition: definition,
                phonetic: "/\(uniqueWord.lowercased())/",
                imageData: nil
            )

            cards.append(card)
        }

        return cards
    }
}

// MARK: - Supporting Types

/// Flashcard data for test generation
private struct FlashcardData {
    let word: String
    let definition: String
    let phonetic: String?
    let imageData: Data?
}
