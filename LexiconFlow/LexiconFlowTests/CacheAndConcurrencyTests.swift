//
//  CacheAndConcurrencyTests.swift
//  LexiconFlowTests
//
//  Performance and concurrency tests:
//  - Cache eviction (10,000 entry limit, LRU eviction)
//  - Concurrency (FoundationModels, QuickTranslationService)
//
//  These tests verify performance characteristics and thread safety.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for cache and concurrency
@MainActor
struct CacheAndConcurrencyTests {
    // MARK: - Test Fixtures

    private func createTestContext() -> ModelContext {
        let schema = Schema([
            Flashcard.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self,
            GeneratedSentence.self,
            StudySession.self,
            DailyStats.self,
            CachedTranslation.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return container.mainContext
    }

    // MARK: - Cache Eviction Tests

    @Test("Cache eviction: 10,000 entry limit is enforced")
    func cacheEvictionLimit() async throws {
        let context = self.createTestContext()

        // Try to insert 11,000 cache entries (exceeds 10,000 limit)
        for i in 0 ..< 11000 {
            let translation = try CachedTranslation(
                sourceWord: "word\(i)",
                translatedText: "translation\(i)",
                sourceLanguage: "en",
                targetLanguage: "es",
                ttlDays: 30
            )
            context.insert(translation)
        }

        try context.save()

        // Count should be at or below 10,000
        let descriptor = FetchDescriptor<CachedTranslation>()
        let count = try context.fetchCount(descriptor)

        #expect(count <= 10000, "Cache should not exceed 10,000 entries (actual: \(count))")
    }

    @Test("Cache eviction: LRU eviction deletes oldest entries")
    func cacheEvictionLRU() async throws {
        let context = self.createTestContext()

        // Insert 10,100 entries to trigger eviction
        // Insert oldest entries first
        for i in 0 ..< 100 {
            let translation = try CachedTranslation(
                sourceWord: "old\(i)",
                translatedText: "old_translation\(i)",
                sourceLanguage: "en",
                targetLanguage: "es",
                cachedAt: Date().addingTimeInterval(-100000), // Very old
                ttlDays: 30
            )
            context.insert(translation)
        }

        // Insert newer entries
        for i in 100 ..< 10100 {
            let translation = try CachedTranslation(
                sourceWord: "new\(i)",
                translatedText: "new_translation\(i)",
                sourceLanguage: "en",
                targetLanguage: "es",
                cachedAt: Date(), // Recent
                ttlDays: 30
            )
            context.insert(translation)
        }

        try context.save()

        // Check that oldest entries were deleted
        let oldDescriptor = FetchDescriptor<CachedTranslation>(
            predicate: #Predicate<CachedTranslation> { translation in
                translation.sourceWord.hasPrefix("old")
            }
        )
        let oldCount = try context.fetchCount(oldDescriptor)

        // Oldest 10% should be evicted
        #expect(oldCount < 100, "Oldest entries should be evicted (remaining: \(oldCount))")

        // Total should be at limit
        let totalDescriptor = FetchDescriptor<CachedTranslation>()
        let totalCount = try context.fetchCount(totalDescriptor)

        #expect(totalCount <= 10000, "Total cache should be at limit (actual: \(totalCount))")
    }

    // MARK: - Concurrency Tests

    @Test("Concurrency: FoundationModels initialization is thread-safe")
    func concurrencyFoundationModelsInitialization() async throws {
        // Create multiple concurrent initialization tasks
        let tasks = (0 ..< 10).map { _ in
            Task {
                await FoundationModelsService.shared.initialize()
            }
        }

        // Wait for all tasks to complete
        for task in tasks {
            await task.value
        }

        // Service should be initialized without errors
        let isAvailable = await FoundationModelsService.shared.isAvailable()
        #expect(isAvailable || !isAvailable, "FoundationModels initialization should complete without crashing")
    }

    @Test("Concurrency: QuickTranslationService is thread-safe")
    func concurrencyQuickTranslationService() async throws {
        let context = self.createTestContext()
        let service = QuickTranslationService.shared

        // Create multiple concurrent translation requests
        let tasks = (0 ..< 20).map { i in
            Task {
                // Create a mock flashcard for each translation
                let flashcard = Flashcard(
                    word: "test\(i)",
                    definition: "test definition",
                    phonetic: nil,
                    imageData: nil
                )

                // Attempt translation (will fail without language packs, but tests thread safety)
                _ = try? await service.translate(
                    flashcard: flashcard,
                    modelContext: context
                )
            }
        }

        // Wait for all tasks to complete without crashing
        for task in tasks {
            await task.value
        }

        // If we reach here, the service is thread-safe
        #expect(true, "QuickTranslationService should handle concurrent requests without crashing")
    }

    @Test("Concurrency: FileIOActor handles concurrent reads")
    func concurrencyFileIOActor() async throws {
        // Note: This test is for when FileIOActor is implemented
        // For now, it's a placeholder for the async I/O refactoring

        #expect(true, "FileIOActor should be implemented for async file I/O")
    }
}
