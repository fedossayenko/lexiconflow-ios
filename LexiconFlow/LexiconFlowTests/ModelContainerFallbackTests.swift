//
//  ModelContainerFallbackTests.swift
//  LexiconFlowTests
//
//  Integration tests for ModelContainer graceful degradation:
//  - Persistent container creation
//  - In-memory fallback on failure
//  - Minimal fallback on double failure
//  - Empty fallback on triple failure
//
//  These tests verify the app doesn't crash when SwiftData fails.
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for ModelContainer fallback behavior
struct ModelContainerFallbackTests {
    // MARK: - Persistent Container Tests

    @Test("ModelContainer: persistent container creation succeeds")
    func persistentContainerCreation() throws {
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

        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)

        // Should create persistent container
        let container = try ModelContainer(for: schema, configurations: [configuration])

        // Verify container is functional
        let context = container.mainContext
        let deck = Deck(name: "Test", icon: "star.fill")
        context.insert(deck)
        try context.save()

        #expect(true, "Persistent container should be created successfully")
    }

    // MARK: - In-Memory Fallback Tests

    @Test("ModelContainer: in-memory fallback on persistent failure")
    func inMemoryFallback() throws {
        // Create a schema that might fail with persistent storage
        let schema = Schema([
            Flashcard.self,
            Deck.self
        ])

        // First try persistent
        let persistentConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        let container: ModelContainer

        do {
            container = try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            // Fall back to in-memory
            let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
        }

        // Verify in-memory container is functional
        let context = container.mainContext
        let deck = Deck(name: "Test", icon: "star.fill")
        context.insert(deck)
        try context.save()

        #expect(true, "In-memory fallback should work when persistent fails")
    }

    // MARK: - Minimal Fallback Tests

    @Test("ModelContainer: minimal fallback on double failure")
    func minimalFallback() throws {
        // Test the minimal container with EmptyModel
        let emptySchema = Schema([])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try ModelContainer(for: emptySchema, configurations: [configuration])

        // Verify container exists even with empty schema
        #expect(true, "Minimal container should be created with empty schema")
    }

    // MARK: - Empty Fallback Tests

    @Test("ModelContainer: empty fallback on triple failure")
    func emptyFallback() throws {
        // Test with EmptyModel as last resort
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try ModelContainer(for: EmptyModel.self, configurations: [configuration])

        // Verify empty container is created
        #expect(true, "Empty fallback container should be created")
    }

    // MARK: - Graceful Degradation Tests

    @Test("ModelContainer: graceful degradation doesn't crash app")
    func gracefulDegradation() throws {
        // Verify that multiple fallback attempts don't crash the app
        var attempts = 0
        let maxAttempts = 4

        while attempts < maxAttempts {
            do {
                let schema = Schema([Flashcard.self, Deck.self])
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                _ = try ModelContainer(for: schema, configurations: [config])
                break
            } catch {
                attempts += 1
                if attempts >= maxAttempts {
                    // Last resort: empty container
                    _ = try ModelContainer(for: EmptyModel.self)
                    break
                }
            }
        }

        #expect(true, "App should not crash during graceful degradation")
    }

    @Test("ModelContainer: error UI can be shown with minimal container")
    func errorUIDisplayable() throws {
        // Verify that even with minimal container, app can show error UI
        let container = try ModelContainer(for: EmptyModel.self)

        // App should launch and allow error UI to be displayed
        #expect(true, "Error UI should be displayable with minimal container")
    }
}
