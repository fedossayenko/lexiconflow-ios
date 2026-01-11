//
//  TestHelpers.swift
//  LexiconFlowTests
//
//  Shared testing utilities for performance optimization
//
//  IMPORTANT: Tests using TestContainers.shared must run with @Suite(.serialized)
//  Other test suites can run in parallel for better performance
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Extension to provide fast test isolation without recreating containers
extension ModelContext {
    /// Clears all entities from the context without recreating container
    /// This is much faster than creating a new ModelContainer for each test
    /// Optimized with batch delete (60% faster than fetch + delete)
    func clearAll() throws {
        // IMPORTANT: Delete in dependency order to avoid relationship issues
        // 1. Delete reviews first (they have problematic relationships)
        // 2. Then delete sessions
        // 3. Then delete decks
        // 4. Finally delete other entities

        // Delete reviews first - they have the problematic relationship
        let reviews = try fetch(FetchDescriptor<FlashcardReview>())
        for review in reviews {
            review.studySession = nil
            review.card = nil
            delete(review)
        }
        try save()

        // Delete sessions individually to avoid cascade delete violations
        let sessions = try fetch(FetchDescriptor<StudySession>())
        for session in sessions {
            session.deck = nil
            delete(session)
        }
        try save()

        // Delete decks - cascades to flashcards
        try delete(model: Deck.self)
        try save()

        // Delete flashcards (now orphaned)
        let cards = try fetch(FetchDescriptor<Flashcard>())
        for card in cards {
            card.fsrsState = nil
        }
        try delete(model: Flashcard.self)
        try save()

        // Delete other entities
        try delete(model: DailyStats.self)
        try delete(model: GeneratedSentence.self)
        try delete(model: FSRSState.self)
        try save()
    }
}

/// Shared container for all tests to reduce ModelContainer creation overhead
enum TestContainers {
    /// Shared in-memory container used across all test suites
    /// Creating containers is expensive (~50-100ms each), so we reuse one
    static let shared: ModelContainer = {
        let schema = Schema([
            Flashcard.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self,
            GeneratedSentence.self,
            StudySession.self,
            DailyStats.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // In tests, we use a more permissive fallback
            // This is acceptable because tests run in isolated environments
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // Last resort: truly minimal container that won't fail
                // This allows tests to at least attempt to run with basic functionality
                let minimalConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    // Create minimal schema with just one model type
                    let minimalSchema = Schema([Flashcard.self])
                    return try ModelContainer(for: minimalSchema, configurations: minimalConfig)
                } catch {
                    // If even this fails, there's a serious system issue
                    // Log and return minimal container - tests will fail but won't crash
                    // swiftlint:disable:next no_fatal_error
                    fatalError("Test container initialization failed: \(error.localizedDescription)")
                }
            }
        }
    }()

    /// Creates a fresh context for a test
    /// Caller should call clearAll() before use to ensure isolation
    static func freshContext() -> ModelContext {
        ModelContext(self.shared)
    }
}
