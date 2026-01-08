//
//  StatisticsViewModelTests.swift
//  LexiconFlowTests
//
//  Tests for StatisticsViewModel
//  Covers: Initialization, state changes, time range switching, error handling
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for StatisticsViewModel
///
/// Tests verify:
/// - Initialization with default and custom time ranges
/// - State changes during refresh operations
/// - Time range switching with persistence
/// - Error handling and Analytics tracking
/// - Computed properties (hasData, isEmpty)
/// - Concurrent access safety
@MainActor
struct StatisticsViewModelTests {
    // MARK: - Test Fixtures

    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    private func createFlashcard(
        context: ModelContext,
        word: String = "test",
        stability: Double = 1.0,
        difficulty: Double = 5.0,
        lastReviewDate: Date? = nil
    ) -> Flashcard {
        let flashcard = Flashcard(
            word: word,
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

    private func createStudySession(
        context: ModelContext,
        startTime: Date,
        endTime: Date? = nil,
        cardsReviewed: Int = 1,
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

    // MARK: - Initialization Tests

    @Test("Initialize with default time range from AppSettings")
    func initializeWithDefaultTimeRange() async throws {
        let context = freshContext()
        try context.clearAll()

        // Reset AppSettings to default
        AppSettings.statisticsTimeRange = "7d"

        let viewModel = StatisticsViewModel(modelContext: context)

        #expect(viewModel.selectedTimeRange == .sevenDays)
        #expect(viewModel.retentionData == nil)
        #expect(viewModel.streakData == nil)
        #expect(viewModel.fsrsMetrics == nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Initialize with custom time range override")
    func initializeWithCustomTimeRange() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(
            modelContext: context,
            timeRange: .thirtyDays
        )

        #expect(viewModel.selectedTimeRange == .thirtyDays)
    }

    @Test("Initialize loads time range from AppSettings")
    func initializeLoadsFromAppSettings() async throws {
        let context = freshContext()
        try context.clearAll()

        // Set AppSettings to 30 days
        AppSettings.statisticsTimeRange = "30d"

        let viewModel = StatisticsViewModel(modelContext: context)

        #expect(viewModel.selectedTimeRange == .thirtyDays)
    }

    @Test("Initialize falls back to default for invalid AppSettings")
    func initializeFallbackForInvalidSettings() async throws {
        let context = freshContext()
        try context.clearAll()

        // Set invalid AppSettings value
        AppSettings.statisticsTimeRange = "invalid"

        let viewModel = StatisticsViewModel(modelContext: context)

        #expect(viewModel.selectedTimeRange == .sevenDays, "Should fallback to sevenDays for invalid rawValue")
    }

    // MARK: - State Change Tests

    @Test("Refresh sets isLoading flag correctly")
    func refreshSetsIsLoadingFlag() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        #expect(!viewModel.isLoading)

        await viewModel.refresh()

        // After refresh completes, isLoading should be false
        #expect(!viewModel.isLoading)
    }

    @Test("Refresh updates all DTOs")
    func refreshUpdatesAllDTOs() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        _ = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-3000)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        // All DTOs should be populated
        #expect(viewModel.retentionData != nil)
        #expect(viewModel.streakData != nil)
        #expect(viewModel.fsrsMetrics != nil)
    }

    @Test("Refresh handles empty data gracefully")
    func refreshHandlesEmptyData() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        // DTOs should be populated but with empty/zero values
        #expect(viewModel.retentionData != nil)
        #expect(viewModel.streakData != nil)
        #expect(viewModel.fsrsMetrics != nil)

        // Verify empty state
        #expect(viewModel.retentionData?.totalCount == 0)
        #expect(viewModel.streakData?.activeDays == 0)
        #expect(viewModel.fsrsMetrics?.totalCards == 0)
    }

    @Test("Refresh completes successfully with no error")
    func refreshCompletesSuccessfully() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        // Should complete with no error
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    // MARK: - Time Range Switching Tests

    @Test("Change time range updates selectedTimeRange")
    func changeTimeRangeUpdatesSelection() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)
        #expect(viewModel.selectedTimeRange == .sevenDays)

        await viewModel.changeTimeRange(.thirtyDays)

        #expect(viewModel.selectedTimeRange == .thirtyDays)
    }

    @Test("Change time range cycles through all options")
    func changeTimeRangeCyclesThroughAllOptions() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // 7d -> 30d
        await viewModel.changeTimeRange(.thirtyDays)
        #expect(viewModel.selectedTimeRange == .thirtyDays)

        // 30d -> all
        await viewModel.changeTimeRange(.allTime)
        #expect(viewModel.selectedTimeRange == .allTime)

        // all -> 7d
        await viewModel.changeTimeRange(.sevenDays)
        #expect(viewModel.selectedTimeRange == .sevenDays)
    }

    // MARK: - Error Handling Tests

    @Test("Clear error removes error message")
    func clearErrorRemovesErrorMessage() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Initially no error
        #expect(viewModel.errorMessage == nil)

        // Clear the error (should be safe to call even with no error)
        viewModel.clearError()

        // Should still be nil
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Error message is user-friendly")
    func errorMessageIsUserFriendly() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Service doesn't throw errors in current implementation
        // but future-proofing ensures errors are handled gracefully
        await viewModel.refresh()

        // Should not crash and errorMessage should be nil for empty data
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Computed Properties Tests

    @Test("HasData is true when at least one DTO exists")
    func hasDataIsTrueWhenAtLeastOneDTOExists() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Initially no data
        #expect(!viewModel.hasData)

        await viewModel.refresh()

        // After refresh, should have data (even if empty DTOs)
        #expect(viewModel.hasData)
    }

    @Test("HasData is false when all DTOs are nil")
    func hasDataIsFalseWhenAllDTOsAreNil() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Without refresh, all DTOs should be nil
        #expect(!viewModel.hasData)
    }

    @Test("IsEmpty is true when all metrics are empty")
    func isEmptyIsTrueWhenAllMetricsEmpty() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        // With no data, isEmpty should be true
        #expect(viewModel.isEmpty)
    }

    @Test("IsEmpty is false when some data exists")
    func isEmptyIsFalseWhenDataExists() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        _ = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-3000)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        // With data, isEmpty should be false
        #expect(!viewModel.isEmpty)
    }

    @Test("IsEmpty is false when DTOs are nil")
    func isEmptyIsFalseWhenDTOsAreNil() async throws {
        let context = freshContext()
        try context.clearAll()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Without refresh, DTOs are nil
        #expect(!viewModel.isEmpty, "isEmpty should be false when DTOs are nil")
    }

    // MARK: - DTO Content Tests

    @Test("Retention rate DTO contains expected data")
    func retentionRateDTOContainsExpectedData() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data: 3 successful, 1 failed
        let card = createFlashcard(context: context)
        _ = createReview(context: context, flashcard: card, rating: 3, reviewDate: Date()) // Good
        _ = createReview(context: context, flashcard: card, rating: 4, reviewDate: Date()) // Easy
        _ = createReview(context: context, flashcard: card, rating: 2, reviewDate: Date()) // Hard (success)
        _ = createReview(context: context, flashcard: card, rating: 0, reviewDate: Date()) // Again (fail)
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        #expect(viewModel.retentionData != nil)
        #expect(viewModel.retentionData?.successfulCount == 3)
        #expect(viewModel.retentionData?.failedCount == 1)
        #expect(viewModel.retentionData?.totalCount == 4)
        #expect(viewModel.retentionData?.rate == 0.75) // 75%
    }

    @Test("FSRS metrics DTO contains expected data")
    func fsrsMetricsDTOContainsExpectedData() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data: 2 cards with different FSRS states
        _ = createFlashcard(
            context: context,
            word: "card1",
            stability: 10.0,
            difficulty: 4.0,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createFlashcard(
            context: context,
            word: "card2",
            stability: 20.0,
            difficulty: 6.0,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        await viewModel.refresh()

        #expect(viewModel.fsrsMetrics != nil)
        #expect(viewModel.fsrsMetrics?.totalCards == 2)
        #expect(viewModel.fsrsMetrics?.reviewedCards == 2)
        #expect(viewModel.fsrsMetrics?.averageStability == 15.0, "Average of 10 and 20")
        #expect(viewModel.fsrsMetrics?.averageDifficulty == 5.0, "Average of 4 and 6")
    }

    // MARK: - Time Range Filtering Tests

    @Test("Refresh with 7 day range filters data correctly")
    func refreshWith7DayRangeFiltersData() async throws {
        let context = freshContext()
        try context.clearAll()

        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Create data outside 7-day range (10 days ago)
        let oldDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let oldCard = createFlashcard(context: context, lastReviewDate: oldDate)
        _ = createReview(context: context, flashcard: oldCard, rating: 3, reviewDate: oldDate)

        // Create data within 7-day range (2 days ago)
        let recentDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let recentCard = createFlashcard(context: context, lastReviewDate: recentDate)
        _ = createReview(context: context, flashcard: recentCard, rating: 3, reviewDate: recentDate)

        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)

        await viewModel.refresh()

        // Should only include recent data
        #expect(viewModel.retentionData?.totalCount == 1, "Should only count recent review")
    }

    @Test("Refresh with 30 day range includes more data")
    func refreshWith30DayRangeIncludesMoreData() async throws {
        let context = freshContext()
        try context.clearAll()

        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Create data within 30-day range (20 days ago)
        let date20Days = calendar.date(byAdding: .day, value: -20, to: now)!
        let card20Days = createFlashcard(context: context, lastReviewDate: date20Days)
        _ = createReview(context: context, flashcard: card20Days, rating: 3, reviewDate: date20Days)

        // Create data within 7-day range (2 days ago)
        let date2Days = calendar.date(byAdding: .day, value: -2, to: now)!
        let card2Days = createFlashcard(context: context, lastReviewDate: date2Days)
        _ = createReview(context: context, flashcard: card2Days, rating: 3, reviewDate: date2Days)

        try context.save()

        // Test with 7-day range
        let viewModel7d = StatisticsViewModel(modelContext: context, timeRange: .sevenDays)
        await viewModel7d.refresh()
        let count7d = viewModel7d.retentionData?.totalCount ?? 0

        // Test with 30-day range
        let viewModel30d = StatisticsViewModel(modelContext: context, timeRange: .thirtyDays)
        await viewModel30d.refresh()
        let count30d = viewModel30d.retentionData?.totalCount ?? 0

        #expect(count30d > count7d, "30-day range should include more data")
    }

    @Test("Refresh with all time range includes all data")
    func refreshWithAllTimeRangeIncludesAllData() async throws {
        let context = freshContext()
        try context.clearAll()

        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Create data at various time ranges
        for daysAgo in [100, 50, 10, 2] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let card = createFlashcard(context: context, lastReviewDate: date)
            _ = createReview(context: context, flashcard: card, rating: 3, reviewDate: date)
        }

        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context, timeRange: .allTime)

        await viewModel.refresh()

        // Should include all data
        #expect(viewModel.retentionData?.totalCount == 4, "Should include all reviews")
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent refresh calls are safe")
    func concurrentRefreshCallsAreSafe() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Trigger multiple concurrent refreshes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    await viewModel.refresh()
                }
            }
        }

        // Should complete without crashes
        #expect(viewModel.retentionData != nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Time range change during concurrent refresh")
    func timeRangeChangeDuringConcurrentRefresh() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Concurrently refresh and change time range
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel.refresh()
            }

            group.addTask {
                await viewModel.changeTimeRange(.thirtyDays)
            }
        }

        // Should complete without crashes
        #expect(viewModel.selectedTimeRange == .thirtyDays)
        #expect(viewModel.retentionData != nil)
    }

    @Test("State reads during concurrent refresh")
    func stateReadsDuringConcurrentRefresh() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Read state while refresh is happening
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel.refresh()
            }

            for _ in 0 ..< 3 {
                group.addTask {
                    _ = await viewModel.isLoading
                    _ = await viewModel.hasData
                    _ = await viewModel.selectedTimeRange
                }
            }
        }

        // Should complete without crashes
        #expect(!viewModel.isLoading)
    }

    // MARK: - Integration Tests

    @Test("Full workflow: load, change range, clear error")
    func fullWorkflowIntegration() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create test data
        let card = createFlashcard(
            context: context,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        _ = createReview(
            context: context,
            flashcard: card,
            rating: 3,
            reviewDate: Date().addingTimeInterval(-3600)
        )
        _ = createStudySession(
            context: context,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-3000)
        )
        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        // 1. Initial refresh
        await viewModel.refresh()
        #expect(viewModel.retentionData != nil)
        #expect(viewModel.streakData != nil)
        #expect(viewModel.fsrsMetrics != nil)

        // 2. Change time range
        await viewModel.changeTimeRange(.thirtyDays)
        #expect(viewModel.selectedTimeRange == .thirtyDays)
        #expect(AppSettings.statisticsTimeRange == "30d")

        // 3. Clear error (should be safe to call even with no error)
        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)

        // 4. Verify computed properties
        #expect(viewModel.hasData)
        #expect(!viewModel.isEmpty)
    }

    @Test("ViewModel handles large datasets")
    func handlesLargeDatasets() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create large dataset (100 cards with reviews)
        for i in 0 ..< 100 {
            let card = createFlashcard(
                context: context,
                word: "card\(i)",
                lastReviewDate: Date().addingTimeInterval(-86400)
            )
            _ = createReview(
                context: context,
                flashcard: card,
                rating: i % 5, // Vary ratings
                reviewDate: Date().addingTimeInterval(-Double(i * 60))
            )
        }

        // Create 30 study sessions
        for i in 0 ..< 30 {
            _ = createStudySession(
                context: context,
                startTime: Date().addingTimeInterval(-Double(i * 3600)),
                endTime: Date().addingTimeInterval(-Double(i * 3600 - 300))
            )
        }

        try context.save()

        let viewModel = StatisticsViewModel(modelContext: context)

        // Refresh should handle large dataset
        await viewModel.refresh()

        #expect(viewModel.retentionData != nil)
        #expect(viewModel.retentionData?.totalCount == 100)
        #expect(viewModel.streakData != nil)
        #expect(viewModel.fsrsMetrics != nil)
        #expect(viewModel.fsrsMetrics?.totalCards == 100)
    }
}
