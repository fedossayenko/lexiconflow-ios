//
//  TestHelpers.swift
//  LexiconFlowTests
//
//  Shared testing utilities for performance optimization
//
//  IMPORTANT: Tests must run with serialized execution when using shared container
//  Run tests with: -parallel-testing-enabled NO
//

import SwiftData
import Testing
@testable import LexiconFlow

/// Extension to provide fast test isolation without recreating containers
extension ModelContext {
    /// Clears all entities from the context without recreating container
    /// This is much faster than creating a new ModelContainer for each test
    func clearAll() throws {
        // IMPORTANT: Delete in reverse dependency order to avoid relationship issues
        // 1. Delete dependent entities first (reviews, sentences, states, daily stats, study sessions)
        // 2. Then delete their parents (cards)
        // 3. Finally delete decks

        let dailyStats = try self.fetch(FetchDescriptor<DailyStats>())
        for stats in dailyStats {
            self.delete(stats)
        }

        let studySessions = try self.fetch(FetchDescriptor<StudySession>())
        for session in studySessions {
            self.delete(session)
        }

        let reviews = try self.fetch(FetchDescriptor<FlashcardReview>())
        for review in reviews {
            self.delete(review)
        }

        let sentences = try self.fetch(FetchDescriptor<GeneratedSentence>())
        for sentence in sentences {
            self.delete(sentence)
        }

        let states = try self.fetch(FetchDescriptor<FSRSState>())
        for state in states {
            self.delete(state)
        }

        let cards = try self.fetch(FetchDescriptor<Flashcard>())
        for card in cards {
            // Clear relationships before deleting to prevent cascade issues
            card.fsrsState = nil
            card.deck = nil
            self.delete(card)
        }

        let decks = try self.fetch(FetchDescriptor<Deck>())
        for deck in decks {
            self.delete(deck)
        }

        try self.save()
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
                // Last resort: minimal container
                return try! ModelContainer(for: schema, configurations: [fallbackConfig])
            }
        }
    }()

    /// Creates a fresh context for a test
    /// Caller should call clearAll() before use to ensure isolation
    static func freshContext() -> ModelContext {
        return ModelContext(shared)
    }
}
