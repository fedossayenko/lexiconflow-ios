//
//  FlashcardDetailViewModel.swift
//  LexiconFlow
//
//  @MainActor view model for flashcard detail view with review history fetching
//  Manages review history display, filtering, and export functionality
//

import Combine
import Foundation
import OSLog
import SwiftData

// MARK: - FlashcardDetailError

/// Errors that can occur in flashcard detail view
enum FlashcardDetailError: LocalizedError, Sendable {
    case exportFailed(underlying: String)
    case invalidFlashcard

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export review history. Please try again."
        case .invalidFlashcard:
            return "Invalid flashcard data."
        }
    }

    var failureReason: String? {
        switch self {
        case let .exportFailed(message):
            return "Underlying error: \(message)"
        case .invalidFlashcard:
            return "Flashcard object is nil or incomplete"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .exportFailed:
            return "Try again. If the problem persists, check your storage."
        case .invalidFlashcard:
            return "Navigate back and select the card again."
        }
    }
}

/// View model for flashcard detail view with review history management
///
/// **Architecture**: @MainActor isolated for safe SwiftData access.
/// **Data Access**: Uses flashcard.reviewLogs relationship (SwiftData auto-updates).
/// **State Change Detection**: Converts FlashcardReview to FlashcardReviewDTO with
///   transition detection (new→learning, learning→review, etc.).
/// **Performance**: Lazy loading with SwiftData relationships, efficient filtering for 100+ reviews.
///
/// **Usage**:
/// ```swift
/// struct FlashcardDetailView: View {
///     let flashcard: Flashcard
///     @StateObject private var viewModel: FlashcardDetailViewModel
///     @Environment(\.modelContext) private var modelContext
///
///     var body: some View {
///         ReviewHistoryListView(reviews: viewModel.filteredReviews)
///             .task {
///                 await viewModel.trackView()
///             }
///     }
/// }
/// ```
@MainActor
final class FlashcardDetailViewModel: ObservableObject {
    /// Logger for view model operations
    private static let logger = Logger(subsystem: "com.lexiconflow.viewmodels", category: "FlashcardDetail")

    // MARK: - Published Properties

    /// Selected time filter for review history
    /// Cache is automatically invalidated when this property changes
    @Published var selectedFilter: ReviewHistoryFilter = .allTime {
        didSet {
            // Automatically invalidate cache when filter changes
            // This ensures cache is invalidated whether filter is set via
            // selectFilter() method or modified directly
            if oldValue != selectedFilter {
                cacheInvalidated = true
            }
        }
    }

    /// Export error for user-facing alert
    @Published var exportError: Error?

    /// Export success state for ShareLink presentation
    @Published var exportCSVString: String?

    /// Export filename for ShareLink
    @Published var exportFilename: String?

    // MARK: - Cache Properties

    /// Cached filtered reviews for performance optimization
    ///
    /// **Why caching**: Prevents O(n) recalculation on every view render.
    /// Cache is invalidated when selectedFilter changes.
    private var cachedFilteredReviews: [FlashcardReviewDTO] = []

    /// Whether the cache is invalid and needs recalculation
    private var cacheInvalidated = true

    // MARK: - Dependencies

    /// The flashcard being displayed
    private let flashcard: Flashcard

    /// Model context for SwiftData operations
    private let modelContext: ModelContext

    /// Export service for CSV generation
    private let exporter = ReviewHistoryExporter()

    // MARK: - Initialization

    /// Initialize with flashcard and model context
    ///
    /// **Why no @Query**: @Query is only for Views, not ViewModels.
    /// We use the flashcard's reviewLogs relationship instead, which SwiftData
    /// automatically keeps up-to-date.
    ///
    /// **Performance**: SwiftData relationships are lazy-loaded, so 100+ reviews
    /// won't impact initialization performance.
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard to display
    ///   - modelContext: SwiftData model context
    init(flashcard: Flashcard, modelContext: ModelContext) {
        self.flashcard = flashcard
        self.modelContext = modelContext
    }

    // MARK: - Computed Properties

    /// All reviews for this flashcard from the relationship
    ///
    /// **Why computed property**: SwiftData automatically updates the relationship
    /// when reviews are added/modified. This provides a stable accessor that
    /// always reflects the current database state.
    private var allReviews: [FlashcardReview] {
        // SwiftData relationship is automatically maintained
        return flashcard.reviewLogs
    }

    /// Filtered review history as DTOs with state changes
    ///
    /// **Why DTO**: FlashcardReview models cannot be Sendable. DTOs provide
    /// thread-safe snapshots for UI rendering.
    ///
    /// **Performance**: O(n) conversion with lazy loading from SwiftData.
    /// Uses caching to prevent recalculation on every view render.
    /// For 100+ reviews, conversion runs in <10ms on modern devices.
    ///
    /// **Cache Strategy**: Cache is invalidated when `selectedFilter` changes.
    /// This prevents O(n) recalculation on every render while maintaining
    /// correctness when filters change.
    var filteredReviews: [FlashcardReviewDTO] {
        // Return cached value if valid
        if !cacheInvalidated {
            return cachedFilteredReviews
        }

        // Recalculate and cache
        let matchingReviews = allReviews.filter { review in
            selectedFilter.matches(review.reviewDate)
        }
        cachedFilteredReviews = convertToDTOs(matchingReviews)
        cacheInvalidated = false
        return cachedFilteredReviews
    }

    /// Total review count (for header stats)
    var totalReviewCount: Int {
        allReviews.count
    }

    /// Average rating (for header stats)
    ///
    /// **Returns**: nil if no reviews exist
    var averageRating: Double? {
        guard !allReviews.isEmpty else { return nil }

        let sum = allReviews.reduce(0.0) { partialResult, review in
            partialResult + Double(review.rating)
        }

        return sum / Double(allReviews.count)
    }

    /// Current FSRS state for header display
    var currentFSRSState: FlashcardState? {
        flashcard.fsrsState?.state
    }

    /// Current stability value for header display
    var currentStability: Double? {
        flashcard.fsrsState?.stability
    }

    // MARK: - State Change Detection

    /// Convert FlashcardReview models to DTOs with state change detection
    ///
    /// **Algorithm**:
    /// 1. Sort reviews by date (ascending) to process chronologically
    /// 2. Infer state progression for each review based on FSRS rules
    /// 3. Detect state transitions (first review, graduation, relearning)
    /// 4. Return DTOs with state change annotations (sorted descending for display)
    ///
    /// **State Inference Logic**:
    /// Since FlashcardReview doesn't store state snapshots, we reconstruct the
    /// state sequence using these rules:
    ///
    /// - **First review**: Always starts in `.new` state
    /// - **After passing review** (rating 1-3): Progress toward `.review`
    ///   - `.new` → `.learning` (first successful review)
    ///   - `.learning` → `.review` (graduation)
    ///   - `.review` → `.review` (stays in review)
    /// - **After failed review** (rating 0): Enter `.relearning`
    ///   - Any state → `.relearning`
    ///   - Next passing review graduates back to `.review`
    ///
    /// **State Transitions Detected**:
    /// - **First Review**: Card's initial review event
    /// - **Graduation**: `.learning` → `.review` transition (user learned the card)
    /// - **Relearning**: Any state → `.relearning` (user failed with rating 0)
    ///
    /// **Edge Cases Handled**:
    /// - First review: Marked as `.firstReview`
    /// - Missing previous state: Assume `.review` (safe default)
    /// - Invalid rating: Treated as passing (rating > 0)
    ///
    /// - Parameter reviews: Reviews to convert (may be unsorted)
    /// - Returns: DTOs with state change annotations (sorted by date descending)
    private func convertToDTOs(_ reviews: [FlashcardReview]) -> [FlashcardReviewDTO] {
        guard !reviews.isEmpty else { return [] }

        // Sort ascending to process chronologically (oldest first)
        let chronological = reviews.sorted { $0.reviewDate < $1.reviewDate }

        var dtos: [FlashcardReviewDTO] = []
        var previousState: FlashcardState?

        for (index, review) in chronological.enumerated() {
            let isFirstReview = (index == 0)

            // Infer current state using FSRS transition rules
            let currentState = inferCurrentState(
                previousState: previousState,
                rating: review.rating,
                isFirstReview: isFirstReview
            )

            // Create DTO with state change detection
            let dto = FlashcardReviewDTO.from(
                review,
                previousState: previousState,
                currentState: currentState,
                isFirstReview: isFirstReview
            )

            dtos.append(dto)

            // Update previous state for next iteration
            previousState = currentState
        }

        // Return sorted descending (newest first) for display
        return dtos.sorted { $0.reviewDate > $1.reviewDate }
    }

    /// Infer the FSRS state after a review based on previous state and rating
    ///
    /// **FSRS State Transition Rules**:
    /// - Rating 0 (Again) → `.relearning`
    /// - Rating 1-3 (Hard/Good/Easy) → Progress toward `.review`
    ///
    /// **Progression Logic**:
    /// ```swift
    /// // First review: .new card state inferred, passing reviews move toward .review
    /// // (inferred .new) --(rating>0, isFirstReview)→ .learning --(rating>0)→ .review
    /// // Any failed review goes to .relearning
    /// any state --(rating=0)→ .relearning --(rating>0)→ .review
    /// ```
    ///
    /// **State Inference for First Review**:
    /// Since FlashcardReview doesn't store state snapshots, we infer that a card
    /// starts in `.new` state before its first review. This enables proper graduation
    /// detection when the card progresses through learning.
    ///
    /// - Parameters:
    ///   - previousState: State before this review (nil for first review)
    ///   - rating: Review rating (0-3, where 0 = Again/fail)
    ///   - isFirstReview: True if this is the card's first review
    /// - Returns: Inferred state after this review
    private func inferCurrentState(
        previousState: FlashcardState?,
        rating: Int,
        isFirstReview: Bool
    ) -> FlashcardState {
        let didFail = (rating == 0)

        // Handle first review: infer card was in .new state before review
        if isFirstReview {
            // Card started in .new, now transitions based on rating
            if didFail {
                return .relearning
            } else {
                // First successful review: .new → .learning (enables graduation detection)
                return .learning
            }
        }

        // Handle missing previous state (shouldn't happen, but defensive)
        guard let previous = previousState else {
            return didFail ? .relearning : .review
        }

        // Handle failed review (rating 0 = Again)
        if didFail {
            return .relearning
        }

        // Handle passing review (rating 1-3)
        switch previous {
        case .new:
            // First successful review: enter learning phase
            return .learning

        case .learning:
            // Second successful review: graduate to review (graduation detected)
            return .review

        case .relearning:
            // Passed after relearning: return to review
            return .review

        case .review:
            // Stay in review state
            return .review
        }
    }

    // MARK: - Export

    /// Export review history as CSV
    ///
    /// **Usage**:
    /// ```swift
    /// Button("Export") {
    ///     await viewModel.exportCSV()
    /// }
    /// .alert("Error", isPresented: .constant(viewModel.exportError != nil)) {
    ///     Button("OK") { viewModel.exportError = nil }
    /// } message: {
    ///     Text(viewModel.exportError?.localizedDescription ?? "")
    /// }
    /// ```
    ///
    /// **Flow**:
    /// 1. Convert filtered reviews to DTOs
    /// 2. Call ReviewHistoryExporter to generate CSV
    /// 3. Set exportCSVString for ShareLink presentation
    /// 4. Track successful export with analytics
    /// 5. Handle errors with user-facing alert
    func exportCSV() async {
        Self.logger.info("Starting CSV export for '\(flashcard.word)'")

        do {
            // Export filtered reviews as DTOs
            let csv = try await exporter.exportFilteredCSV(
                filteredReviews,
                for: flashcard,
                filter: selectedFilter
            )

            // Generate filename
            let filename = exporter.generateFilename(for: flashcard)

            // Update published properties for ShareLink
            exportCSVString = csv
            exportFilename = filename
            exportError = nil

            // Track successful export
            let csvByteCount = csv.utf8.count
            await trackExport(csvByteCount: csvByteCount)

            Self.logger.info("CSV export successful: \(csvByteCount) bytes")

        } catch {
            Self.logger.error("CSV export failed: \(error.localizedDescription)")

            // Track error with analytics
            await Analytics.trackError("review_history_export_failed", error: error)

            // Set user-facing error
            exportError = FlashcardDetailError.exportFailed(
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - Analytics

    /// Track when user views flashcard detail
    ///
    /// **Why async**: Analytics tracking may involve network calls
    func trackView() async {
        await Analytics.trackEvent("review_history_viewed", metadata: [
            "flashcard_word": flashcard.word,
            "review_count": "\(totalReviewCount)",
            "current_state": currentFSRSState?.rawValue ?? "none",
            "stability": currentStability.map { String(format: "%.2f", $0) } ?? "0.0",
        ])
    }

    /// Track when user changes filter
    ///
    /// - Parameter filter: The newly selected filter
    func trackFilterChange(_ filter: ReviewHistoryFilter) async {
        await Analytics.trackEvent("review_history_filter_changed", metadata: [
            "filter": filter.rawValue,
            "flashcard_word": flashcard.word,
        ])
    }

    /// Track when user exports review history
    ///
    /// **Usage**: Call after successful CSV export.
    ///
    /// **Metadata tracked**:
    /// - flashcard_word: The word being exported
    /// - review_count: Number of reviews in export
    /// - filter_type: Time filter applied (allTime, lastWeek, lastMonth)
    /// - file_size_bytes: Size of generated CSV file
    ///
    /// - Parameter csvByteCount: Size of the exported CSV in bytes
    func trackExport(csvByteCount: Int) async {
        await Analytics.trackEvent("review_history_exported", metadata: [
            "flashcard_word": flashcard.word,
            "review_count": "\(filteredReviews.count)",
            "filter_type": selectedFilter.rawValue,
            "file_size_bytes": "\(csvByteCount)",
        ])
    }
}

// MARK: - Filter Selection

extension FlashcardDetailViewModel {
    /// Update selected filter and invalidate cache
    ///
    /// **Note**: Analytics tracking is handled by the view using `.task(id:)` modifier
    /// for automatic task lifecycle management. This prevents memory leaks from
    /// untracked fire-and-forget tasks.
    ///
    /// - Parameter filter: The new filter to apply
    func selectFilter(_ filter: ReviewHistoryFilter) {
        selectedFilter = filter
        // Cache is automatically invalidated by didSet
        // Trigger recalculation immediately for UI responsiveness
        _ = filteredReviews
    }
}
