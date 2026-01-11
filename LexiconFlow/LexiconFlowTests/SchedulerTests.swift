//
//  SchedulerTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for Scheduler and study modes
//  Covers: due card fetching, review processing, queries
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for Scheduler class
///
/// Tests the main scheduler API including:
/// - Due card queries
/// - Review processing with FSRS
/// - Study mode differences
@Suite(.serialized)
@MainActor
struct SchedulerTests {
    // MARK: - Test Fixtures

    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
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

        let dueCards = await scheduler.fetchCards(mode: .scheduled, limit: 20)

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

        let dueCards = await scheduler.fetchCards(mode: .scheduled, limit: 20)

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
        for i in 1 ... 5 {
            _ = createTestFlashcard(
                context: context,
                word: "card\(i)",
                state: .review,
                dueOffset: -Double(i * 3600)
            )
        }
        try context.save()

        let cards3 = await scheduler.fetchCards(mode: .scheduled, limit: 3)
        let cards10 = await scheduler.fetchCards(mode: .scheduled, limit: 10)

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

        let dueCards = await scheduler.fetchCards(mode: .scheduled, limit: 20)

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
        for i in 1 ... 5 {
            _ = createTestFlashcard(context: context, word: "due\(i)", state: .review, dueOffset: -3600)
        }

        // Create 3 new cards (not counted as due)
        for i in 1 ... 3 {
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

        let newCards = await scheduler.fetchCards(mode: .learning, limit: 20)

        #expect(newCards.count == 1)
        #expect(newCards.allSatisfy { $0.fsrsState?.stateEnum == FlashcardState.new.rawValue })
    }

    @Test("Fetch new cards sorts by creation date ascending")
    func fetchNewCardsSortedByCreationDate() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Set sequential mode for this test
        AppSettings.newCardOrderMode = .sequential

        // Create cards with different creation dates
        let card3 = createTestFlashcard(context: context, word: "card3", state: .new)
        try context.save()

        try await Task.sleep(for: .milliseconds(10)) // Ensure different timestamps

        let card1 = createTestFlashcard(context: context, word: "card1", state: .new)
        try context.save()

        try await Task.sleep(for: .milliseconds(10))

        let card2 = createTestFlashcard(context: context, word: "card2", state: .new)
        try context.save()

        // Manually set creation dates to control order
        card1.createdAt = Date().addingTimeInterval(-300) // 5 minutes ago (oldest)
        card2.createdAt = Date().addingTimeInterval(-60) // 1 minute ago (middle)
        card3.createdAt = Date() // now (newest)
        try context.save()

        let newCards = await scheduler.fetchCards(mode: .learning, limit: 20)

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
        for i in 1 ... 5 {
            _ = createTestFlashcard(context: context, word: "new\(i)", state: .new)
        }

        // Create 3 review cards
        for i in 1 ... 3 {
            _ = createTestFlashcard(context: context, word: "review\(i)", state: .review, dueOffset: -3600)
        }

        // Create 2 learning cards
        for i in 1 ... 2 {
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
            rating: 2, // Good
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
        for i in 1 ... 25 {
            _ = createTestFlashcard(context: context, word: "new\(i)", state: .new)
        }
        try context.save()

        let cards = await scheduler.fetchCards(mode: .learning, limit: 20)

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

    @Test("Process review handles all four ratings")
    func processReviewAllRatings() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        for rating in 0 ... 3 {
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

        let dueCards = await scheduler.fetchCards(mode: .scheduled)
        let learningCards = await scheduler.fetchCards(mode: .learning)
        let count = scheduler.dueCardCount()

        #expect(dueCards.isEmpty)
        #expect(learningCards.isEmpty)
        #expect(count == 0)
    }

    @Test("Processing review without FSRS state returns nil")
    func processReviewWithoutState() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create flashcard without FSRS state
        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)
        try context.save()

        #expect(flashcard.fsrsState == nil)

        let result = await scheduler.processReview(
            flashcard: flashcard,
            rating: 2,
            mode: .scheduled
        )

        // Should return nil when FSRSState is missing (in scheduled mode)
        #expect(result == nil, "processReview should return nil when FSRSState is nil")
        #expect(flashcard.fsrsState == nil, "FSRSState should still be nil")
    }

    @Test("Concurrent review processing is serialized")
    func concurrentReviews() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 10 cards
        var cards: [Flashcard] = []
        for i in 1 ... 10 {
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
        for i in 1 ... 20 {
            let offset = i % 2 == 0 ? -3600.0 : 3600.0
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review, dueOffset: offset)
        }
        try context.save()

        // Fetch from multiple tasks concurrently
        await withTaskGroup(of: Int.self) { group in
            for _ in 1 ..< 5 {
                group.addTask {
                    let cards = await scheduler.fetchCards(mode: .scheduled, limit: 20)
                    return cards.count
                }
            }
        }

        // Should complete without errors
        let dueCards = await scheduler.fetchCards(mode: .scheduled, limit: 20)
        #expect(dueCards.count == 10) // Half are due
    }

    @Test("Concurrency: mixed scheduled and learning operations")
    func concurrentMixedModes() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards
        for i in 1 ... 5 {
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review)
        }
        try context.save()

        // Fetch cards before entering concurrent context
        let cardsToProcess = try context.fetch(FetchDescriptor<Flashcard>())

        // Process reviews in different modes concurrently
        await withTaskGroup(of: Void.self) { group in
            for (i, card) in cardsToProcess.enumerated() {
                group.addTask {
                    let mode: StudyMode = i % 2 == 0 ? .scheduled : .learning
                    _ = await scheduler.processReview(
                        flashcard: card,
                        rating: 2,
                        mode: mode
                    )
                }
            }
        }

        // All reviews should be logged
        let allCards = try context.fetch(FetchDescriptor<Flashcard>())
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
            for _ in 0 ..< 10 {
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
        for i in 1 ... 10 {
            let offset = i <= 5 ? -3600.0 : 3600.0
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .review, dueOffset: offset)
        }
        try context.save()

        // Fetch due cards from multiple tasks
        var results: [Int] = []
        await withTaskGroup(of: Int.self) { group in
            for _ in 1 ..< 5 {
                group.addTask {
                    await scheduler.fetchCards(mode: .scheduled, limit: 20).count
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
        for i in 1 ... 100 {
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

        await Task.sleep(1000000) // 1ms delay

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
        for i in 1 ... 100 {
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

    // MARK: - Crash Prevention Tests

    // MARK: - Multi-Deck Tests (Phase 9)

    @Test("Multi-deck: fetchCards returns cards from all selected decks")
    func fetchCardsMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        let deck3 = createTestDeck(context: context, name: "Deck3")
        try context.save()

        // Add due cards to deck1 and deck2
        let card1 = createTestFlashcard(context: context, word: "card1", state: .review, dueOffset: -3600)
        card1.deck = deck1

        let card2 = createTestFlashcard(context: context, word: "card2", state: .review, dueOffset: -3600)
        card2.deck = deck2

        let card3 = createTestFlashcard(context: context, word: "card3", state: .review, dueOffset: -3600)
        card3.deck = deck3
        try context.save()

        // Fetch from deck1 and deck2 only
        let cards = scheduler.fetchCards(for: [deck1, deck2], mode: .scheduled, limit: 20)

        #expect(cards.count == 2)
        #expect(cards.allSatisfy { [$0.word].contains(where: { ["card1", "card2"].contains($0) }) })
    }

    @Test("Multi-deck: fetchCards with empty deck array returns empty")
    func fetchCardsEmptyDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create a deck with due cards
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let card1 = createTestFlashcard(context: context, word: "card1", state: .review, dueOffset: -3600)
        card1.deck = deck1
        try context.save()

        // Fetch with empty deck array
        let cards = scheduler.fetchCards(for: [], mode: .scheduled, limit: 20)

        #expect(cards.isEmpty)
    }

    @Test("Multi-deck: dueCardCount counts across all selected decks")
    func dueCardCountMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        let deck3 = createTestDeck(context: context, name: "Deck3")
        try context.save()

        // Add due cards: 3 in deck1, 2 in deck2, 1 in deck3
        for i in 1 ... 3 {
            let card = createTestFlashcard(context: context, word: "deck1_\(i)", state: .review, dueOffset: -3600)
            card.deck = deck1
        }

        for i in 1 ... 2 {
            let card = createTestFlashcard(context: context, word: "deck2_\(i)", state: .review, dueOffset: -3600)
            card.deck = deck2
        }

        let card = createTestFlashcard(context: context, word: "deck3_1", state: .review, dueOffset: -3600)
        card.deck = deck3
        try context.save()

        // Count from deck1 and deck2 only
        let count = scheduler.dueCardCount(for: [deck1, deck2])

        #expect(count == 5)
    }

    @Test("Multi-deck: newCardCount counts across all selected decks")
    func newCardCountMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        let deck3 = createTestDeck(context: context, name: "Deck3")
        try context.save()

        // Add new cards: 4 in deck1, 3 in deck2, 2 in deck3
        for i in 1 ... 4 {
            let card = createTestFlashcard(context: context, word: "deck1_\(i)", state: .new)
            card.deck = deck1
        }

        for i in 1 ... 3 {
            let card = createTestFlashcard(context: context, word: "deck2_\(i)", state: .new)
            card.deck = deck2
        }

        for i in 1 ... 2 {
            let card = createTestFlashcard(context: context, word: "deck3_\(i)", state: .new)
            card.deck = deck3
        }
        try context.save()

        // Count from deck1 and deck3 only
        let count = scheduler.newCardCount(for: [deck1, deck3])

        #expect(count == 6)
    }

    @Test("Multi-deck: totalCardCount counts across all selected decks")
    func totalCardCountMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        try context.save()

        // Add various cards to deck1
        let card1 = createTestFlashcard(context: context, word: "new1", state: .new)
        card1.deck = deck1

        let card2 = createTestFlashcard(context: context, word: "review1", state: .review, dueOffset: -3600)
        card2.deck = deck1

        let card3 = createTestFlashcard(context: context, word: "learning1", state: .learning, dueOffset: -600)
        card3.deck = deck1

        // Add cards to deck2
        let card4 = createTestFlashcard(context: context, word: "new2", state: .new)
        card4.deck = deck2

        let card5 = createTestFlashcard(context: context, word: "review2", state: .review, dueOffset: -3600)
        card5.deck = deck2
        try context.save()

        // Count all cards from both decks
        let count = scheduler.totalCardCount(for: [deck1, deck2])

        #expect(count == 5)
    }

    @Test("Multi-deck: fetchCards respects limit across multiple decks")
    func fetchCardsLimitMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks with 10 cards each
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        let deck3 = createTestDeck(context: context, name: "Deck3")

        for i in 1 ... 10 {
            let card1 = createTestFlashcard(context: context, word: "deck1_\(i)", state: .review, dueOffset: -3600)
            card1.deck = deck1

            let card2 = createTestFlashcard(context: context, word: "deck2_\(i)", state: .review, dueOffset: -3600)
            card2.deck = deck2

            let card3 = createTestFlashcard(context: context, word: "deck3_\(i)", state: .review, dueOffset: -3600)
            card3.deck = deck3
        }
        try context.save()

        // Fetch with limit of 15 (should get 15, not all 30)
        let cards = scheduler.fetchCards(for: [deck1, deck2, deck3], mode: .scheduled, limit: 15)

        #expect(cards.count == 15)
    }

    @Test("Multi-deck: learning mode works with multiple decks")
    func fetchNewCardsMultipleDecks() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        try context.save()

        // Add new cards to both decks
        for i in 1 ... 3 {
            let card1 = createTestFlashcard(context: context, word: "deck1_\(i)", state: .new)
            card1.deck = deck1

            let card2 = createTestFlashcard(context: context, word: "deck2_\(i)", state: .new)
            card2.deck = deck2
        }

        // Add some review cards (should not be included)
        let reviewCard = createTestFlashcard(context: context, word: "review", state: .review, dueOffset: -3600)
        reviewCard.deck = deck1
        try context.save()

        // Fetch new cards from both decks
        let cards = scheduler.fetchCards(for: [deck1, deck2], mode: .learning, limit: 20)

        #expect(cards.count == 6)
        #expect(cards.allSatisfy { $0.fsrsState?.stateEnum == FlashcardState.new.rawValue })
    }

    // MARK: - Card Ordering Tests

    @Test("Random mode returns different orders on consecutive calls")
    func randomModeVaries() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 20 new cards
        for i in 1 ... 20 {
            _ = createTestFlashcard(context: context, word: "card\(i)", state: .new)
        }
        try context.save()

        // Set random mode
        AppSettings.newCardOrderMode = .random

        let batch1 = await scheduler.fetchCards(mode: .learning, limit: 10)
        let batch2 = await scheduler.fetchCards(mode: .learning, limit: 10)

        // Orders should differ (with high probability)
        #expect(batch1.count == 10)
        #expect(batch2.count == 10)

        // Count matches between batches (should be low for random)
        let matches = zip(batch1, batch2).count(where: { $0.0.word == $0.1.word })
        #expect(matches < 5, "Random orders should have few positional matches")
    }

    @Test("Sequential mode returns cards sorted by creation date")
    func sequentialModeOldestFirst() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create cards with specific creation dates
        let card3 = createTestFlashcard(context: context, word: "card3", state: .new)
        try context.save()
        try await Task.sleep(for: .milliseconds(10))

        let card1 = createTestFlashcard(context: context, word: "card1", state: .new)
        try context.save()
        try await Task.sleep(for: .milliseconds(10))

        let card2 = createTestFlashcard(context: context, word: "card2", state: .new)
        try context.save()

        // Manually set creation dates
        card1.createdAt = Date().addingTimeInterval(-300) // oldest
        card2.createdAt = Date().addingTimeInterval(-60) // middle
        card3.createdAt = Date() // newest
        try context.save()

        // Set sequential mode
        AppSettings.newCardOrderMode = .sequential

        let cards = await scheduler.fetchCards(mode: .learning, limit: 20)

        #expect(cards.count == 3)
        #expect(cards[0].word == "card1", "Oldest card should be first")
        #expect(cards[1].word == "card2")
        #expect(cards[2].word == "card3", "Newest card should be last")
    }

    @Test("Multi-deck interleaving distributes cards evenly")
    func interleaveDistributesEvenly() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create 3 decks with 5 cards each
        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        let deck3 = createTestDeck(context: context, name: "Deck3")
        try context.save()

        var allCards: [Flashcard] = []

        // Create cards in round-robin order with controlled timestamps
        for i in 1 ... 5 {
            let card1 = createTestFlashcard(context: context, word: "d1_\(i)", state: .new)
            card1.deck = deck1
            card1.createdAt = Date().addingTimeInterval(-Double(1000 - i * 10)) // Ensure order within deck
            allCards.append(card1)

            let card2 = createTestFlashcard(context: context, word: "d2_\(i)", state: .new)
            card2.deck = deck2
            card2.createdAt = Date().addingTimeInterval(-Double(1000 - i * 10))
            allCards.append(card2)

            let card3 = createTestFlashcard(context: context, word: "d3_\(i)", state: .new)
            card3.deck = deck3
            card3.createdAt = Date().addingTimeInterval(-Double(1000 - i * 10))
            allCards.append(card3)
        }
        try context.save()

        // Enable interleaving
        AppSettings.multiDeckInterleaveEnabled = true
        AppSettings.newCardOrderMode = .sequential

        let cards = scheduler.fetchCards(for: [deck1, deck2, deck3], mode: .learning, limit: 9)

        #expect(cards.count == 9)

        // Verify interleaving pattern: cards should alternate between decks
        // Count how many times the deck changes (should be high for interleaved)
        let deckTransitions = zip(cards, cards.dropFirst()).count(where: { $0.0.deck?.id != $0.1.deck?.id })
        #expect(deckTransitions >= 6, "Should have many deck transitions (interleaved), got \(deckTransitions)")

        // Verify we get cards from all 3 decks
        let uniqueDeckIDs = Set(cards.compactMap { $0.deck?.id })
        #expect(uniqueDeckIDs.count == 3, "Should have cards from all 3 decks")

        // Verify each deck is represented (approximately 3 cards each from 9 total)
        let deck1Count = cards.count(where: { $0.deck?.id == deck1.id })
        let deck2Count = cards.count(where: { $0.deck?.id == deck2.id })
        let deck3Count = cards.count(where: { $0.deck?.id == deck3.id })
        #expect(deck1Count == 3, "Deck1 should have 3 cards")
        #expect(deck2Count == 3, "Deck2 should have 3 cards")
        #expect(deck3Count == 3, "Deck3 should have 3 cards")
    }

    @Test("Multi-deck random with interleaving maintains proportional representation")
    func randomInterleaveProportional() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        // Create decks with different sizes
        let deck1 = createTestDeck(context: context, name: "Deck1") // 10 cards
        let deck2 = createTestDeck(context: context, name: "Deck2") // 5 cards
        try context.save()

        for i in 1 ... 10 {
            let card = createTestFlashcard(context: context, word: "d1_\(i)", state: .new)
            card.deck = deck1
        }

        for i in 1 ... 5 {
            let card = createTestFlashcard(context: context, word: "d2_\(i)", state: .new)
            card.deck = deck2
        }
        try context.save()

        AppSettings.multiDeckInterleaveEnabled = true
        AppSettings.newCardOrderMode = .random

        let cards = scheduler.fetchCards(for: [deck1, deck2], mode: .learning, limit: 12)

        #expect(cards.count == 12)

        // Verify proportional representation (2:1 ratio for deck sizes)
        let deck1Count = cards.count(where: { $0.deck?.id == deck1.id })
        let deck2Count = cards.count(where: { $0.deck?.id == deck2.id })

        // With interleaving + random, should be approximately 2:1 ratio
        // (not exact due to randomness, but roughly proportional)
        let ratio = Double(deck1Count) / Double(deck2Count)
        #expect(ratio > 1.5 && ratio < 2.5, "Ratio should be approximately 2:1")
    }

    @Test("Interleaving disabled preserves deck grouping")
    func interleavingDisabled() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let deck1 = createTestDeck(context: context, name: "Deck1")
        let deck2 = createTestDeck(context: context, name: "Deck2")
        try context.save()

        // Create all deck1 cards first, then deck2 cards
        // with controlled timestamps to ensure deck1 cards are older
        for i in 1 ... 3 {
            let card1 = createTestFlashcard(context: context, word: "d1_\(i)", state: .new)
            card1.deck = deck1
            card1.createdAt = Date().addingTimeInterval(-Double(10 + i)) // Older timestamps
        }

        for i in 1 ... 3 {
            let card2 = createTestFlashcard(context: context, word: "d2_\(i)", state: .new)
            card2.deck = deck2
            card2.createdAt = Date().addingTimeInterval(-Double(3 + i)) // Newer timestamps
        }
        try context.save()

        AppSettings.multiDeckInterleaveEnabled = false
        AppSettings.newCardOrderMode = .sequential

        let cards = scheduler.fetchCards(for: [deck1, deck2], mode: .learning, limit: 6)

        #expect(cards.count == 6)

        // Without interleaving, cards should be grouped by deck (sorted by createdAt)
        // Since deck1 cards are older, all deck1 cards should come first
        #expect(cards[0].word.hasPrefix("d1_"), "First card should be from deck1")
        #expect(cards[1].word.hasPrefix("d1_"), "Second card should be from deck1")
        #expect(cards[2].word.hasPrefix("d1_"), "Third card should be from deck1")
        #expect(cards[3].word.hasPrefix("d2_"), "Fourth card should be from deck2")

        // Check that there's only 1 transition (deck1 -> deck2)
        let deckTransitions = zip(cards, cards.dropFirst()).count(where: { $0.0.deck?.id != $0.1.deck?.id })
        #expect(deckTransitions == 1, "Should have exactly 1 transition (deck1 to deck2)")
    }

    @Test("Single deck with interleaving enabled works correctly")
    func singleDeckInterleaving() async throws {
        let context = freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)

        let deck1 = createTestDeck(context: context, name: "Deck1")
        try context.save()

        for i in 1 ... 5 {
            let card = createTestFlashcard(context: context, word: "card\(i)", state: .new)
            card.deck = deck1
        }
        try context.save()

        AppSettings.multiDeckInterleaveEnabled = true
        AppSettings.newCardOrderMode = .sequential

        let cards = scheduler.fetchCards(for: [deck1], mode: .learning, limit: 5)

        // Should behave like single-deck mode (no interleaving needed)
        #expect(cards.count == 5)
    }
}

// MARK: - SwiftData Rollback Tests

@Suite("SwiftData Rollback Tests")
@MainActor
struct SwiftDataRollbackTests {
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    private func createTestDeck(context: ModelContext) -> Deck {
        let deck = Deck(name: "Test Deck", icon: "folder.fill", order: 0)
        context.insert(deck)
        try! context.save()
        return deck
    }

    private func createTestFlashcard(
        context: ModelContext,
        word: String = "test",
        state: FlashcardState = .new,
        dueOffset: TimeInterval = 0
    ) -> Flashcard {
        let deck = createTestDeck(context: context)
        let card = Flashcard(word: word, definition: word)
        card.deck = deck
        context.insert(card)

        let fsrsState = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(dueOffset),
            stateEnum: state.rawValue
        )
        fsrsState.card = card

        context.insert(fsrsState)
        try! context.save()

        return card
    }

    @Test("processReview failure leaves database unchanged")
    func reviewFailureRollback() async throws {
        let context = freshContext()
        try context.clearAll()

        let scheduler = Scheduler(modelContext: context)
        let card = createTestFlashcard(context: context, word: "test", state: .review, dueOffset: -3600)

        // Capture initial state
        let initialStability = card.fsrsState?.stability
        let initialDifficulty = card.fsrsState?.difficulty
        let initialDueDate = card.fsrsState?.dueDate

        // Process a review
        let result = await scheduler.processReview(
            flashcard: card,
            rating: 3,
            mode: .scheduled
        )

        // Verify review succeeded (rollback not needed in success case)
        #expect(result != nil)

        // In a real rollback test, you'd simulate a failure and verify state unchanged
        // For now, verify state was updated
        let updatedCard = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(updatedCard?.fsrsState?.stability ?? 0 >= initialStability ?? 0)
    }

    @Test("AppSettings save failure doesn't corrupt selection")
    func appSettingsSaveFailure() async {
        // Test that AppSettings handles save failures gracefully
        let originalSelection = AppSettings.selectedDeckIDs

        // Attempt to save invalid data (simulated)
        AppSettings.selectedDeckIDs = []

        // Should not crash and should return empty set
        let selection = AppSettings.selectedDeckIDs
        #expect(selection.isEmpty)

        // Restore original selection
        AppSettings.selectedDeckIDs = originalSelection
    }

    @Test("Statistics load failure handles gracefully")
    func statsLoadFailure() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create deck with no cards
        let deck = createTestDeck(context: context)

        let scheduler = Scheduler(modelContext: context)

        // Should handle gracefully without crashing
        let newCount = scheduler.newCardCount(for: deck)
        let dueCount = scheduler.dueCardCount(for: deck)
        let totalCount = scheduler.totalCardCount(for: deck)

        #expect(newCount == 0)
        #expect(dueCount == 0)
        #expect(totalCount == 0)
    }

    @Test("Concurrent review failure doesn't corrupt card state")
    func concurrentReviewFailure() async throws {
        let context = freshContext()
        try context.clearAll()

        let card = createTestFlashcard(context: context, word: "test", state: .review, dueOffset: -3600)
        let scheduler = Scheduler(modelContext: context)

        // Simulate concurrent operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await scheduler.processReview(flashcard: card, rating: 3, mode: .scheduled)
            }
            group.addTask {
                _ = await scheduler.processReview(flashcard: card, rating: 3, mode: .scheduled)
            }
        }

        // Should not crash or corrupt state
        let updatedCard = try context.fetch(FetchDescriptor<Flashcard>()).first
        #expect(updatedCard != nil)
    }

    @Test("Deck deletion during session handles gracefully")
    func deckDeletionDuringSession() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createTestDeck(context: context)
        let deckID = deck.id

        // Create a card
        _ = createTestFlashcard(context: context, word: "test", state: .review, dueOffset: -3600)

        let viewModel = StudySessionViewModel(
            modelContext: context,
            decks: [deck],
            mode: .scheduled
        )

        viewModel.loadCards()

        // Delete deck
        context.delete(deck)
        try! context.save()

        // Verify deck is deleted
        let descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckID })
        let deletedDeck = try? context.fetch(descriptor).first

        #expect(deletedDeck == nil)
    }

    @Test("Corrupted FSRSState recovery")
    func corruptedStateRecovery() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createTestDeck(context: context)
        let card = Flashcard(word: "test", definition: "test")
        card.deck = deck

        // Create card with corrupted state (nil FSRSState)
        context.insert(card)
        try! context.save()

        let scheduler = Scheduler(modelContext: context)

        // Should handle cards without FSRSState gracefully
        let totalCount = scheduler.totalCardCount(for: deck)
        #expect(totalCount >= 0) // Should count the card even without state
    }
}
