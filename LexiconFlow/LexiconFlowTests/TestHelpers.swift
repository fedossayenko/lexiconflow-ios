//
//  TestHelpers.swift
//  LexiconFlowTests
//
//  Shared testing utilities and fixtures for all test suites
//
//  IMPORTANT: Tests must run with serialized execution when using shared container
//  Run tests with: -parallel-testing-enabled NO
//

import SwiftData
import Testing
import Foundation
@testable import LexiconFlow

// MARK: - ModelContext Extension

/// Extension to provide fast test isolation without recreating containers
extension ModelContext {
    /// Clears all entities from the context without recreating container
    /// This is much faster than creating a new ModelContainer for each test
    func clearAll() throws {
        // First, fetch and delete all existing entities to properly clear this context's cache
        let reviews = try self.fetch(FetchDescriptor<FlashcardReview>())
        for review in reviews {
            self.delete(review)
        }

        let states = try self.fetch(FetchDescriptor<FSRSState>())
        for state in states {
            self.delete(state)
        }

        let cards = try self.fetch(FetchDescriptor<Flashcard>())
        for card in cards {
            self.delete(card)
        }

        let decks = try self.fetch(FetchDescriptor<Deck>())
        for deck in decks {
            self.delete(deck)
        }

        try self.save()
    }
}

// MARK: - Test Containers

/// Shared container for all tests to reduce ModelContainer creation overhead
enum TestContainers {
    /// Shared in-memory container used across all test suites
    /// Creating containers is expensive (~50-100ms each), so we reuse one
    static let shared: ModelContainer = {
        let schema = Schema([
            Flashcard.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fallback: create empty container if schema fails
            // This allows tests to run with minimal functionality instead of crashing
            let fallbackContainer = ModelContainer(for: [])
            print("⚠️ WARNING: Test container creation failed, using empty fallback: \(error)")
            return fallbackContainer
        }
    }()

    /// Creates a fresh context for a test
    /// Caller should call clearAll() before use to ensure isolation
    static func freshContext() -> ModelContext {
        return ModelContext(shared)
    }
}

// MARK: - Test Fixtures

/// Factory methods for creating test data
///
/// Provides centralized fixture creation to eliminate duplicate code
/// across test suites. All fixtures are pre-configured with sensible defaults.
enum TestFixtures {

    // MARK: - Flashcard Fixtures

    /// Create a test flashcard with default values
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert the flashcard into
    ///   - word: The word (default: random UUID)
    ///   - definition: The definition (default: "Test definition")
    ///   - phonetic: The phonetic pronunciation (default: nil)
    ///   - state: FSRS state (default: .new)
    ///   - dueOffset: Offset from now for due date (default: 0)
    ///   - stability: FSRS stability (default: 0.0)
    ///   - difficulty: FSRS difficulty (default: 5.0)
    ///   - save: Whether to save to context (default: true)
    ///
    /// - Returns: Configured Flashcard instance
    ///
    /// **Usage:**
    /// ```swift
    /// let card = TestFixtures.createFlashcard(context: context, word: "test")
    /// #expect(card.word == "test")
    /// ```
    static func createFlashcard(
        context: ModelContext,
        word: String = UUID().uuidString,
        definition: String = "Test definition",
        phonetic: String? = nil,
        state: FlashcardState = .new,
        dueOffset: TimeInterval = 0,
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        save: Bool = true
    ) -> Flashcard {
        let flashcard = Flashcard(
            word: word,
            definition: definition,
            phonetic: phonetic
        )

        let fsrsState = FSRSState(
            stability: stability,
            difficulty: difficulty,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(dueOffset),
            stateEnum: state.rawValue
        )
        context.insert(fsrsState)
        flashcard.fsrsState = fsrsState

        if save {
            context.insert(flashcard)
        }

        return flashcard
    }

    /// Create multiple test flashcards
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert flashcards into
    ///   - count: Number of flashcards to create
    ///   - state: FSRS state for all cards (default: .new)
    ///   - dueOffset: Offset for due dates (default: 0)
    ///
    /// - Returns: Array of created Flashcard instances
    static func createFlashcards(
        context: ModelContext,
        count: Int,
        state: FlashcardState = .new,
        dueOffset: TimeInterval = 0
    ) -> [Flashcard] {
        return (0..<count).map { index in
            createFlashcard(
                context: context,
                word: "word_\(index)_\(UUID().uuidString)",
                definition: "Definition \(index)",
                state: state,
                dueOffset: dueOffset
            )
        }
    }

    /// Create flashcard with specific due date
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - word: The word
    ///   - dueDate: Specific due date
    ///
    /// - Returns: Configured Flashcard with due date in past/future
    static func createFlashcard(
        context: ModelContext,
        word: String,
        dueDate: Date
    ) -> Flashcard {
        let flashcard = Flashcard(word: word, definition: "Test")

        let fsrsState = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: dueDate,
            stateEnum: FlashcardState.review.rawValue
        )
        context.insert(fsrsState)
        flashcard.fsrsState = fsrsState
        context.insert(flashcard)

        return flashcard
    }

    // MARK: - Deck Fixtures

    /// Create a test deck
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert deck into
    ///   - name: Deck name (default: "Test Deck")
    ///   - icon: Deck icon (default: "📚")
    ///   - save: Whether to save to context (default: true)
    ///
    /// - Returns: Configured Deck instance
    static func createDeck(
        context: ModelContext,
        name: String = "Test Deck",
        icon: String = "📚",
        save: Bool = true
    ) -> Deck {
        let deck = Deck(name: name, icon: icon)

        if save {
            context.insert(deck)
        }

        return deck
    }

    /// Create deck with cards
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - cardCount: Number of cards to add to deck
    ///   - state: FSRS state for cards (default: .new)
    ///
    /// - Returns: Tuple of (Deck, [Flashcard])
    static func createDeckWithCards(
        context: ModelContext,
        cardCount: Int,
        state: FlashcardState = .new
    ) -> (Deck, [Flashcard]) {
        let deck = createDeck(context: context)

        let cards = (0..<cardCount).map { index in
            let card = createFlashcard(
                context: context,
                word: "deck_card_\(index)",
                definition: "Card \(index) in deck",
                state: state
            )
            card.deck = deck
            return card
        }

        try? context.save()

        return (deck, cards)
    }

    // MARK: - Review Log Fixtures

    /// Create a test review log
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - card: Flashcard to associate review with
    ///   - rating: Review rating (0-3)
    ///   - scheduledDays: Days until next review
    ///   - elapsedDays: Days since last review
    ///
    /// - Returns: Configured FlashcardReview instance
    static func createReviewLog(
        context: ModelContext,
        card: Flashcard,
        rating: Int = 2,
        scheduledDays: Double = 1.0,
        elapsedDays: Double = 0.0
    ) -> FlashcardReview {
        let review = FlashcardReview(
            rating: rating,
            reviewDate: Date(),
            scheduledDays: scheduledDays,
            elapsedDays: elapsedDays
        )
        review.card = card
        context.insert(review)

        return review
    }

    /// Create multiple review logs for a card
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - card: Flashcard to associate reviews with
    ///   - count: Number of reviews to create
    ///   - ratings: Array of ratings (one per review)
    ///
    /// - Returns: Array of created FlashcardReview instances
    static func createReviewLogs(
        context: ModelContext,
        card: Flashcard,
        count: Int,
        ratings: [Int]? = nil
    ) -> [FlashcardReview] {
        let defaultRatings = Array(repeating: 2, count: count)
        let actualRatings = ratings ?? defaultRatings

        return actualRatings.enumerated().map { index, rating in
            createReviewLog(
                context: context,
                card: card,
                rating: rating,
                scheduledDays: Double(index + 1),
                elapsedDays: Double(index)
            )
        }
    }

    // MARK: - Specialized Fixtures

    /// Create a flashcard ready for review (due in past)
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - word: The word
    ///
    /// - Returns: Flashcard with due date 1 hour in past
    static func createDueFlashcard(
        context: ModelContext,
        word: String = "due_card"
    ) -> Flashcard {
        return createFlashcard(
            context: context,
            word: word,
            state: .review,
            dueOffset: -3600  // 1 hour ago
        )
    }

    /// Create a flashcard due in future
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - word: The word
    ///
    /// - Returns: Flashcard with due date 1 hour in future
    static func createFutureFlashcard(
        context: ModelContext,
        word: String = "future_card"
    ) -> Flashcard {
        return createFlashcard(
            context: context,
            word: word,
            state: .review,
            dueOffset: 3600  // 1 hour in future
        )
    }

    /// Create a new flashcard (not yet reviewed)
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - word: The word
    ///
    /// - Returns: Flashcard with state=new, due=now
    static func createNewFlashcard(
        context: ModelContext,
        word: String = "new_card"
    ) -> Flashcard {
        return createFlashcard(
            context: context,
            word: word,
            state: .new,
            dueOffset: 0
        )
    }

    // MARK: - Batch Creation Helpers

    /// Create a batch of due cards for testing
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - count: Number of due cards
    ///
    /// - Returns: Array of due Flashcard instances
    static func createDueCards(context: ModelContext, count: Int) -> [Flashcard] {
        return (0..<count).map { index in
            createFlashcard(
                context: context,
                word: "due_\(index)",
                state: .review,
                dueOffset: -Double((index + 1) * 3600)  // 1, 2, 3... hours ago
            )
        }
    }

    /// Create cards with varying stability for cram mode testing
    ///
    /// - Parameters:
    ///   - context: ModelContext to insert into
    ///   - stabilities: Array of stability values
    ///
    /// - Returns: Array of Flashcard instances with specified stabilities
    static func createCardsWithStabilities(
        context: ModelContext,
        stabilities: [Double]
    ) -> [Flashcard] {
        return stabilities.enumerated().map { index, stability in
            createFlashcard(
                context: context,
                word: "stability_\(stability)_\(index)",
                state: .review,
                stability: stability
            )
        }
    }
}

// MARK: - Test Context Helpers

/// Convenience methods for setting up test contexts
enum TestContext {
    /// Create a fresh context with cleared data
    static func clean() -> ModelContext {
        let context = TestContainers.freshContext()
        try? context.clearAll()
        return context
    }

    /// Create context with specified number of flashcards
    static func withFlashcards(count: Int) -> ModelContext {
        let context = clean()
        _ = TestFixtures.createFlashcards(context: context, count: count)
        return context
    }

    /// Create context with specified number of due cards
    static func withDueCards(count: Int) -> ModelContext {
        let context = clean()
        _ = TestFixtures.createDueCards(context: context, count: count)
        return context
    }
}
