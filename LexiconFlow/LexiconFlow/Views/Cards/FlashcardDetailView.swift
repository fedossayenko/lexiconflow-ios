//
//  FlashcardDetailView.swift
//  LexiconFlow
//
//  Main detail view displaying flashcard information and review history
//  Integrates card info header, review history stats, and review timeline
//

import OSLog
import SwiftData
import SwiftUI

/// Flashcard detail view with card information and review history
///
/// **Architecture**:
/// - Uses FlashcardDetailViewModel (@MainActor) for data management
/// - Displays card info (word, definition, translation, phonetic, CEFR)
/// - Shows review history with filtering and export functionality
/// - Follows "Liquid Glass" design patterns with glass morphism effects
///
/// **Usage**:
/// ```swift
/// NavigationLink("View Details") {
///     FlashcardDetailView(flashcard: selectedCard)
/// }
/// ```
struct FlashcardDetailView: View {
    /// The flashcard to display
    let flashcard: Flashcard

    /// Model context for SwiftData operations
    @Environment(\.modelContext) private var modelContext

    /// View model for review history management (lazy initialized)
    ///
    /// **Why @State with optional**: @StateObject doesn't support optional types.
    /// The nil check in .task ensures the viewModel is only created once,
    /// preventing recreation on view updates.
    @State private var viewModel: FlashcardDetailViewModel?

    /// Current filter for task lifecycle management
    @State private var currentFilter: ReviewHistoryFilter = .allTime

    /// Alert presentation state for export errors
    @State private var showingExportError = false

    /// Logger for view lifecycle
    private static let logger = Logger(subsystem: "com.lexiconflow.views", category: "FlashcardDetail")

    /// Initialize with flashcard
    ///
    /// **Why @State with lazy initialization**: @StateObject doesn't support optionals.
    /// The nil check in .task ensures single initialization, preventing memory leaks.
    ///
    /// - Parameter flashcard: The flashcard to display
    init(flashcard: Flashcard) {
        self.flashcard = flashcard
    }

    var body: some View {
        Group {
            if let viewModel {
                self.mainContent(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            if self.viewModel == nil {
                self.viewModel = FlashcardDetailViewModel(
                    flashcard: self.flashcard,
                    modelContext: self.modelContext
                )
                // Track analytics directly inline (no wrapper needed)
                await Analytics.trackEvent("review_history_viewed", metadata: [
                    "flashcard_word": self.flashcard.word,
                    "review_count": "\(self.flashcard.reviewLogs.count)",
                    "current_state": self.flashcard.fsrsState?.stateEnum ?? "none",
                    "stability": self.flashcard.fsrsState.map { String(format: "%.2f", $0.stability) } ?? "0.0"
                ])
            }
        }
    }

    /// Main content when view model is initialized
    private func mainContent(viewModel: FlashcardDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                self.cardInfoSection
                self.reviewHistoryHeader
                ReviewHistoryListView(
                    reviews: viewModel.filteredReviews,
                    selectedFilter: Binding(
                        get: { viewModel.selectedFilter },
                        set: { newFilter in
                            self.currentFilter = newFilter
                            viewModel.selectFilter(newFilter)
                        }
                    ),
                    onFilterChange: { filter in
                        Self.logger.debug("Filter changed to: \(filter.rawValue)")
                    },
                    onExport: {
                        Task {
                            await self.exportReviewHistory()
                        }
                    }
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(self.flashcard.word)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                self.exportToolbarItem(viewModel: viewModel)
            }
        }
        .alert("Export Failed", isPresented: self.$showingExportError) {
            Button("OK", role: .cancel) {
                viewModel.exportError = nil
                self.showingExportError = false
            }
        } message: {
            Text(viewModel.exportError?.localizedDescription ?? "An unknown error occurred")
        }
        .onChange(of: viewModel.exportError != nil) { _, hasError in
            self.showingExportError = hasError
        }
        .onChange(of: self.currentFilter) { _, newFilter in
            // Track filter changes for analytics
            Analytics.trackEvent("review_history_filter_changed", metadata: [
                "filter": newFilter.rawValue,
                "flashcard_word": self.flashcard.word
            ])
        }
    }

    /// Export toolbar item
    @ViewBuilder
    private func exportToolbarItem(viewModel: FlashcardDetailViewModel) -> some View {
        if let csvString = viewModel.exportCSVString,
           let _ = viewModel.exportFilename
        {
            ShareLink(
                item: csvString,
                preview: SharePreview("Review History", image: Image(systemName: "square.and.arrow.up"))
            ) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export review history")
            .accessibilityHint("Exports filtered reviews as CSV file")
        }
    }

    // MARK: - Card Info Section

    /// Card information header showing word, definition, translation, phonetic, and CEFR
    @ViewBuilder
    private var cardInfoSection: some View {
        if self.viewModel != nil {
            VStack(alignment: .leading, spacing: 20) {
                // Word and CEFR badge row
                HStack(alignment: .top, spacing: 12) {
                    Text(self.flashcard.word)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Phonetic (if available)
                if let phonetic = flashcard.phonetic {
                    Text(phonetic)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pronunciation: \(phonetic)")
                }

                // Translation (if available)
                if let translation = flashcard.translation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(translation)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                    .accessibilityLabel("Translation: \(translation)")
                }

                // Definition
                VStack(alignment: .leading, spacing: 8) {
                    Text("Definition")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(self.flashcard.definition)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Definition: \(self.flashcard.definition)")

                // FSRS State info (if available)
                if let state = flashcard.fsrsState?.state,
                   let stability = flashcard.fsrsState?.stability
                {
                    self.fsrsStateInfo(state: state, stability: stability)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    /// FSRS state information display
    ///
    /// **Why separate view**: Extracts complex state display logic for cleaner
    /// code organization and reusability.
    private func fsrsStateInfo(state: FlashcardState, stability: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: self.stateIcon(for: state))
                .font(.callout)
                .foregroundStyle(self.stateColor(for: state))

            VStack(alignment: .leading, spacing: 2) {
                Text(self.stateLabel(for: state))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("Stability: \(self.stabilityText(stability))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(self.stateColor(for: state).opacity(0.1))
        .cornerRadius(12)
        .accessibilityLabel("FSRS state: \(self.stateLabel(for: state)), Stability: \(self.stabilityText(stability))")
    }

    /// Review history header with statistics
    @ViewBuilder
    private var reviewHistoryHeader: some View {
        if let viewModel {
            VStack(spacing: 16) {
                // Section title
                HStack {
                    Text("Review History")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                // Stats header
                ReviewHistoryHeaderView(
                    totalReviews: viewModel.totalReviewCount,
                    averageRating: viewModel.averageRating,
                    currentState: viewModel.currentFSRSState,
                    stability: viewModel.currentStability
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Export

    /// Export review history as CSV
    ///
    /// **Flow**:
    /// 1. Call viewModel.exportCSV() to generate CSV
    /// 2. Update exportCSVString for ShareLink presentation
    /// 3. Handle errors with user-facing alert
    /// 4. Track export with analytics
    /// 5. Trigger haptic feedback (success or error)
    private func exportReviewHistory() async {
        guard let viewModel else { return }

        Self.logger.info("Exporting review history for '\(self.flashcard.word)'")

        await viewModel.exportCSV()

        // Trigger haptic feedback based on export result
        if AppSettings.hapticEnabled {
            if viewModel.exportCSVString != nil {
                // Success haptic for successful export
                HapticService.shared.triggerSuccess()
            } else if viewModel.exportError != nil {
                // Error haptic for failed export
                HapticService.shared.triggerError()
            }
        }

        // Show share sheet if export succeeded
        if viewModel.exportCSVString != nil {
            Self.logger.info("Export successful, presenting share sheet")
        } else {
            Self.logger.error("Export failed: \(viewModel.exportError?.localizedDescription ?? "Unknown error")")
        }
    }

    // MARK: - Helper Methods

    /// SF Symbol icon for FSRS state
    private func stateIcon(for state: FlashcardState) -> String {
        switch state {
        case .new: "sparkles"
        case .learning: "graduationcap.fill"
        case .review: "checkmark.circle.fill"
        case .relearning: "arrow.clockwise.circle.fill"
        }
    }

    /// Color for FSRS state
    private func stateColor(for state: FlashcardState) -> Color {
        switch state {
        case .new: Theme.Colors.stateNew
        case .learning: Theme.Colors.stateLearning
        case .review: Theme.Colors.stateReview
        case .relearning: Theme.Colors.stateRelearning
        }
    }

    /// Human-readable state label
    private func stateLabel(for state: FlashcardState) -> String {
        switch state {
        case .new: "New"
        case .learning: "Learning"
        case .review: "Review"
        case .relearning: "Relearning"
        }
    }

    /// Format stability in human-readable units
    private func stabilityText(_ stability: Double) -> String {
        if stability < 1.0 {
            let hours = Int(stability * 24)
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if stability < 7.0 {
            let days = Int(stability)
            return days == 1 ? "1 day" : "\(days) days"
        } else if stability < 30.0 {
            let weeks = Int(stability / 7.0)
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        } else {
            let months = Int(stability / 30.0)
            return months == 1 ? "1 month" : "\(months) months"
        }
    }
}

// MARK: - Preview

private extension Preview {
    static func makePreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Flashcard.self, configurations: config)
        } catch {
            // Preview failure indicates a real problem - log and use minimal fallback
            assertionFailure("Failed to create preview container: \(error.localizedDescription)")
            // Fallback: return empty container to prevent preview crash
            // EmptyModel.self is guaranteed to succeed as it has no persistent properties
            return try! ModelContainer(for: EmptyModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}

#Preview("Flashcard Detail - New Card") {
    let container = Preview.makePreviewContainer()

    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time; short-lived; transitory",
        phonetic: "/əˈfem(ə)rəl/"
    )

    NavigationStack {
        FlashcardDetailView(flashcard: card)
    }
    .modelContainer(container)
}

#Preview("Flashcard Detail - With Translation") {
    let container = Preview.makePreviewContainer()

    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time; short-lived; transitory",
        translation: "Эфемерный",
        phonetic: "/əˈfem(ə)rəl/"
    )

    NavigationStack {
        FlashcardDetailView(flashcard: card)
    }
    .modelContainer(container)
}

#Preview("Flashcard Detail - With Reviews") {
    let container = Preview.makePreviewContainer()

    let card: Flashcard = {
        let card = Flashcard(
            word: "Serendipity",
            definition: "The occurrence of events by chance in a happy or beneficial way",
            translation: "Счастливая случайность",
            phonetic: "/ˌserənˈdipədē/"
        )

        // Add sample reviews
        let mainContext = container.mainContext
        let review1 = FlashcardReview(
            rating: 2,
            reviewDate: Date().addingTimeInterval(-1 * 24 * 60 * 60),
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        let review2 = FlashcardReview(
            rating: 3,
            reviewDate: Date().addingTimeInterval(-5 * 24 * 60 * 60),
            scheduledDays: 7.0,
            elapsedDays: 5.0
        )
        review1.card = card
        review2.card = card
        card.reviewLogs = [review1, review2]

        // Add FSRS state
        let state = FSRSState(
            stability: 14.3,
            state: .review
        )
        state.card = card
        card.fsrsState = state

        try? mainContext.save()

        return card
    }()

    NavigationStack {
        FlashcardDetailView(flashcard: card)
    }
    .modelContainer(container)
}
