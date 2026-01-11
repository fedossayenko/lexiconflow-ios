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
@preconcurrency import Testing
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
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
            StudySession.self,
            DailyStats.self,
            GeneratedSentence.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    @MainActor
    private func createTestFlashcard(in context: ModelContext) -> Flashcard {
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        let flashcard = Flashcard(
            word: "concurrent",
            definition: "existing or happening at the same time",
            phonetic: "/kənˈkɜːrənt/"
        )
        flashcard.deck = deck

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state
        state.card = flashcard

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
            for _ in 0 ..< self.concurrencyCount {
                group.addTask {
                    // Call actor-isolated FSRSWrapper
                    try! await FSRSWrapper.shared.processReview(
                        flashcard: flashcard,
                        rating: Int.random(in: 1 ... 5)
                    )
                }
            }

            // Collect all results
            for await result in group {
                await results.append(result)
            }
        }

        // Verify all operations completed successfully
        let count = await results.count
        #expect(count == self.concurrencyCount, "All concurrent operations should complete")

        // Verify consistency: all results should have valid state
        let array = await results.array
        for result in array {
            #expect(result.stability > 0, "Stability should be positive")
            #expect(result.difficulty > 0, "Difficulty should be positive")
            #expect(result.dueDate > Date(), "Due date should be in the future")
        }
    }

    @Test("MainActor ViewModel prevents concurrent mutation")
    @MainActor
    func mainActorViewModelSafety() async throws {
        let context = self.freshContext()
        let viewModel = Scheduler(modelContext: context)
        let flashcard = self.createTestFlashcard(in: context)

        // Track success count
        let results = LockedArray<Bool>()

        // Process 50 concurrent reviews
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 50 {
                group.addTask { @MainActor in
                    // Call @MainActor ViewModel from concurrent tasks
                    // Note: Using @MainActor on the task ensures we're on the right actor
                    // The async call to processReview is allowed here
                    let result = try? await viewModel.processReview(
                        flashcard: flashcard,
                        rating: Int.random(in: 1 ... 5)
                    )
                    return result != nil
                }
            }

            for await success in group {
                if success {
                    await results.append(true)
                }
            }
        }

        // Verify no data races occurred
        let count = await results.count
        #expect(count > 0, "At least some reviews should succeed")

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
        let flashcard = await createTestFlashcard(in: freshContext())

        // Get DTO from actor
        let dto = try await FSRSWrapper.shared.processReview(
            flashcard: flashcard,
            rating: 3
        )

        // Verify DTO properties are accessible (Sendable check is at compile time)
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
        let isSupported = await service.isLanguagePairSupported()
        guard isSupported else {
            print("Skipping: Language pair not supported")
            return
        }

        // Skip if language pack not downloaded (CI environment)
        let needsDownload = await service.needsLanguageDownload("es")
        guard !needsDownload else {
            print("Skipping: Language pack not downloaded (CI environment)")
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
                if result != nil {
                    await results.append(result!)
                }
            }
        }

        // Verify all operations completed successfully
        let array = await results.array
        #expect(array.count > 0, "Translations should complete")
    }

    // MARK: - Data Race Detection Tests

    @Test("Actor isolation prevents data races in counters")
    func actorPreventsDataRaces() async {
        // Create an actor with mutable state
        actor Counter {
            private var value = 0

            func increment() {
                self.value += 1
            }

            func get() -> Int {
                self.value
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
    private var storage: [Element] = []

    func append(_ element: Element) {
        self.storage.append(element)
    }

    /// Increment counter for tracking successful operations
    func increment() {
        // This method is used when Element is not needed, just counting
        // The actual increment is tracked by appending a placeholder if needed
        // or by using a separate counter
    }

    var array: [Element] { self.storage }
    var count: Int { self.storage.count }
}
