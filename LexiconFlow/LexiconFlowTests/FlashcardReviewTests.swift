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
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.5,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 5.5
        )

        context.insert(review)
        try context.save()

        #expect(review.flashcard?.word == "test")
        #expect(review.rating == 3)
        #expect(review.timeTaken == 5.5)
        #expect(review.scheduledDays == 3.0)
        #expect(review.elapsedDays == 1.0)
        #expect(review.state == "review")
        #expect(review.stability == 2.0)
        #expect(review.difficulty == 5.5)
    }

    @Test("FlashcardReview creation with minimal fields")
    func flashcardReviewCreationWithMinimalFields() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 0,
            scheduledDays: 0,
            elapsedDays: 0,
            state: "new",
            stability: 0,
            difficulty: 5
        )

        context.insert(review)
        try context.save()

        #expect(review.rating == 2)
        #expect(review.timeTaken == 0)
        #expect(review.scheduledDays == 0)
    }

    // MARK: - Rating Tests

    @Test("FlashcardReview rating: again (0)")
    func reviewRatingAgain() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 0,
            timeTaken: 10.0,
            scheduledDays: 0,
            elapsedDays: 1.0,
            state: "relearning",
            stability: 0.1,
            difficulty: 6.0
        )

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
            flashcard: flashcard,
            rating: 1,
            timeTaken: 8.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.5
        )

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
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 5.0
        )

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
            flashcard: flashcard,
            rating: 3,
            timeTaken: 2.0,
            scheduledDays: 7.0,
            elapsedDays: 3.0,
            state: "review",
            stability: 5.0,
            difficulty: 4.0
        )

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
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)

        let afterCreation = Date()
        try context.save()

        #expect(review.timestamp >= beforeCreation)
        #expect(review.timestamp <= afterCreation)
    }

    @Test("FlashcardReview timestamp ordering")
    func reviewTimestampOrdering() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review1)

        // Small delay to ensure different timestamps
        try Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let review2 = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 3.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 4.5
        )
        context.insert(review2)

        try context.save()

        #expect(review1.timestamp < review2.timestamp)
    }

    // MARK: - Time Taken Tests

    @Test("FlashcardReview timeTaken: zero seconds")
    func reviewTimeTakenZero() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.timeTaken == 0)
    }

    @Test("FlashcardReview timeTaken: fractional seconds")
    func reviewTimeTakenFractional() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 3.7,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.timeTaken == 3.7)
    }

    @Test("FlashcardReview timeTaken: large value")
    func reviewTimeTakenLarge() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 1,
            timeTaken: 300.0, // 5 minutes
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.timeTaken == 300.0)
    }

    // MARK: - Scheduled/Elapsed Days Tests

    @Test("FlashcardReview scheduledDays and elapsedDays")
    func reviewScheduledElapsedDays() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 7.0,
            elapsedDays: 6.5,
            state: "review",
            stability: 5.0,
            difficulty: 5.0
        )

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
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 0,
            elapsedDays: 0,
            state: "new",
            stability: 0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.elapsedDays == 0)
    }

    // MARK: - State String Tests

    @Test("FlashcardReview state: new")
    func reviewStateNew() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 0,
            elapsedDays: 0,
            state: "new",
            stability: 0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.state == "new")
    }

    @Test("FlashcardReview state: learning")
    func reviewStateLearning() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 0,
            elapsedDays: 0,
            state: "learning",
            stability: 0.5,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.state == "learning")
    }

    @Test("FlashcardReview state: review")
    func reviewStateReview() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.state == "review")
    }

    // MARK: - Review-Flashcard Relationship Tests

    @Test("FlashcardReview-flashcard relationship")
    func reviewFlashcardRelationship() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "hola", definition: "hello")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.flashcard?.word == "hola")
        #expect(review.flashcard?.definition == "hello")
    }

    @Test("FlashcardReview with no flashcard (should not happen in practice)")
    func reviewWithNoFlashcard() throws {
        let context = freshContext()
        try context.clearAll()

        // Create a review without associating it with a flashcard
        // This shouldn't happen in practice but tests the optional
        let review = FlashcardReview(
            flashcard: nil,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )

        context.insert(review)
        try context.save()

        #expect(review.flashcard == nil)
    }

    // MARK: - Multiple Reviews Tests

    @Test("Flashcard with multiple reviews")
    func flashcardWithMultipleReviews() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            flashcard: flashcard,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 0,
            state: "learning",
            stability: 0.5,
            difficulty: 5.0
        )
        context.insert(review1)

        try Task.sleep(nanoseconds: 10_000_000)

        let review2 = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 4.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 4.8
        )
        context.insert(review2)

        try Task.sleep(nanoseconds: 10_000_000)

        let review3 = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 3.0,
            scheduledDays: 7.0,
            elapsedDays: 3.0,
            state: "review",
            stability: 5.0,
            difficulty: 4.5
        )
        context.insert(review3)

        try context.save()

        #expect(flashcard.reviewLogs.count == 3)
        #expect(flashcard.reviewLogs[0].rating == 2)
        #expect(flashcard.reviewLogs[1].rating == 3)
        #expect(flashcard.reviewLogs[2].rating == 3)

        // Verify ordering (oldest to newest)
        #expect(flashcard.reviewLogs[0].timestamp < flashcard.reviewLogs[1].timestamp)
        #expect(flashcard.reviewLogs[1].timestamp < flashcard.reviewLogs[2].timestamp)
    }

    // MARK: - Cascade Delete Tests

    @Test("Cascade delete: deleting flashcard nullifies reviews")
    func deleteFlashcardNullifiesReviews() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            flashcard: flashcard,
            rating: 3,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
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
                flashcard: flashcard,
                rating: i % 4,
                timeTaken: Double(i),
                scheduledDays: 1.0,
                elapsedDays: 1.0,
                state: "review",
                stability: 1.0,
                difficulty: 5.0
            )
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
            flashcard: flashcard1,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review1)

        let review2 = FlashcardReview(
            flashcard: flashcard2,
            rating: 3,
            timeTaken: 3.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 4.5
        )
        context.insert(review2)

        try context.save()

        // Fetch reviews with rating 3
        let predicate = #Predicate<FlashcardReview> { $0.rating == 3 }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.rating == 3)
    }

    @Test("Query: fetch reviews by state")
    func fetchReviewsByState() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard1 = Flashcard(word: "test1", definition: "test")
        context.insert(flashcard1)

        let flashcard2 = Flashcard(word: "test2", definition: "test")
        context.insert(flashcard2)

        let review1 = FlashcardReview(
            flashcard: flashcard1,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 0,
            elapsedDays: 0,
            state: "learning",
            stability: 0.5,
            difficulty: 5.0
        )
        context.insert(review1)

        let review2 = FlashcardReview(
            flashcard: flashcard2,
            rating: 3,
            timeTaken: 3.0,
            scheduledDays: 3.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 4.5
        )
        context.insert(review2)

        try context.save()

        // Fetch reviews in learning state
        let predicate = #Predicate<FlashcardReview> { $0.state == "learning" }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
    }

    @Test("Query: fetch reviews sorted by timestamp")
    func fetchReviewsSortedByTimestamp() throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        // Create multiple reviews
        for i in 1...3 {
            let review = FlashcardReview(
                flashcard: flashcard,
                rating: 2,
                timeTaken: 5.0,
                scheduledDays: 1.0,
                elapsedDays: 1.0,
                state: "review",
                stability: 1.0,
                difficulty: 5.0
            )
            context.insert(review)

            // Small delay to ensure different timestamps
            try Task.sleep(nanoseconds: 10_000_000)
        }

        try context.save()

        // Fetch sorted by timestamp (oldest first)
        let descriptor = FetchDescriptor<FlashcardReview>(sortBy: [SortDescriptor(\.timestamp)])
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].timestamp < results[1].timestamp)
        #expect(results[1].timestamp < results[2].timestamp)
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
            flashcard: flashcard1,
            rating: 2,
            timeTaken: 5.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 1.0,
            difficulty: 5.0
        )
        context.insert(review1)

        let review2 = FlashcardReview(
            flashcard: flashcard2,
            rating: 3,
            timeTaken: 3.0,
            scheduledDays: 1.0,
            elapsedDays: 1.0,
            state: "review",
            stability: 2.0,
            difficulty: 4.5
        )
        context.insert(review2)

        try context.save()

        // Fetch reviews for flashcard1 using its word
        let predicate = #Predicate<FlashcardReview> { $0.flashcard?.word == "card1" }
        let descriptor = FetchDescriptor<FlashcardReview>(predicate: predicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.flashcard?.word == "card1")
    }
}
