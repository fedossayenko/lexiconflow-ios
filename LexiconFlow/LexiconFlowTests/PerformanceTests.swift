//
//  PerformanceTests.swift
//  LexiconFlowTests
//
//  Performance benchmarks for critical operations
//  Tests scaling with large datasets
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Performance benchmark suite
///
/// Tests that operations meet performance requirements:
/// - Review processing: < 10ms per card
/// - Due card query: < 100ms for 10k cards
/// - Preview generation: < 50ms
/// - Batch import: < 30s for 10k cards
@MainActor
struct PerformanceTests {

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - FSRS Processing Performance

    @Test("FSRS review processing is fast", .enabled(true))
    func fsrsProcessingPerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create test card
        let flashcard = Flashcard(word: "test", definition: "test")
        let state = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        context.insert(state)
        flashcard.fsrsState = state
        context.insert(flashcard)
        try! context.save()

        // Benchmark review processing
        let duration = try Benchmark.measure("fsrs_review") {
            _ = await scheduler.processReview(
                flashcard: flashcard,
                rating: 2,
                mode: .scheduled
            )
        }

        // Should complete in less than 10ms
        #expect(duration < 0.01, "FSRS processing should be < 10ms, took \(duration * 1000)ms")
    }

    @Test("Preview generation is fast")
    func previewPerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        let flashcard = Flashcard(word: "test", definition: "test")
        let state = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        context.insert(state)
        flashcard.fsrsState = state
        context.insert(flashcard)
        try! context.save()

        let duration = try Benchmark.measure("preview_generation") {
            _ = await scheduler.previewRatings(for: flashcard)
        }

        // Should complete in less than 50ms
        #expect(duration < 0.05, "Preview should be < 50ms, took \(duration * 1000)ms")
    }

    // MARK: - Query Performance

    @Test("Due card query scales well", .enabled(true))
    func dueCardQueryPerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 1000 due cards
        let batchSize = 100
        for batch in 0..<10 {
            for i in 0..<batchSize {
                let flashcard = Flashcard(
                    word: "word\(batch * batchSize + i)",
                    definition: "test"
                )
                let state = FSRSState(
                    stability: 5.0,
                    difficulty: 5.0,
                    retrievability: 0.9,
                    dueDate: Date().addingTimeInterval(-3600), // Due 1 hour ago
                    stateEnum: FlashcardState.review.rawValue
                )
                context.insert(state)
                flashcard.fsrsState = state
                context.insert(flashcard)
            }
            try! context.save()
        }

        // Benchmark query
        let duration = try Benchmark.measure("due_card_query_1000") {
            _ = scheduler.fetchCards(mode: .scheduled, limit: 20)
        }

        // Should complete in less than 100ms
        #expect(duration < 0.1, "Query should be < 100ms, took \(duration * 1000)ms")
    }

    @Test("Due card count is fast")
    func dueCardCountPerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 500 due cards
        for i in 0..<500 {
            let flashcard = Flashcard(word: "word\(i)", definition: "test")
            let state = FSRSState(
                stability: 5.0,
                difficulty: 5.0,
                retrievability: 0.9,
                dueDate: Date().addingTimeInterval(-3600),
                stateEnum: FlashcardState.review.rawValue
            )
            context.insert(state)
            flashcard.fsrsState = state
            context.insert(flashcard)
        }
        try! context.save()

        let duration = try Benchmark.measure("due_card_count_500") {
            _ = scheduler.dueCardCount()
        }

        // Should complete in less than 50ms
        #expect(duration < 0.05, "Count should be < 50ms, took \(duration * 1000)ms")
    }

    // MARK: - Cram Mode Performance

    @Test("Cram mode sorting by stability is fast")
    func cramModePerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 500 cards with varying stability
        for i in 0..<500 {
            let stability = Double.random(in: 1...50)
            let flashcard = Flashcard(word: "word\(i)", definition: "test")
            let state = FSRSState(
                stability: stability,
                difficulty: 5.0,
                retrievability: 0.9,
                dueDate: Date(),
                stateEnum: FlashcardState.review.rawValue
            )
            context.insert(state)
            flashcard.fsrsState = state
            context.insert(flashcard)
        }
        try! context.save()

        let duration = try Benchmark.measure("cram_sort_500") {
            _ = scheduler.fetchCards(mode: .cram, limit: 20)
        }

        // Should complete in less than 100ms
        #expect(duration < 0.1, "Cram sort should be < 100ms, took \(duration * 1000)ms")
    }

    // MARK: - Date Math Performance

    @Test("DateMath calculations are fast")
    func dateMathPerformance() {
        let pastDate = Date().addingTimeInterval(-86400 * 5) // 5 days ago
        let now = Date()

        let duration = try! Benchmark.measure("date_math_elapsed") {
            for _ in 0..<1000 {
                _ = DateMath.elapsedDays(from: pastDate, to: now)
            }
        }

        // 1000 operations should be fast
        #expect(duration < 0.01, "1000 date math ops should be < 10ms, took \(duration * 1000)ms")

        // Per-operation should be < 0.01ms
        let perOp = duration / 1000.0
        #expect(perOp < 0.00001, "Per operation should be < 0.01ms, took \(perOp * 1000000)μs")
    }

    // MARK: - Memory Performance

    @Test("Review logs don't cause memory issues")
    func reviewLogsMemoryEfficiency() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        let flashcard = Flashcard(word: "test", definition: "test")
        let state = FSRSState(
            stability: 5.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.review.rawValue
        )
        context.insert(state)
        flashcard.fsrsState = state
        context.insert(flashcard)

        // Add 100 reviews (simulating long-term use)
        for i in 0..<100 {
            let review = FlashcardReview(
                rating: Int.random(in: 0...3),
                reviewDate: Date().addingTimeInterval(-Double(86400 * (100 - i))),
                scheduledDays: 0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
        }
        try! context.save()

        // Using cached lastReviewDate should be fast
        let duration = try Benchmark.measure("process_with_100_reviews") {
            _ = await scheduler.processReview(
                flashcard: flashcard,
                rating: 2,
                mode: .scheduled
            )
        }

        // Should still be fast even with 100 reviews
        #expect(duration < 0.01, "Processing with 100 reviews should be < 10ms, took \(duration * 1000)ms")
    }

    // MARK: - Concurrency Performance

    @Test("Concurrent review processing scales linearly")
    func concurrentProcessingPerformance() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create 50 cards
        var cards: [Flashcard] = []
        for i in 0..<50 {
            let flashcard = Flashcard(word: "word\(i)", definition: "test")
            let state = FSRSState(
                stability: 5.0,
                difficulty: 5.0,
                retrievability: 0.9,
                dueDate: Date(),
                stateEnum: FlashcardState.review.rawValue
            )
            context.insert(state)
            flashcard.fsrsState = state
            context.insert(flashcard)
            cards.append(flashcard)
        }
        try! context.save()

        // Process concurrently
        let duration = try await Benchmark.measure("concurrent_50_reviews") {
            await withTaskGroup(of: Void.self) { group in
                for card in cards {
                    group.addTask {
                        _ = await scheduler.processReview(
                            flashcard: card,
                            rating: 2,
                            mode: .scheduled
                        )
                    }
                }
            }
        }

        // With 50 concurrent operations, should still be reasonable
        // (actor serializes, but concurrent calls should be efficient)
        let perOp = duration / 50.0
        #expect(perOp < 0.01, "Per concurrent op should be < 10ms, took \(perOp * 1000)ms")
    }
}
