//
//  StatisticsService.swift
//  LexiconFlow
//
//  @MainActor service for calculating study statistics
//  Provides concurrency-safe methods for retention, streaks, and FSRS metrics
//

import Foundation
import OSLog
import SwiftData

// MARK: - Data Transfer Objects

/// Retention rate data with trend information
///
/// **Why DTO?**: Returning computed data instead of models prevents
/// cross-actor concurrency issues and enables efficient caching.
struct RetentionRateData: Sendable {
    /// Overall retention rate (0.0 to 1.0)
    let rate: Double

    /// Number of successful reviews (Good, Easy)
    let successfulCount: Int

    /// Number of failed reviews (Again)
    let failedCount: Int

    /// Total number of reviews
    var totalCount: Int { self.successfulCount + self.failedCount }

    /// Trend data points for graph rendering (date, rate)
    let trendData: [(date: Date, rate: Double)]

    /// Formatted percentage (e.g., "85%")
    var formattedPercentage: String {
        "\(Int(self.rate * 100))%"
    }
}

/// Study streak data with calendar visualization
///
/// Tracks consecutive days of study activity for gamification.
struct StudyStreakData: Sendable {
    /// Current consecutive days of study
    let currentStreak: Int

    /// Longest streak achieved
    let longestStreak: Int

    /// Calendar data for heatmap visualization
    /// - Key: Date (midnight normalized)
    /// - Value: Study time in seconds (nil = no activity)
    let calendarData: [Date: TimeInterval]

    /// Total number of active days
    let activeDays: Int

    /// Whether user has studied today
    let hasStudiedToday: Bool
}

/// FSRS metrics distribution data
///
/// Aggregates memory stability and difficulty across all cards.
struct FSRSMetricsData: Sendable {
    /// Average stability across all cards (in days)
    let averageStability: Double

    /// Average difficulty across all cards (0-10 scale)
    let averageDifficulty: Double

    /// Stability distribution histogram
    /// - Key: Stability bucket (days)
    /// - Value: Count of cards in this bucket
    let stabilityDistribution: [String: Int]

    /// Difficulty distribution histogram
    /// - Key: Difficulty bucket (0-10 scale)
    /// - Value: Count of cards in this bucket
    let difficultyDistribution: [String: Int]

    /// Total number of cards analyzed
    let totalCards: Int

    /// Number of cards with reviews (has meaningful FSRS state)
    let reviewedCards: Int

    /// Formatted average stability (e.g., "12.5 days")
    var formattedStability: String {
        if self.averageStability >= 365.0 {
            let years = self.averageStability / 365.0
            return String(format: "%.1f years", years)
        } else if self.averageStability >= 30.0 {
            let months = self.averageStability / 30.0
            return String(format: "%.1f months", months)
        } else if self.averageStability >= 7.0 {
            let weeks = self.averageStability / 7.0
            return String(format: "%.1f weeks", weeks)
        } else {
            return String(format: "%.1f days", self.averageStability)
        }
    }

    /// Formatted average difficulty (e.g., "5.2 / 10")
    var formattedDifficulty: String {
        String(format: "%.1f / 10", self.averageDifficulty)
    }
}

/// Time range for statistics filtering
enum StatisticsTimeRange: String, Sendable, CaseIterable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case allTime = "all"

    var displayName: String {
        switch self {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .allTime: "All time"
        }
    }

    /// Accessibility-friendly label for VoiceOver
    var accessibilityLabel: String {
        switch self {
        case .sevenDays: "Last 7 days"
        case .thirtyDays: "Last 30 days"
        case .allTime: "All time"
        }
    }
}

// MARK: - Statistics Service

/// @MainActor service for calculating study statistics
///
/// **Why @MainActor?**: Statistics calculations involve aggregating data from
/// multiple SwiftData models. @MainActor ensures safe access to ModelContext
/// (which is non-Sendable) and prevents data races during concurrent queries.
///
/// **Architecture**:
/// - All methods run on @MainActor for safe SwiftData ModelContext access
/// - Returns DTOs instead of SwiftData models
/// - Uses ModelContext for database queries
/// - Timezone-aware calculations via DateMath
@MainActor
final class StatisticsService {
    // MARK: - Configuration

    /// Buckets for stability distribution histogram
    private enum StabilityBuckets {
        static let buckets: [(key: String, maxValue: Double)] = [
            ("0-1 days", 1.0),
            ("1-3 days", 3.0),
            ("3-7 days", 7.0),
            ("1-2 weeks", 14.0),
            ("2-4 weeks", 30.0),
            ("1-3 months", 90.0),
            ("3-6 months", 180.0),
            ("6-12 months", 365.0),
            ("1+ years", Double.infinity)
        ]
    }

    /// Buckets for difficulty distribution histogram
    private enum DifficultyBuckets {
        static let buckets: [(key: String, maxValue: Double)] = [
            ("0-2 (Very Easy)", 2.0),
            ("2-4 (Easy)", 4.0),
            ("4-6 (Medium)", 6.0),
            ("6-8 (Hard)", 8.0),
            ("8-10 (Very Hard)", 10.0)
        ]
    }

    // MARK: - Properties

    /// Shared singleton instance for app-wide access
    static let shared = StatisticsService()

    /// Logger for statistics calculations
    private let logger = Logger(subsystem: "com.lexiconflow.statistics", category: "StatisticsService")

    /// Private initializer for singleton pattern
    private init() {
        self.logger.info("StatisticsService initialized")
    }

    // MARK: - Retention Rate

    /// Calculate retention rate over a time period
    ///
    /// **Definition**: (successful reviews / total reviews)
    /// - Successful: rating >= 1 (Hard, Good, Easy)
    /// - Failed: rating == 0 (Again)
    ///
    /// - Parameters:
    ///   - context: SwiftData ModelContext for queries
    ///   - timeRange: Time range to filter reviews
    ///   - startDate: Optional custom start date (overrides timeRange)
    ///
    /// - Returns: RetentionRateData with rate and trend data
    func calculateRetentionRate(
        context: ModelContext,
        timeRange: StatisticsTimeRange = .allTime,
        startDate: Date? = nil
    ) -> RetentionRateData {
        let filterStartDate = startDate ?? self.startDateForTimeRange(timeRange)

        self.logger.debug("Calculating retention rate from \(filterStartDate)")

        // Fetch all reviews within time range
        let reviewsDescriptor = FetchDescriptor<FlashcardReview>(
            predicate: #Predicate<FlashcardReview> { review in
                review.reviewDate >= filterStartDate
            }
        )

        do {
            let reviews = try context.fetch(reviewsDescriptor)

            guard !reviews.isEmpty else {
                self.logger.info("No reviews found for retention rate calculation")
                return RetentionRateData(
                    rate: 0.0,
                    successfulCount: 0,
                    failedCount: 0,
                    trendData: []
                )
            }

            // Calculate overall retention
            let successfulReviews = reviews.filter { $0.rating >= 1 }
            let failedReviews = reviews.filter { $0.rating == 0 }

            let rate = Double(successfulReviews.count) / Double(reviews.count)

            // Generate trend data (grouped by day)
            let trendData = self.generateRetentionTrend(reviews: reviews, startDate: filterStartDate)

            self.logger.info("""
            Retention rate calculated:
            - Rate: \(Int(rate * 100))%
            - Successful: \(successfulReviews.count)
            - Failed: \(failedReviews.count)
            - Trend points: \(trendData.count)
            """)

            return RetentionRateData(
                rate: rate,
                successfulCount: successfulReviews.count,
                failedCount: failedReviews.count,
                trendData: trendData
            )
        } catch {
            self.logger.error("Failed to calculate retention rate: \(error.localizedDescription)")
            return RetentionRateData(
                rate: 0.0,
                successfulCount: 0,
                failedCount: 0,
                trendData: []
            )
        }
    }

    /// Generate trend data points for retention rate over time
    ///
    /// - Parameters:
    ///   - reviews: All reviews to analyze
    ///   - startDate: Start of time range
    ///
    /// - Returns: Array of (date, rate) tuples sorted by date
    private func generateRetentionTrend(
        reviews: [FlashcardReview],
        startDate _: Date
    ) -> [(date: Date, rate: Double)] {
        // Group reviews by calendar day
        var dailyReviews: [Date: [FlashcardReview]] = [:]

        for review in reviews {
            let day = DateMath.startOfDay(for: review.reviewDate)
            dailyReviews[day, default: []].append(review)
        }

        // Calculate retention rate for each day
        let trendData = dailyReviews
            .sorted { $0.key < $1.key }
            .map { day, reviews -> (Date, Double) in
                let successful = reviews.count(where: { $0.rating >= 1 })
                let rate = Double(successful) / Double(reviews.count)
                return (day, rate)
            }

        return trendData
    }

    // MARK: - Study Streak

    /// Calculate current study streak and calendar data
    ///
    /// **Definition**: Consecutive days with study activity
    /// - Activity = any study session with duration > 0
    /// - Streak breaks on days with no activity
    ///
    /// - Parameters:
    ///   - context: SwiftData ModelContext for queries
    ///   - timeRange: Time range to analyze (default: all time)
    ///
    /// - Returns: StudyStreakData with current streak and calendar heatmap
    func calculateStudyStreak(
        context: ModelContext,
        timeRange: StatisticsTimeRange = .allTime
    ) -> StudyStreakData {
        let startDate = self.startDateForTimeRange(timeRange)

        self.logger.debug("Calculating study streak from \(startDate)")

        // Fetch all study sessions within time range
        // NOTE: endTime filter applied in-memory (SwiftData predicates don't support optional comparisons)
        let sessionsDescriptor = FetchDescriptor<StudySession>(
            predicate: #Predicate<StudySession> { session in
                session.startTime >= startDate
            }
        )

        do {
            let sessions = try context.fetch(sessionsDescriptor)

            // Filter to completed sessions only (endTime != nil)
            let completedSessions = sessions.filter { $0.endTime != nil }

            // Group sessions by calendar day
            var dailyStudyTime: [Date: TimeInterval] = [:]

            for session in completedSessions {
                let day = DateMath.startOfDay(for: session.startTime)
                let duration = session.durationSeconds
                dailyStudyTime[day, default: 0.0] += duration
            }

            guard !dailyStudyTime.isEmpty else {
                self.logger.info("No study sessions found for streak calculation")
                return StudyStreakData(
                    currentStreak: 0,
                    longestStreak: 0,
                    calendarData: [:],
                    activeDays: 0,
                    hasStudiedToday: false
                )
            }

            // Calculate streaks
            let sortedDays = dailyStudyTime.keys.sorted()
            let currentStreak = self.calculateCurrentStreak(activeDays: sortedDays)
            let longestStreak = self.calculateLongestStreak(activeDays: sortedDays)

            // Check if studied today
            let today = DateMath.startOfDay(for: Date())
            let hasStudiedToday = dailyStudyTime[today] ?? 0 > 0

            self.logger.info("""
            Study streak calculated:
            - Current: \(currentStreak) days
            - Longest: \(longestStreak) days
            - Active days: \(dailyStudyTime.count)
            - Studied today: \(hasStudiedToday)
            """)

            return StudyStreakData(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                calendarData: dailyStudyTime,
                activeDays: dailyStudyTime.count,
                hasStudiedToday: hasStudiedToday
            )
        } catch {
            self.logger.error("Failed to calculate study streak: \(error.localizedDescription)")
            return StudyStreakData(
                currentStreak: 0,
                longestStreak: 0,
                calendarData: [:],
                activeDays: 0,
                hasStudiedToday: false
            )
        }
    }

    /// Calculate current consecutive day streak
    ///
    /// - Parameter activeDays: Sorted array of days with activity
    ///
    /// - Returns: Current streak count
    private func calculateCurrentStreak(activeDays: [Date]) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        let today = DateMath.startOfDay(for: Date())
        // Convert to Set for O(1) lookup instead of O(n) iteration
        let activeDaysSet = Set(activeDays.map { DateMath.startOfDay(for: $0) })

        var currentStreak = 0
        var checkDate = today

        // Count consecutive days backwards from today
        // O(1) per iteration with Set lookup
        while activeDaysSet.contains(checkDate) {
            currentStreak += 1
            checkDate = DateMath.addingDays(-1, to: checkDate)

            // Safety: prevent infinite loop with max iteration limit (100 years)
            if currentStreak > 36500 { break }
        }

        return currentStreak
    }

    /// Calculate longest consecutive day streak
    ///
    /// - Parameter activeDays: Sorted array of days with activity
    ///
    /// - Returns: Longest streak count
    private func calculateLongestStreak(activeDays: [Date]) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        var longestStreak = 1
        var currentStreak = 1

        for i in 1 ..< activeDays.count {
            let prevDay = activeDays[i - 1]
            let currDay = activeDays[i]

            // Check if consecutive (1 day apart)
            let daysBetween = DateMath.elapsedDays(from: prevDay, to: currDay)
            if daysBetween <= 1.0 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        return longestStreak
    }

    // MARK: - FSRS Metrics

    /// Calculate FSRS metrics across all cards
    ///
    /// Aggregates stability and difficulty data from all FSRSState records.
    ///
    /// - Parameters:
    ///   - context: SwiftData ModelContext for queries
    ///   - timeRange: Time range to filter cards (by last review date)
    ///
    /// - Returns: FSRSMetricsData with averages and distributions
    func calculateFSRSMetrics(
        context: ModelContext,
        timeRange: StatisticsTimeRange = .allTime
    ) -> FSRSMetricsData {
        let startDate = self.startDateForTimeRange(timeRange)

        self.logger.debug("Calculating FSRS metrics from \(startDate)")

        // Fetch all FSRS states with reviews since start date
        let statesDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { _ in
                // We'll filter in-memory since predicates don't support optional comparisons well
                true
            }
        )

        do {
            let allStates = try context.fetch(statesDescriptor)
            let reviewedStates = allStates.filter { state in
                guard let reviewDate = state.lastReviewDate else { return false }
                return reviewDate >= startDate
            }

            guard !reviewedStates.isEmpty else {
                self.logger.info("No reviewed cards found for FSRS metrics")
                return FSRSMetricsData(
                    averageStability: 0.0,
                    averageDifficulty: 5.0,
                    stabilityDistribution: [:],
                    difficultyDistribution: [:],
                    totalCards: allStates.count,
                    reviewedCards: 0
                )
            }

            // Calculate averages
            let totalStability = reviewedStates.reduce(0.0) { $0 + $1.stability }
            let totalDifficulty = reviewedStates.reduce(0.0) { $0 + $1.difficulty }

            let averageStability = totalStability / Double(reviewedStates.count)
            let averageDifficulty = totalDifficulty / Double(reviewedStates.count)

            // Generate distributions
            let stabilityDistribution = self.generateStabilityDistribution(reviewedStates)
            let difficultyDistribution = self.generateDifficultyDistribution(reviewedStates)

            self.logger.info("""
            FSRS metrics calculated:
            - Avg stability: \(String(format: "%.2f", averageStability)) days
            - Avg difficulty: \(String(format: "%.2f", averageDifficulty)) / 10
            - Total cards: \(allStates.count)
            - Reviewed cards: \(reviewedStates.count)
            """)

            return FSRSMetricsData(
                averageStability: averageStability,
                averageDifficulty: averageDifficulty,
                stabilityDistribution: stabilityDistribution,
                difficultyDistribution: difficultyDistribution,
                totalCards: allStates.count,
                reviewedCards: reviewedStates.count
            )
        } catch {
            self.logger.error("Failed to calculate FSRS metrics: \(error.localizedDescription)")
            return FSRSMetricsData(
                averageStability: 0.0,
                averageDifficulty: 5.0,
                stabilityDistribution: [:],
                difficultyDistribution: [:],
                totalCards: 0,
                reviewedCards: 0
            )
        }
    }

    /// Generate stability distribution histogram
    ///
    /// - Parameter states: FSRS states to analyze
    ///
    /// - Returns: Dictionary mapping bucket labels to counts
    private func generateStabilityDistribution(_ states: [FSRSState]) -> [String: Int] {
        var distribution: [String: Int] = [:]

        // Initialize all buckets to 0
        for bucket in StabilityBuckets.buckets {
            distribution[bucket.key] = 0
        }

        // Count cards in each bucket
        for state in states {
            var foundBucket = false
            for bucket in StabilityBuckets.buckets {
                if state.stability <= bucket.maxValue {
                    distribution[bucket.key, default: 0] += 1
                    foundBucket = true
                    break
                }
            }

            // Fallback for very high stability values
            if !foundBucket {
                distribution["1+ years", default: 0] += 1
            }
        }

        return distribution
    }

    /// Generate difficulty distribution histogram
    ///
    /// - Parameter states: FSRS states to analyze
    ///
    /// - Returns: Dictionary mapping bucket labels to counts
    private func generateDifficultyDistribution(_ states: [FSRSState]) -> [String: Int] {
        var distribution: [String: Int] = [:]

        // Initialize all buckets to 0
        for bucket in DifficultyBuckets.buckets {
            distribution[bucket.key] = 0
        }

        // Count cards in each bucket
        for state in states {
            let difficulty = max(0.0, min(10.0, state.difficulty)) // Clamp to 0-10

            var foundBucket = false
            for bucket in DifficultyBuckets.buckets {
                if difficulty <= bucket.maxValue {
                    distribution[bucket.key, default: 0] += 1
                    foundBucket = true
                    break
                }
            }

            // Fallback for edge cases
            if !foundBucket {
                distribution["8-10 (Very Hard)", default: 0] += 1
            }
        }

        return distribution
    }

    // MARK: - Time Range Helpers

    /// Calculate start date for a given time range
    ///
    /// - Parameter timeRange: Time range enum
    ///
    /// - Returns: Start date (midnight in user's timezone)
    private func startDateForTimeRange(_ timeRange: StatisticsTimeRange) -> Date {
        let now = Date()

        switch timeRange {
        case .sevenDays:
            return DateMath.addingDays(-7, to: now)
        case .thirtyDays:
            return DateMath.addingDays(-30, to: now)
        case .allTime:
            // Far past date (effectively all time)
            return Date(timeIntervalSince1970: 0)
        }
    }

    // MARK: - Daily Stats Aggregation

    /// Aggregate DailyStats from StudySession records
    ///
    /// Called when app backgrounds or study sessions complete to maintain
    /// pre-aggregated statistics for dashboard performance.
    ///
    /// - Parameter context: SwiftData ModelContext for queries
    ///
    /// - Returns: Number of DailyStats records created/updated
    ///
    /// - Throws: SwiftData fetch/save errors
    func aggregateDailyStats(context: ModelContext) async throws -> Int {
        self.logger.info("Starting daily stats aggregation")

        // Fetch all sessions (endTime and dailyStats filters applied in-memory)
        // NOTE: SwiftData predicates don't support optional comparisons
        let sessionsDescriptor = FetchDescriptor<StudySession>()

        do {
            let sessions = try context.fetch(sessionsDescriptor)

            // Filter to completed sessions without daily stats
            let sessionsToAggregate = sessions.filter { $0.endTime != nil && $0.dailyStats == nil }

            guard !sessionsToAggregate.isEmpty else {
                self.logger.info("No new sessions to aggregate")
                return 0
            }

            // Group sessions by calendar day
            var sessionsByDay: [Date: [StudySession]] = [:]
            for session in sessionsToAggregate {
                let day = DateMath.startOfDay(for: session.startTime)
                sessionsByDay[day, default: []].append(session)
            }

            // Create or update DailyStats for each day
            var aggregatedCount = 0
            var createdDailyStats: [DailyStats] = []

            for (day, daySessions) in sessionsByDay {
                // Check if DailyStats already exists for this day
                let existingStatsDescriptor = FetchDescriptor<DailyStats>(
                    predicate: #Predicate<DailyStats> { stats in
                        stats.date == day
                    }
                )

                let existingStatsResults = try context.fetch(existingStatsDescriptor)
                let existingStats = existingStatsResults.first

                let totalStudyTime = daySessions.reduce(0.0) { $0 + $1.durationSeconds }
                let totalReviews = daySessions.reduce(0) { $0 + $1.cardsReviewed }

                // Calculate retention rate for the day
                let allReviews = daySessions.flatMap(\.reviewsLog)
                let retentionRate: Double?
                if !allReviews.isEmpty {
                    let successful = allReviews.count(where: { $0.rating >= 1 })
                    retentionRate = Double(successful) / Double(allReviews.count)
                } else {
                    retentionRate = nil
                }

                if let existing = existingStats {
                    // Update existing record
                    existing.studyTimeSeconds += totalStudyTime
                    // Note: cardsLearned is computed during review, not aggregated
                    if let newRate = retentionRate {
                        // Weighted average of existing and new retention
                        let existingReviewCount = existing.studySessions.reduce(0) { $0 + $1.cardsReviewed }
                        let newReviewCount = totalReviews
                        let totalReviewCount = existingReviewCount + newReviewCount

                        if totalReviewCount > 0 {
                            let existingRate = existing.retentionRate ?? 0.0
                            existing.retentionRate = (existingRate * Double(existingReviewCount) + newRate * Double(newReviewCount)) / Double(totalReviewCount)
                        } else {
                            existing.retentionRate = newRate
                        }
                    }

                    self.logger.debug("Updated DailyStats for \(day)")
                } else {
                    // Create new record
                    let dailyStats = DailyStats(
                        date: day,
                        cardsLearned: 0, // Computed separately during reviews
                        studyTimeSeconds: totalStudyTime,
                        retentionRate: retentionRate
                    )

                    context.insert(dailyStats)
                    createdDailyStats.append(dailyStats)

                    // Link sessions to this DailyStats record
                    for session in daySessions {
                        session.dailyStats = dailyStats
                    }

                    self.logger.debug("Created DailyStats for \(day)")
                }

                aggregatedCount += 1
            }

            // Atomic save - all or nothing
            try context.save()

            self.logger.info("Daily stats aggregation complete: \(aggregatedCount) days updated")
            return aggregatedCount
        } catch {
            self.logger.error("Failed to aggregate daily stats: \(error.localizedDescription)")
            Task { await Analytics.trackError("aggregate_daily_stats", error: error) }
            throw error
        }
    }
}
