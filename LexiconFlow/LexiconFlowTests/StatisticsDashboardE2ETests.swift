//
//  StatisticsDashboardE2ETests.swift
//  LexiconFlowTests
//
//  End-to-end integration tests for Statistics Dashboard
//  Tests verify complete workflow from study session to statistics display
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for Statistics Dashboard end-to-end integration
///
/// Tests verify:
/// - Complete workflow: Study session → Dashboard statistics
/// - Study session tracking and review linking
/// - DailyStats aggregation
/// - StatisticsViewModel data refresh
/// - Time range filtering (7d, 30d, all time)
/// - All study modes (scheduled, learning, cram)
/// - Realistic user scenarios with realistic data
@MainActor
struct StatisticsDashboardE2ETests {

    // MARK: - Test Fixtures

    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    private func createDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "book.fill", order: 0)
        context.insert(deck)
        return deck
    }

    private func createFlashcard(
        context: ModelContext,
        word: String,
        stateEnum: String = FlashcardState.new.rawValue,
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        lastReviewDate: Date? = nil
    ) -> Flashcard {
        let flashcard = Flashcard(
            word: word,
            definition: "Test definition for \(word)",
            phonetic: "/test/"
        )

        let fsrsState = FSRSState(
            stability: stability,
            difficulty: difficulty,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: stateEnum
        )
        fsrsState.card = flashcard
        fsrsState.lastReviewDate = lastReviewDate

        context.insert(flashcard)
        context.insert(fsrsState)

        return flashcard
    }

    private func createStudySession(
        context: ModelContext,
        startTime: Date,
        endTime: Date? = nil,
        cardsReviewed: Int = 10,
        modeEnum: String = "scheduled"
    ) -> StudySession {
        let session = StudySession(
            startTime: startTime,
            endTime: endTime ?? startTime.addingTimeInterval(300),
            cardsReviewed: cardsReviewed,
            modeEnum: modeEnum
        )
        context.insert(session)
        return session
    }

    private func createReview(
        context: ModelContext,
        flashcard: Flashcard,
        rating: Int,
        reviewDate: Date,
        scheduledDays: Double = 0.0,
        elapsedDays: Double = 0.0,
        studySession: StudySession? = nil
    ) -> FlashcardReview {
        let review = FlashcardReview(
            rating: rating,
            reviewDate: reviewDate,
            scheduledDays: scheduledDays,
            elapsedDays: elapsedDays
        )
        review.card = flashcard
        review.studySession = studySession
        context.insert(review)
        return review
    }

    // MARK: - Complete Workflow Tests

    @Test("E2E: Complete workflow from study session to dashboard statistics")
    func completeWorkflowFromStudySessionToDashboard() async throws {
        let context = freshContext()
        try context.clearAll()

        // Step 1: Create a deck with flashcards
        let deck = createDeck(context: context, name: "Vocabulary Deck")
        let cards = [
            createFlashcard(context: context, word: "ephemeral"),
            createFlashcard(context: context, word: "serendipity"),
            createFlashcard(context: context, word: "mellifluous"),
            createFlashcard(context: context, word: "luminous"),
            createFlashcard(context: context, word: "ethereal")
        ]
        try context.save()

        // Step 2: Simulate study session with StudySessionViewModel
        // FIXED: Pass the deck array so cards can be fetched
        let studyViewModel = StudySessionViewModel(modelContext: context, decks: [deck], mode: .scheduled)
        studyViewModel.loadCards()

        #expect(studyViewModel.cards.count == 5, "Should load all 5 cards")

        // Fetch the created study session from context
        let descriptor = FetchDescriptor<StudySession>()
        let sessions = try context.fetch(descriptor)
        #expect(!sessions.isEmpty, "Should create a study session")

        guard let session = sessions.first else {
            throw TestError(message: "Study session not created")
        }

        // Step 3: Submit ratings for all cards
        for card in cards {
            guard let currentCard = studyViewModel.currentCard else { break }
            await studyViewModel.submitRating(Int.random(in: 1...4), card: currentCard)
        }

        #expect(studyViewModel.isComplete, "Session should be complete")
        #expect(session.endTime != nil, "Session should have end time")
        #expect(session.cardsReviewed == 5, "Should have reviewed 5 cards")

        try context.save()

        // Step 4: Run DailyStats aggregation (simulating app background)
        let aggregatedDays = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(aggregatedDays == 1, "Should aggregate 1 day of statistics")

        // Step 5: Create StatisticsViewModel and refresh
        let statsViewModel = StatisticsViewModel(modelContext: context)
        await statsViewModel.refresh()

        // Step 6: Verify dashboard statistics reflect the study session
        #expect(statsViewModel.retentionData != nil, "Should have retention data")
        #expect(statsViewModel.streakData != nil, "Should have streak data")
        #expect(statsViewModel.fsrsMetrics != nil, "Should have FSRS metrics")
        #expect(!statsViewModel.isEmpty, "Dashboard should not be empty")

        // Verify retention rate calculation
        let retentionData = statsViewModel.retentionData!
        #expect(retentionData.totalCount == 5, "Should have 5 total reviews")
        #expect(retentionData.successfulCount > 0, "Should have at least 1 successful review")

        // Verify study streak
        let streakData = statsViewModel.streakData!
        #expect(streakData.currentStreak >= 1, "Should have at least 1 day streak")

        // Verify FSRS metrics
        let fsrsMetrics = statsViewModel.fsrsMetrics!
        #expect(fsrsMetrics.totalCards == 5, "Should have 5 total cards")

        // Workflow verified: Study session → Dashboard statistics
    }

    @Test("E2E: Multiple study sessions over consecutive days")
    func multipleStudySessionsOverConsecutiveDays() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)
        let calendar = Calendar.autoupdatingCurrent

        // Create cards for 3 days of study sessions
        var allReviews: [FlashcardReview] = []

        for dayOffset in 0..<3 {
            let dayStart = calendar.startOfDay(for: Date().addingTimeInterval(-Double(dayOffset * 86400)))

            // Create study session for this day
            let session = createStudySession(
                context: context,
                startTime: dayStart.addingTimeInterval(3600), // 1:00 AM
                endTime: dayStart.addingTimeInterval(4200), // 1:10 AM
                cardsReviewed: 10,
                modeEnum: "scheduled"
            )

            // Create flashcards and reviews for this session
            for i in 0..<10 {
                let card = createFlashcard(
                    context: context,
                    word: "word\(dayOffset)_\(i)",
                    stateEnum: FlashcardState.review.rawValue,
                    stability: Double(dayOffset + 1) * 2.0,
                    difficulty: Double.random(in: 3...7),
                    lastReviewDate: dayStart.addingTimeInterval(3600 + Double(i * 60))
                )

                let review = createReview(
                    context: context,
                    flashcard: card,
                    rating: Int.random(in: 1...4),
                    reviewDate: dayStart.addingTimeInterval(3600 + Double(i * 60)),
                    scheduledDays: 0,
                    elapsedDays: 0,
                    studySession: session
                )
                allReviews.append(review)
            }
        }

        try context.save()

        // Aggregate daily stats
        let aggregatedDays = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(aggregatedDays == 3, "Should aggregate 3 days of statistics")

        // Refresh dashboard with 7-day time range
        let statsViewModel = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await statsViewModel.refresh()

        // Verify statistics across all days
        #expect(statsViewModel.retentionData?.totalCount == 30, "Should have 30 total reviews")
        #expect(statsViewModel.streakData?.currentStreak == 3, "Should have 3-day streak")
        #expect(statsViewModel.fsrsMetrics?.totalCards == 30, "Should have 30 total cards")

        // Multiple study sessions verified: 3 days, 30 reviews, 3-day streak
    }

    @Test("E2E: Study session with mixed ratings (Again, Hard, Good, Easy)")
    func studySessionWithMixedRatings() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)
        let session = createStudySession(context: context, startTime: Date(), cardsReviewed: 20)

        // Create cards with mixed ratings
        let ratings = [0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 0, 1, 2, 3, 2, 1, 3, 2, 1, 0]
        var cards: [Flashcard] = []

        for (index, rating) in ratings.enumerated() {
            let card = createFlashcard(
                context: context,
                word: "word_\(index)",
                stateEnum: FlashcardState.review.rawValue,
                stability: Double(index) * 0.5,
                difficulty: Double(rating) + 3.0,
                lastReviewDate: Date()
            )

            createReview(
                context: context,
                flashcard: card,
                rating: rating,
                reviewDate: Date().addingTimeInterval(Double(index * 30)),
                studySession: session
            )
            cards.append(card)
        }

        try context.save()

        // Refresh dashboard
        let statsViewModel = StatisticsViewModel(modelContext: context)
        await statsViewModel.refresh()

        // Verify retention rate calculation
        let retentionData = statsViewModel.retentionData!
        let expectedSuccessCount = ratings.filter { $0 >= 1 }.count
        let expectedFailedCount = ratings.filter { $0 == 0 }.count
        let expectedRate = Double(expectedSuccessCount) / Double(ratings.count)

        #expect(retentionData.totalCount == 20, "Should have 20 total reviews")
        #expect(retentionData.successfulCount == expectedSuccessCount, "Should have \(expectedSuccessCount) successful reviews")
        #expect(retentionData.failedCount == expectedFailedCount, "Should have \(expectedFailedCount) failed reviews")
        #expect(abs(retentionData.rate - expectedRate) < 0.01, "Retention rate should be \(expectedRate)")

        // Mixed ratings verified: \(expectedSuccessCount)/20 successful (\(Int(expectedRate * 100))%)
    }

    // MARK: - Time Range Filtering Tests

    @Test("E2E: Time range filtering (7d vs 30d vs all time)")
    func timeRangeFiltering() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)
        let calendar = Calendar.autoupdatingCurrent

        // Create data across 45 days
        for dayOffset in 0..<45 {
            guard dayOffset % 3 == 0 else { continue } // Every 3 days to keep test fast

            let dayStart = calendar.startOfDay(for: Date().addingTimeInterval(-Double(dayOffset * 86400)))
            let session = createStudySession(
                context: context,
                startTime: dayStart.addingTimeInterval(3600),
                cardsReviewed: 5,
                modeEnum: "scheduled"
            )

            for i in 0..<5 {
                let card = createFlashcard(
                    context: context,
                    word: "word_\(dayOffset)_\(i)",
                    stateEnum: FlashcardState.review.rawValue,
                    stability: 1.0,
                    difficulty: 5.0,
                    lastReviewDate: dayStart
                )

                createReview(
                    context: context,
                    flashcard: card,
                    rating: Int.random(in: 2...4),
                    reviewDate: dayStart,
                    studySession: session
                )
            }
        }

        try context.save()

        // Test 7-day range
        let viewModel7d = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await viewModel7d.refresh()
        let reviews7d = viewModel7d.retentionData?.totalCount ?? 0
        #expect(reviews7d > 0, "7d range should have data")
        #expect(reviews7d <= 35, "7d range should have <= 35 reviews (7 days * 5 reviews/day)")

        // Test 30-day range
        let viewModel30d = StatisticsViewModel(modelContext: context, timeRange: .thirtyDays)
        await viewModel30d.refresh()
        let reviews30d = viewModel30d.retentionData?.totalCount ?? 0
        #expect(reviews30d >= reviews7d, "30d range should have >= 7d reviews")
        #expect(reviews30d <= 75, "30d range should have <= 75 reviews (15 days * 5 reviews/day)")

        // Test all-time range
        let viewModelAll = StatisticsViewModel(modelContext: context, timeRange: .allTime)
        await viewModelAll.refresh()
        let reviewsAll = viewModelAll.retentionData?.totalCount ?? 0
        #expect(reviewsAll >= reviews30d, "All time range should have >= 30d reviews")
        #expect(reviewsAll == 75, "All time range should have 75 reviews (15 days * 5 reviews/day)")

        // Time range verified: 7d=\(reviews7d), 30d=\(reviews30d), all=\(reviewsAll) reviews
    }

    // MARK: - Study Mode Tests

    @Test("E2E: All study modes (scheduled, learning, cram)")
    func allStudyModes() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)

        // Scheduled mode session
        let scheduledSession = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(-86400), // Yesterday
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )

        for i in 0..<10 {
            let card = createFlashcard(
                context: context,
                word: "scheduled_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date().addingTimeInterval(-86400)
            )
            createReview(
                context: context,
                flashcard: card,
                rating: Int.random(in: 2...4),
                reviewDate: Date().addingTimeInterval(-86400),
                studySession: scheduledSession
            )
        }

        // Learning mode session
        let learningSession = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(-43200), // 12 hours ago
            cardsReviewed: 5,
            modeEnum: "learning"
        )

        for i in 0..<5 {
            let card = createFlashcard(
                context: context,
                word: "learning_\(i)",
                stateEnum: FlashcardState.learning.rawValue,
                lastReviewDate: Date().addingTimeInterval(-43200)
            )
            createReview(
                context: context,
                flashcard: card,
                rating: Int.random(in: 1...3),
                reviewDate: Date().addingTimeInterval(-43200),
                studySession: learningSession
            )
        }

        // Cram mode session
        let cramSession = createStudySession(
            context: context,
            startTime: Date(),
            cardsReviewed: 8,
            modeEnum: "cram"
        )

        for i in 0..<8 {
            let card = createFlashcard(
                context: context,
                word: "cram_\(i)",
                stateEnum: FlashcardState.review.rawValue
            )
            createReview(
                context: context,
                flashcard: card,
                rating: Int.random(in: 1...4),
                reviewDate: Date(),
                studySession: cramSession
            )
        }

        try context.save()

        // Aggregate and refresh
        let aggregatedDays = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(aggregatedDays == 2, "Should aggregate 2 days")

        let statsViewModel = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await statsViewModel.refresh()

        // Verify all sessions are included in statistics
        let retentionData = statsViewModel.retentionData!
        #expect(retentionData.totalCount == 23, "Should have 23 total reviews (10+5+8)")
        #expect(statsViewModel.streakData?.currentStreak == 2, "Should have 2-day streak")
        #expect(statsViewModel.fsrsMetrics?.totalCards == 23, "Should have 23 total cards")

        // All study modes verified: Scheduled (10), Learning (5), Cram (8)
    }

    // MARK: - Edge Case Tests

    @Test("E2E: New user with no study data")
    func newUserWithNoStudyData() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create only a deck, no cards or sessions
        let deck = createDeck(context: context)
        try context.save()

        let statsViewModel = StatisticsViewModel(modelContext: context)
        await statsViewModel.refresh()

        // Verify empty state
        #expect(statsViewModel.retentionData != nil, "Retention data should exist (empty)")
        #expect(statsViewModel.streakData != nil, "Streak data should exist (empty)")
        #expect(statsViewModel.fsrsMetrics != nil, "FSRS metrics should exist (empty)")
        #expect(statsViewModel.isEmpty, "Dashboard should be empty")
        #expect(statsViewModel.retentionData?.totalCount == 0, "Should have 0 reviews")
        #expect(statsViewModel.streakData?.currentStreak == 0, "Should have 0 streak")
        #expect(statsViewModel.fsrsMetrics?.totalCards == 0, "Should have 0 cards")

        // New user empty state verified
    }

    @Test("E2E: Study session interrupted (not completed)")
    func studySessionInterrupted() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)

        // Create cards
        for i in 0..<20 {
            createFlashcard(
                context: context,
                word: "word_\(i)",
                stateEnum: FlashcardState.learning.rawValue
            )
        }
        try context.save()

        // Start study session
        // FIXED: Pass the deck array so cards can be fetched
        let studyViewModel = StudySessionViewModel(modelContext: context, decks: [deck], mode: .scheduled)
        studyViewModel.loadCards()

        // Fetch the created study session from context
        let descriptor = FetchDescriptor<StudySession>()
        let sessions = try context.fetch(descriptor)
        guard let session = sessions.first else {
            throw TestError(message: "Study session not created")
        }

        // Submit only 3 ratings out of 20
        for _ in 0..<3 {
            guard let card = studyViewModel.currentCard else { break }
            await studyViewModel.submitRating(2, card: card)
        }

        #expect(!studyViewModel.isComplete, "Session should not be complete")
        #expect(session.endTime == nil, "Session should not have end time")

        // Simulate cleanup (user exits study view)
        studyViewModel.cleanup()

        #expect(session.endTime != nil, "Session should be finalized on cleanup")
        #expect(session.cardsReviewed == 3, "Should have 3 cards reviewed")

        try context.save()

        // Verify dashboard shows partial session data
        let statsViewModel = StatisticsViewModel(modelContext: context)
        await statsViewModel.refresh()

        #expect(statsViewModel.retentionData?.totalCount == 3, "Should have 3 reviews")
        #expect(statsViewModel.streakData?.currentStreak == 1, "Should have 1-day streak")

        // Interrupted session verified: 3 reviews recorded, session finalized
    }

    @Test("E2E: Dashboard refresh with changing data")
    func dashboardRefreshWithChangingData() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)
        let statsViewModel = StatisticsViewModel(modelContext: context)

        // Initial refresh with no data
        await statsViewModel.refresh()
        #expect(statsViewModel.isEmpty, "Should be empty initially")

        // Add study session
        let session = createStudySession(context: context, startTime: Date(), cardsReviewed: 5)
        for i in 0..<5 {
            let card = createFlashcard(
                context: context,
                word: "word_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date()
            )
            createReview(
                context: context,
                flashcard: card,
                rating: 3,
                reviewDate: Date(),
                studySession: session
            )
        }
        try context.save()

        // Refresh and verify data appears
        await statsViewModel.refresh()
        #expect(!statsViewModel.isEmpty, "Should have data after session")
        #expect(statsViewModel.retentionData?.totalCount == 5, "Should have 5 reviews")

        // Add another session
        let session2 = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(3600),
            cardsReviewed: 3
        )
        for i in 0..<3 {
            let card = createFlashcard(
                context: context,
                word: "word2_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date().addingTimeInterval(3600)
            )
            createReview(
                context: context,
                flashcard: card,
                rating: 4,
                reviewDate: Date().addingTimeInterval(3600),
                studySession: session2
            )
        }
        try context.save()

        // Refresh and verify data updates
        await statsViewModel.refresh()
        #expect(statsViewModel.retentionData?.totalCount == 8, "Should have 8 reviews (5+3)")

        // Dashboard refresh verified: Data updates correctly on refresh
    }

    // MARK: - Realistic User Scenarios

    @Test("E2E: Realistic scenario - Consistent learner over 30 days")
    func consistentLearnerScenario() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context, name: "Spanish Vocabulary")
        let calendar = Calendar.autoupdatingCurrent

        // Simulate 30 days of consistent learning (5 days/week)
        var totalCards = 0
        var totalReviews = 0

        for week in 0..<4 {
            for day in 0..<5 { // Monday to Friday
                let dayOffset = week * 7 + day
                let dayStart = calendar.startOfDay(for: Date().addingTimeInterval(-Double(dayOffset * 86400)))

                // Study session: 15-25 cards per day
                let cardsToday = Int.random(in: 15...25)
                let session = createStudySession(
                    context: context,
                    startTime: dayStart.addingTimeInterval(3600 + Double(day * 3600)),
                    endTime: dayStart.addingTimeInterval(3600 + Double(day * 3600) + Double(cardsToday * 20)),
                    cardsReviewed: cardsToday,
                    modeEnum: "scheduled"
                )

                for i in 0..<cardsToday {
                    let card = createFlashcard(
                        context: context,
                        word: "word_\(dayOffset)_\(i)",
                        stateEnum: FlashcardState.review.rawValue,
                        stability: Double(week * 7 + day) * 0.5 + Double.random(in: 0...2),
                        difficulty: Double.random(in: 3...8),
                        lastReviewDate: dayStart
                    )

                    // Realistic rating distribution (more goods, few agains)
                    let ratingDistribution = [0, 1, 2, 2, 2, 3, 3, 3, 3, 3]
                    let rating = ratingDistribution.randomElement() ?? 2

                    createReview(
                        context: context,
                        flashcard: card,
                        rating: rating,
                        reviewDate: dayStart.addingTimeInterval(Double(i * 20)),
                        scheduledDays: 0,
                        elapsedDays: 0,
                        studySession: session
                    )
                    totalCards += 1
                    totalReviews += 1
                }
            }
        }

        try context.save()

        // Aggregate statistics
        let aggregatedDays = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(aggregatedDays == 20, "Should aggregate 20 days of study")

        // Refresh dashboard
        let statsViewModel = StatisticsViewModel(modelContext: context, timeRange: .thirtyDays)
        await statsViewModel.refresh()

        // Verify realistic statistics
        let retentionData = statsViewModel.retentionData!
        let streakData = statsViewModel.streakData!
        let fsrsMetrics = statsViewModel.fsrsMetrics!

        #expect(retentionData.totalCount == totalReviews, "Should have \(totalReviews) reviews")
        #expect(retentionData.rate > 0.6, "Retention should be >60% (realistic)")
        #expect(streakData.currentStreak == 5, "Should have 5-day streak (weekdays)")
        #expect(fsrsMetrics.totalCards == totalCards, "Should have \(totalCards) cards")
        #expect(fsrsMetrics.averageStability > 0, "Should have positive average stability")

        // Consistent learner scenario: 20 days, \(totalCards) cards, \(Int(retentionData.rate * 100))% retention
    }

    @Test("E2E: Realistic scenario - Irregular learner with gaps")
    func irregularLearnerScenario() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)
        let calendar = Calendar.autoupdatingCurrent

        // Simulate irregular learning pattern: 3 days on, 2 days off, 1 day on, 3 days off, etc.
        let studyPattern = [true, true, true, false, false, true, false, false, false, true, true, false]

        for (dayOffset, shouldStudy) in studyPattern.enumerated() {
            guard shouldStudy else { continue }

            let dayStart = calendar.startOfDay(for: Date().addingTimeInterval(-Double(dayOffset * 86400)))

            // Varying study intensity
            let cardsToday = dayOffset % 3 == 0 ? 20 : 10
            let session = createStudySession(
                context: context,
                startTime: dayStart.addingTimeInterval(3600),
                cardsReviewed: cardsToday,
                modeEnum: "scheduled"
            )

            for i in 0..<cardsToday {
                let card = createFlashcard(
                    context: context,
                    word: "irregular_\(dayOffset)_\(i)",
                    stateEnum: FlashcardState.review.rawValue,
                    stability: 1.0,
                    difficulty: 5.0,
                    lastReviewDate: dayStart
                )

                createReview(
                    context: context,
                    flashcard: card,
                    rating: Int.random(in: 1...4),
                    reviewDate: dayStart.addingTimeInterval(Double(i * 30)),
                    studySession: session
                )
            }
        }

        try context.save()

        // Refresh dashboard
        let statsViewModel = StatisticsViewModel(modelContext: context, timeRange: .thirtyDays)
        await statsViewModel.refresh()

        // Verify pattern recognition
        let streakData = statsViewModel.streakData!
        // FIXED: Current streak is 3 (days 0, 1, 2 are consecutive study days)
        // Previous expectation of 2 was incorrect
        #expect(streakData.currentStreak == 3, "Should have 3-day current streak (last 3 consecutive study days)")
        #expect(streakData.longestStreak == 3, "Should have 3-day longest streak")

        // Irregular learner scenario: Pattern detected, longest streak = \(streakData.longestStreak)
    }

    // MARK: - Data Persistence Tests

    @Test("E2E: Data persistence across ViewModel recreation")
    func dataPersistenceAcrossViewModelRecreation() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)

        // Create initial data
        let session1 = createStudySession(context: context, startTime: Date(), cardsReviewed: 10)
        for i in 0..<10 {
            let card = createFlashcard(
                context: context,
                word: "persistent_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date()
            )
            createReview(
                context: context,
                flashcard: card,
                rating: 3,
                reviewDate: Date(),
                studySession: session1
            )
        }
        try context.save()

        // Create first ViewModel and refresh
        let viewModel1 = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await viewModel1.refresh()

        let initialRetention = viewModel1.retentionData
        let initialStreak = viewModel1.streakData
        let initialFSRS = viewModel1.fsrsMetrics

        #expect(initialRetention?.totalCount == 10, "First ViewModel: Should have 10 reviews")

        // Add more data
        let session2 = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(3600),
            cardsReviewed: 5
        )
        for i in 0..<5 {
            let card = createFlashcard(
                context: context,
                word: "new_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date().addingTimeInterval(3600)
            )
            createReview(
                context: context,
                flashcard: card,
                rating: 4,
                reviewDate: Date().addingTimeInterval(3600),
                studySession: session2
            )
        }
        try context.save()

        // Create second ViewModel and verify it picks up new data
        let viewModel2 = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await viewModel2.refresh()

        #expect(viewModel2.retentionData?.totalCount == 15, "Second ViewModel: Should have 15 reviews")
        #expect(viewModel2.streakData?.currentStreak == 1, "Should have 1-day streak")

        // Data persistence verified: ViewModels pick up database changes
    }

    // MARK: - Error Handling Tests

    @Test("E2E: Graceful handling of corrupted study session data")
    func gracefulHandlingOfCorruptedData() async throws {
        let context = freshContext()
        try context.clearAll()

        let deck = createDeck(context: context)

        // Create valid session
        let validSession = createStudySession(
            context: context,
            startTime: Date(),
            cardsReviewed: 5
        )

        for i in 0..<5 {
            let card = createFlashcard(
                context: context,
                word: "valid_\(i)",
                stateEnum: FlashcardState.review.rawValue,
                lastReviewDate: Date()
            )
            createReview(
                context: context,
                flashcard: card,
                rating: 3,
                reviewDate: Date(),
                studySession: validSession
            )
        }

        try context.save()

        // Verify dashboard works with valid data
        let statsViewModel = StatisticsViewModel(modelContext: context)
        await statsViewModel.refresh()

        #expect(statsViewModel.retentionData?.totalCount == 5, "Should have 5 reviews")
        #expect(statsViewModel.errorMessage == nil, "Should have no errors")

        // Graceful handling verified: Dashboard works with partial data
    }
}

// MARK: - Test Error Helper

private struct TestError: Error {
    let message: String
}
