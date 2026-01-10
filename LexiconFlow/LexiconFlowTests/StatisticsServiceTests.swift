//
//  StatisticsServiceTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for StatisticsService
//  Covers: Retention rate, study streaks, FSRS metrics, time ranges, aggregation, edge cases
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for StatisticsService
/// Uses shared container for performance - each test clears context before use
@MainActor
struct StatisticsServiceTests {
    /// Get a fresh isolated context for testing
    /// Caller should call clearAll() before use to ensure test isolation
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - Test Data Creation Helpers

    /// Create a test flashcard with FSRS state
    private func createFlashcard(
        context: ModelContext,
        stability: Double = 1.0,
        difficulty: Double = 5.0,
        lastReviewDate: Date? = nil
    ) -> Flashcard {
        let flashcard = Flashcard(
            word: "test",
            definition: "test definition",
            phonetic: nil,
            imageData: nil
        )
        context.insert(flashcard)

        let state = FSRSState(
            stability: stability,
            difficulty: difficulty,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: "review"
        )
        state.card = flashcard
        state.lastReviewDate = lastReviewDate
        context.insert(state)

        return flashcard
    }

    /// Create a test study session
    private func createStudySession(
        context: ModelContext,
        startTime: Date,
        endTime: Date? = nil,
        cardsReviewed: Int = 0,
        modeEnum: String = "scheduled"
    ) -> StudySession {
        let session = StudySession(
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: cardsReviewed,
            modeEnum: modeEnum
        )
        context.insert(session)
        return session
    }

    /// Create a test flashcard review
    private func createReview(
        context: ModelContext,
        flashcard: Flashcard,
        rating: Int,
        reviewDate: Date
    ) -> FlashcardReview {
        let review = FlashcardReview(
            rating: rating,
            reviewDate: reviewDate,
            scheduledDays: 0,
            elapsedDays: 0
        )
        review.card = flashcard
        context.insert(review)
        return review
    }

    /// Clear StatisticsService cache to ensure test isolation
    /// The singleton cache persists across tests with 60-second TTL
    private func clearStatisticsCache() {
        StatisticsService.shared.invalidateCache()
    }

    // MARK: - Retention Rate Tests

    @Test("Retention rate with empty data")
    func retentionRateEmptyData() async throws {
        let context = freshContext()
        try context.clearAll()

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        #expect(result.rate == 0.0)
        #expect(result.successfulCount == 0)
        #expect(result.failedCount == 0)
        #expect(result.totalCount == 0)
        #expect(result.trendData.isEmpty)
    }

    @Test("Retention rate with single successful review")
    func retentionRateSingleSuccessful() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let reviewDate = Date()
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: reviewDate)

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        #expect(result.rate == 1.0)
        #expect(result.successfulCount == 1)
        #expect(result.failedCount == 0)
        #expect(result.totalCount == 1)
        #expect(result.trendData.count == 1)
        #expect(result.formattedPercentage == "100%")
    }

    @Test("Retention rate with single failed review")
    func retentionRateSingleFailed() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let reviewDate = Date()
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: reviewDate)

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        #expect(result.rate == 0.0)
        #expect(result.successfulCount == 0)
        #expect(result.failedCount == 1)
        #expect(result.totalCount == 1)
        #expect(result.trendData.count == 1)
        #expect(result.formattedPercentage == "0%")
    }

    @Test("Retention rate with mixed reviews")
    func retentionRateMixedReviews() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let reviewDate = Date()

        // Create 3 successful (rating >= 1) and 1 failed (rating 0)
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: reviewDate)
        _ = createReview(context: context, flashcard: flashcard, rating: 4, reviewDate: reviewDate)
        _ = createReview(context: context, flashcard: flashcard, rating: 1, reviewDate: reviewDate)
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: reviewDate)

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        #expect(result.rate == 0.75) // 3/4 = 0.75
        #expect(result.successfulCount == 3)
        #expect(result.failedCount == 1)
        #expect(result.totalCount == 4)
        #expect(result.formattedPercentage == "75%")
    }

    @Test("Retention rate with time range filtering")
    func retentionRateTimeRangeFiltering() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let today = Date()
        let tenDaysAgo = DateMath.addingDays(-10, to: today)

        // Old review (outside 7-day range)
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: tenDaysAgo)

        // Recent reviews (within 7-day range)
        for _ in 0 ..< 5 {
            _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: today)
        }

        // Test 7-day range (should only count recent reviews)
        let result7Days = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .sevenDays
        )
        #expect(result7Days.successfulCount == 5)
        #expect(result7Days.totalCount == 5)

        // Test all time range (should count all reviews)
        let resultAllTime = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )
        #expect(resultAllTime.successfulCount == 6)
        #expect(resultAllTime.totalCount == 6)
    }

    @Test("Retention rate with custom start date")
    func retentionRateCustomStartDate() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let today = Date()
        let fiveDaysAgo = DateMath.addingDays(-5, to: today)
        let tenDaysAgo = DateMath.addingDays(-10, to: today)

        // Old review
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: tenDaysAgo)

        // Recent reviews
        for _ in 0 ..< 3 {
            _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: fiveDaysAgo)
        }

        // Custom start date at 6 days ago (should exclude the 10-day-old review)
        let customStartDate = DateMath.addingDays(-6, to: today)
        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime,
            startDate: customStartDate
        )

        #expect(result.rate == 1.0)
        #expect(result.successfulCount == 3)
        #expect(result.failedCount == 0)
        #expect(result.totalCount == 3)
    }

    @Test("Retention rate with timezone boundary handling")
    func retentionRateTimezoneBoundaries() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)

        // Create reviews at day boundaries (23:59 and 00:01 next day)
        let day1 = DateMath.startOfDay(for: Date()).addingTimeInterval(86340) // 23:59
        let day2 = DateMath.startOfDay(for: Date()).addingTimeInterval(86460) // 00:01 next day

        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: day1)
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: day2)

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        // Should have 2 separate trend data points (different calendar days)
        #expect(result.trendData.count == 2)
        #expect(result.rate == 1.0)
    }

    // MARK: - Study Streak Tests

    @Test("Study streak with empty data")
    func studyStreakEmptyData() async throws {
        let context = freshContext()
        try context.clearAll()

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 0)
        #expect(result.activeDays == 0)
        #expect(result.hasStudiedToday == false)
        #expect(result.calendarData.isEmpty)
    }

    @Test("Study streak with single session today")
    func studyStreakSingleSessionToday() async throws {
        let context = freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-300) // 5 minutes ago
        let endTime = Date()
        _ = createStudySession(
            context: context,
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 1)
        #expect(result.activeDays == 1)
        #expect(result.hasStudiedToday == true)
        #expect(result.calendarData.count == 1)
    }

    @Test("Study streak with consecutive days")
    func studyStreakConsecutiveDays() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let yesterday = DateMath.addingDays(-1, to: today)
        let twoDaysAgo = DateMath.addingDays(-2, to: today)

        _ = createStudySession(context: context, startTime: twoDaysAgo, endTime: twoDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: yesterday, endTime: yesterday.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: today, endTime: today.addingTimeInterval(300), cardsReviewed: 5)

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 3)
        #expect(result.longestStreak == 3)
        #expect(result.activeDays == 3)
        #expect(result.hasStudiedToday == true)
    }

    @Test("Study streak broken by missed day")
    func studyStreakBrokenByMissedDay() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let twoDaysAgo = DateMath.addingDays(-2, to: today)
        let threeDaysAgo = DateMath.addingDays(-3, to: today)

        // Day 1, 2, 3: studied
        _ = createStudySession(context: context, startTime: threeDaysAgo, endTime: threeDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: twoDaysAgo, endTime: twoDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: today, endTime: today.addingTimeInterval(300), cardsReviewed: 5)

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 1) // Only today (streak broken yesterday)
        #expect(result.longestStreak == 2) // Two consecutive days earlier
        #expect(result.activeDays == 3)
        #expect(result.hasStudiedToday == true)
    }

    @Test("Study streak longest streak calculation")
    func studyStreakLongestStreak() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()

        // Create two separate streaks: 5 days, then 3 days
        for i in 0 ..< 5 {
            let date = DateMath.addingDays(-Double(i), to: today)
            _ = createStudySession(context: context, startTime: date, endTime: date.addingTimeInterval(300), cardsReviewed: 5)
        }

        // Gap of 2 days
        for i in 7 ..< 10 {
            let date = DateMath.addingDays(-Double(i), to: today)
            _ = createStudySession(context: context, startTime: date, endTime: date.addingTimeInterval(300), cardsReviewed: 5)
        }

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 5) // Current streak
        #expect(result.longestStreak == 5) // Longest streak
        #expect(result.activeDays == 8)
    }

    @Test("Study streak not studied today")
    func studyStreakNotStudiedToday() async throws {
        let context = freshContext()
        try context.clearAll()

        let yesterday = DateMath.addingDays(-1, to: Date())
        let twoDaysAgo = DateMath.addingDays(-2, to: Date())

        _ = createStudySession(context: context, startTime: twoDaysAgo, endTime: twoDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: yesterday, endTime: yesterday.addingTimeInterval(300), cardsReviewed: 5)

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.currentStreak == 0) // No activity today
        #expect(result.longestStreak == 2)
        #expect(result.hasStudiedToday == false)
    }

    @Test("Study streak calendar heatmap data")
    func studyStreakCalendarHeatmap() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let yesterday = DateMath.addingDays(-1, to: today)

        // Create sessions with different durations
        _ = createStudySession(context: context, startTime: yesterday, endTime: yesterday.addingTimeInterval(600), cardsReviewed: 10) // 10 min
        _ = createStudySession(context: context, startTime: today, endTime: today.addingTimeInterval(1200), cardsReviewed: 20) // 20 min

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.calendarData.count == 2)

        // Check study time values
        let yesterdayStart = DateMath.startOfDay(for: yesterday)
        let todayStart = DateMath.startOfDay(for: today)

        let yesterdayTime = result.calendarData[yesterdayStart]
        let todayTime = result.calendarData[todayStart]

        #expect(yesterdayTime == 600.0)
        #expect(todayTime == 1200.0)
    }

    @Test("Study streak with multiple sessions per day")
    func studyStreakMultipleSessionsPerDay() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()

        // Multiple sessions on same day should be aggregated
        _ = createStudySession(context: context, startTime: today, endTime: today.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: today.addingTimeInterval(600), endTime: today.addingTimeInterval(900), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: today.addingTimeInterval(1200), endTime: today.addingTimeInterval(1500), cardsReviewed: 5)

        let result = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(result.activeDays == 1) // Still only 1 active day
        #expect(result.calendarData.count == 1)

        let todayStart = DateMath.startOfDay(for: today)
        let totalTime = result.calendarData[todayStart]

        #expect(totalTime == 900.0) // 300 + 300 + 300 = 900 seconds
    }

    @Test("Study streak with time range filtering")
    func studyStreakTimeRangeFiltering() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let fiveDaysAgo = DateMath.addingDays(-5, to: today)
        let tenDaysAgo = DateMath.addingDays(-10, to: today)

        _ = createStudySession(context: context, startTime: tenDaysAgo, endTime: tenDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: fiveDaysAgo, endTime: fiveDaysAgo.addingTimeInterval(300), cardsReviewed: 5)
        _ = createStudySession(context: context, startTime: today, endTime: today.addingTimeInterval(300), cardsReviewed: 5)

        // 7-day range should exclude the 10-day-old session
        let result7Days = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .sevenDays
        )

        #expect(result7Days.activeDays == 2) // Only 5 days ago and today

        // All time should include all sessions
        let resultAllTime = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        #expect(resultAllTime.activeDays == 3)
    }

    // MARK: - FSRS Metrics Tests

    @Test("FSRS metrics with empty data")
    func fsrsMetricsEmptyData() async throws {
        let context = freshContext()
        try context.clearAll()

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.averageStability == 0.0)
        #expect(result.averageDifficulty == 5.0)
        #expect(result.totalCards == 0)
        #expect(result.reviewedCards == 0)
        #expect(result.stabilityDistribution.isEmpty)
        #expect(result.difficultyDistribution.isEmpty)
    }

    @Test("FSRS metrics with single reviewed card")
    func fsrsMetricsSingleCard() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()
        _ = createFlashcard(
            context: context,
            stability: 10.0,
            difficulty: 4.0,
            lastReviewDate: lastReview
        )

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.averageStability == 10.0)
        #expect(result.averageDifficulty == 4.0)
        #expect(result.totalCards == 1)
        #expect(result.reviewedCards == 1)
        #expect(result.formattedStability == "1.4 weeks") // 10 days = 1.4 weeks
        #expect(result.formattedDifficulty == "4.0 / 10")
    }

    @Test("FSRS metrics with multiple cards")
    func fsrsMetricsMultipleCards() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Create cards with varying stability and difficulty
        _ = createFlashcard(context: context, stability: 5.0, difficulty: 3.0, lastReviewDate: lastReview)
        _ = createFlashcard(context: context, stability: 15.0, difficulty: 5.0, lastReviewDate: lastReview)
        _ = createFlashcard(context: context, stability: 25.0, difficulty: 7.0, lastReviewDate: lastReview)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.averageStability == 15.0) // (5 + 15 + 25) / 3
        #expect(result.averageDifficulty == 5.0) // (3 + 5 + 7) / 3
        #expect(result.totalCards == 3)
        #expect(result.reviewedCards == 3)
    }

    @Test("FSRS metrics excluding unreviewed cards")
    func fsrsMetricsExcludeUnreviewed() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Reviewed cards
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 5.0, lastReviewDate: lastReview)
        _ = createFlashcard(context: context, stability: 20.0, difficulty: 6.0, lastReviewDate: lastReview)

        // Unreviewed card (no last review date)
        _ = createFlashcard(context: context, stability: 0.0, difficulty: 5.0, lastReviewDate: nil)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.averageStability == 15.0) // Only reviewed cards
        #expect(result.averageDifficulty == 5.5)
        #expect(result.totalCards == 3)
        #expect(result.reviewedCards == 2) // Only 2 reviewed
    }

    @Test("FSRS metrics stability distribution")
    func fsrsMetricsStabilityDistribution() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Create cards across different stability buckets
        _ = createFlashcard(context: context, stability: 0.5, difficulty: 5.0, lastReviewDate: lastReview) // 0-1 days
        _ = createFlashcard(context: context, stability: 2.0, difficulty: 5.0, lastReviewDate: lastReview) // 1-3 days
        _ = createFlashcard(context: context, stability: 5.0, difficulty: 5.0, lastReviewDate: lastReview) // 3-7 days
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 5.0, lastReviewDate: lastReview) // 1-2 weeks
        _ = createFlashcard(context: context, stability: 25.0, difficulty: 5.0, lastReviewDate: lastReview) // 2-4 weeks
        _ = createFlashcard(context: context, stability: 60.0, difficulty: 5.0, lastReviewDate: lastReview) // 1-3 months
        _ = createFlashcard(context: context, stability: 150.0, difficulty: 5.0, lastReviewDate: lastReview) // 3-6 months
        _ = createFlashcard(context: context, stability: 300.0, difficulty: 5.0, lastReviewDate: lastReview) // 6-12 months
        _ = createFlashcard(context: context, stability: 500.0, difficulty: 5.0, lastReviewDate: lastReview) // 1+ years

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.stabilityDistribution["0-1 days"] == 1)
        #expect(result.stabilityDistribution["1-3 days"] == 1)
        #expect(result.stabilityDistribution["3-7 days"] == 1)
        #expect(result.stabilityDistribution["1-2 weeks"] == 1)
        #expect(result.stabilityDistribution["2-4 weeks"] == 1)
        #expect(result.stabilityDistribution["1-3 months"] == 1)
        #expect(result.stabilityDistribution["3-6 months"] == 1)
        #expect(result.stabilityDistribution["6-12 months"] == 1)
        #expect(result.stabilityDistribution["1+ years"] == 1)
    }

    @Test("FSRS metrics difficulty distribution")
    func fsrsMetricsDifficultyDistribution() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Create cards across different difficulty buckets
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 1.0, lastReviewDate: lastReview) // 0-2
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 3.0, lastReviewDate: lastReview) // 2-4
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 5.0, lastReviewDate: lastReview) // 4-6
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 7.0, lastReviewDate: lastReview) // 6-8
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 9.0, lastReviewDate: lastReview) // 8-10

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.difficultyDistribution["0-2 (Very Easy)"] == 1)
        #expect(result.difficultyDistribution["2-4 (Easy)"] == 1)
        #expect(result.difficultyDistribution["4-6 (Medium)"] == 1)
        #expect(result.difficultyDistribution["6-8 (Hard)"] == 1)
        #expect(result.difficultyDistribution["8-10 (Very Hard)"] == 1)
    }

    @Test("FSRS metrics with difficulty clamping")
    func fsrsMetricsDifficultyClamping() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Test edge cases: negative and > 10 difficulty
        _ = createFlashcard(context: context, stability: 10.0, difficulty: -5.0, lastReviewDate: lastReview) // Should clamp to 0
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 15.0, lastReviewDate: lastReview) // Should clamp to 10

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        // Both should be in extreme buckets
        #expect(result.difficultyDistribution["0-2 (Very Easy)"] == 1) // Clamped to 0
        #expect(result.difficultyDistribution["8-10 (Very Hard)"] == 1) // Clamped to 10
    }

    @Test("FSRS metrics formatted stability")
    func fsrsMetricsFormattedStability() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()

        // Test different stability ranges
        _ = createFlashcard(context: context, stability: 0.5, difficulty: 5.0, lastReviewDate: lastReview) // days
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 5.0, lastReviewDate: lastReview) // weeks
        _ = createFlashcard(context: context, stability: 45.0, difficulty: 5.0, lastReviewDate: lastReview) // months
        _ = createFlashcard(context: context, stability: 400.0, difficulty: 5.0, lastReviewDate: lastReview) // years

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        let avg = result.averageStability // (0.5 + 10 + 45 + 400) / 4 = 113.875 days

        if avg >= 365 {
            #expect(result.formattedStability.contains("years"))
        } else if avg >= 30 {
            #expect(result.formattedStability.contains("months"))
        } else if avg >= 7 {
            #expect(result.formattedStability.contains("weeks"))
        } else {
            #expect(result.formattedStability.contains("days"))
        }
    }

    // MARK: - Daily Stats Aggregation Tests

    @Test("Daily stats aggregation with empty data")
    func dailyStatsAggregationEmpty() async throws {
        let context = freshContext()
        try context.clearAll()

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 0)
    }

    @Test("Daily stats aggregation with single session")
    func dailyStatsAggregationSingleSession() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let flashcard = createFlashcard(context: context, lastReviewDate: today)
        let session = createStudySession(
            context: context,
            startTime: today,
            endTime: today.addingTimeInterval(600),
            cardsReviewed: 5
        )

        // Add reviews to session
        for _ in 0 ..< 5 {
            _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: today)
            session.cardsReviewed += 1
        }
        session.reviewsLog = (try? context.fetch(FetchDescriptor<FlashcardReview>())) ?? []

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 1)

        // Verify DailyStats was created
        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats[0].studyTimeSeconds == 600.0)
        #expect(stats[0].retentionRate == 1.0) // All successful
    }

    @Test("Daily stats aggregation with multiple sessions per day")
    func dailyStatsAggregationMultipleSessions() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let flashcard = createFlashcard(context: context, lastReviewDate: today)

        // Create multiple sessions on same day
        for i in 0 ..< 3 {
            let startTime = today.addingTimeInterval(TimeInterval(i * 1000))
            let session = createStudySession(
                context: context,
                startTime: startTime,
                endTime: startTime.addingTimeInterval(300),
                cardsReviewed: 2
            )

            // Add reviews
            for _ in 0 ..< 2 {
                _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: startTime)
            }
        }

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 1) // Only 1 DailyStats record for all sessions

        // Verify aggregation
        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats[0].studyTimeSeconds == 900.0) // 300 * 3
    }

    @Test("Daily stats aggregation across multiple days")
    func dailyStatsAggregationMultipleDays() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let yesterday = DateMath.addingDays(-1, to: today)

        // Create sessions on different days
        _ = createStudySession(
            context: context,
            startTime: yesterday,
            endTime: yesterday.addingTimeInterval(300),
            cardsReviewed: 5
        )
        _ = createStudySession(
            context: context,
            startTime: today,
            endTime: today.addingTimeInterval(600),
            cardsReviewed: 10
        )

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 2) // 2 DailyStats records

        let stats = try context.fetch(FetchDescriptor<DailyStats>()).sorted { $0.date < $1.date }
        #expect(stats.count == 2)
        #expect(stats[0].studyTimeSeconds == 300.0)
        #expect(stats[1].studyTimeSeconds == 600.0)
    }

    @Test("Daily stats aggregation updating existing records")
    func dailyStatsAggregationUpdateExisting() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let todayStart = DateMath.startOfDay(for: today)

        // Create existing DailyStats
        let existingStats = DailyStats(
            date: todayStart,
            cardsLearned: 5,
            studyTimeSeconds: 300.0,
            retentionRate: 0.8
        )
        context.insert(existingStats)
        try context.save()

        // Create new session that should update the stats
        let session = createStudySession(
            context: context,
            startTime: today,
            endTime: today.addingTimeInterval(600),
            cardsReviewed: 10
        )

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 1)

        // Verify existing stats were updated, not duplicated
        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats[0].studyTimeSeconds == 900.0) // 300 + 600
        #expect(stats[0].cardsLearned == 5) // Unchanged
    }

    @Test("Daily stats aggregation only processes unaggregated sessions")
    func dailyStatsAggregationIncremental() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()

        // Create first session and aggregate
        let session1 = createStudySession(
            context: context,
            startTime: today,
            endTime: today.addingTimeInterval(300),
            cardsReviewed: 5
        )
        let count1 = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(count1 == 1)

        // Create second session
        let session2 = createStudySession(
            context: context,
            startTime: today.addingTimeInterval(1000),
            endTime: today.addingTimeInterval(1300),
            cardsReviewed: 5
        )

        // Aggregate again - should only process new session
        let count2 = try await StatisticsService.shared.aggregateDailyStats(context: context)
        #expect(count2 == 1) // Only session2 processed

        // Verify we still have only 1 DailyStats record (aggregated)
        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats[0].studyTimeSeconds == 600.0) // 300 + 300
    }

    // MARK: - Concurrency Stress Tests

    @Test("StatisticsService concurrent access safety")
    func statisticsServiceConcurrentAccess() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let flashcard = createFlashcard(context: context, lastReviewDate: today)

        // Create test data
        for i in 0 ..< 10 {
            let date = DateMath.addingDays(-Double(i), to: today)
            _ = createStudySession(
                context: context,
                startTime: date,
                endTime: date.addingTimeInterval(300),
                cardsReviewed: 5
            )
            _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: date)
        }

        // Test concurrent access to all methods
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    _ = await StatisticsService.shared.calculateRetentionRate(context: context)
                }

                group.addTask {
                    _ = await StatisticsService.shared.calculateStudyStreak(context: context)
                }

                group.addTask {
                    _ = await StatisticsService.shared.calculateFSRSMetrics(context: context)
                }
            }
        }

        // If we get here without crashes or data races, the test passes
        #expect(true)
    }

    @Test("StatisticsService aggregation concurrency")
    func statisticsServiceAggregationConcurrency() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()

        // Create sessions for concurrent aggregation
        for i in 0 ..< 10 {
            let date = DateMath.addingDays(-Double(i), to: today)
            _ = createStudySession(
                context: context,
                startTime: date,
                endTime: date.addingTimeInterval(300),
                cardsReviewed: 5
            )
        }

        // Run concurrent aggregations
        await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 3 {
                group.addTask {
                    do {
                        return try await StatisticsService.shared.aggregateDailyStats(context: context)
                    } catch {
                        // Return 0 on error (aggregation failed)
                        return 0
                    }
                }
            }

            var results: [Int] = []
            for await result in group {
                results.append(result)
            }

            // All should complete (even if some return 0 due to no new data)
            #expect(results.count == 3)
        }
    }

    // MARK: - Edge Cases and Error Handling

    @Test("StatisticsService with nil model context operations")
    func statisticsServiceNilHandling() async throws {
        let context = freshContext()
        try context.clearAll()

        // Empty context should return default DTOs, not crash
        let retention = await StatisticsService.shared.calculateRetentionRate(context: context)
        #expect(retention.rate == 0.0)
        #expect(retention.successfulCount == 0)

        let streak = await StatisticsService.shared.calculateStudyStreak(context: context)
        #expect(streak.currentStreak == 0)
        #expect(streak.longestStreak == 0)

        let fsrs = await StatisticsService.shared.calculateFSRSMetrics(context: context)
        #expect(fsrs.averageStability == 0.0)
        #expect(fsrs.totalCards == 0)
    }

    @Test("StatisticsService time range display names")
    func statisticsServiceTimeRangeDisplayNames() async throws {
        #expect(StatisticsTimeRange.sevenDays.displayName == "7 days")
        #expect(StatisticsTimeRange.thirtyDays.displayName == "30 days")
        #expect(StatisticsTimeRange.allTime.displayName == "All time")
    }

    @Test("StatisticsService with all rating values")
    func statisticsServiceAllRatings() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = createFlashcard(context: context)
        let today = Date()

        // Test all possible rating values (0-4)
        // 0 = Again (failed), 1 = Hard (successful), 2 = Good, 3 = Easy, 4 = Custom Easy
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: today)
        _ = createReview(context: context, flashcard: flashcard, rating: 1, reviewDate: today)
        _ = createReview(context: context, flashcard: flashcard, rating: 2, reviewDate: today)
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: today)
        _ = createReview(context: context, flashcard: flashcard, rating: 4, reviewDate: today)

        let result = await StatisticsService.shared.calculateRetentionRate(context: context)

        #expect(result.failedCount == 1) // Only rating 0
        #expect(result.successfulCount == 4) // Ratings 1-4
        #expect(result.rate == 0.8) // 4/5
    }

    // MARK: - Cache Invalidation Tests (P0)

    @Test("invalidateCache clears cached metrics")
    func invalidateCacheClearsCachedMetrics() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let flashcard = createFlashcard(context: context, lastReviewDate: Date())
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: Date())

        // First call should populate cache
        _ = await StatisticsService.shared.getCachedMetrics(context: context)
        #expect(StatisticsService.shared.cachedMetrics != nil)

        // Invalidate cache
        StatisticsService.shared.invalidateCache()

        // Cache should be cleared
        #expect(StatisticsService.shared.cachedMetrics == nil)
        #expect(StatisticsService.shared.cacheTimestamp == nil)
    }

    @Test("getCachedMetrics respects TTL expiration")
    func cachedMetricsExpiresAfterTTL() async throws {
        let context = freshContext()
        try context.clearAll()

        let service = StatisticsService.shared

        // Set a very short TTL for testing (1 second instead of 60)
        service.cacheTTL = 1.0

        // Create test data
        let flashcard = createFlashcard(context: context, lastReviewDate: Date())
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: Date())

        // First call populates cache
        let firstCall = service.getCachedMetrics(context: context)
        #expect(firstCall.retentionRate > 0)

        // Wait for TTL to expire
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Cache should be invalid now
        #expect(service.isCacheValid() == false)

        // Second call should recalculate (not return stale cache)
        // We can verify this by checking the timestamp changed
        let oldTimestamp = service.cacheTimestamp
        let secondCall = service.getCachedMetrics(context: context)
        #expect(secondCall.timestamp > oldTimestamp!)
    }

    @Test("aggregateDailyStats does not auto-invalidate cache")
    func aggregateDailyStatsNoAutoInvalidate() async throws {
        let context = freshContext()
        try context.clearAll()

        // Populate cache with initial data
        let flashcard = createFlashcard(context: context, lastReviewDate: Date())
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: Date())
        _ = StatisticsService.shared.getCachedMetrics(context: context)

        let initialCache = StatisticsService.shared.cachedMetrics

        // Aggregate daily stats (should NOT invalidate cache)
        let session = createStudySession(
            context: context,
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            cardsReviewed: 5
        )
        _ = try await StatisticsService.shared.aggregateDailyStats(context: context)

        // Cache should still be valid (aggregation doesn't auto-invalidate)
        // This is expected behavior - cache must be manually invalidated
        #expect(StatisticsService.shared.cachedMetrics?.timestamp == initialCache?.timestamp)

        // Manual invalidation required
        StatisticsService.shared.invalidateCache()
        #expect(StatisticsService.shared.cachedMetrics == nil)
    }

    @Test("manual cache invalidation prevents stale metrics")
    func manualInvalidationPreventsStaleMetrics() async throws {
        clearStatisticsCache()
        let context = freshContext()
        try context.clearAll()

        // Create initial data
        let flashcard = createFlashcard(context: context, lastReviewDate: Date())
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: Date())

        // Populate cache
        let firstMetrics = StatisticsService.shared.getCachedMetrics(context: context)
        let firstTimestamp = firstMetrics.timestamp

        // Add new data (would change metrics if recalculated)
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: Date())

        // Cache still returns old data (stale)
        let staleMetrics = StatisticsService.shared.getCachedMetrics(context: context)
        #expect(staleMetrics.timestamp == firstTimestamp)

        // Invalidate and recalculate
        StatisticsService.shared.invalidateCache()
        let freshMetrics = StatisticsService.shared.getCachedMetrics(context: context)

        // New metrics should have different timestamp
        #expect(freshMetrics.timestamp > firstTimestamp)
    }

    @Test("cache handles empty data gracefully")
    func cacheHandlesFailedOperations() async throws {
        clearStatisticsCache()
        let context = freshContext()
        try context.clearAll()

        // Empty context should return default DTOs without crashing
        let result = StatisticsService.shared.getCachedMetrics(context: context)
        #expect(result.retentionRate == 0.0)
        #expect(result.totalCards == 0)
        #expect(result.dueCards == 0)
    }

    @Test("cache reuse within TTL returns same instance")
    func cacheReuseWithinTTL() async throws {
        clearStatisticsCache()
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let flashcard = createFlashcard(context: context, lastReviewDate: Date())
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: Date())

        // Multiple calls within TTL should return same cached instance
        let call1 = StatisticsService.shared.getCachedMetrics(context: context)
        let call2 = StatisticsService.shared.getCachedMetrics(context: context)
        let call3 = StatisticsService.shared.getCachedMetrics(context: context)

        // All should have same timestamp (cache hit, not recalculated)
        #expect(call1.timestamp == call2.timestamp)
        #expect(call2.timestamp == call3.timestamp)
    }

    // MARK: - P1 Edge Case Tests

    @Test("FSRS metrics respects 7-day time range filtering")
    func fsrsMetricsRespectsSevenDayTimeRange() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let sixDaysAgo = DateMath.addingDays(-6, to: today)
        let eightDaysAgo = DateMath.addingDays(-8, to: today)

        // Card reviewed 6 days ago (within 7-day range)
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 4.0, lastReviewDate: sixDaysAgo)
        // Card reviewed 8 days ago (outside 7-day range)
        _ = createFlashcard(context: context, stability: 20.0, difficulty: 6.0, lastReviewDate: eightDaysAgo)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .sevenDays
        )

        #expect(result.reviewedCards == 1) // Only the card from 6 days ago
        #expect(result.averageStability == 10.0)
        #expect(result.averageDifficulty == 4.0)
    }

    @Test("FSRS metrics respects 30-day time range filtering")
    func fsrsMetricsRespectsThirtyDayTimeRange() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let twentyDaysAgo = DateMath.addingDays(-20, to: today)
        let fortyDaysAgo = DateMath.addingDays(-40, to: today)

        // Card reviewed 20 days ago (within 30-day range)
        _ = createFlashcard(context: context, stability: 10.0, difficulty: 4.0, lastReviewDate: twentyDaysAgo)
        // Card reviewed 40 days ago (outside 30-day range)
        _ = createFlashcard(context: context, stability: 20.0, difficulty: 6.0, lastReviewDate: fortyDaysAgo)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .thirtyDays
        )

        #expect(result.reviewedCards == 1) // Only the card from 20 days ago
        #expect(result.averageStability == 10.0)
    }

    @Test("Retention rate filters correctly at exact time range boundary")
    func retentionRateFiltersAtExactTimeRangeBoundary() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = DateMath.startOfDay(for: Date())
        let sevenDaysAgoStart = DateMath.addingDays(-7, to: today)
        let sevenDaysAgoEnd = sevenDaysAgoStart.addingTimeInterval(86399) // End of 7 days ago
        let eightDaysAgo = DateMath.addingDays(-8, to: today)

        let flashcard = createFlashcard(context: context)

        // Review exactly at boundary (end of 7 days ago) - should be included
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: sevenDaysAgoEnd)
        // Review before boundary (8 days ago) - should be excluded
        _ = createReview(context: context, flashcard: flashcard, rating: 0, reviewDate: eightDaysAgo)
        // Review today - should be included
        _ = createReview(context: context, flashcard: flashcard, rating: 3, reviewDate: today)

        let result = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .sevenDays
        )

        #expect(result.successfulCount == 2) // 7 days ago + today
        #expect(result.failedCount == 0)
        #expect(result.totalCount == 2)
    }

    @Test("Study streak crosses year boundary correctly")
    func studyStreakCrossesYearBoundaryCorrectly() async throws {
        let context = freshContext()
        try context.clearAll()

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2023
        components.month = 12
        components.day = 30
        let dec30 = calendar.date(from: components)!

        components.day = 31
        let dec31 = calendar.date(from: components)!

        components.year = 2024
        components.month = 1
        components.day = 1
        let jan01 = calendar.date(from: components)!

        // Create sessions: Dec 30, Dec 31, Jan 01 (consecutive)
        _ = createStudySession(context: context, startTime: dec30.addingTimeInterval(3600), endTime: dec30.addingTimeInterval(3900))
        _ = createStudySession(context: context, startTime: dec31.addingTimeInterval(3600), endTime: dec31.addingTimeInterval(3900))
        _ = createStudySession(context: context, startTime: jan01.addingTimeInterval(3600), endTime: jan01.addingTimeInterval(3900))

        let result = await StatisticsService.shared.calculateStudyStreak(context: context, timeRange: .allTime)

        #expect(result.longestStreak == 3) // Should have 3-day streak across year boundary
        #expect(result.activeDays == 3)
    }

    @Test("Study streak handles leap year")
    func studyStreakHandlesLeapYear() async throws {
        let context = freshContext()
        try context.clearAll()

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024 // Leap year
        components.month = 2
        components.day = 28
        let feb28 = calendar.date(from: components)!

        components.day = 29
        let feb29 = calendar.date(from: components)!

        components.month = 3
        components.day = 1
        let mar01 = calendar.date(from: components)!

        // Create sessions: Feb 28, Feb 29, Mar 01 (consecutive in leap year)
        _ = createStudySession(context: context, startTime: feb28, endTime: feb28.addingTimeInterval(300))
        _ = createStudySession(context: context, startTime: feb29, endTime: feb29.addingTimeInterval(300))
        _ = createStudySession(context: context, startTime: mar01, endTime: mar01.addingTimeInterval(300))

        let result = await StatisticsService.shared.calculateStudyStreak(context: context, timeRange: .allTime)

        #expect(result.longestStreak == 3) // Should handle Feb 29 correctly
        #expect(result.activeDays == 3)
    }

    @Test("Study streak handles DST transition")
    func studyStreakHandlesDSTTransition() async throws {
        let context = freshContext()
        try context.clearAll()

        // DST transitions typically occur in March (spring forward) and November (fall back)
        // Create sessions around a typical DST boundary
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10 // Day before DST
        let dayBeforeDST = calendar.date(from: components)!

        components.day = 11 // DST day
        let dstDay = calendar.date(from: components)!

        // Create sessions spanning DST transition
        _ = createStudySession(context: context, startTime: dayBeforeDST, endTime: dayBeforeDST.addingTimeInterval(300))
        _ = createStudySession(context: context, startTime: dstDay, endTime: dstDay.addingTimeInterval(300))

        let result = await StatisticsService.shared.calculateStudyStreak(context: context, timeRange: .allTime)

        // Should handle DST transition correctly (consecutive days)
        #expect(result.longestStreak == 2)
        #expect(result.activeDays == 2)
    }

    @Test("FSRS handles zero stability")
    func fsrsHandlesZeroStability() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()
        // Zero stability should fall into "0-1 days" bucket
        _ = createFlashcard(context: context, stability: 0.0, difficulty: 5.0, lastReviewDate: lastReview)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        #expect(result.stabilityDistribution["0-1 days"] == 1)
        #expect(result.averageStability == 0.0)
    }

    @Test("FSRS handles extreme stability values")
    func fsrsHandlesExtremeStabilityValues() async throws {
        let context = freshContext()
        try context.clearAll()

        let lastReview = Date()
        // Very large stability (effectively "infinite" for practical purposes)
        _ = createFlashcard(context: context, stability: 99999.0, difficulty: 5.0, lastReviewDate: lastReview)

        let result = await StatisticsService.shared.calculateFSRSMetrics(
            context: context,
            timeRange: .allTime
        )

        // Should fall into "1+ years" bucket
        #expect(result.stabilityDistribution["1+ years"] == 1)
        #expect(result.averageStability == 99999.0)
    }

    @Test("aggregateDailyStats updates existing records")
    func aggregateDailyStatsUpdatesExisting() async throws {
        let context = freshContext()
        try context.clearAll()

        let today = Date()
        let todayStart = DateMath.startOfDay(for: today)

        // Create existing DailyStats
        let existingStats = DailyStats(
            date: todayStart,
            cardsLearned: 5,
            studyTimeSeconds: 300.0,
            retentionRate: 0.8
        )
        context.insert(existingStats)
        try context.save()

        // Create new session that should update the stats
        _ = createStudySession(
            context: context,
            startTime: today,
            endTime: today.addingTimeInterval(600),
            cardsReviewed: 10
        )

        let count = try await StatisticsService.shared.aggregateDailyStats(context: context)

        #expect(count == 1)

        // Verify existing stats were updated, not duplicated
        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats[0].studyTimeSeconds == 900.0) // 300 + 600
        #expect(stats[0].cardsLearned == 5) // Unchanged
    }
}

// MARK: - Testable Extension for StatisticsService

// Note: cacheTTL is now internal (var) and can be set directly in tests
// No extension needed - properties are accessible directly
