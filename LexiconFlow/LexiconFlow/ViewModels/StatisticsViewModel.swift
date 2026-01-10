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
        self.statisticsService = StatisticsService.shared

        // Use provided time range or load from AppSettings
        if let timeRange {
            self.selectedTimeRange = timeRange
        } else {
            // Load from AppSettings (convert string to enum)
            let savedRange = AppSettings.statisticsTimeRange
            self.selectedTimeRange = StatisticsTimeRange(rawValue: savedRange) ?? .sevenDays
        }

        // swiftformat:disable:next redundantSelf
        logger.info("StatisticsViewModel initialized with time range: \(self.selectedTimeRange.displayName)")
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
        self.isLoading = true
        self.errorMessage = nil

        // swiftformat:disable:next redundantSelf
        logger.debug("Refreshing statistics for time range: \(self.selectedTimeRange.displayName)")

        // Fetch metrics sequentially to avoid capturing non-Sendable ModelContext in Sendable closure
        // Swift 6 strict concurrency requires this approach
        let retentionResult = self.statisticsService.calculateRetentionRate(
            context: self.modelContext,
            timeRange: self.selectedTimeRange
        )

        let streakResult = self.statisticsService.calculateStudyStreak(
            context: self.modelContext,
            timeRange: self.selectedTimeRange
        )

        let fsrsResult = self.statisticsService.calculateFSRSMetrics(
            context: self.modelContext,
            timeRange: self.selectedTimeRange
        )

        // Update published properties on main actor
        self.retentionData = retentionResult
        self.streakData = streakResult
        self.fsrsMetrics = fsrsResult

        self.logger.info("""
        Statistics refreshed:
        - Retention: \(retentionResult.formattedPercentage)
        - Streak: \(streakResult.currentStreak) days
        - FSRS: \(fsrsResult.formattedStability) avg stability
        """)

        self.isLoading = false
    }

    /// Change the selected time range and refresh data
    ///
    /// - Parameter timeRange: New time range to select
    ///
    /// **Side Effect**: Updates AppSettings.statisticsTimeRange for persistence
    func changeTimeRange(_ timeRange: StatisticsTimeRange) async {
        guard self.selectedTimeRange != timeRange else { return }

        // swiftformat:disable:next redundantSelf
        logger.info("Changing time range from \(self.selectedTimeRange.displayName) to \(timeRange.displayName)")

        self.selectedTimeRange = timeRange

        // Persist to AppSettings
        AppSettings.statisticsTimeRange = timeRange.rawValue

        // Refresh data with new time range
        await self.refresh()
    }

    /// Clear error message (user dismissed error)
    func clearError() {
        self.errorMessage = nil
    }
}

// MARK: - Computed Properties

extension StatisticsViewModel {
    /// Whether there is any data to display
    var hasData: Bool {
        self.retentionData != nil || self.streakData != nil || self.fsrsMetrics != nil
    }

    /// Whether dashboard is in empty state (no study activity)
    var isEmpty: Bool {
        guard let retentionData,
              let streakData,
              let fsrsMetrics else { return false }

        // Check if all metrics are empty/zero
        return retentionData.totalCount == 0 &&
            streakData.activeDays == 0 &&
            fsrsMetrics.totalCards == 0
    }
}
