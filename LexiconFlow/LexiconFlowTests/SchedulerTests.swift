//
//  SchedulerTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for Scheduler and study modes
//  Covers: due card fetching, cram mode, review processing, queries
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for Scheduler class
///
/// Tests the main scheduler API including:
/// - Due card queries
/// - Cram mode behavior
/// - Review processing with FSRS
/// - Study mode differences
@MainActor
struct SchedulerTests {

    // MARK: - Test Fixtures

    /// Create a test ModelContainer with in-memory storage
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// Create a test deck
    private func createTestDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "📚")
        context.insert(deck)
        try! context.save()
        return deck
    }

    /// Create a test flashcard with specified parameters
    private func createTestFlashcard(
        context: ModelContext,
        word: String = UUID().uuidString,
        state: FlashcardState = .new,
        dueOffset: TimeInterval = 0,
        stability: Double = 0.0,
        difficulty: Double = 5.0
    ) -> Flashcard {
        let flashcard = Flashcard(
            word: word,
            definition: "Test definition",
            phonetic: "tɛst"
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
        context.insert(flashcard)
        try! context.save()
        return flashcard
    }

    // MARK: - Due Card Query Tests

    @Test("Fetch due cards returns only cards with due date in past")
    func fetchDueCardsOnlyDue() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 3 cards: due, not due, due
        _ = createTestFlashcard(context: context, word: "due1", dueOffset: -3600) // 1 hour ago
        _ = createTestFlashcard(context: context, word: "future", dueOffset: 3600) // 1 hour future
        _ = createTestFlashcard(context: context, word: "due2", dueOffset: -7200) // 2 hours ago

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        #expect(dueCards.count == 2)
        #expect(dueCards.allSatisfy { $0.word.contains("due") })
    }

    @Test("Fetch due cards excludes new cards")
    func fetchDueCardsExcludesNew() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create new card (due in past but state = new)
        _ = createTestFlashcard(context: context, word: "new", state: .new, dueOffset: -3600)
        // Create review card (due in past and state = review)
        _ = createTestFlashcard(context: context, word: "review", state: .review, dueOffset: -3600)

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        #expect(dueCards.count == 1)
        #expect(dueCards.first?.word == "review")
    }

    @Test("Fetch due cards respects limit parameter")
    func fetchDueCardsLimit() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 5 due cards
        for i in 1...5 {
            _ = createTestFlashcard(
                context: context,
                word: "card\(i)",
                state: .review,
                dueOffset: -Double(i * 3600)
            )
        }

        let cards3 = scheduler.fetchCards(mode: .scheduled, limit: 3)
        let cards10 = scheduler.fetchCards(mode: .scheduled, limit: 10)

        #expect(cards3.count == 3)
        #expect(cards10.count == 5) // Only 5 exist
    }

    @Test("Fetch due cards sorts by due date ascending")
    func fetchDueCardsSorting() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different due dates
        let due1 = createTestFlashcard(context: context, word: "middle", state: .review, dueOffset: -3600)
        let due2 = createTestFlashcard(context: context, word: "latest", state: .review, dueOffset: -1800)
        let due3 = createTestFlashcard(context: context, word: "earliest", state: .review, dueOffset: -7200)

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        #expect(dueCards.count == 3)
        // Should be sorted: earliest, middle, latest
        #expect(dueCards[0].word == "earliest")
        #expect(dueCards[1].word == "middle")
        #expect(dueCards[2].word == "latest")
    }

    @Test("Due card count returns accurate number")
    func dueCardCountAccuracy() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 5 due cards
        for i in 1...5 {
            _ = createTestFlashcard(context: context, word: "due\(i)", state: .review, dueOffset: -3600)
        }

        // Create 2 non-due cards
        _ = createTestFlashcard(context: context, word: "future1", state: .review, dueOffset: 3600)
        _ = createTestFlashcard(context: context, word: "new1", state: .new, dueOffset: -3600)

        let count = scheduler.dueCardCount()

        #expect(count == 5)
    }

    // MARK: - Cram Mode Tests

    @Test("Cram mode ignores due dates")
    func cramModeIgnoresDueDates() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different due dates and stability
        _ = createTestFlashcard(context: context, word: "low_stability", state: .review, dueOffset: 3600, stability: 1.0)
        _ = createTestFlashcard(context: context, word: "high_stability", state: .review, dueOffset: -3600, stability: 20.0)

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        // Both should be fetched regardless of due date
        #expect(cramCards.count == 2)
    }

    @Test("Cram mode excludes new cards")
    func cramModeExcludesNew() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create review card
        _ = createTestFlashcard(context: context, word: "review", state: .review, stability: 5.0)
        // Create new card
        _ = createTestFlashcard(context: context, word: "new", state: .new, stability: 1.0)

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        #expect(cramCards.count == 1)
        #expect(cramCards.first?.word == "review")
    }

    @Test("Cram mode sorts by stability ascending")
    func cramModeStabilitySorting() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different stability values
        _ = createTestFlashcard(context: context, word: "high", state: .review, stability: 20.0)
        _ = createTestFlashcard(context: context, word: "low", state: .review, stability: 2.0)
        _ = createTestFlashcard(context: context, word: "mid", state: .review, stability: 10.0)

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        #expect(cramCards.count == 3)
        // Should be sorted: low, mid, high (by stability)
        #expect(cramCards[0].word == "low")
        #expect(cramCards[1].word == "mid")
        #expect(cramCards[2].word == "high")
    }

    // MARK: - Review Processing Tests

    @Test("Process review in scheduled mode updates FSRS state")
    func scheduledModeUpdatesState() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        let initialStability = flashcard.fsrsState!.stability

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 2, // Good
            mode: .scheduled
        )

        // FSRS state should be updated
        #expect(flashcard.fsrsState?.stability != initialStability)
        #expect(flashcard.fsrsState!.dueDate > Date())
    }

    @Test("Process review in scheduled mode creates review log")
    func scheduledModeCreatesLog() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        let initialLogCount = flashcard.reviewLogs.count

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 2,
            mode: .scheduled
        )

        #expect(flashcard.reviewLogs.count == initialLogCount + 1)

        let newLog = flashcard.reviewLogs.last
        #expect(newLog?.rating == 2)
        #expect(newLog?.scheduledDays ?? 0 > 0)
    }

    @Test("Process review in cram mode does not update FSRS state")
    func cramModeNoStateUpdate() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        let initialStability = flashcard.fsrsState!.stability
        let initialDifficulty = flashcard.fsrsState!.difficulty
        let initialDue = flashcard.fsrsState!.dueDate

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 2,
            mode: .cram
        )

        // FSRS state should NOT change
        #expect(flashcard.fsrsState?.stability == initialStability)
        #expect(flashcard.fsrsState?.difficulty == initialDifficulty)
        #expect(flashcard.fsrsState?.dueDate == initialDue)
    }

    @Test("Process review in cram mode still creates log")
    func cramModeCreatesLog() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        let initialLogCount = flashcard.reviewLogs.count

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 1, // Hard
            mode: .cram
        )

        #expect(flashcard.reviewLogs.count == initialLogCount + 1)

        let newLog = flashcard.reviewLogs.last
        #expect(newLog?.rating == 1)
        #expect(newLog?.scheduledDays == 0) // Cram mode doesn't schedule
    }

    @Test("Process review handles all four ratings")
    func processReviewAllRatings() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        for rating in 0...3 {
            let flashcard = createTestFlashcard(context: context, state: .review)
            let initialLogCount = flashcard.reviewLogs.count

            let result = await scheduler.processReview(
                flashcard: flashcard,
                rating: rating,
                mode: .scheduled
            )

            // All ratings should succeed
            #expect(flashcard.reviewLogs.count == initialLogCount + 1)
            #expect(result != nil)
            #expect(result?.rating == rating)
        }
    }

    // MARK: - Preview Tests

    @Test("Preview ratings returns all four options")
    func previewRatings() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        let previews = await scheduler.previewRatings(for: flashcard)

        #expect(previews.count == 4)
        #expect(previews[0] != nil)
        #expect(previews[1] != nil)
        #expect(previews[2] != nil)
        #expect(previews[3] != nil)
    }

    @Test("Preview due dates are in future")
    func previewDatesInFuture() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        let now = Date()

        let previews = await scheduler.previewRatings(for: flashcard)

        for (rating, dueDate) in previews {
            #expect(dueDate > now, "Rating \(rating) should schedule future date")
        }
    }

    // MARK: - Reset Tests

    @Test("Reset flashcard returns to new state")
    func resetFlashcard() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        // Set to review with high stability
        flashcard.fsrsState!.stability = 50.0
        flashcard.fsrsState!.difficulty = 8.0
        try! context.save()

        await scheduler.resetFlashcard(flashcard)

        #expect(flashcard.fsrsState!.stateEnum == FlashcardState.new.rawValue)
        #expect(flashcard.fsrsState!.dueDate <= Date())
    }

    // MARK: - Edge Case Tests

    @Test("Empty database returns empty arrays")
    func emptyDatabase() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        let dueCards = scheduler.fetchCards(mode: .scheduled)
        let cramCards = scheduler.fetchCards(mode: .cram)
        let count = scheduler.dueCardCount()

        #expect(dueCards.isEmpty)
        #expect(cramCards.isEmpty)
        #expect(count == 0)
    }

    @Test("Processing review without FSRS state creates state")
    func processReviewWithoutState() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create flashcard without FSRS state
        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)
        try! context.save()

        #expect(flashcard.fsrsState == nil)

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 2,
            mode: .scheduled
        )

        // State should be created
        #expect(flashcard.fsrsState != nil)
    }

    @Test("Concurrent review processing is serialized")
    func concurrentReviews() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 10 cards
        var cards: [Flashcard] = []
        for i in 1...10 {
            let card = createTestFlashcard(context: context, word: "card\(i)", state: .review)
            cards.append(card)
        }

        // Process all concurrently
        await withTaskGroup(of: Void.self) { group in
            for card in cards {
                group.addTask {
                    _ = await scheduler.processReview(
                        flashcard: card,
                        rating: 2,
                        mode: .scheduled
                    )
                }
            }
        }

        // All should have been processed
        let totalCount = cards.reduce(0) { $0 + $1.reviewLogs.count }
        #expect(totalCount == 10)
    }
}
