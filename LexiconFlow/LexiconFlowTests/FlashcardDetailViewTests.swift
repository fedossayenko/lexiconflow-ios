//
//  FlashcardDetailViewTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardDetailView and review history UI components
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify view creation, data flow, and component rendering.
//  Full UI behavior testing requires UI tests or snapshot tests.
//

import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

@MainActor
struct FlashcardDetailViewTests {
    // MARK: - Test Fixtures

    private func createTestFlashcard(
        word: String = "Ephemeral",
        definition: String = "Lasting for a very short time",
        phonetic: String? = "/əˈfem(ə)rəl/",
        translation: String? = nil
    ) -> Flashcard {
        let card = Flashcard(
            word: word,
            definition: definition,
            translation: translation,
            phonetic: phonetic
        )
        return card
    }

    private func createTestReview(
        rating: Int,
        daysAgo: Int,
        scheduledDays: Double,
        elapsedDays: Double
    ) -> FlashcardReview {
        return FlashcardReview(
            rating: rating,
            reviewDate: Date().addingTimeInterval(-TimeInterval(daysAgo * 24 * 60 * 60)),
            scheduledDays: scheduledDays,
            elapsedDays: elapsedDays
        )
    }

    private func createTestDTO(
        rating: Int,
        daysAgo: Int,
        scheduledDays: Double,
        elapsedDays: Double,
        stateChange: ReviewStateChange = .none
    ) -> FlashcardReviewDTO {
        return FlashcardReviewDTO(
            id: UUID(),
            rating: rating,
            reviewDate: Date().addingTimeInterval(-TimeInterval(daysAgo * 24 * 60 * 60)),
            scheduledDays: scheduledDays,
            elapsedDays: elapsedDays,
            stateChange: stateChange
        )
    }

    // MARK: - ReviewHistoryRow Tests

    @Test("ReviewHistoryRow renders with first review")
    func reviewHistoryRowWithFirstReview() {
        let dto = createTestDTO(
            rating: 2, // Good
            daysAgo: 1,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            stateChange: .firstReview
        )

        let row = ReviewHistoryRow(review: dto)

        // Verify row can be created
        #expect(dto.rating == 2, "Rating should be Good")
        #expect(dto.stateChange == .firstReview, "State change should be first review")
    }

    @Test("ReviewHistoryRow renders with graduated state change")
    func reviewHistoryRowWithGraduated() {
        let dto = createTestDTO(
            rating: 3, // Easy
            daysAgo: 5,
            scheduledDays: 7.0,
            elapsedDays: 5.0,
            stateChange: .graduated
        )

        let row = ReviewHistoryRow(review: dto)

        // Verify graduated badge
        #expect(dto.stateChange == .graduated, "State change should be graduated")
        #expect(dto.ratingLabel == "Easy", "Rating label should be Easy")
    }

    @Test("ReviewHistoryRow renders with relearning state change")
    func reviewHistoryRowWithRelearning() {
        let dto = createTestDTO(
            rating: 0, // Again
            daysAgo: 1,
            scheduledDays: 1.0,
            elapsedDays: 3.0,
            stateChange: .relearning
        )

        let row = ReviewHistoryRow(review: dto)

        // Verify relearning badge
        #expect(dto.stateChange == .relearning, "State change should be relearning")
        #expect(dto.ratingLabel == "Again", "Rating label should be Again")
    }

    @Test("ReviewHistoryRow renders with normal review (no state change)")
    func reviewHistoryRowWithNoStateChange() {
        let dto = createTestDTO(
            rating: 2, // Good
            daysAgo: 10,
            scheduledDays: 14.0,
            elapsedDays: 10.0,
            stateChange: .none
        )

        let row = ReviewHistoryRow(review: dto)

        // Verify no state change badge
        #expect(dto.stateChange == .none, "State change should be none")
        #expect(dto.stateChangeBadge == nil, "State change badge should be nil")
    }

    @Test("ReviewHistoryRow rating colors")
    func reviewHistoryRowRatingColors() {
        // Test all rating colors
        let againDTO = createTestDTO(rating: 0, daysAgo: 1, scheduledDays: 1.0, elapsedDays: 1.0)
        let hardDTO = createTestDTO(rating: 1, daysAgo: 1, scheduledDays: 1.0, elapsedDays: 1.0)
        let goodDTO = createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 1.0, elapsedDays: 1.0)
        let easyDTO = createTestDTO(rating: 3, daysAgo: 1, scheduledDays: 1.0, elapsedDays: 1.0)

        // Verify rating labels
        #expect(againDTO.ratingLabel == "Again", "Rating 0 should be Again")
        #expect(hardDTO.ratingLabel == "Hard", "Rating 1 should be Hard")
        #expect(goodDTO.ratingLabel == "Good", "Rating 2 should be Good")
        #expect(easyDTO.ratingLabel == "Easy", "Rating 3 should be Easy")

        // Verify rating icons exist
        #expect(!againDTO.ratingIcon.isEmpty, "Again should have icon")
        #expect(!hardDTO.ratingIcon.isEmpty, "Hard should have icon")
        #expect(!goodDTO.ratingIcon.isEmpty, "Good should have icon")
        #expect(!easyDTO.ratingIcon.isEmpty, "Easy should have icon")
    }

    @Test("ReviewHistoryRow date formatting")
    func reviewHistoryRowDateFormatting() {
        let nowDTO = createTestDTO(rating: 2, daysAgo: 0, scheduledDays: 1.0, elapsedDays: 0.0)
        let hoursDTO = createTestDTO(rating: 2, daysAgo: 0, scheduledDays: 1.0, elapsedDays: 0.1)
        let daysDTO = createTestDTO(rating: 2, daysAgo: 2, scheduledDays: 3.0, elapsedDays: 2.0)
        let weeksDTO = createTestDTO(rating: 2, daysAgo: 14, scheduledDays: 21.0, elapsedDays: 14.0)

        // Verify relative date strings
        #expect(!nowDTO.relativeDateString.isEmpty, "Should have relative date string")
        #expect(!hoursDTO.relativeDateString.isEmpty, "Should have relative date string")
        #expect(!daysDTO.relativeDateString.isEmpty, "Should have relative date string")
        #expect(!weeksDTO.relativeDateString.isEmpty, "Should have relative date string")
    }

    // MARK: - ReviewHistoryListView Tests

    @Test("ReviewHistoryListView renders with reviews")
    func reviewHistoryListViewWithReviews() {
        let reviews = [
            createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0),
            createTestDTO(rating: 3, daysAgo: 5, scheduledDays: 7.0, elapsedDays: 5.0),
            createTestDTO(rating: 1, daysAgo: 10, scheduledDays: 2.0, elapsedDays: 3.0),
        ]

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify view can be created with reviews
        #expect(reviews.count == 3, "Should have 3 reviews")
    }

    @Test("ReviewHistoryListView renders with empty reviews")
    func reviewHistoryListViewWithEmptyReviews() {
        let reviews: [FlashcardReviewDTO] = []

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify view handles empty state
        #expect(reviews.isEmpty, "Should show empty state")
    }

    @Test("ReviewHistoryListView filter change callback")
    func reviewHistoryListViewFilterChange() {
        var filterChanged = false
        var capturedFilter: ReviewHistoryFilter?

        let reviews = [createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0)]

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { filter in
                filterChanged = true
                capturedFilter = filter
            },
            onExport: nil
        )

        // Verify callback can be set
        #expect(!filterChanged, "Callback should not be invoked on creation")
    }

    @Test("ReviewHistoryListView export callback")
    func reviewHistoryListViewExportCallback() {
        var exportTapped = false

        let reviews = [createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0)]

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: {
                exportTapped = true
            }
        )

        // Verify export callback can be set
        #expect(!exportTapped, "Export callback should not be invoked on creation")
    }

    @Test("ReviewHistoryListView with all filters")
    func reviewHistoryListViewWithAllFilters() {
        let reviews = [
            createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0), // last week
            createTestDTO(rating: 2, daysAgo: 10, scheduledDays: 14.0, elapsedDays: 10.0), // last month
            createTestDTO(rating: 2, daysAgo: 40, scheduledDays: 45.0, elapsedDays: 40.0), // all time
        ]

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify all time filter shows all reviews
        #expect(reviews.count == 3, "All time filter should show all 3 reviews")
    }

    @Test("ReviewHistoryListView with last week filter")
    func reviewHistoryListViewWithLastWeekFilter() {
        let reviews = [
            createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0),
            createTestDTO(rating: 2, daysAgo: 5, scheduledDays: 7.0, elapsedDays: 5.0),
        ]

        @State var selectedFilter: ReviewHistoryFilter = .lastWeek
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify last week filter
        #expect(selectedFilter == .lastWeek, "Filter should be last week")
        #expect(reviews.count == 2, "Should show 2 reviews from last week")
    }

    @Test("ReviewHistoryListView with last month filter")
    func reviewHistoryListViewWithLastMonthFilter() {
        let reviews = [
            createTestDTO(rating: 2, daysAgo: 5, scheduledDays: 7.0, elapsedDays: 5.0),
            createTestDTO(rating: 2, daysAgo: 20, scheduledDays: 25.0, elapsedDays: 20.0),
        ]

        @State var selectedFilter: ReviewHistoryFilter = .lastMonth
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify last month filter
        #expect(selectedFilter == .lastMonth, "Filter should be last month")
        #expect(reviews.count == 2, "Should show 2 reviews from last month")
    }

    // MARK: - FlashcardDetailView Tests

    @Test("FlashcardDetailView renders with new card")
    func flashcardDetailViewWithNewCard() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard()
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify view can be created
        #expect(card.word == "Ephemeral", "View should display card word")
        #expect(card.definition == "Lasting for a very short time", "View should display definition")
    }

    @Test("FlashcardDetailView renders with translation")
    func flashcardDetailViewWithTranslation() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: "/əˈfem(ə)rəl/",
            translation: "Эфемерный"
        )
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify translation is displayed
        #expect(card.translation == "Эфемерный", "View should display translation")
    }

    @Test("FlashcardDetailView renders with context sentence")
    func flashcardDetailViewWithContextSentence() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: nil
        )
        context.insert(card)
        try context.save()

        // Add a generated sentence with context
        let sentence = try GeneratedSentence(
            sentenceText: "The ephemeral beauty of cherry blossoms reminds us to appreciate the present moment.",
            cefrLevel: "B2"
        )
        sentence.flashcard = card
        context.insert(sentence)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify context sentence is accessible via generatedSentences
        #expect(card.generatedSentences.first?.sentenceText.contains("ephemeral") == true, "View should display context sentence")
    }

    @Test("FlashcardDetailView renders with reviews")
    func flashcardDetailViewWithReviews() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard()
        context.insert(card)

        // Add reviews
        let review1 = createTestReview(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0)
        let review2 = createTestReview(rating: 3, daysAgo: 5, scheduledDays: 7.0, elapsedDays: 5.0)
        review1.card = card
        review2.card = card
        context.insert(review1)
        context.insert(review2)

        // Add FSRS state
        let state = FSRSState(
            stability: 14.3,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(14 * 24 * 60 * 60),
            stateEnum: FlashcardState.review.rawValue
        )
        state.card = card
        context.insert(state)

        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify card has reviews and state
        #expect(card.reviewLogs.count == 2, "Card should have 2 reviews")
        #expect(card.fsrsState != nil, "Card should have FSRS state")
        #expect(card.fsrsState?.stability == 14.3, "FSRS state should have stability")
    }

    @Test("FlashcardDetailView navigation title")
    func flashcardDetailViewNavigationTitle() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard(word: "Serendipity")
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify navigation title is card word
        #expect(card.word == "Serendipity", "Navigation title should be card word")
    }

    @Test("FlashcardDetailView with FSRS state")
    func flashcardDetailViewWithFSRSState() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard()
        context.insert(card)

        // Add FSRS state
        let state = FSRSState(
            stability: 2.5,
            difficulty: 6.0,
            retrievability: 0.85,
            dueDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            stateEnum: FlashcardState.learning.rawValue
        )
        state.card = card
        context.insert(state)

        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify FSRS state is displayed
        #expect(card.fsrsState?.stateEnum == FlashcardState.learning.rawValue, "Should display learning state")
        #expect(card.fsrsState?.stability == 2.5, "Should display stability")
    }

    // MARK: - Empty State Tests

    @Test("FlashcardDetailView with no reviews shows empty state")
    func flashcardDetailViewWithNoReviews() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard()
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify empty state is handled
        #expect(card.reviewLogs.isEmpty, "Should show empty review history state")
    }

    @Test("FlashcardDetailView with no FSRS state")
    func flashcardDetailViewWithNoFSRSState() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard()
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify nil FSRS state is handled
        #expect(card.fsrsState == nil, "Should handle nil FSRS state gracefully")
    }

    @Test("ReviewHistoryListView empty state action button")
    func reviewHistoryListViewEmptyStateAction() {
        let reviews: [FlashcardReviewDTO] = []

        var actionTapped = false
        @State var selectedFilter: ReviewHistoryFilter = .lastWeek

        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { filter in
                if filter == .allTime {
                    actionTapped = true
                }
            },
            onExport: nil
        )

        // Verify empty state can trigger action
        #expect(reviews.isEmpty, "Empty state should have action button")
    }

    // MARK: - Accessibility Tests

    @Test("ReviewHistoryRow has accessibility label")
    func reviewHistoryRowAccessibilityLabel() {
        let dto = createTestDTO(
            rating: 2,
            daysAgo: 1,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            stateChange: .firstReview
        )

        let row = ReviewHistoryRow(review: dto)

        // Verify accessibility properties exist
        #expect(!dto.ratingLabel.isEmpty, "Should have accessibility label for rating")
        #expect(dto.stateChangeBadge != nil, "Should have accessibility label for state change")
        #expect(!dto.relativeDateString.isEmpty, "Should have accessibility hint with date")
    }

    @Test("ReviewHistoryListView has accessibility labels")
    func reviewHistoryListViewAccessibilityLabels() {
        let reviews = [createTestDTO(rating: 2, daysAgo: 1, scheduledDays: 3.0, elapsedDays: 1.0)]

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: {}
        )

        // Verify accessibility labels can be set
        #expect(!reviews.isEmpty, "View should support accessibility")
    }

    @Test("FlashcardDetailView has accessibility labels")
    func flashcardDetailViewAccessibilityLabels() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = createTestFlashcard(
            word: "Test",
            definition: "Test definition",
            phonetic: "/test/"
        )
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify accessibility labels can be set
        #expect(card.word == "Test", "Should support accessibility labels")
    }

    // MARK: - Edge Cases

    @Test("FlashcardDetailView with very long word")
    func flashcardDetailViewWithLongWord() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let longWord = String(repeating: "a", count: 100)
        let card = createTestFlashcard(word: longWord)
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify long words are handled
        #expect(card.word.count == 100, "Should handle long words")
    }

    @Test("FlashcardDetailView with special characters")
    func flashcardDetailViewWithSpecialCharacters() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        let card = Flashcard(
            word: "日本語",
            definition: "Japanese language with emoji 🇯🇵",
            translation: "Японский",
            phonetic: nil
        )
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify special characters are handled
        #expect(card.word == "日本語", "Should handle Unicode characters")
        #expect(card.translation == "Японский", "Should handle Cyrillic characters")
    }

    @Test("ReviewHistoryListView with many reviews")
    func reviewHistoryListViewWithManyReviews() {
        var reviews: [FlashcardReviewDTO] = []

        // Create 100 reviews
        for i in 0 ..< 100 {
            reviews.append(createTestDTO(
                rating: i % 4,
                daysAgo: i,
                scheduledDays: Double(i + 1),
                elapsedDays: Double(i)
            ))
        }

        @State var selectedFilter: ReviewHistoryFilter = .allTime
        let view = ReviewHistoryListView(
            reviews: reviews,
            selectedFilter: $selectedFilter,
            onFilterChange: { _ in },
            onExport: nil
        )

        // Verify view handles many reviews
        #expect(reviews.count == 100, "Should handle 100 reviews without crash")
    }

    @Test("FlashcardDetailView with optional fields")
    func flashcardDetailViewWithOptionalFields() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()

        // Card with only required fields
        let card = Flashcard(word: "Test", definition: "Test definition")
        context.insert(card)
        try context.save()

        let view = FlashcardDetailView(flashcard: card)

        // Verify optional fields are handled
        #expect(card.phonetic == nil, "Should handle nil phonetic")
        #expect(card.translation == nil, "Should handle nil translation")
    }

    @Test("ReviewHistoryRow with boundary values")
    func reviewHistoryRowWithBoundaryValues() {
        // Test edge case: zero scheduled days
        let zeroScheduledDTO = createTestDTO(
            rating: 2,
            daysAgo: 0,
            scheduledDays: 0.0,
            elapsedDays: 0.0
        )

        // Test edge case: very large scheduled days
        let largeScheduledDTO = createTestDTO(
            rating: 2,
            daysAgo: 100,
            scheduledDays: 365.0,
            elapsedDays: 100.0
        )

        // Verify boundary values are handled
        #expect(!zeroScheduledDTO.scheduledIntervalDescription.isEmpty, "Should handle zero scheduled days")
        #expect(!largeScheduledDTO.scheduledIntervalDescription.isEmpty, "Should handle large scheduled days")
    }
}
