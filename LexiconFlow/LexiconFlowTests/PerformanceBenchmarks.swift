//
//  PerformanceBenchmarks.swift
//  LexiconFlowTests
//
//  Performance benchmarks for critical operations:
//  - Batch translation SLA (20 cards < 5 seconds)
//  - Keychain read/write (< 100ms)
//  - SwiftData queries (< 200ms)
//
//  These tests verify performance service level agreements (SLAs).
//

import Testing
import SwiftData
import Foundation
@testable import LexiconFlow

/// Performance benchmark test suite
@MainActor
struct PerformanceBenchmarks {

    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Batch Translation Benchmarks

    @Test("Batch translation of 20 cards completes within 5 seconds", .enabled(if: false))
    // NOTE: Disabled by default - requires valid API key
    // Enable with: swift test --enable TestCodableFeature
    func batchTranslation20CardsSLA() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create 20 test cards
        let cards = (1...20).map { i in
            Flashcard(word: "word\(i)", definition: "definition \(i)")
        }

        for card in cards {
            context.insert(card)
        }
        try context.save()

        // Configure API key (requires valid key for real test)
        // try KeychainManager.setAPIKey("YOUR_VALID_API_KEY")

        let service = TranslationService.shared
        let startTime = Date()

        // This will fail without valid API key, but timing is still measured
        _ = try await service.translateBatch(
            cards,
            maxConcurrency: 5,
            progressHandler: { _ in }
        )

        let duration = Date().timeIntervalSince(startTime)

        // SLA: 20 cards should complete within 5 seconds
        #expect(duration < 5.0, "20-card batch should complete in <5s, took \(duration)s")

        // Cleanup
        // try KeychainManager.deleteAPIKey()
    }

    @Test("Single card translation completes within 5 seconds", .enabled(if: false))
    // NOTE: Disabled by default - requires valid API key
    func singleCardTranslationSLA() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let card = Flashcard(word: "hello", definition: "greeting")
        context.insert(card)
        try context.save()

        // Configure API key
        // try KeychainManager.setAPIKey("YOUR_VALID_API_KEY")

        let service = TranslationService.shared
        let startTime = Date()

        _ = try await service.translateBatch(
            [card],
            maxConcurrency: 1,
            progressHandler: { _ in }
        )

        let duration = Date().timeIntervalSince(startTime)

        // SLA: Single card should complete within 5 seconds
        #expect(duration < 5.0, "Single card translation should complete in <5s, took \(duration)s")

        // Cleanup
        // try KeychainManager.deleteAPIKey()
    }

    // MARK: - Keychain Performance Benchmarks

    @Test("Keychain write completes within 100ms")
    func keychainWriteSLA() throws {
        let testKey = "sk-test-\(UUID().uuidString)"

        let startTime = Date()
        try KeychainManager.setAPIKey(testKey)
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Keychain write should complete within 100ms
        #expect(duration * 1000 < 100, "Keychain write should complete in <100ms, took \(Int(duration * 1000))ms")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Keychain read completes within 100ms")
    func keychainReadSLA() throws {
        let testKey = "sk-test-\(UUID().uuidString)"
        try KeychainManager.setAPIKey(testKey)

        let startTime = Date()
        let retrieved = try KeychainManager.getAPIKey()
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Keychain read should complete within 100ms
        #expect(duration * 1000 < 100, "Keychain read should complete in <100ms, took \(Int(duration * 1000))ms")
        #expect(retrieved == testKey, "Retrieved key should match")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Keychain hasAPIKey check completes within 50ms")
    func keychainHasAPIKeySLA() throws {
        let testKey = "sk-test-\(UUID().uuidString)"
        try KeychainManager.setAPIKey(testKey)

        let startTime = Date()
        let hasKey = KeychainManager.hasAPIKey()
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Keychain existence check should complete within 50ms
        #expect(duration * 1000 < 50, "Keychain hasAPIKey should complete in <50ms, took \(Int(duration * 1000))ms")
        #expect(hasKey, "hasAPIKey should return true")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("Keychain delete completes within 100ms")
    func keychainDeleteSLA() throws {
        let testKey = "sk-test-\(UUID().uuidString)"
        try KeychainManager.setAPIKey(testKey)

        let startTime = Date()
        try KeychainManager.deleteAPIKey()
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Keychain delete should complete within 100ms
        #expect(duration * 1000 < 100, "Keychain delete should complete in <100ms, took \(Int(duration * 1000))ms")
    }

    @Test("Generic Keychain write/read completes within 100ms")
    func keychainGenericReadWriteSLA() throws {
        let account = "perf_test_account"
        let value = "test-value-\(UUID().uuidString)"

        // Write
        let writeStart = Date()
        try KeychainManager.set(value, forAccount: account)
        let writeDuration = Date().timeIntervalSince(writeStart)

        #expect(writeDuration * 1000 < 100, "Keychain generic write should complete in <100ms, took \(Int(writeDuration * 1000))ms")

        // Read
        let readStart = Date()
        let retrieved = try KeychainManager.get(forAccount: account)
        let readDuration = Date().timeIntervalSince(readStart)

        #expect(readDuration * 1000 < 100, "Keychain generic read should complete in <100ms, took \(Int(readDuration * 1000))ms")
        #expect(retrieved == value, "Retrieved value should match")

        // Cleanup
        try KeychainManager.delete(forAccount: account)
    }

    // MARK: - SwiftData Query Benchmarks

    @Test("SwiftData fetch all cards completes within 200ms")
    func swiftDataFetchAllCardsSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Insert 100 cards
        for i in 1...100 {
            let card = Flashcard(word: "word\(i)", definition: "definition \(i)")
            context.insert(card)
        }
        try context.save()

        let startTime = Date()
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Fetching 100 cards should complete within 200ms
        #expect(duration * 1000 < 200, "Fetching 100 cards should complete in <200ms, took \(Int(duration * 1000))ms")
        #expect(fetched.count == 100, "Should fetch all 100 cards")
    }

    @Test("SwiftData fetch with predicate completes within 200ms")
    func swiftDataFetchWithPredicateSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Insert 100 cards
        for i in 1...100 {
            let card = Flashcard(word: "word\(i)", definition: "definition \(i)")
            context.insert(card)
        }
        try context.save()

        let startTime = Date()
        let fetchDescriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate<Flashcard> { card in
                card.word.contains("word1")
            }
        )
        let fetched = try context.fetch(fetchDescriptor)
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Fetch with predicate should complete within 200ms
        #expect(duration * 1000 < 200, "Fetch with predicate should complete in <200ms, took \(Int(duration * 1000))ms")
        // Should match word1, word10-word19 (11 cards), but also word12, word13, etc.
        #expect(fetched.count >= 11, "Should find at least 11 matching cards")
    }

    @Test("SwiftData insert 100 cards completes within 500ms")
    func swiftDataInsert100CardsSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let startTime = Date()

        for i in 1...100 {
            let card = Flashcard(word: "word\(i)", definition: "definition \(i)")
            context.insert(card)
        }

        try context.save()

        let duration = Date().timeIntervalSince(startTime)

        // SLA: Inserting 100 cards should complete within 500ms
        #expect(duration * 1000 < 500, "Inserting 100 cards should complete in <500ms, took \(Int(duration * 1000))ms")

        // Verify all were inserted
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)
        #expect(fetched.count == 100, "All 100 cards should be inserted")
    }

    @Test("SwiftData update card completes within 100ms")
    func swiftDataUpdateCardSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let card = Flashcard(word: "original", definition: "original definition")
        context.insert(card)
        try context.save()

        let startTime = Date()

        card.word = "updated"
        card.definition = "updated definition"

        try context.save()

        let duration = Date().timeIntervalSince(startTime)

        // SLA: Updating a card should complete within 100ms
        #expect(duration * 1000 < 100, "Updating card should complete in <100ms, took \(Int(duration * 1000))ms")

        // Verify update
        #expect(card.word == "updated", "Word should be updated")
        #expect(card.definition == "updated definition", "Definition should be updated")
    }

    @Test("SwiftData delete card completes within 100ms")
    func swiftDataDeleteCardSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let card = Flashcard(word: "to_delete", definition: "will be deleted")
        context.insert(card)
        try context.save()

        let startTime = Date()

        context.delete(card)
        try context.save()

        let duration = Date().timeIntervalSince(startTime)

        // SLA: Deleting a card should complete within 100ms
        #expect(duration * 1000 < 100, "Deleting card should complete in <100ms, took \(Int(duration * 1000))ms")

        // Verify deletion
        let fetchDescriptor = FetchDescriptor<Flashcard>()
        let fetched = try context.fetch(fetchDescriptor)
        #expect(fetched.count == 0, "Card should be deleted")
    }

    // MARK: - FSRS Algorithm Benchmarks

    @Test("FSRS processReview completes within 50ms")
    func fsrsProcessReviewSLA() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(word: "test", definition: "definition")
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state

        context.insert(flashcard)
        context.insert(state)
        try context.save()

        let scheduler = Scheduler(modelContext: context)

        let startTime = Date()
        let review = await scheduler.processReview(flashcard: flashcard, rating: 3)
        let duration = Date().timeIntervalSince(startTime)

        // SLA: FSRS processing should complete within 50ms
        #expect(duration * 1000 < 50, "FSRS processReview should complete in <50ms, took \(Int(duration * 1000))ms")
        #expect(review != nil, "Review should be created")
    }

    // MARK: - Composite Operation Benchmarks

    @Test("Save card with FSRSState completes within 200ms")
    func saveCardWithFSRSStateSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let startTime = Date()

        let flashcard = Flashcard(
            word: "test",
            definition: "definition",
            phonetic: "/tɛst/",
            imageData: nil
        )

        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )

        flashcard.fsrsState = state
        context.insert(flashcard)
        context.insert(state)
        try context.save()

        let duration = Date().timeIntervalSince(startTime)

        // SLA: Saving card with FSRSState should complete within 200ms
        #expect(duration * 1000 < 200, "Saving card with FSRSState should complete in <200ms, took \(Int(duration * 1000))ms")

        // Verify
        #expect(flashcard.fsrsState != nil, "FSRSState should be linked")
    }

    @Test("SwiftData fetch with complex predicate completes within 200ms")
    func swiftDataFetchWithComplexPredicateSLA() throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Insert 100 cards
        for i in 1...100 {
            let flashcard = Flashcard(word: "word\(i)", definition: "definition \(i)")
            context.insert(flashcard)
        }
        try context.save()

        let startTime = Date()
        // Simulate fetching due cards with complex predicate
        let fetchDescriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate<Flashcard> { card in
                card.word.contains("word1") || card.word.contains("word2")
            }
        )
        let fetched = try context.fetch(fetchDescriptor)
        let duration = Date().timeIntervalSince(startTime)

        // SLA: Fetch with complex predicate should complete within 200ms
        #expect(duration * 1000 < 200, "Fetch with complex predicate should complete in <200ms, took \(Int(duration * 1000))ms")
        // Should match word1, word2, word10-19, word20-29 (29 cards)
        #expect(fetched.count > 0, "Should find matching cards")
    }

    // MARK: - Memory Benchmarks

    @Test("100 flashcards use reasonable memory")
    func memoryUsageFor100Flashcards() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let beforeMemory = getMemoryUsage()

        // Create 100 cards
        for i in 1...100 {
            let flashcard = Flashcard(
                word: "word\(i)",
                definition: String(repeating: "definition text ", count: 10), // ~150 chars
                phonetic: "/w3ːd\(i)/"
            )
            context.insert(flashcard)
        }
        try context.save()

        let afterMemory = getMemoryUsage()
        let memoryIncrease = afterMemory - beforeMemory

        // SLA: 100 flashcards should use less than 50MB
        #expect(memoryIncrease < 50 * 1024 * 1024, "100 flashcards should use <50MB, used \(memoryIncrease / 1024 / 1024)MB")
    }

    // MARK: - Helper Functions

    /// Get current memory usage in bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}
