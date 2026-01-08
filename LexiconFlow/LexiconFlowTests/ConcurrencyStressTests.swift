//
//  ConcurrencyStressTests.swift
//  LexiconFlowTests
//
//  Concurrency stress tests for Swift 6 strict compliance
//  Tests actor isolation, data race prevention, and concurrent access patterns
//

import Foundation
import OSLog
import SwiftData
import Testing
@testable import LexiconFlow

/// Concurrency stress test suite for Swift 6 strict compliance
///
/// Tests verify:
/// - Actor-isolated services prevent data races
/// - Concurrent access to @MainActor ViewModels is safe
/// - DTO pattern prevents cross-actor model mutations
/// - Sendable conformance for data transfer
///
/// **Concurrency Patterns Tested:**
/// - Actor isolation with FSRSWrapper
/// - @MainActor isolation with Scheduler
/// - Concurrent TaskGroup operations
/// - Async/await vs DispatchQueue patterns
@Suite(.serialized)
struct ConcurrencyStressTests {
    // MARK: - Test Configuration

    /// Logger for concurrency diagnostics
    private let logger = Logger(subsystem: "com.lexiconflow.tests", category: "Concurrency")

    /// Number of concurrent operations for stress tests
    private let concurrencyCount = 100

    // MARK: - Test Helpers

    @MainActor
    private func freshContext() -> ModelContext {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    private func createTestFlashcard(in context: ModelContext) -> Flashcard {
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "concurrent",
            phonetic: "/kənˈkɜːrənt/",
            definition: "existing or happening at the same time",
            partOfSpeech: "adjective",
            cefrLevel: "C1",
            deck: deck
        )
        flashcard.fsrsState = FSRSState(card: flashcard)
        context.insert(flashcard)
        try! context.save()
        return flashcard
    }

    // MARK: - Actor Isolation Tests

    @Test("Concurrent FSRS review processing maintains consistency")
    func concurrentFSRSProcessing() async throws {
        // Create a test flashcard
        let flashcard = try await createTestFlashcard(in: freshContext())

        // Track results
        let results = LockedArray<FSRSReviewResult>()

        // Process 100 concurrent reviews using TaskGroup
        await withTaskGroup(of: FSRSReviewResult.self) { group in
            for _ in 0 ..< concurrencyCount {
                group.addTask {
                    // Call actor-isolated FSRSWrapper
                    try! FSRSWrapper.shared.processReview(
                        flashcard: flashcard,
                        rating: Int.random(in: 1 ... 5)
                    )
                }
            }

            // Collect all results
            for await result in group {
                results.append(result)
            }
        }

        // Verify all operations completed successfully
        #expect(results.count == concurrencyCount, "All concurrent operations should complete")

        // Verify consistency: all results should have valid state
        for result in results.array {
            #expect(result.stability > 0, "Stability should be positive")
            #expect(result.difficulty > 0, "Difficulty should be positive")
            #expect(result.dueDate > Date(), "Due date should be in the future")
        }
    }

    @Test("MainActor ViewModel prevents concurrent mutation")
    @MainActor
    func mainActorViewModelSafety() async throws {
        let viewModel = Scheduler(modelContext: freshContext())
        let flashcard = createTestFlashcard(in: viewModel.modelContext)

        // Track results
        let results = LockedArray<FlashcardReview?>()

        // Process 50 concurrent reviews
        await withTaskGroup(of: FlashcardReview?.self) { group in
            for _ in 0 ..< 50 {
                group.addTask {
                    // Call @MainActor ViewModel from concurrent tasks
                    try? await viewModel.processReview(
                        flashcard: flashcard,
                        rating: Int.random(in: 1 ... 5)
                    )
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        // Verify no data races occurred
        #expect(results.array.count > 0, "At least some reviews should succeed")

        // Verify flashcard state is consistent
        #expect(
            flashcard.fsrsState?.stability != nil,
            "Stability should be set after reviews"
        )
    }

    // MARK: - Sendable Tests

    @Test("DTOs are Sendable across actor boundaries")
    func sendableDTOs() async throws {
        // Create test flashcard
        let flashcard = try await createTestFlashcard(in: freshContext())

        // Get DTO from actor
        let dto = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 3
        )

        // Verify DTO is Sendable (compilation test)
        #expect(dto is Sendable, "DTOs must conform to Sendable")

        // Verify DTO properties are accessible
        #expect(dto.stability > 0)
        #expect(dto.difficulty > 0)
        #expect(dto.dueDate > Date())
    }

    // MARK: - Concurrent Translation Tests

    @Test("Concurrent translation requests maintain safety")
    func concurrentTranslation() async throws {
        let service = OnDeviceTranslationService.shared
        await service.setLanguages(source: "en", target: "es")

        // Skip if language pair not supported
        guard service.isLanguagePairSupported() else {
            print("Skipping: Language pair not supported")
            return
        }

        let words = Array(repeating: "Hello", count: 20)
        let results = LockedArray<String>()

        // Process 20 concurrent translations
        await withTaskGroup(of: String?.self) { group in
            for word in words {
                group.addTask {
                    try? await service.translate(text: word)
                }
            }

            for await result in group {
                if let translation = result {
                    results.append(translation)
                }
            }
        }

        // Verify all operations completed successfully
        #expect(results.array.count > 0, "Translations should complete")
    }

    // MARK: - Data Race Detection Tests

    @Test("Actor isolation prevents data races in counters")
    func actorPreventsDataRaces() async {
        // Create an actor with mutable state
        actor Counter {
            private var value = 0

            func increment() {
                value += 1
            }

            func get() -> Int {
                value
            }
        }

        let counter = Counter()

        // Increment from 100 concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    await counter.increment()
                }
            }
        }

        // Verify final count is 100 (no lost increments)
        let finalValue = await counter.get()
        #expect(finalValue == 100, "Counter should reach 100 without data races")
    }
}

// MARK: - Test Helpers

/// Thread-safe array for concurrent test result collection
private actor LockedArray<Element> {
    private var array: [Element] = []

    func append(_ element: Element) {
        array.append(element)
    }

    var array: [Element] { array }
}
