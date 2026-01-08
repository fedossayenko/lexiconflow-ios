//
//  StatisticsViewModel.swift
//  LexiconFlow
//
//  @MainActor ViewModel for study statistics dashboard
//  Manages state for retention rate, study streak, and FSRS metrics
//

import Combine
import Foundation
import OSLog
import SwiftData

/// ViewModel for the study statistics dashboard
///
/// **Architecture**: @MainActor ObservableObject for SwiftUI reactivity
/// - Integrates with StatisticsService for data calculations
/// - Persists time range preference via AppSettings
///
/// **Data Flow**:
/// 1. refresh() calls StatisticsService to compute DTOs
/// 2. DTOs update @Published properties
/// 3. View re-renders automatically
@MainActor
final class StatisticsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Retention rate data with trend information
    @Published private(set) var retentionData: RetentionRateData?

    /// Study streak data with calendar visualization
    @Published private(set) var streakData: StudyStreakData?

    /// FSRS metrics (stability, difficulty distributions)
    @Published private(set) var fsrsMetrics: FSRSMetricsData?

    /// Selected time range for filtering statistics
    @Published private(set) var selectedTimeRange: StatisticsTimeRange

    /// Whether data is currently being refreshed
    @Published private(set) var isLoading = false

    /// Error message if data loading failed
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    /// SwiftData model context for queries
    private let modelContext: ModelContext

    /// Statistics service for data calculations
    private let statisticsService: StatisticsService

    /// Logger for view model operations
    private let logger = Logger(subsystem: "com.lexiconflow.statistics", category: "StatisticsViewModel")

    // MARK: - Initialization

    /// Initialize the view model
    ///
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - timeRange: Initial time range selection (defaults to AppSettings)
    init(modelContext: ModelContext, timeRange: StatisticsTimeRange? = nil) {
        self.modelContext = modelContext
        statisticsService = StatisticsService.shared

        // Use provided time range or load from AppSettings
        if let timeRange = timeRange {
            selectedTimeRange = timeRange
        } else {
            // Load from AppSettings (convert string to enum)
            let savedRange = AppSettings.statisticsTimeRange
            selectedTimeRange = StatisticsTimeRange(rawValue: savedRange) ?? .sevenDays
        }

        logger.info("StatisticsViewModel initialized with time range: \(selectedTimeRange.displayName)")
    }

    // MARK: - Public Methods

    /// Refresh all statistics from the service
    ///
    /// This method:
    /// 1. Sets isLoading to true
    /// 2. Calls StatisticsService for all metrics
    /// 3. Updates published properties with DTOs
    /// 4. Handles errors with Analytics tracking
    ///
    /// **Usage**: Call on view appear and after time range changes
    /// **Note**: Uses sequential await instead of async let to avoid capturing non-Sendable ModelContext
    func refresh() async {
        isLoading = true
        errorMessage = nil

        logger.debug("Refreshing statistics for time range: \(selectedTimeRange.displayName)")

        // Fetch metrics sequentially to avoid capturing non-Sendable ModelContext in Sendable closure
        // Swift 6 strict concurrency requires this approach
        let retentionResult = await statisticsService.calculateRetentionRate(
            context: modelContext,
            timeRange: selectedTimeRange
        )

        let streakResult = await statisticsService.calculateStudyStreak(
            context: modelContext,
            timeRange: selectedTimeRange
        )

        let fsrsResult = await statisticsService.calculateFSRSMetrics(
            context: modelContext,
            timeRange: selectedTimeRange
        )

        // Update published properties on main actor
        retentionData = retentionResult
        streakData = streakResult
        fsrsMetrics = fsrsResult

        logger.info("""
        Statistics refreshed:
        - Retention: \(retentionResult.formattedPercentage)
        - Streak: \(streakResult.currentStreak) days
        - FSRS: \(fsrsResult.formattedStability) avg stability
        """)

        isLoading = false
    }

    /// Change the selected time range and refresh data
    ///
    /// - Parameter timeRange: New time range to select
    ///
    /// **Side Effect**: Updates AppSettings.statisticsTimeRange for persistence
    func changeTimeRange(_ timeRange: StatisticsTimeRange) async {
        guard selectedTimeRange != timeRange else { return }

        logger.info("Changing time range from \(selectedTimeRange.displayName) to \(timeRange.displayName)")

        selectedTimeRange = timeRange

        // Persist to AppSettings
        AppSettings.statisticsTimeRange = timeRange.rawValue

        // Refresh data with new time range
        await refresh()
    }

    /// Clear error message (user dismissed error)
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Computed Properties

extension StatisticsViewModel {
    /// Whether there is any data to display
    var hasData: Bool {
        retentionData != nil || streakData != nil || fsrsMetrics != nil
    }

    /// Whether dashboard is in empty state (no study activity)
    var isEmpty: Bool {
        guard let retentionData = retentionData,
              let streakData = streakData,
              let fsrsMetrics = fsrsMetrics else { return false }

        // Check if all metrics are empty/zero
        return retentionData.totalCount == 0 &&
            streakData.activeDays == 0 &&
            fsrsMetrics.totalCards == 0
    }
}
