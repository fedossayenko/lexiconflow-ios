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
        // First, fetch and delete all existing entities to properly clear this context's cache
        let reviews = try self.fetch(FetchDescriptor<FlashcardReview>())
        for review in reviews {
            self.delete(review)
        }

        let states = try self.fetch(FetchDescriptor<FSRSState>())
        for state in states {
            self.delete(state)
        }

        let cards = try self.fetch(FetchDescriptor<Flashcard>())
        for card in cards {
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
            FlashcardReview.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return container
    }()

    /// Creates a fresh context for a test
    /// Caller should call clearAll() before use to ensure isolation
    static func freshContext() -> ModelContext {
        return ModelContext(shared)
    }
}
