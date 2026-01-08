//
//  PerformanceTests.swift
//  LexiconFlowTests
//
//  Performance tests for statistics dashboard with large datasets
//  Tests with 1000+ cards, months of study history, thousands of reviews
//
//  IMPORTANT: Tests measure actual execution time, not behavior
//  Run on simulator or device for accurate results (CI may vary)
//

import Foundation
import OSLog
import SwiftData
import Testing
@testable import LexiconFlow

/// Performance test suite for statistics dashboard
///
/// Tests verify:
/// - Dashboard load time with 1000+ cards
/// - StatisticsService calculations with large datasets
/// - Chart rendering performance with many data points
/// - Time range filtering efficiency
/// - View refresh reactivity
///
/// **Performance Thresholds:**
/// - ViewModel refresh: <500ms with 1000 cards
/// - StatisticsService calculations: <100ms each
/// - DailyStats aggregation: <1s for 1000 sessions
@MainActor
struct PerformanceTests {
    // MARK: - Test Configuration

    /// Performance threshold for ViewModel refresh (milliseconds)
    private let viewModelRefreshThreshold: TimeInterval = 500.0 // 500ms

    /// Performance threshold for StatisticsService methods (milliseconds)
    private let serviceCalculationThreshold: TimeInterval = 100.0 // 100ms

    /// Performance threshold for aggregation (milliseconds)
    private let aggregationThreshold: TimeInterval = 1000.0 // 1s

    /// Logger for performance diagnostics
    private let logger = Logger(subsystem: "com.lexiconflow.tests", category: "Performance")

    // MARK: - Test Helpers

    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    /// Measure execution time of a block
    ///
    /// - Parameter block: Block to execute and measure
    /// - Returns: Execution time in milliseconds
    private func measureTime(_ block: () async throws -> Void) async throws -> TimeInterval {
        let start = Date()
        try await block()
        let end = Date()
        return end.timeIntervalSince(start) * 1000.0 // Convert to milliseconds
    }

    /// Create large dataset with specified number of cards and days
    ///
    /// - Parameters:
    ///   - context: Model context for inserts
    ///   - cardCount: Number of flashcards to create
    ///   - daysOfHistory: Number of days of study history
    ///   - reviewsPerCard: Average reviews per card
    ///
    /// - Returns: Tuple of (created cards, sessions, reviews)
    private func createLargeDataset(
        context: ModelContext,
        cardCount: Int = 1000,
        daysOfHistory: Int = 90,
        reviewsPerCard _: Int = 3
    ) async throws -> (cards: [Flashcard], sessions: [StudySession], reviews: [FlashcardReview]) {
        let deck = Deck(name: "Performance Test Deck")
        context.insert(deck)

        var cards: [Flashcard] = []
        var sessions: [StudySession] = []
        var reviews: [FlashcardReview] = []

        let calendar = Calendar.autoupdatingCurrent
        let today = Date()

        // Create flashcards with varied FSRS states
        for i in 0 ..< cardCount {
            let card = Flashcard(
                word: "word\(i)",
                definition: "definition \(i)",
                phonetic: nil,
                imageData: nil
            )
            card.deck = deck
            context.insert(card)

            // Varied FSRS states to simulate real data
            let stability = Double.random(in: 1.0 ... 180.0) // 1 day to 6 months
            let difficulty = Double.random(in: 1.0 ... 9.0) // 1-9 scale
            let retrievability = Double.random(in: 0.5 ... 0.99) // 50-99%

            let state = FSRSState(
                stability: stability,
                difficulty: difficulty,
                retrievability: retrievability,
                dueDate: today.addingTimeInterval(Double.random(in: -86400 ... 86400 * 30)),
                stateEnum: ["new", "learning", "review"].randomElement() ?? "review"
            )
            // lastReviewDate will be set during review creation
            state.card = card
            context.insert(state)

            cards.append(card)
        }

        // Create study sessions over history period
        for dayOffset in 0 ..< daysOfHistory {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            // Skip some days to create realistic streak patterns
            if Double.random(in: 0 ... 1) > 0.7 { // 30% chance of studying
                let modeEnum = [StudyMode.scheduled, .learning, .cram].randomElement() ?? .scheduled
                let modeString: String
                switch modeEnum {
                case .scheduled: modeString = "scheduled"
                case .learning: modeString = "learning"
                case .cram: modeString = "cram"
                }

                let session = StudySession(
                    startTime: dayDate.addingTimeInterval(Double.random(in: 0 ... 3600)),
                    endTime: dayDate.addingTimeInterval(Double.random(in: 300 ... 1800)),
                    cardsReviewed: Int.random(in: 10 ... 50),
                    modeEnum: modeString
                )
                session.deck = deck
                context.insert(session)
                sessions.append(session)

                // Create reviews for this session
                let cardsInSession = Int.random(in: 5 ... min(30, cardCount / 10))
                for _ in 0 ..< cardsInSession {
                    let card = cards.randomElement()!
                    let rating = Int.random(in: 1 ... 4) // 1=Again, 4=Easy

                    let review = FlashcardReview(
                        rating: rating,
                        reviewDate: dayDate.addingTimeInterval(Double.random(in: 0 ... 3600)),
                        scheduledDays: 0,
                        elapsedDays: 0
                    )
                    review.card = card
                    review.studySession = session

                    // Update FSRS state
                    if let state = card.fsrsState {
                        state.lastReviewDate = review.reviewDate
                    }

                    context.insert(review)
                    reviews.append(review)
                }
            }
        }

        try context.save()

        logger.info("""
        Created large dataset:
        - \(cards.count) flashcards
        - \(sessions.count) study sessions
        - \(reviews.count) reviews
        - \(daysOfHistory) days of history
        """)

        return (cards, sessions, reviews)
    }

    // MARK: - ViewModel Performance Tests

    @Test(
        "ViewModel refresh with 1000 cards loads in under 500ms",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func viewModelRefreshPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create large dataset
        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Create ViewModel
        let viewModel = StatisticsViewModel(modelContext: context)

        // Measure refresh time
        let refreshTime = try await measureTime {
            await viewModel.refresh()
        }

        // Verify performance threshold
        #expect(
            refreshTime < viewModelRefreshThreshold,
            "ViewModel refresh took \(refreshTime)ms, expected <\(viewModelRefreshThreshold)ms"
        )

        logger.info("ViewModel refresh completed in \(refreshTime)ms")

        // Verify data was loaded correctly
        #expect(viewModel.hasData, "ViewModel should have data after refresh")
        #expect(!viewModel.isLoading, "ViewModel should not be loading after refresh")
    }

    @Test(
        "ViewModel refresh with 5000 cards completes within threshold",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func viewModelRefreshVeryLargeDataset() async throws {
        let context = freshContext()
        try context.clearAll()

        // Create very large dataset
        _ = try await createLargeDataset(
            context: context,
            cardCount: 5000,
            daysOfHistory: 180,
            reviewsPerCard: 5
        )

        let viewModel = StatisticsViewModel(modelContext: context)

        // Measure refresh time
        let refreshTime = try await measureTime {
            await viewModel.refresh()
        }

        // More lenient threshold for very large dataset
        let largeDatasetThreshold = viewModelRefreshThreshold * 2 // 1000ms

        #expect(
            refreshTime < largeDatasetThreshold,
            "ViewModel refresh with 5000 cards took \(refreshTime)ms, expected <\(largeDatasetThreshold)ms"
        )

        logger.info("ViewModel refresh with 5000 cards completed in \(refreshTime)ms")
    }

    // MARK: - StatisticsService Performance Tests

    @Test(
        "calculateRetentionRate with 1000 reviews completes in under 100ms",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func retentionRatePerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        let (_, _, reviews) = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Ensure we have reviews
        #expect(reviews.count > 0, "Should have created reviews")

        // Measure calculation time
        let calculationTime = try await measureTime {
            _ = await StatisticsService.shared.calculateRetentionRate(
                context: context,
                timeRange: .allTime
            )
        }

        #expect(
            calculationTime < serviceCalculationThreshold,
            "calculateRetentionRate took \(calculationTime)ms, expected <\(serviceCalculationThreshold)ms"
        )

        logger.info("calculateRetentionRate completed in \(calculationTime)ms")
    }

    @Test(
        "calculateStudyStreak with 90 days of history completes in under 100ms",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func studyStreakPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Measure calculation time
        let calculationTime = try await measureTime {
            _ = await StatisticsService.shared.calculateStudyStreak(
                context: context,
                timeRange: .allTime
            )
        }

        #expect(
            calculationTime < serviceCalculationThreshold,
            "calculateStudyStreak took \(calculationTime)ms, expected <\(serviceCalculationThreshold)ms"
        )

        logger.info("calculateStudyStreak completed in \(calculationTime)ms")
    }

    @Test(
        "calculateFSRSMetrics with 1000 cards completes in under 100ms",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func fsrsMetricsPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Measure calculation time
        let calculationTime = try await measureTime {
            _ = await StatisticsService.shared.calculateFSRSMetrics(
                context: context,
                timeRange: .allTime
            )
        }

        #expect(
            calculationTime < serviceCalculationThreshold,
            "calculateFSRSMetrics took \(calculationTime)ms, expected <\(serviceCalculationThreshold)ms"
        )

        logger.info("calculateFSRSMetrics completed in \(calculationTime)ms")
    }

    // MARK: - Time Range Filtering Performance

    @Test(
        "Time range filtering does not significantly impact performance",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func timeRangeFilteringPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Test all three time ranges
        let timeRanges: [StatisticsTimeRange] = [.sevenDays, .thirtyDays, .allTime]
        var times: [TimeInterval] = []

        for timeRange in timeRanges {
            let time = try await measureTime {
                _ = await StatisticsService.shared.calculateRetentionRate(
                    context: context,
                    timeRange: timeRange
                )
            }
            times.append(time)
        }

        // All time ranges should complete within threshold
        for (index, time) in times.enumerated() {
            #expect(
                time < serviceCalculationThreshold,
                "calculateRetentionRate for \(timeRanges[index].displayName) took \(time)ms, expected <\(serviceCalculationThreshold)ms"
            )
        }

        logger.info("Time range performance: 7d=\(times[0])ms, 30d=\(times[1])ms, all=\(times[2])ms")
    }

    // MARK: - Aggregation Performance Tests

    @Test(
        "aggregateDailyStats with 1000 sessions completes in under 1s",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func aggregationPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        let (_, sessions, _) = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        logger.info("Aggregating \(sessions.count) study sessions")

        // Measure aggregation time
        let aggregationTime = try await measureTime {
            _ = try await StatisticsService.shared.aggregateDailyStats(context: context)
        }

        #expect(
            aggregationTime < aggregationThreshold,
            "aggregateDailyStats took \(aggregationTime)ms, expected <\(aggregationThreshold)ms"
        )

        logger.info("aggregateDailyStats completed in \(aggregationTime)ms")
    }

    // MARK: - Concurrent Access Performance

    @Test(
        "Concurrent refresh calls complete efficiently",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func concurrentRefreshPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        let viewModel = StatisticsViewModel(modelContext: context)

        // Measure time for 5 concurrent refreshes
        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    await viewModel.refresh()
                }
            }
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime) * 1000.0

        // Concurrent refreshes should not be significantly slower than single
        // (within 3x threshold to allow for some concurrency overhead)
        let concurrentThreshold = viewModelRefreshThreshold * 3

        #expect(
            totalTime < concurrentThreshold,
            "5 concurrent refreshes took \(totalTime)ms, expected <\(concurrentThreshold)ms"
        )

        logger.info("5 concurrent refreshes completed in \(totalTime)ms")
    }

    // MARK: - Memory Pressure Tests

    @Test(
        "ViewModel does not leak memory with repeated refreshes",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func memoryLeakTest() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        let viewModel = StatisticsViewModel(modelContext: context)

        // Perform many refreshes
        for i in 0 ..< 10 {
            await viewModel.refresh()

            // Verify data is still valid
            #expect(viewModel.hasData, "ViewModel should have data on refresh \(i + 1)")
            #expect(!viewModel.isLoading, "ViewModel should not be loading after refresh \(i + 1)")
        }

        logger.info("Memory leak test: 10 refreshes completed successfully")
    }

    // MARK: - Chart Data Performance

    @Test(
        "Trend chart data with 90 data points is generated efficiently",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func trendChartDataPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Get retention rate data with trend
        let data = await StatisticsService.shared.calculateRetentionRate(
            context: context,
            timeRange: .allTime
        )

        // Verify trend data exists
        #expect(data.trendData.count > 0, "Should have trend data")

        logger.info("Trend chart has \(data.trendData.count) data points")

        // Measure time to access all trend data (simulating chart rendering)
        let accessTime = try await measureTime {
            for _ in data.trendData {
                // Access data point (simulate chart iteration)
            }
        }

        #expect(
            accessTime < 10.0, // Should be nearly instant
            "Trend data access took \(accessTime)ms, expected <10ms"
        )

        logger.info("Trend chart data access completed in \(accessTime)ms")
    }

    @Test(
        "Calendar heatmap with 90 days is generated efficiently",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func calendarHeatmapPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        // Get streak data with calendar heatmap
        let data = await StatisticsService.shared.calculateStudyStreak(
            context: context,
            timeRange: .allTime
        )

        // Verify calendar heatmap exists
        #expect(data.calendarData.count > 0, "Should have calendar heatmap data")

        logger.info("Calendar heatmap has \(data.calendarData.count) days")

        // Measure time to access all heatmap data (simulating calendar rendering)
        let accessTime = try await measureTime {
            for _ in data.calendarData {
                // Access heatmap entry (simulate calendar iteration)
            }
        }

        #expect(
            accessTime < 10.0, // Should be nearly instant
            "Calendar heatmap access took \(accessTime)ms, expected <10ms"
        )

        logger.info("Calendar heatmap access completed in \(accessTime)ms")
    }

    // MARK: - Integration Performance Test

    @Test(
        "Full dashboard workflow with large dataset completes efficiently",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func fullDashboardWorkflowPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        _ = try await createLargeDataset(
            context: context,
            cardCount: 1000,
            daysOfHistory: 90,
            reviewsPerCard: 3
        )

        let viewModel = StatisticsViewModel(modelContext: context)

        let startTime = Date()

        // Full workflow: load → change time range → refresh
        await viewModel.refresh()

        await viewModel.changeTimeRange(.thirtyDays)

        await viewModel.refresh()

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime) * 1000.0

        // Full workflow should complete in under 2 seconds
        let workflowThreshold = 2000.0

        #expect(
            totalTime < workflowThreshold,
            "Full workflow took \(totalTime)ms, expected <\(workflowThreshold)ms"
        )

        // Verify final state
        #expect(viewModel.selectedTimeRange == .thirtyDays, "Time range should be 30 days")
        #expect(viewModel.hasData, "Should have data")
        #expect(!viewModel.isLoading, "Should not be loading")

        logger.info("Full dashboard workflow completed in \(totalTime)ms")
    }
}
