//
//  FlashcardReviewTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardReview model
//  Covers: FlashcardReview creation, relationships, timestamp accuracy
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for FlashcardReview model
@MainActor
struct FlashcardReviewTests {

    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    // MARK: - FlashcardReview Creation Tests

    @Test("FlashcardReview creation with all fields")
    func flashcardReviewCreationWithAllFields() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.card?.word == "test")
        #expect(review.rating == 3)
        #expect(review.scheduledDays == 3.0)
        #expect(review.elapsedDays == 1.0)
    }

    @Test("FlashcardReview creation with minimal fields")
    func flashcardReviewCreationWithMinimalFields() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 0,
            elapsedDays: 0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.rating == 2)
        #expect(review.scheduledDays == 0)
        #expect(review.elapsedDays == 0)
    }

    // MARK: - Rating Tests

    @Test("FlashcardReview rating: again (0)")
    func reviewRatingAgain() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 0,
            scheduledDays: 0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.rating == 0)
    }

    @Test("FlashcardReview rating: hard (1)")
    func reviewRatingHard() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 1,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.rating == 1)
    }

    @Test("FlashcardReview rating: good (2)")
    func reviewRatingGood() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.rating == 2)
    }

    @Test("FlashcardReview rating: easy (3)")
    func reviewRatingEasy() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 7.0,
            elapsedDays: 3.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.rating == 3)
    }

    // MARK: - Timestamp Tests

    @Test("FlashcardReview timestamp is set automatically")
    func reviewTimestampAutomatic() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let beforeCreation = Date()

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)

        let afterCreation = Date()
        try context.save()

        #expect(review.reviewDate >= beforeCreation)
        #expect(review.reviewDate <= afterCreation)
    }

    @Test("FlashcardReview timestamp ordering")
    func reviewTimestampOrdering() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review1.card = flashcard
        context.insert(review1)

        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let review2 = FlashcardReview(
            rating: 3,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)

        try context.save()

        #expect(review1.reviewDate < review2.reviewDate)
    }

    // MARK: - Scheduled/Elapsed Days Tests

    @Test("FlashcardReview scheduledDays and elapsedDays")
    func reviewScheduledElapsedDays() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 7.0,
            elapsedDays: 6.5
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.scheduledDays == 7.0)
        #expect(review.elapsedDays == 6.5)
    }

    @Test("FlashcardReview elapsedDays can be zero")
    func reviewElapsedDaysZero() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 0,
            elapsedDays: 0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.elapsedDays == 0)
    }

    // MARK: - Review-Flashcard Relationship Tests

    @Test("FlashcardReview-flashcard relationship")
    func reviewFlashcardRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "hola", definition: "hello")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard

        context.insert(review)
        try context.save()

        #expect(review.card?.word == "hola")
        #expect(review.card?.definition == "hello")
    }

    @Test("FlashcardReview with no flashcard (should not happen in practice)")
    func reviewWithNoFlashcard() throws {
        let context = freshContext()
        try context.clearAll()

        // Create a review without associating it with a flashcard
        // This shouldn't happen in practice but tests the optional
        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        // Don't set review.card - leave it nil

        context.insert(review)
        try context.save()

        #expect(review.card == nil)
    }

    // MARK: - Multiple Reviews Tests

    @Test("Flashcard with multiple reviews")
    func flashcardWithMultipleReviews() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 0
        )
        review1.card = flashcard
        context.insert(review1)

        try await Task.sleep(nanoseconds: 10_000_000)

        let review2 = FlashcardReview(
            rating: 3,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        context.insert(review2)

        try await Task.sleep(nanoseconds: 10_000_000)

        let review3 = FlashcardReview(
            rating: 3,
            scheduledDays: 7.0,
            elapsedDays: 3.0
        )
        review3.card = flashcard
        context.insert(review3)

        try context.save()

        #expect(flashcard.reviewLogs.count == 3)
        #expect(flashcard.reviewLogs[0].rating == 2)
        #expect(flashcard.reviewLogs[1].rating == 3)
        #expect(flashcard.reviewLogs[2].rating == 3)

        // Verify ordering (oldest to newest)
        #expect(flashcard.reviewLogs[0].reviewDate < flashcard.reviewLogs[1].reviewDate)
        #expect(flashcard.reviewLogs[1].reviewDate < flashcard.reviewLogs[2].reviewDate)
    }

    // MARK: - Cascade Delete Tests

    @Test("Cascade delete: deleting flashcard nullifies reviews")
    func deleteFlashcardNullifiesReviews() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)

        try context.save()

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Reviews should be deleted (cascade delete rule)
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        #expect(reviews.count == 0)
    }

    @Test("Cascade delete: deleting flashcard with multiple reviews")
    func deleteFlashcardWithMultipleReviews() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        for i in 1...5 {
            let review = FlashcardReview(
                rating: i % 4,
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
        }

        try context.save()

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // All reviews should be deleted
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        #expect(reviews.count == 0)
    }

    // MARK: - Query Tests

    @Test("Query: fetch reviews by rating")
    func fetchReviewsByRating() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "test1", definition: "test")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "test2", definition: "test")
        context.insert(flashcard2)

        let review1 = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review1.card = flashcard1
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard2
        context.insert(review2)

        try context.save()

        // Fetch reviews with rating 3
        let predicate = #Predicate<FlashcardReview> { $0.rating == 3 }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.rating == 3)
    }

    @Test("Query: fetch reviews by elapsed days")
    func fetchReviewsByElapsedDays() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "test1", definition: "test")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "test2", definition: "test")
        context.insert(flashcard2)

        let review1 = FlashcardReview(
            rating: 2,
            scheduledDays: 0,
            elapsedDays: 0
        )
        review1.card = flashcard1
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 3,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard2
        context.insert(review2)

        try context.save()

        // Fetch reviews with zero elapsed days
        let predicate = #Predicate<FlashcardReview> { $0.elapsedDays == 0 }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
    }

    @Test("Query: fetch reviews sorted by timestamp")
    func fetchReviewsSortedByTimestamp() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        // Create multiple reviews
        for i in 1...3 {
            let review = FlashcardReview(
                rating: 2,
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)

            // Small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        try context.save()

        // Fetch sorted by reviewDate (oldest first)
        let descriptor = FetchDescriptor<FlashcardReview>(sortBy: [SortDescriptor(\.reviewDate)])
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].reviewDate < results[1].reviewDate)
        #expect(results[1].reviewDate < results[2].reviewDate)
    }

    @Test("Query: fetch reviews for specific flashcard")
    func fetchReviewsForFlashcard() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "card1", definition: "test")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "card2", definition: "test")
        context.insert(flashcard2)

        let review1 = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review1.card = flashcard1
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard2
        context.insert(review2)

        try context.save()

        // Fetch reviews for flashcard1 using its word
        let predicate = #Predicate<FlashcardReview> { $0.card?.word == "card1" }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.card?.word == "card1")
    }
}
