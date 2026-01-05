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

    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    /// Create a test deck (does NOT save - caller must save)
    private func createTestDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "📚")
        context.insert(deck)
        return deck
    }

    /// Create a test flashcard with specified parameters (does NOT save - caller must save)
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
        return flashcard
    }

    // MARK: - Due Card Query Tests

    @Test("Fetch due cards returns only cards with due date in past")
    func fetchDueCardsOnlyDue() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 cards: due, not due, due (specify review state for due cards)
        _ = createTestFlashcard(context: context, word: "due1", state: .review, dueOffset: -3600) // 1 hour ago
        _ = createTestFlashcard(context: context, word: "future", state: .review, dueOffset: 3600) // 1 hour future
        _ = createTestFlashcard(context: context, word: "due2", state: .review, dueOffset: -7200) // 2 hours ago
        try context.save()

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        #expect(dueCards.count == 2)
        #expect(dueCards.allSatisfy { $0.word.contains("due") })
    }

    @Test("Fetch due cards excludes new cards")
    func fetchDueCardsExcludesNew() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create new card (due now, state = new)
        _ = createTestFlashcard(context: context, word: "new", state: .new, dueOffset: 0)
        // Create review card (due in past and state = review)
        _ = createTestFlashcard(context: context, word: "review", state: .review, dueOffset: -3600)
        // Create future card (not due yet)
        _ = createTestFlashcard(context: context, word: "future", state: .review, dueOffset: 3600)
        try context.save()

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        // Only review cards are due (new cards are excluded)
        #expect(dueCards.count == 1)
        #expect(!dueCards.contains { $0.word == "new" })
        #expect(dueCards.contains { $0.word == "review" })
        #expect(!dueCards.contains { $0.word == "future" })
    }

    @Test("Fetch due cards respects limit parameter")
    func fetchDueCardsLimit() async throws {
        let context = freshContext()
        try context.clearAll()
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
        try context.save()

        let cards3 = scheduler.fetchCards(mode: .scheduled, limit: 3)
        let cards10 = scheduler.fetchCards(mode: .scheduled, limit: 10)

        #expect(cards3.count == 3)
        #expect(cards10.count == 5) // Only 5 exist
    }

    @Test("Fetch due cards sorts by due date ascending")
    func fetchDueCardsSorting() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different due dates
        let due1 = createTestFlashcard(context: context, word: "middle", state: .review, dueOffset: -3600)
        let due2 = createTestFlashcard(context: context, word: "latest", state: .review, dueOffset: -1800)
        let due3 = createTestFlashcard(context: context, word: "earliest", state: .review, dueOffset: -7200)
        try context.save()

        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)

        #expect(dueCards.count == 3)
        // Should be sorted: earliest, middle, latest
        #expect(dueCards[0].word == "earliest")
        #expect(dueCards[1].word == "middle")
        #expect(dueCards[2].word == "latest")
    }

    @Test("Due card count excludes new cards")
    func dueCardCountExcludesNew() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 5 due review cards
        for i in 1...5 {
            _ = createTestFlashcard(context: context, word: "due\(i)", state: .review, dueOffset: -3600)
        }

        // Create 3 new cards (not counted as due)
        for i in 1...3 {
            _ = createTestFlashcard(context: context, word: "new\(i)", state: .new, dueOffset: 0)
        }

        // Create 2 non-due cards (future)
        _ = createTestFlashcard(context: context, word: "future1", state: .review, dueOffset: 3600)
        _ = createTestFlashcard(context: context, word: "future2", state: .learning, dueOffset: 7200)
        try context.save()

        let count = scheduler.dueCardCount()

        // Should count only the 5 due review cards (new cards are excluded)
        #expect(count == 5)
    }

    // MARK: - Cram Mode Tests

    @Test("Cram mode ignores due dates")
    func cramModeIgnoresDueDates() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different due dates and stability
        _ = createTestFlashcard(context: context, word: "low_stability", state: .review, dueOffset: 3600, stability: 1.0)
        _ = createTestFlashcard(context: context, word: "high_stability", state: .review, dueOffset: -3600, stability: 20.0)
        try context.save()

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        // Both should be fetched regardless of due date
        #expect(cramCards.count == 2)
    }

    @Test("Cram mode includes new cards")
    func cramModeIncludesNew() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create review card
        _ = createTestFlashcard(context: context, word: "review", state: .review, stability: 5.0)
        // Create new card (stability=0, should appear first)
        _ = createTestFlashcard(context: context, word: "new", state: .new, stability: 0.0)
        try context.save()

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        // Both should be fetched, new cards first (lowest stability)
        #expect(cramCards.count == 2)
        #expect(cramCards.first?.word == "new", "New cards with stability=0 should appear first in cram mode")
    }

    @Test("Cram mode sorts by stability ascending")
    func cramModeStabilitySorting() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different stability values
        _ = createTestFlashcard(context: context, word: "high", state: .review, stability: 20.0)
        _ = createTestFlashcard(context: context, word: "low", state: .review, stability: 2.0)
        _ = createTestFlashcard(context: context, word: "mid", state: .review, stability: 10.0)
        try context.save()

        let cramCards = scheduler.fetchCards(mode: .cram, limit: 20)

        #expect(cramCards.count == 3)
        // Should be sorted: low, mid, high (by stability)
        #expect(cramCards[0].word == "low")
        #expect(cramCards[1].word == "mid")
        #expect(cramCards[2].word == "high")
    }

    // MARK: - Learning Mode Tests

    @Test("Fetch new cards returns only cards with state = new")
    func fetchNewCardsOnlyNew() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create new card
        _ = createTestFlashcard(context: context, word: "new", state: .new)
        // Create review card
        _ = createTestFlashcard(context: context, word: "review", state: .review, dueOffset: -3600)
        // Create learning card
        _ = createTestFlashcard(context: context, word: "learning", state: .learning, dueOffset: -600)
        try context.save()

        let newCards = scheduler.fetchCards(mode: .learning, limit: 20)

        #expect(newCards.count == 1)
        #expect(newCards.allSatisfy { $0.fsrsState?.stateEnum == FlashcardState.new.rawValue })
    }

    @Test("Fetch new cards sorts by creation date ascending")
    func fetchNewCardsSortedByCreationDate() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards with different creation dates
        let card3 = createTestFlashcard(context: context, word: "card3", state: .new)
        try context.save()

        try await Task.sleep(for: .milliseconds(10))  // Ensure different timestamps

        let card1 = createTestFlashcard(context: context, word: "card1", state: .new)
        try context.save()

        try await Task.sleep(for: .milliseconds(10))

        let card2 = createTestFlashcard(context: context, word: "card2", state: .new)
        try context.save()

        // Manually set creation dates to control order
        card1.createdAt = Date().addingTimeInterval(-300)  // 5 minutes ago (oldest)
        card2.createdAt = Date().addingTimeInterval(-60)   // 1 minute ago (middle)
        card3.createdAt = Date()                           // now (newest)
        try context.save()

        let newCards = scheduler.fetchCards(mode: .learning, limit: 20)

        #expect(newCards.count == 3)
        #expect(newCards[0].word == "card1", "Oldest card should be first")
        #expect(newCards[1].word == "card2")
        #expect(newCards[2].word == "card3", "Newest card should be last")
    }

    @Test("New card count excludes non-new cards")
    func newCardCountExcludesReviewAndLearning() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 5 new cards
        for i in 1...5 {
            _ = createTestFlashcard(context: context, word: "new\(i)", state: .new)
        }

        // Create 3 review cards
        for i in 1...3 {
            _ = createTestFlashcard(context: context, word: "review\(i)", state: .review, dueOffset: -3600)
        }

        // Create 2 learning cards
        for i in 1...2 {
            _ = createTestFlashcard(context: context, word: "learning\(i)", state: .learning, dueOffset: -600)
        }

        try context.save()

        let count = scheduler.newCardCount()

        #expect(count == 5, "Should count only new cards")
    }

    @Test("Learning mode processes reviews with FSRS")
    func learningModeProcessReview() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let newCard = createTestFlashcard(context: context, word: "newcard", state: .new)
        try context.save()

        let initialState = newCard.fsrsState!
        #expect(initialState.stateEnum == FlashcardState.new.rawValue)
        #expect(initialState.stability == 0.0)

        // Process first review in learning mode
        let review = await scheduler.processReview(
            flashcard: newCard,
            rating: 2,  // Good
            mode: .learning
        )

        #expect(review != nil)

        // Card should transition from new to learning or review
        let newState = newCard.fsrsState!
        #expect(newState.stateEnum != FlashcardState.new.rawValue, "State should change from new")
        #expect(newState.stability > 0, "Stability should be set after first review")
        #expect(newState.lastReviewDate != nil, "Last review date should be cached")
    }

    @Test("Learning mode respects study limit")
    func learningModeRespectsLimit() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 25 new cards
        for i in 1...25 {
            _ = createTestFlashcard(context: context, word: "new\(i)", state: .new)
        }
        try context.save()

        let cards = scheduler.fetchCards(mode: .learning, limit: 20)

        #expect(cards.count == 20, "Should respect study limit")
    }

    // MARK: - Review Processing Tests

    @Test("Process review in scheduled mode updates FSRS state")
    func scheduledModeUpdatesState() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        // Create review card with meaningful stability (> 0 for review state)
        let flashcard = createTestFlashcard(context: context, state: .review, stability: 5.0)
        try context.save()

        let initialStability = flashcard.fsrsState!.stability

        _ = await scheduler.processReview(
            flashcard: flashcard,
            rating: 3, // Easy - more likely to affect stability
            mode: .scheduled
        )

        // FSRS state should be updated (stability may increase or stay same)
        #expect(flashcard.fsrsState!.stability >= initialStability, "Easy rating should maintain or increase stability")
        #expect(flashcard.fsrsState!.dueDate > Date(), "Due date should be in future")
    }

    @Test("Process review in scheduled mode creates review log")
    func scheduledModeCreatesLog() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        try context.save()

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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        try context.save()

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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        try context.save()

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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        for rating in 0...3 {
            try context.clearAll()
            let flashcard = createTestFlashcard(context: context, state: .review)
            try context.save()
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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        try context.save()

        let previews = await scheduler.previewRatings(for: flashcard)

        #expect(previews.count == 4)
        #expect(previews[0] != nil)
        #expect(previews[1] != nil)
        #expect(previews[2] != nil)
        #expect(previews[3] != nil)
    }

    @Test("Preview due dates are in future")
    func previewDatesInFuture() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)
        let now = Date()
        try context.save()

        let previews = await scheduler.previewRatings(for: flashcard)

        for (rating, dueDate) in previews {
            #expect(dueDate > now, "Rating \(rating) should schedule future date")
        }
    }

    // MARK: - Reset Tests

    @Test("Reset flashcard returns to new state")
    func resetFlashcard() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let flashcard = createTestFlashcard(context: context, state: .review)

        // Set to review with high stability
        flashcard.fsrsState!.stability = 50.0
        flashcard.fsrsState!.difficulty = 8.0
        try context.save()

        await scheduler.resetFlashcard(flashcard)

        #expect(flashcard.fsrsState!.stateEnum == FlashcardState.new.rawValue)
        #expect(flashcard.fsrsState!.dueDate <= Date())
    }

    // MARK: - Edge Case Tests

    @Test("Empty database returns empty arrays")
    func emptyDatabase() async throws {
        let context = freshContext()
        try context.clearAll()
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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create flashcard without FSRS state
        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)
        try context.save()

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
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 10 cards
        var cards: [Flashcard] = []
        for i in 1...10 {
            let card = createTestFlashcard(context: context, word: "card\(i)", state: .review)
            cards.append(card)
        }
        try context.save()

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

    // MARK: - Concurrency Tests

    @Test("Concurrency: concurrent fetch operations are safe")
    func concurrentFetchOperations() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 20 cards with various due dates
        for i in 1...20 {
            let offset = i % 2 == 0 ? -3600.0 : 3600.0
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review, dueOffset: offset)
        }
        try context.save()

        // Fetch from multiple tasks concurrently
        await withTaskGroup(of: Int.self) { group in
            for _ in 1..<5 {
                group.addTask {
                    let cards = scheduler.fetchCards(mode: .scheduled, limit: 20)
                    return cards.count
                }
            }
        }

        // Should complete without errors
        let dueCards = scheduler.fetchCards(mode: .scheduled, limit: 20)
        #expect(dueCards.count == 10) // Half are due
    }

    @Test("Concurrency: mixed scheduled and cram operations")
    func concurrentMixedModes() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards
        for i in 1...5 {
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review)
        }
        try context.save()

        // Process reviews in different modes concurrently
        await withTaskGroup(of: Void.self) { group in
            for (i, card) in context.fetch(FetchDescriptor<Flashcard>()).enumerated() {
                group.addTask {
                    let mode: StudyMode = i % 2 == 0 ? .scheduled : .cram
                    _ = await scheduler.processReview(
                        flashcard: card,
                        rating: 2,
                        mode: mode
                    )
                }
            }
        }

        // All reviews should be logged
        let allCards = context.fetch(FetchDescriptor<Flashcard>())
        let totalReviews = allCards.reduce(0) { $0 + $1.reviewLogs.count }
        #expect(totalReviews == 5)
    }

    @Test("Concurrency: FSRSState updates are serialized")
    func concurrentFSRSStateUpdates() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let card = createTestFlashcard(context: context, word: "test", state: .review)
        try context.save()

        // Process same card multiple times concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 1..<10 {
                group.addTask {
                    _ = await scheduler.processReview(
                        flashcard: card,
                        rating: 2,
                        mode: .scheduled
                    )
                }
            }
        }

        // All reviews should be logged
        #expect(card.reviewLogs.count == 10)

        // FSRSState should have final review's values
        #expect(card.fsrsState?.lastReviewDate != nil)
    }

    @Test("Concurrency: error handling during concurrent reviews")
    func concurrentErrorHandling() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create some cards without FSRSState to test error handling
        let card1 = Flashcard(word: "noState", definition: "test")
        context.insert(card1)

        let card2 = createTestFlashcard(context: context, word: "withState", state: .review)
        try context.save()

        // Process both concurrently - one should fail gracefully
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await scheduler.processReview(flashcard: card1, rating: 2, mode: .scheduled)
            }
            group.addTask {
                _ = await scheduler.processReview(flashcard: card2, rating: 2, mode: .scheduled)
            }
        }

        // Card with state should have review
        #expect(card2.reviewLogs.count == 1)
    }

    @Test("Concurrency: race condition in due card fetching")
    func raceConditionInDueCardFetching() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards and mark some as due during the test
        for i in 1...10 {
            let offset = i <= 5 ? -3600.0 : 3600.0
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review, dueOffset: offset)
        }
        try context.save()

        // Fetch due cards from multiple tasks
        var results: [Int] = []
        await withTaskGroup(of: Int.self) { group in
            for _ in 1..<5 {
                group.addTask {
                    return scheduler.fetchCards(mode: .scheduled, limit: 20).count
                }
            }

            for await count in group {
                results.append(count)
            }
        }

        // All fetches should return same count
        #expect(results.allSatisfy { $0 == 5 })
    }

    @Test("Concurrency: large batch processing")
    func concurrentLargeBatch() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 100 cards
        var cards: [Flashcard] = []
        for i in 1...100 {
            let card = createTestFlashcard(context: context, word: "card\(i)", state: .review)
            cards.append(card)
        }
        try context.save()

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

        // All should be processed
        let totalCount = cards.reduce(0) { $0 + $1.reviewLogs.count }
        #expect(totalCount == 100)
    }

    // MARK: - lastReviewDate Cache Tests (from main branch)

    @Test("lastReviewDate is updated after processReview")
    func lastReviewDateUpdated() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let card = createTestFlashcard(context: context, state: .review)
        let beforeDate = Date().addingTimeInterval(-100)
        card.fsrsState!.lastReviewDate = beforeDate
        try context.save()

        let afterDate = Date().addingTimeInterval(100)

        _ = await scheduler.processReview(flashcard: card, rating: 2, mode: .scheduled)

        // lastReviewDate should be updated to current time
        #expect(card.fsrsState!.lastReviewDate! > beforeDate)
        #expect(card.fsrsState!.lastReviewDate! < afterDate)
    }

    @Test("lastReviewDate consistency with review logs")
    func lastReviewDateLogConsistency() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let card = createTestFlashcard(context: context, state: .review)
        try context.save()

        // Process 3 reviews
        _ = await scheduler.processReview(flashcard: card, rating: 2, mode: .scheduled)
        let review1Time = card.fsrsState!.lastReviewDate

        await Task.sleep(1_000_000) // 1ms delay

        _ = await scheduler.processReview(flashcard: card, rating: 3, mode: .scheduled)
        let review2Time = card.fsrsState!.lastReviewDate

        // lastReviewDate should be the most recent review
        #expect(card.fsrsState!.lastReviewDate == review2Time)
        #expect(review2Time! > review1Time!)
    }

    @Test("FSRSState orphan prevention on flashcard delete")
    func fsrsStateOrphanPrevention() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create flashcard with FSRS state
        let card = createTestFlashcard(context: context, word: "orphan_test", state: .review)
        let stateId = card.fsrsState!.persistentModelID
        try context.save()

        // Delete the flashcard
        context.delete(card)
        try context.save()

        // Fetch to verify FSRS state is also deleted (cascade)
        let fetchDescriptor = FetchDescriptor<FSRSState>()
        let remainingStates = try context.fetch(fetchDescriptor)

        #expect(remainingStates.isEmpty, "FSRSState should be cascade deleted with flashcard")
    }

    @Test("Stress test with >10 concurrent operations")
    func concurrentStressTest() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 100 cards
        var cards: [Flashcard] = []
        for i in 1...100 {
            let card = createTestFlashcard(context: context, word: "card\(i)", state: .review)
            cards.append(card)
        }
        try context.save()

        // Process all concurrently with different ratings
        await withTaskGroup(of: Void.self) { group in
            for (index, card) in cards.enumerated() {
                group.addTask {
                    let rating = index % 4 // Cycle through all ratings
                    _ = await scheduler.processReview(
                        flashcard: card,
                        rating: rating,
                        mode: .scheduled
                    )
                }
            }
        }

        // All should be processed
        let totalLogs = cards.reduce(0) { $0 + $1.reviewLogs.count }
        #expect(totalLogs == 100)

        // Verify no data corruption
        for card in cards {
            #expect(card.fsrsState != nil)
            #expect(card.reviewLogs.count == 1)
        }
    }
}
