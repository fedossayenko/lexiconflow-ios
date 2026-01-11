//
//  Deck.swift
//  LexiconFlow
//
//  Container for organizing cards into thematic groups
//

import Foundation
import SwiftData

/// A deck containing related vocabulary cards
///
/// Decks provide organizational structure to the card collection.
/// Users can create decks for different topics (e.g., "GRE Words",
/// "Business English", "Daily Vocabulary").
///
/// Cards can exist without a deck (orphaned cards), but typically
/// belong to exactly one deck.
@Model
final class Deck {
    /// Unique identifier for this deck
    var id: UUID

    /// Display name for this deck
    var name: String

    /// SF Symbol name for deck icon (optional)
    /// Examples: "book.fill", "star.fill", "folder.fill"
    var icon: String?

    /// When this deck was created
    var createdAt: Date

    /// Display order in the UI (lower = higher priority)
    var order: Int

    /// All cards belonging to this deck
    /// - Deleting deck nullifies the deck reference on cards (cards persist as orphans)
    /// - This preserves user learning progress (FSRS state) when deck is deleted
    /// - Inverse points to Flashcard.deck (both sides use .nullify for consistency)
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify, inverse: \Flashcard.deck) var cards: [Flashcard] = []

    /// All study sessions for this deck
    /// - Deleting deck sets studySession.deck to nil (sessions preserved in history)
    /// - Inverse points to StudySession.deck
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify, inverse: \StudySession.deck) var studySessions: [StudySession] = []

    // MARK: - Initialization

    /// Initialize a new deck
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Display name for the deck
    ///   - icon: SF Symbol name (optional)
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - order: Display order (defaults to 0)
    init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        createdAt: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.order = order
        // cards is auto-initialized by SwiftData
    }
}
