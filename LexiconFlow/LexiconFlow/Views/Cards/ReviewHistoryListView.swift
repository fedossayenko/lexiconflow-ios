//
//  ReviewHistoryListView.swift
//  LexiconFlow
//
//  List view for review history with filtering controls
//  Displays filtered reviews with picker for time ranges
//

import SwiftUI

struct ReviewHistoryListView: View {
    /// The reviews to display (already filtered by view model)
    let reviews: [FlashcardReviewDTO]

    /// Currently selected filter
    @Binding var selectedFilter: ReviewHistoryFilter

    /// Callback when filter changes
    let onFilterChange: (ReviewHistoryFilter) -> Void

    /// Optional callback when export button is tapped
    let onExport: (() -> Void)?

    /// Initialize with reviews and filter binding
    ///
    /// **Why @Binding for filter**: Allows parent view (FlashcardDetailView)
    /// to observe filter changes for analytics tracking while keeping
    /// filter selection logic in this view.
    ///
    /// - Parameters:
    ///   - reviews: Filtered reviews from view model
    ///   - selectedFilter: Currently selected time filter
    ///   - onFilterChange: Callback when user changes filter
    ///   - onExport: Optional callback for export button
    init(
        reviews: [FlashcardReviewDTO],
        selectedFilter: Binding<ReviewHistoryFilter>,
        onFilterChange: @escaping (ReviewHistoryFilter) -> Void,
        onExport: (() -> Void)? = nil
    ) {
        self.reviews = reviews
        _selectedFilter = selectedFilter
        self.onFilterChange = onFilterChange
        self.onExport = onExport
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker header
            self.filterPickerHeader

            // Review list or empty state
            if self.reviews.isEmpty {
                self.emptyStateView
            } else {
                self.reviewList
            }
        }
    }

    // MARK: - Filter Picker Header

    /// Time filter picker with export button
    private var filterPickerHeader: some View {
        HStack {
            // Filter picker
            Picker("Time Range", selection: self.$selectedFilter) {
                ForEach(ReviewHistoryFilter.allCases, id: \.self) { filter in
                    Label(filter.displayName, systemImage: filter.icon)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: self.selectedFilter) { _, newValue in
                self.onFilterChange(newValue)

                // Haptic feedback for filter change
                if AppSettings.hapticEnabled {
                    HapticService.shared.triggerLight()
                }
            }

            Spacer()

            // Export button (if callback provided)
            if let onExport {
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
                .accessibilityLabel("Export review history")
                .accessibilityHint("Exports filtered reviews as CSV file")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Review List

    /// Lazy-loaded list of review rows
    ///
    /// **Why LazyVStack instead of List**: LazyVStack provides better
    /// performance for custom row layouts with complex styling. It loads
    /// only visible rows, making it suitable for 100+ reviews.
    private var reviewList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(self.reviews) { review in
                    ReviewHistoryRow(review: review)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    /// Empty state when no reviews match the filter
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Reviews", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("No reviews found for \(self.selectedFilter.displayName.lowercased())")
        } actions: {
            Button("Show All Time") {
                self.selectedFilter = .allTime
                self.onFilterChange(.allTime)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Show All Time reviews")
            .accessibilityHint("Displays all reviews regardless of date")
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedFilter: ReviewHistoryFilter = .allTime

        var body: some View {
            NavigationStack {
                ReviewHistoryListView(
                    reviews: sampleReviews,
                    selectedFilter: $selectedFilter,
                    onFilterChange: { _ in },
                    onExport: {}
                )
                .navigationTitle("Review History")
            }
        }

        /// Sample review data for preview
        var sampleReviews: [FlashcardReviewDTO] {
            [
                FlashcardReviewDTO(
                    id: UUID(),
                    rating: 2, // Good
                    reviewDate: Date().addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
                    scheduledDays: 3.0,
                    elapsedDays: 1.0,
                    stateChange: .none
                ),
                FlashcardReviewDTO(
                    id: UUID(),
                    rating: 3, // Easy
                    reviewDate: Date().addingTimeInterval(-5 * 24 * 60 * 60), // 5 days ago
                    scheduledDays: 14.0,
                    elapsedDays: 5.0,
                    stateChange: .graduated
                ),
                FlashcardReviewDTO(
                    id: UUID(),
                    rating: 1, // Hard
                    reviewDate: Date().addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
                    scheduledDays: 2.0,
                    elapsedDays: 3.0,
                    stateChange: .none
                ),
                FlashcardReviewDTO(
                    id: UUID(),
                    rating: 0, // Again
                    reviewDate: Date().addingTimeInterval(-15 * 24 * 60 * 60), // 15 days ago
                    scheduledDays: 1.0,
                    elapsedDays: 7.0,
                    stateChange: .relearning
                ),
                FlashcardReviewDTO(
                    id: UUID(),
                    rating: 2, // Good
                    reviewDate: Date().addingTimeInterval(-20 * 24 * 60 * 60), // 20 days ago
                    scheduledDays: 5.0,
                    elapsedDays: 4.0,
                    stateChange: .firstReview
                )
            ]
        }
    }

    return PreviewWrapper()
}
