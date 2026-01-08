//
//  StatisticsDashboardView.swift
//  LexiconFlow
//
//  Main statistics dashboard showing retention rate, study streak, and FSRS metrics
//

import SwiftData
import SwiftUI

struct StatisticsDashboardView: View {
    // MARK: - State

    /// ViewModel holder with proper SwiftUI observation
    /// Using ViewModelHolder allows lazy initialization while maintaining
    /// proper observation of @Published properties via @StateObject
    @StateObject private var viewModelHolder = ViewModelHolder<StatisticsViewModel>()

    /// Whether to show error alert
    @State private var showError = false

    /// Accessibility announcement for screen reader users
    @State private var accessibilityAnnouncement = ""

    /// Model context for ViewModel initialization
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        @ViewBuilder var content: some View {
            if let viewModel = viewModelHolder.value {
                dashboardContent(viewModel: viewModel)
            } else {
                ProgressView("Loading statistics...")
            }
        }

        return content
            .task {
                await initializeViewModel()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    viewModelHolder.value?.clearError()
                }
                .accessibilityLabel("Dismiss error")
            } message: {
                Text(viewModelHolder.value?.errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: viewModelHolder.value?.errorMessage != nil) { _, hasError in
                if hasError {
                    showError = true
                }
            }
            .accessibilityHint(accessibilityAnnouncement)
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(viewModel: StatisticsViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                // MARK: - Header Section

                Section {
                    EmptyView()
                } header: {
                    dashboardHeader(viewModel: viewModel)
                }

                // MARK: - Error State (highest priority check)

                if viewModel.errorMessage != nil {
                    errorView
                }

                // MARK: - Loading State

                else if viewModel.isLoading {
                    loadingView
                }

                // MARK: - Empty State

                else if viewModel.isEmpty {
                    emptyStateView
                }

                // MARK: - Metrics Display

                else if viewModel.hasData {
                    metricsContent(viewModel: viewModel)
                }

                // MARK: - Fallback (should never reach)

                else {
                    loadingView
                }
            }
            .padding()
        }
        .accessibilityIdentifier("StatisticsDashboard")
        .accessibilityLabel("Statistics Dashboard")
        .accessibilityHint("Displays your learning progress, retention rate, study streak, and FSRS metrics")
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Header with Time Range Picker

    private func dashboardHeader(viewModel: StatisticsViewModel) -> some View {
        VStack(spacing: 16) {
            // Time range picker
            TimeRangePicker(selection: Binding(
                get: { viewModel.selectedTimeRange },
                set: { newValue in
                    Task {
                        await viewModel.changeTimeRange(newValue)
                    }
                }
            ))
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Metrics Content

    @ViewBuilder
    private func metricsContent(viewModel: StatisticsViewModel) -> some View {
        // Retention Rate Card
        if let retentionData = viewModel.retentionData {
            MetricCard(
                title: "Retention Rate",
                value: retentionData.formattedPercentage,
                subtitle: "\(retentionData.successfulCount) of \(retentionData.totalCount) reviews successful",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            .accessibilityLabel("Retention rate \(retentionData.formattedPercentage)")
            .accessibilityHint("\(retentionData.successfulCount) successful out of \(retentionData.totalCount) total reviews")
            .accessibilityAddTraits(.isStaticText)
        }

        // Study Streak Card
        if let streakData = viewModel.streakData {
            MetricCard(
                title: "Study Streak",
                value: "\(streakData.currentStreak)",
                subtitle: streakData.currentStreak == 1 ? "day" : "days",
                icon: "flame.fill",
                color: .orange
            )
            .accessibilityLabel("Current study streak \(streakData.currentStreak) days")
            .accessibilityHint("Longest streak: \(streakData.longestStreak) days")
            .accessibilityAddTraits(.isStaticText)
        }

        // Grid Layout for Secondary Metrics
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
        ], spacing: 16) {
            // Total Study Time
            if let streakData = viewModel.streakData {
                let totalStudyTime = streakData.calendarData.values.reduce(0, +)
                studyTimeMetricCard(totalSeconds: totalStudyTime)
            }

            // Cards Analyzed
            if let fsrsMetrics = viewModel.fsrsMetrics {
                cardsMetricCard(totalCards: fsrsMetrics.totalCards, reviewedCards: fsrsMetrics.reviewedCards)
            }
        }

        // Retention Trend Chart (implemented in subtask 4.3)
        if let retentionData = viewModel.retentionData {
            RetentionTrendChart(data: retentionData)
        }

        // Study Streak Calendar (implemented in subtask 4.4)
        if let streakData = viewModel.streakData, streakData.activeDays > 0 {
            StudyStreakCalendarView(data: streakData)
        }

        // FSRS Distribution Chart (implemented in subtask 4.5)
        if let fsrsMetrics = viewModel.fsrsMetrics {
            FSRSDistributionChart(data: fsrsMetrics)
        }
    }

    // MARK: - Metric Cards

    private func studyTimeMetricCard(totalSeconds: TimeInterval) -> some View {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        let formattedTime = formatter.string(from: totalSeconds) ?? "0s"

        return MetricCard(
            title: "Study Time",
            value: formattedTime,
            subtitle: "Total time studied",
            icon: "clock.fill",
            color: .green
        )
        .accessibilityLabel("Total study time \(formattedTime)")
        .accessibilityAddTraits(.isStaticText)
    }

    private func cardsMetricCard(totalCards: Int, reviewedCards: Int) -> some View {
        return MetricCard(
            title: "Cards",
            value: "\(reviewedCards)",
            subtitle: "of \(totalCards) reviewed",
            icon: "rectangle.stack.fill",
            color: .purple
        )
        .accessibilityLabel("\(reviewedCards) of \(totalCards) cards reviewed")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .accessibilityLabel("Loading")

            Text("Loading statistics...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading statistics")
        .accessibilityHint("Please wait while your study data is being refreshed")
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        NavigationLink(destination: StudyView()) {
            EmptyStateView.statisticsDashboard {
                // NavigationLink handles the action
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No study data")
        .accessibilityHint("Double tap to start your first study session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Failed to load statistics")
                .font(.headline)

            if let errorMessage = viewModelHolder.value?.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Retry") {
                Task {
                    await viewModelHolder.value?.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading statistics")
        .accessibilityHint("Double tap Retry to attempt loading again")
    }

    // MARK: - Initialization

    /// Initialize ViewModel with safe pattern
    ///
    /// **Why lazy initialization?**: Prevents app crashes if ModelContainer fails.
    /// Follows iOS 26 best practices for view initialization.
    private func initializeViewModel() async {
        guard viewModelHolder.value == nil else { return }

        // Initialize on MainActor (ViewModel is @MainActor)
        await MainActor.run {
            viewModelHolder.value = StatisticsViewModel(modelContext: modelContext)
        }

        // Initial data refresh
        await viewModelHolder.value?.refresh()
    }
}

// MARK: - Preview

@ViewBuilder
private func makePreviewContainer() -> some View {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try? ModelContainer(
        for: Flashcard.self, StudySession.self, DailyStats.self, Deck.self, FSRSState.self, FlashcardReview.self,
        configurations: config
    )

    if let container = container {
        NavigationStack {
            StatisticsDashboardView()
        }
        .modelContainer(container)
    } else {
        Text("Preview unavailable: ModelContainer creation failed")
            .foregroundStyle(.red)
    }
}

#Preview("Statistics Dashboard - Empty State") {
    makePreviewContainer()
}

#Preview("Statistics Dashboard - Dark Mode") {
    makePreviewContainer()
        .preferredColorScheme(.dark)
}

#Preview("Statistics Dashboard - New User") {
    makePreviewContainer()
}
