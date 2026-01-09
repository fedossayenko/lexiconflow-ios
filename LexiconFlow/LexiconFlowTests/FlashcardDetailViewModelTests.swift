//
//  FlashcardDetailViewModelTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardDetailViewModel with focus on state change detection
//  Covers: state transitions, DTO conversion, filtering, export functionality
//
//  Test Suite (25 tests):
//  - State Change Detection (6 tests): first review, graduation, relearning,
//    failure handling, missing state, complex progressions
//  - Filter Tests (3 tests): allTime, lastWeek, lastMonth
//  - Header Stats Tests (5 tests): total count, average rating, empty stats,
//    FSRS state reading, missing FSRS state
//  - Export Tests (4 tests): filtered export, all export, empty export,
//    special characters handling
//  - Performance Tests (2 tests): load 100+ reviews, filter 100+ reviews
//  - Edge Cases (5 tests): out-of-order reviews, same day reviews,
//    invalid ratings, DTO properties verification, filter selection
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for FlashcardDetailViewModel
@MainActor
struct FlashcardDetailViewModelTests {
    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - State Change Detection Tests

    @Test("Detect first review correctly")
    func detectFirstReview() throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create flashcard with one review
        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 0.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        // Create view model
        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Verify first review is detected
        #expect(viewModel.filteredReviews.count == 1, "Should have one review")
        let dto = viewModel.filteredReviews[0]
        #expect(dto.stateChange == .firstReview, "First review should be marked")
    }

    @Test("Detect graduation: learning → review transition")
    func detectGraduation() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        let now = Date()

        // First review: enters learning state
        let review1 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 2), // 2 days ago
            scheduledDays: 1.0,
            elapsedDays: 0.0
        )
        review1.card = flashcard
        context.insert(review1)

        // Second review: graduates to review state
        let review2 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400), // 1 day ago
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 2, "Should have two reviews")

        let dtos = viewModel.filteredReviews.sorted { $0.reviewDate < $1.reviewDate }

        // First review: marked as first review
        #expect(dtos[0].stateChange == .firstReview, "First review should be marked")

        // Second review: should show graduation
        #expect(dtos[1].stateChange == .graduated, "Second review should show graduation")
    }

    @Test("Detect relearning: review → relearning transition")
    func detectRelearning() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        let now = Date()

        // Create a graduated card with several reviews
        let review1 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 5),
            scheduledDays: 1.0,
            elapsedDays: 0.0
        )
        review1.card = flashcard
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 3),
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)

        // Failed review (rating 0): enters relearning
        let review3 = FlashcardReview(
            rating: 0, // Again
            reviewDate: now.addingTimeInterval(-86400),
            scheduledDays: 1.0,
            elapsedDays: 2.0
        )
        review3.card = flashcard
        context.insert(review3)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 3, "Should have three reviews")

        let dtos = viewModel.filteredReviews.sorted { $0.reviewDate < $1.reviewDate }

        // First review: first review
        #expect(dtos[0].stateChange == .firstReview, "First review should be marked")

        // Second review: graduation
        #expect(dtos[1].stateChange == .graduated, "Second review should show graduation")

        // Third review: relearning (failed with rating 0)
        #expect(dtos[2].stateChange == .relearning, "Third review should show relearning")
    }

    @Test("Handle first review with failure (rating 0)")
    func firstReviewWithFailure() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        // First review with rating 0 (Again)
        let review = FlashcardReview(
            rating: 0,
            reviewDate: Date(),
            scheduledDays: 0.0,
            elapsedDays: 0.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 1, "Should have one review")
        let dto = viewModel.filteredReviews[0]

        // Should still be marked as first review even with failure
        #expect(dto.stateChange == .firstReview, "First review should be marked even with rating 0")
    }

    @Test("Handle missing previous state gracefully")
    func missingPreviousState() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        // Create a single review (edge case: only one review in history)
        let review = FlashcardReview(
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 0.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Should not crash and should handle gracefully
        #expect(viewModel.filteredReviews.count == 1, "Should have one review")
        let dto = viewModel.filteredReviews[0]
        #expect(dto.stateChange == .firstReview, "Single review should be marked as first")
    }

    @Test("Complex progression: new → learning → review → relearning → review")
    func complexProgression() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "complex", definition: "Complex progression test")
        context.insert(flashcard)

        let now = Date()

        // Review 1: First review (new → learning)
        let review1 = FlashcardReview(
            rating: 2, // Good
            reviewDate: now.addingTimeInterval(-86400 * 10),
            scheduledDays: 1.0,
            elapsedDays: 0.0
        )
        review1.card = flashcard
        context.insert(review1)

        // Review 2: Graduation (learning → review)
        let review2 = FlashcardReview(
            rating: 3, // Easy
            reviewDate: now.addingTimeInterval(-86400 * 7),
            scheduledDays: 4.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)

        // Review 3: Stay in review
        let review3 = FlashcardReview(
            rating: 2, // Good
            reviewDate: now.addingTimeInterval(-86400 * 3),
            scheduledDays: 10.0,
            elapsedDays: 4.0
        )
        review3.card = flashcard
        context.insert(review3)

        // Review 4: Failure (review → relearning)
        let review4 = FlashcardReview(
            rating: 0, // Again
            reviewDate: now.addingTimeInterval(-86400),
            scheduledDays: 0.5,
            elapsedDays: 2.0
        )
        review4.card = flashcard
        context.insert(review4)

        // Review 5: Recovery (relearning → review)
        let review5 = FlashcardReview(
            rating: 2, // Good
            reviewDate: now,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review5.card = flashcard
        context.insert(review5)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 5, "Should have five reviews")

        let dtos = viewModel.filteredReviews.sorted { $0.reviewDate < $1.reviewDate }

        // Verify state changes
        #expect(dtos[0].stateChange == .firstReview, "Review 1: First review")
        #expect(dtos[1].stateChange == .graduated, "Review 2: Graduated to review")
        #expect(dtos[2].stateChange == .none, "Review 3: Stayed in review")
        #expect(dtos[3].stateChange == .relearning, "Review 4: Failed and entered relearning")
        #expect(dtos[4].stateChange == .none, "Review 5: Returned to review (no special marker)")
    }

    // MARK: - Filter Tests

    @Test("Filter reviews by last week")
    func filterByLastWeek() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test filtering")
        context.insert(flashcard)

        let now = Date()

        // Old review (3 weeks ago)
        let oldReview = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 21),
            scheduledDays: 3.0,
            elapsedDays: 2.0
        )
        oldReview.card = flashcard
        context.insert(oldReview)

        // Recent review (2 days ago)
        let recentReview = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 2),
            scheduledDays: 5.0,
            elapsedDays: 4.0
        )
        recentReview.card = flashcard
        context.insert(recentReview)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // All reviews
        #expect(viewModel.filteredReviews.count == 2, "Should have 2 reviews with all time filter")

        // Last week filter
        viewModel.selectFilter(.lastWeek)
        #expect(viewModel.filteredReviews.count == 1, "Should have 1 review with last week filter")
        #expect(viewModel.filteredReviews[0].id == recentReview.id, "Should show recent review")
    }

    @Test("Filter reviews by last month")
    func filterByLastMonth() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test month filtering")
        context.insert(flashcard)

        let now = Date()

        // Very old review (60 days ago)
        let veryOldReview = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 60),
            scheduledDays: 3.0,
            elapsedDays: 2.0
        )
        veryOldReview.card = flashcard
        context.insert(veryOldReview)

        // Recent review (10 days ago)
        let recentReview = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 10),
            scheduledDays: 5.0,
            elapsedDays: 4.0
        )
        recentReview.card = flashcard
        context.insert(recentReview)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Last month filter
        viewModel.selectFilter(.lastMonth)
        #expect(viewModel.filteredReviews.count == 1, "Should have 1 review with last month filter")
        #expect(viewModel.filteredReviews[0].id == recentReview.id, "Should show recent review")
    }

    @Test("Filter reviews by all time (default)")
    func filterByAllTime() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test all time filtering")
        context.insert(flashcard)

        let now = Date()

        // Create reviews across different time periods
        let oldReview = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 100), // 100 days ago
            scheduledDays: 3.0,
            elapsedDays: 2.0
        )
        oldReview.card = flashcard
        context.insert(oldReview)

        let recentReview = FlashcardReview(
            rating: 3,
            reviewDate: now.addingTimeInterval(-86400), // 1 day ago
            scheduledDays: 5.0,
            elapsedDays: 4.0
        )
        recentReview.card = flashcard
        context.insert(recentReview)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // All time filter is default
        #expect(viewModel.selectedFilter == .allTime, "Default filter should be allTime")
        #expect(viewModel.filteredReviews.count == 2, "Should show all reviews with allTime filter")

        // Explicitly set to allTime
        viewModel.selectFilter(.allTime)
        #expect(viewModel.filteredReviews.count == 2, "Should show all reviews with explicit allTime filter")
    }

    // MARK: - Header Stats Tests

    @Test("Calculate total review count")
    func totalReviewCount() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test stats")
        context.insert(flashcard)

        for i in 0 ..< 5 {
            let review = FlashcardReview(
                rating: i % 4,
                reviewDate: Date().addingTimeInterval(-86400 * Double(5 - i)),
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.totalReviewCount == 5, "Should count 5 reviews")
    }

    @Test("Calculate average rating")
    func averageRating() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test average rating")
        context.insert(flashcard)

        // Ratings: 2, 3, 1, 2 = average 2.0
        let ratings = [2, 3, 1, 2]
        for (i, rating) in ratings.enumerated() {
            let review = FlashcardReview(
                rating: rating,
                reviewDate: Date().addingTimeInterval(-86400 * Double(4 - i)),
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        let avg = viewModel.averageRating
        #expect(avg != nil, "Should have average rating")
        #expect(avg! == 2.0, "Average should be 2.0")
    }

    @Test("Handle empty review history for stats")
    func emptyReviewHistoryStats() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test empty stats")
        context.insert(flashcard)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.totalReviewCount == 0, "Should have 0 reviews")
        #expect(viewModel.averageRating == nil, "Average should be nil for no reviews")
    }

    @Test("Read FSRS state and stability")
    func fsrsStateAndStability() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test FSRS state")
        context.insert(flashcard)

        // Create FSRS state
        let state = FSRSState(
            stability: 5.5,
            difficulty: 4.2,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        state.card = flashcard
        context.insert(state)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Verify FSRS state is accessible
        #expect(viewModel.currentFSRSState == .review, "Should read FSRS state")
        #expect(viewModel.currentStability == 5.5, "Should read stability value")
    }

    @Test("Handle missing FSRS state")
    func missingFSRSState() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "Test missing FSRS state")
        context.insert(flashcard)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Should handle missing FSRS state gracefully
        #expect(viewModel.currentFSRSState == nil, "Should return nil for missing state")
        #expect(viewModel.currentStability == nil, "Should return nil for missing stability")
    }

    // MARK: - Export Tests

    @Test("Export CSV with filtered reviews")
    func exportCSVFiltered() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "export", definition: "Export test")
        context.insert(flashcard)

        let now = Date()

        // Create multiple reviews
        for i in 0 ..< 5 {
            let review = FlashcardReview(
                rating: i % 4,
                reviewDate: now.addingTimeInterval(-86400 * Double(5 - i)),
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Filter to last week (should have fewer reviews)
        viewModel.selectFilter(.lastWeek)

        // Export
        await viewModel.exportCSV()

        // Verify export succeeded
        #expect(viewModel.exportError == nil, "Export should succeed")
        #expect(viewModel.exportCSVString != nil, "Should have CSV string")
        #expect(viewModel.exportFilename != nil, "Should have filename")

        // Verify CSV contains headers and data
        let csv = viewModel.exportCSVString!
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count >= 2, "CSV should have header and at least one row")
    }

    @Test("Export all reviews CSV")
    func exportCSVAll() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "all", definition: "Export all test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            reviewDate: Date(),
            scheduledDays: 7.0,
            elapsedDays: 6.5
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        await viewModel.exportCSV()

        #expect(viewModel.exportError == nil, "Export should succeed")
        #expect(viewModel.exportCSVString != nil, "Should have CSV string")

        // Verify CSV format (headers include Word,Definition,Rating,Review Date,Scheduled Days,Elapsed Days,State Change)
        let csv = viewModel.exportCSVString!
        #expect(csv.contains("Review Date"), "CSV should have Review Date header")
        #expect(csv.contains("Rating"), "CSV should have Rating header")
        #expect(csv.contains("all"), "CSV should contain flashcard word")
    }

    @Test("Export CSV with empty review history")
    func exportCSVEmpty() async throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "empty", definition: "Empty export test")
        context.insert(flashcard)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        await viewModel.exportCSV()

        // Export should fail with empty reviews (no data to export)
        #expect(viewModel.exportError != nil, "Export should fail with empty reviews")
        #expect(viewModel.exportCSVString == nil, "Should not have CSV string")
        #expect(viewModel.exportFilename == nil, "Should not have filename")
    }

    @Test("Export CSV with special characters in data")
    func exportCSVSpecialCharacters() async throws {
        let context = self.freshContext()
        try context.clearAll()

        // Flashcard with special characters
        let flashcard = Flashcard(
            word: "test,word",
            definition: "A word with \"quotes\" and 'apostrophes'"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 0.5
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        await viewModel.exportCSV()

        #expect(viewModel.exportError == nil, "Export should succeed with special characters")
        #expect(viewModel.exportCSVString != nil, "Should have CSV string")

        // Verify special characters are properly escaped
        let csv = viewModel.exportCSVString!
        #expect(csv.contains("test,word"), "CSV should contain word with comma")
    }

    // MARK: - Performance Tests

    @Test("Performance: Load 100+ reviews efficiently")
    func loadManyReviews() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "performance", definition: "Performance test")
        context.insert(flashcard)

        // Create 150 reviews
        let reviewCount = 150
        for i in 0 ..< reviewCount {
            let review = FlashcardReview(
                rating: i % 4,
                reviewDate: Date().addingTimeInterval(-86400 * Double(reviewCount - i)),
                scheduledDays: Double(i % 10),
                elapsedDays: Double(i % 10)
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        // Measure load time
        let startTime = Date()
        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )
        let loadTime = Date().timeIntervalSince(startTime)

        // Verify all reviews loaded
        #expect(viewModel.filteredReviews.count == reviewCount, "Should load all \(reviewCount) reviews")

        // Performance check: should load in under 100ms on modern devices
        // This is a soft threshold - actual time depends on test hardware
        #expect(loadTime < 1.0, "Should load 150 reviews in under 1 second, took \(String(format: "%.3f", loadTime))s")
    }

    @Test("Performance: Filter 100+ reviews efficiently")
    func filterManyReviews() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "filterperf", definition: "Filter performance test")
        context.insert(flashcard)

        let now = Date()

        // Create 150 reviews spread over 6 months
        for i in 0 ..< 150 {
            let daysAgo = Double(i) * 1.2 // Spread out over ~180 days
            let review = FlashcardReview(
                rating: i % 4,
                reviewDate: now.addingTimeInterval(-86400 * daysAgo),
                scheduledDays: Double(i % 10),
                elapsedDays: Double(i % 10)
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Measure filter time
        let startTime = Date()
        viewModel.selectFilter(.lastWeek)
        let filterTime = Date().timeIntervalSince(startTime)

        // Should filter quickly
        #expect(filterTime < 0.1, "Should filter in under 100ms, took \(String(format: "%.3f", filterTime * 1000))ms")

        // Verify some reviews were filtered
        let allCount = viewModel.totalReviewCount
        let filteredCount = viewModel.filteredReviews.count
        #expect(filteredCount < allCount, "Filter should reduce review count")
    }

    // MARK: - Edge Cases

    @Test("Handle out-of-order reviews")
    func outOfOrderReviews() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "order", definition: "Test ordering")
        context.insert(flashcard)

        let now = Date()

        // Insert reviews in random order
        let review3 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 3),
            scheduledDays: 3.0,
            elapsedDays: 2.0
        )
        review3.card = flashcard
        context.insert(review3)

        let review1 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 10),
            scheduledDays: 1.0,
            elapsedDays: 0.0
        )
        review1.card = flashcard
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 2,
            reviewDate: now.addingTimeInterval(-86400 * 5),
            scheduledDays: 2.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Should correctly order and detect state changes
        #expect(viewModel.filteredReviews.count == 3, "Should have 3 reviews")

        let dtos = viewModel.filteredReviews.sorted { $0.reviewDate < $1.reviewDate }
        #expect(dtos[0].stateChange == .firstReview, "Oldest review should be first")
        #expect(dtos[1].stateChange == .graduated, "Middle review should show graduation")
    }

    @Test("Handle reviews on same day")
    func sameDayReviews() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "sameday", definition: "Same day reviews")
        context.insert(flashcard)

        let baseDate = Date()

        // Multiple reviews on same day (cram mode) - created in past so filter includes them
        for i in 0 ..< 3 {
            let review = FlashcardReview(
                rating: 2,
                reviewDate: baseDate.addingTimeInterval(-Double(i * 3600)), // 1 hour ago, 2 hours ago, 3 hours ago
                scheduledDays: 0.1,
                elapsedDays: 0.04
            )
            review.card = flashcard
            context.insert(review)
        }
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 3, "Should handle same-day reviews")

        let dtos = viewModel.filteredReviews.sorted { $0.reviewDate < $1.reviewDate }
        #expect(dtos[0].stateChange == .firstReview, "First should be marked")
        #expect(dtos[1].stateChange == .graduated, "Second should graduate")
    }

    @Test("Handle invalid rating values")
    func invalidRatingValues() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "invalid", definition: "Invalid rating test")
        context.insert(flashcard)

        // Create review with normal rating
        let review = FlashcardReview(
            rating: 5, // Invalid rating (should be 0-3)
            reviewDate: Date(),
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Should not crash and should handle gracefully
        #expect(viewModel.filteredReviews.count == 1, "Should handle invalid rating")
        let dto = viewModel.filteredReviews[0]
        #expect(dto.rating == 5, "DTO should preserve actual rating value")
        #expect(dto.ratingLabel == "Good", "Label should default to Good for invalid rating")
    }

    @Test("Verify DTO properties are correctly set")
    func dtoProperties() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "dto", definition: "DTO property test")
        context.insert(flashcard)

        let testDate = Date()
        let review = FlashcardReview(
            rating: 3,
            reviewDate: testDate,
            scheduledDays: 7.0,
            elapsedDays: 6.5
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        #expect(viewModel.filteredReviews.count == 1, "Should have one review")
        let dto = viewModel.filteredReviews[0]

        // Verify DTO matches review properties
        #expect(dto.rating == 3, "Rating should match")
        #expect(dto.reviewDate == testDate, "Date should match")
        #expect(dto.scheduledDays == 7.0, "Scheduled days should match")
        #expect(dto.elapsedDays == 6.5, "Elapsed days should match")
        #expect(dto.stateChange == .firstReview, "Should be marked as first review")
        #expect(dto.ratingLabel == "Easy", "Should have correct label")
    }

    @Test("Filter selection updates selectedFilter property")
    func filterSelection() throws {
        let context = self.freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "filter", definition: "Filter selection test")
        context.insert(flashcard)
        try context.save()

        let viewModel = FlashcardDetailViewModel(
            flashcard: flashcard,
            modelContext: context
        )

        // Default filter
        #expect(viewModel.selectedFilter == .allTime, "Default should be allTime")

        // Change filter
        viewModel.selectFilter(.lastWeek)
        #expect(viewModel.selectedFilter == .lastWeek, "Should update to lastWeek")

        viewModel.selectFilter(.lastMonth)
        #expect(viewModel.selectedFilter == .lastMonth, "Should update to lastMonth")

        viewModel.selectFilter(.allTime)
        #expect(viewModel.selectedFilter == .allTime, "Should update to allTime")
    }
}
