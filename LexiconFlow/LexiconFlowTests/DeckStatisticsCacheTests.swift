//
//  DeckStatisticsCacheTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for DeckStatisticsCache including:
//  - TTL behavior (30-second expiration)
//  - Cache invalidation (single deck, all decks)
//  - Batch operations
//  - Thread safety via @MainActor
//  - Edge cases (empty cache, non-existent decks)
//  - Integration with Scheduler
//
//  Uses mock time provider for deterministic TTL testing

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

@Suite(.serialized)
@MainActor
struct DeckStatisticsCacheTests {
    // MARK: - Basic Cache Operations

    @Test("Cache returns nil when empty")
    func cacheReturnsNilWhenEmpty() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let result = cache.get(deckID: UUID())
        #expect(result == nil)
    }

    @Test("Cache stores and retrieves statistics")
    func cacheStoresAndRetrieves() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deckID = UUID()
        let stats = DeckStatistics(due: 5, new: 10, total: 15)

        cache.set(stats, for: deckID)
        let retrieved = cache.get(deckID: deckID)

        #expect(retrieved?.due == 5)
        #expect(retrieved?.new == 10)
        #expect(retrieved?.total == 15)
    }

    @Test("Cache respects TTL expiration")
    func cacheRespectsTTL() async throws {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        // Set TTL to 0.1 seconds for fast testing
        cache.setTTLForTesting(0.1)

        let deckID = UUID()
        let stats = DeckStatistics(due: 5, new: 10, total: 15)

        cache.set(stats, for: deckID)

        // Should hit immediately
        #expect(cache.get(deckID: deckID)?.due == 5)

        // Wait for TTL to expire
        try await Task.sleep(for: .milliseconds(150))

        // Should miss after TTL expires
        #expect(cache.get(deckID: deckID) == nil)

        // Reset TTL for other tests
        cache.resetTTL()
    }

    // MARK: - Invalidation

    @Test("Cache invalidates specific deck")
    func cacheInvalidatesSpecificDeck() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = UUID()
        let deck2 = UUID()

        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: deck1)
        cache.set(DeckStatistics(due: 2, new: 0, total: 2), for: deck2)

        // Both should exist
        #expect(cache.get(deckID: deck1)?.due == 1)
        #expect(cache.get(deckID: deck2)?.due == 2)

        // Invalidate deck1
        cache.invalidate(deckID: deck1)

        // deck1 should be gone, deck2 should remain
        #expect(cache.get(deckID: deck1) == nil)
        #expect(cache.get(deckID: deck2)?.due == 2)
    }

    @Test("Cache invalidates all decks")
    func cacheInvalidatesAll() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = UUID()
        let deck2 = UUID()

        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: deck1)
        cache.set(DeckStatistics(due: 2, new: 0, total: 2), for: deck2)

        // Both should exist
        #expect(cache.get(deckID: deck1)?.due == 1)
        #expect(cache.get(deckID: deck2)?.due == 2)

        // Invalidate all
        cache.invalidate()

        // Both should be gone
        #expect(cache.get(deckID: deck1) == nil)
        #expect(cache.get(deckID: deck2) == nil)
    }

    // MARK: - Batch Operations

    @Test("Cache setBatch stores multiple decks")
    func cacheSetBatch() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = UUID()
        let deck2 = UUID()
        let deck3 = UUID()

        let batch: [UUID: DeckStatistics] = [
            deck1: DeckStatistics(due: 1, new: 0, total: 1),
            deck2: DeckStatistics(due: 2, new: 1, total: 3),
            deck3: DeckStatistics(due: 5, new: 2, total: 7)
        ]

        cache.setBatch(batch)

        #expect(cache.get(deckID: deck1)?.due == 1)
        #expect(cache.get(deckID: deck2)?.due == 2)
        #expect(cache.get(deckID: deck3)?.due == 5)
        #expect(cache.size == 3)
    }

    @Test("Cache setBatch overwrites existing entries")
    func cacheSetBatchOverwrites() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = UUID()

        // Set initial value
        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: deck1)
        #expect(cache.get(deckID: deck1)?.due == 1)

        // Overwrite with batch
        cache.setBatch([deck1: DeckStatistics(due: 10, new: 5, total: 15)])
        #expect(cache.get(deckID: deck1)?.due == 10)
    }

    // MARK: - Validation

    @Test("Cache isValid returns correct status")
    func cacheIsValid() async throws {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deckID = UUID()

        // Invalid when not in cache
        #expect(cache.isValid(deckID: deckID) == false)

        // Valid when stored
        cache.set(DeckStatistics(due: 5, new: 0, total: 5), for: deckID)
        #expect(cache.isValid(deckID: deckID) == true)

        // Invalid after expiration
        cache.setTTLForTesting(0.1)
        cache.set(DeckStatistics(due: 5, new: 0, total: 5), for: deckID)

        try? await Task.sleep(for: .milliseconds(150))

        #expect(cache.isValid(deckID: deckID) == false)
        cache.resetTTL()
    }

    // MARK: - Age Calculation

    @Test("Cache age returns correct value")
    func cacheAge() async throws {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        // Age is nil when empty
        #expect(cache.age() == nil)

        // Set some cache
        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: UUID())

        // Age should be small
        let age1 = cache.age()
        #expect(age1 != nil)
        #expect(age1! < 1.0) // Less than 1 second

        // Wait and check again
        try await Task.sleep(for: .milliseconds(100))
        let age2 = cache.age()
        #expect(age2 != nil)
        #expect(age2! > age1!) // Age should increase
    }

    @Test("Cache age is nil after invalidation")
    func cacheAgeNilAfterInvalidation() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        // Set some cache
        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: UUID())

        #expect(cache.age() != nil)

        // Invalidate all
        cache.invalidate()

        // Age should be nil
        #expect(cache.age() == nil)
    }

    // MARK: - Size

    @Test("Cache size returns correct count")
    func cacheSize() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        #expect(cache.size == 0)

        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: UUID())
        #expect(cache.size == 1)

        cache.set(DeckStatistics(due: 2, new: 0, total: 2), for: UUID())
        #expect(cache.size == 2)
    }

    // MARK: - Edge Cases

    @Test("Cache handles multiple entries for same deck")
    func cacheHandlesSameDeck() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deckID = UUID()

        cache.set(DeckStatistics(due: 1, new: 0, total: 1), for: deckID)
        cache.set(DeckStatistics(due: 5, new: 2, total: 7), for: deckID)

        // Should only have one entry (latest value)
        #expect(cache.size == 1)
        #expect(cache.get(deckID: deckID)?.due == 5)
    }

    @Test("Cache handles zero statistics")
    func cacheHandlesZeroStats() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deckID = UUID()
        let stats = DeckStatistics(due: 0, new: 0, total: 0)

        cache.set(stats, for: deckID)
        let retrieved = cache.get(deckID: deckID)

        #expect(retrieved?.due == 0)
        #expect(retrieved?.new == 0)
        #expect(retrieved?.total == 0)
    }

    @Test("Cache handles large statistics")
    func cacheHandlesLargeStats() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deckID = UUID()
        let stats = DeckStatistics(due: 10000, new: 5000, total: 15000)

        cache.set(stats, for: deckID)
        let retrieved = cache.get(deckID: deckID)

        #expect(retrieved?.due == 10000)
        #expect(retrieved?.new == 5000)
        #expect(retrieved?.total == 15000)
    }

    // MARK: - Mock Time Provider Tests (Deterministic TTL)

    @Test("Cache hit within TTL window using mock time")
    func cacheHitWithinTTLWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        let mockDate = Date()
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()
        cache.set(DeckStatistics(due: 5, new: 10, total: 15), for: deckID)

        // Immediate retrieval should hit
        let result = cache.get(deckID: deckID)
        #expect(result != nil)
        #expect(result?.due == 5)

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("Cache miss after TTL expiration using mock time")
    func cacheMissAfterTTLWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        var mockDate = Date()
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()
        cache.set(DeckStatistics(due: 5, new: 10, total: 15), for: deckID)

        // Advance time beyond TTL
        mockDate = mockDate.addingTimeInterval(31)

        let result = cache.get(deckID: deckID)
        #expect(result == nil, "Cache should expire after 31 seconds")

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("Cache invalid exactly at TTL boundary using mock time")
    func cacheInvalidAtTTLBoundaryWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        // Use fixed reference point to avoid floating point precision issues
        var mockDate = Date(timeIntervalSince1970: 0)
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()
        cache.set(DeckStatistics(due: 5, new: 10, total: 15), for: deckID)

        // Advance to exactly TTL (30 seconds) - should be invalid (condition is age < ttl, not <=)
        mockDate = mockDate.addingTimeInterval(30)

        let result = cache.get(deckID: deckID)
        #expect(result == nil, "Cache should be invalid at exactly 30 seconds (age < ttl, not <=)")

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("Timestamp updated on set operation using mock time")
    func timestampUpdatedOnSetWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        // Use fixed reference point to avoid floating point precision issues
        var mockDate = Date(timeIntervalSince1970: 0)
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()

        // Initial set
        cache.set(DeckStatistics(due: 1, new: 1, total: 2), for: deckID)
        let firstAge = cache.age()

        // Age should be 0 immediately after set
        #expect(abs(firstAge ?? 0) < 0.001)

        // Advance time
        mockDate = mockDate.addingTimeInterval(1)
        let ageAfterTimeAdvance = cache.age()

        // Age should be approximately the time advanced (1 second)
        #expect(abs((ageAfterTimeAdvance ?? 0) - 1) < 0.5, "Age should reflect elapsed time")

        // Update with new data - this resets the timestamp to current mock time (1 second after start)
        cache.set(DeckStatistics(due: 2, new: 2, total: 4), for: deckID)
        let secondAge = cache.age()

        // After set, age should be reset to 0 (timestamp updated to current mock time)
        #expect(abs(secondAge ?? 0) < 0.001, "Age should reset to 0 after set")

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("Age increases over time using mock time")
    func ageIncreasesOverTimeWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        // Use fixed reference point to avoid floating point precision issues
        var mockDate = Date(timeIntervalSince1970: 0)
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        cache.set(DeckStatistics(due: 1, new: 1, total: 2), for: UUID())

        let age1 = cache.age()
        // Use approximate comparison for floating point values
        #expect(abs(age1 ?? 0) < 0.001)

        mockDate = mockDate.addingTimeInterval(5)
        let age2 = cache.age()

        #expect(abs((age2 ?? 0) - 5) < 0.001)

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("setBatch resets timestamp using mock time")
    func setBatchResetsTimestampWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        // Use fixed reference point to avoid floating point precision issues
        var mockDate = Date(timeIntervalSince1970: 0)
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        cache.setBatch([UUID(): DeckStatistics(due: 1, new: 1, total: 2)])
        let initialAge = cache.age()
        // Use approximate comparison for floating point values
        #expect(abs(initialAge ?? 0) < 0.001)

        mockDate = mockDate.addingTimeInterval(15)
        let ageAfterTimeAdvance = cache.age()

        // Age should be approximately the time advanced (15 seconds)
        #expect(abs((ageAfterTimeAdvance ?? 0) - 15) < 1.0, "Age should reflect elapsed time")

        // setBatch resets timestamp to current mock time
        cache.setBatch([UUID(): DeckStatistics(due: 2, new: 2, total: 4)])
        let ageAfterBatch = cache.age()

        // After setBatch, age should be reset to 0 (timestamp updated to current mock time)
        #expect(abs(ageAfterBatch ?? 0) < 0.001, "Age should reset to 0 after setBatch")

        DeckStatisticsCache.resetTimeProvider()
    }

    @Test("Custom TTL for faster testing using mock time")
    func customTTLForTestingWithMockTime() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        var mockDate = Date()
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()
        cache.setTTLForTesting(0.1) // 100ms TTL
        cache.set(DeckStatistics(due: 5, new: 10, total: 15), for: deckID)

        // Should be valid immediately
        #expect(cache.get(deckID: deckID) != nil)

        // Advance beyond custom TTL
        mockDate = mockDate.addingTimeInterval(0.2)

        #expect(cache.get(deckID: deckID) == nil, "Cache should expire after custom TTL")

        cache.resetTTL()
        DeckStatisticsCache.resetTimeProvider()
    }

    // MARK: - Integration Tests with Scheduler

    @Test("fetchDeckStatistics populates cache on first call")
    func fetchDeckStatisticsPopulatesCache() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck = Deck(name: "Test", icon: "test")
        context.insert(deck)

        let card = Flashcard(word: "test", definition: "test", phonetic: nil)
        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: "review"
        )
        context.insert(state)
        card.fsrsState = state
        card.deck = deck
        context.insert(card)
        try context.save()

        // First call should populate cache
        let stats1 = scheduler.fetchDeckStatistics(for: deck)

        #expect(cache.get(deckID: deck.id) != nil, "Cache should be populated")
        #expect(cache.get(deckID: deck.id)?.due == stats1.due)
    }

    @Test("fetchDeckStatistics returns cached data on second call")
    func fetchDeckStatisticsReturnsCachedData() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck = Deck(name: "Test", icon: "test")
        context.insert(deck)

        let card = Flashcard(word: "test", definition: "test", phonetic: nil)
        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: "review"
        )
        context.insert(state)
        card.fsrsState = state
        card.deck = deck
        context.insert(card)
        try context.save()

        // First call
        let stats1 = scheduler.fetchDeckStatistics(for: deck)

        // Second call should return same data (cached)
        let stats2 = scheduler.fetchDeckStatistics(for: deck)

        #expect(stats1.due == stats2.due)
        #expect(stats1.new == stats2.new)
        #expect(stats1.total == stats2.total)
    }

    @Test("processReview invalidates cache for affected deck")
    func processReviewInvalidatesCache() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck = Deck(name: "Test", icon: "test")
        context.insert(deck)

        let card = Flashcard(word: "test", definition: "test", phonetic: nil)
        let state = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: "review"
        )
        context.insert(state)
        card.fsrsState = state
        card.deck = deck
        context.insert(card)
        try context.save()

        // Pre-warm cache
        _ = scheduler.fetchDeckStatistics(for: deck)
        #expect(cache.get(deckID: deck.id) != nil)

        // Process review
        _ = await scheduler.processReview(flashcard: card, rating: 3)

        // Cache should be invalidated
        #expect(cache.get(deckID: deck.id) == nil, "Cache should be invalidated after review")
    }

    @Test("batch fetch uses cached data when available")
    func batchFetchUsesCachedData() async throws {
        let context = TestContainers.freshContext()
        try context.clearAll()
        let scheduler = Scheduler(modelContext: context)
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = Deck(name: "Deck1", icon: "test1")
        let deck2 = Deck(name: "Deck2", icon: "test2")
        context.insert(deck1)
        context.insert(deck2)

        let card1 = Flashcard(word: "card1", definition: "test", phonetic: nil)
        let state1 = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: "review"
        )
        context.insert(state1)
        card1.fsrsState = state1
        card1.deck = deck1
        context.insert(card1)

        let card2 = Flashcard(word: "card2", definition: "test", phonetic: nil)
        let state2 = FSRSState(
            stability: 1.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date().addingTimeInterval(-3600),
            stateEnum: "review"
        )
        context.insert(state2)
        card2.fsrsState = state2
        card2.deck = deck2
        context.insert(card2)

        try context.save()

        // Pre-warm cache for deck1 only
        let cachedStats = DeckStatistics(due: 99, new: 99, total: 99)
        cache.set(cachedStats, for: deck1.id)

        // Batch fetch should use cached data for deck1
        let results = scheduler.fetchDeckStatistics(for: [deck1, deck2])

        #expect(results[deck1.id]?.due == 99, "Should use cached data for deck1")
        #expect(results[deck2.id]?.due == 1, "Should fetch fresh data for deck2")
    }

    // MARK: - Additional Edge Cases

    @Test("Invalidate non-existent deck does not crash")
    func invalidateNonExistentDeckDoesNotCrash() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        let deck1 = UUID()
        cache.set(DeckStatistics(due: 1, new: 1, total: 2), for: deck1)

        // Invalidate deck that doesn't exist
        cache.invalidate(deckID: UUID())

        #expect(cache.get(deckID: deck1) != nil, "Original deck should remain")
        #expect(cache.size == 1)
    }

    @Test("Rapid set and get operations stress test")
    func rapidSetAndGetOperations() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        // Stress test with rapid operations
        for i in 0 ..< 100 {
            let deckID = UUID()
            cache.set(DeckStatistics(due: i, new: i, total: i * 2), for: deckID)
            #expect(cache.get(deckID: deckID)?.due == i)
        }

        #expect(cache.size == 100)
    }

    @Test("Cache performance with many entries")
    func cachePerformanceWithManyEntries() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()

        // Test with 1000 entries
        let deckIDs = (0 ..< 1000).map { _ in UUID() }

        for deckID in deckIDs {
            cache.set(DeckStatistics(due: 1, new: 1, total: 2), for: deckID)
        }

        #expect(cache.size == 1000)

        // Random lookups should be fast (O(1))
        let randomID = deckIDs.randomElement()!
        let start = Date()
        let result = cache.get(deckID: randomID)
        let duration = Date().timeIntervalSince(start)

        #expect(result != nil)
        #expect(duration < 0.001, "Lookup should be sub-millisecond")
    }

    @Test("isValid reflects cache validity correctly")
    func isValidReflectsCacheValidity() {
        let cache = DeckStatisticsCache.shared
        cache.clearForTesting()
        DeckStatisticsCache.resetTimeProvider()

        let mockDate = Date()
        DeckStatisticsCache.setTimeProviderForTesting { mockDate }

        let deckID = UUID()

        #expect(cache.isValid(deckID: deckID) == false)

        cache.set(DeckStatistics(due: 5, new: 10, total: 15), for: deckID)
        #expect(cache.isValid(deckID: deckID) == true)

        // Invalidate
        cache.invalidate(deckID: deckID)
        #expect(cache.isValid(deckID: deckID) == false)

        DeckStatisticsCache.resetTimeProvider()
    }
}
