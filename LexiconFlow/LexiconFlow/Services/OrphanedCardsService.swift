//
//  OrphanedCardsService.swift
//  LexiconFlow
//
//  Service for managing orphaned flashcards (cards without deck assignment)
//

import Foundation
import OSLog
import SwiftData

/// Service for managing orphaned flashcards (cards without deck assignment)
///
/// Orphaned cards are flashcards that have no deck association. This occurs when:
/// - A deck is deleted (cards persist due to .nullify delete rule)
/// - A card is created without deck assignment
/// - A card's deck reference is explicitly set to nil
///
/// This service provides CRUD operations for managing orphaned cards,
/// including fetching, reassigning to decks, and bulk deletion.
@MainActor
final class OrphanedCardsService: Sendable {
    /// Shared singleton instance for app-wide access
    static let shared = OrphanedCardsService()

    private let logger = Logger(subsystem: "com.lexiconflow.orphaned", category: "OrphanedCardsService")

    private init() {}

    // MARK: - Public API

    /// Fetch all orphaned flashcards from the database
    ///
    /// Orphaned cards are those with `deck == nil`. This performs a database
    /// query and may be expensive for large datasets.
    ///
    /// - Parameter context: SwiftData model context for the query
    /// - Returns: Array of orphaned flashcards (empty if none found)
    func fetchOrphanedCards(context: ModelContext) -> [Flashcard] {
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate<Flashcard> { card in
                card.deck == nil
            }
        )

        do {
            let orphans = try context.fetch(descriptor)
            logger.debug("Found \(orphans.count) orphaned cards")
            return orphans
        } catch {
            Analytics.trackError("fetch_orphaned_cards", error: error)
            logger.error("Failed to fetch orphaned cards: \(error)")
            return []
        }
    }

    /// Reassign orphaned cards to a specific deck
    ///
    /// Updates the `deck` property of each card to point to the target deck,
    /// then saves the context and invalidates the statistics cache.
    ///
    /// - Parameters:
    ///   - cards: Array of orphaned flashcards to reassign
    ///   - deck: Target deck for reassignment
    ///   - context: SwiftData model context for the update
    /// - Returns: Number of successfully reassigned cards
    /// - Throws: `SwiftData.Error` if save fails
    func reassignCards(_ cards: [Flashcard], to deck: Deck, context: ModelContext) async throws -> Int {
        for card in cards {
            card.deck = deck
        }

        try context.save()
        DeckStatisticsCache.shared.invalidate()

        logger.info("Reassigned \(cards.count) cards to deck \(deck.name)")
        Analytics.trackEvent("cards_reassigned", metadata: [
            "count": String(cards.count),
            "deck_id": deck.id.uuidString,
            "deck_name": deck.name
        ])

        return cards.count
    }

    /// Bulk delete orphaned cards from the database
    ///
    /// Permanently removes the specified cards and their associated data
    /// (FSRS state, review logs, generated sentences) via cascade delete rules.
    ///
    /// - Parameters:
    ///   - cards: Array of orphaned flashcards to delete
    ///   - context: SwiftData model context for the deletion
    /// - Returns: Number of successfully deleted cards
    /// - Throws: `SwiftData.Error` if save fails
    func deleteOrphanedCards(_ cards: [Flashcard], context: ModelContext) async throws -> Int {
        for card in cards {
            context.delete(card)
        }

        try context.save()
        DeckStatisticsCache.shared.invalidate()

        logger.info("Deleted \(cards.count) orphaned cards")
        Analytics.trackEvent("orphaned_cards_deleted", metadata: [
            "count": String(cards.count)
        ])

        return cards.count
    }

    /// Get the count of orphaned cards in the database
    ///
    /// Convenience method that fetches all orphaned cards and returns the count.
    /// For large datasets, consider using a count query instead.
    ///
    /// - Parameter context: SwiftData model context for the query
    /// - Returns: Number of orphaned cards (0 if none found)
    func orphanedCardCount(context: ModelContext) -> Int {
        fetchOrphanedCards(context: context).count
    }
}
