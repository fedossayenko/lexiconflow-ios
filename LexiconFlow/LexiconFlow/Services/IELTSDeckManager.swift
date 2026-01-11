//
//  IELTSDeckManager.swift
//  LexiconFlow
//
//  Manages IELTS vocabulary decks organized by CEFR level
//  Creates and maintains six separate decks (A1, A2, B1, B2, C1, C2)
//

import Foundation
import OSLog
import SwiftData

/// Manager for IELTS vocabulary decks organized by CEFR level
///
/// **Purpose**: Creates and manages six separate decks, one for each CEFR level.
/// **Usage**: Call `getDeck(for:)` to get or create a deck for a specific level.
///
/// **Example**:
/// ```swift
/// let manager = IELTSDeckManager(modelContext: context)
/// let b2Deck = try manager.getDeck(for: "B2")
/// ```
@MainActor
final class IELTSDeckManager {
    /// Logger for deck operations
    private static let logger = Logger(subsystem: "com.lexiconflow.ielts", category: "DeckManager")

    /// The model context for data operations
    private let modelContext: ModelContext

    /// CEFR level deck names
    private let deckNames = [
        "A1": "IELTS A1 (Beginner)",
        "A2": "IELTS A2 (Elementary)",
        "B1": "IELTS B1 (Intermediate)",
        "B2": "IELTS B2 (Upper Intermediate)",
        "C1": "IELTS C1 (Advanced)",
        "C2": "IELTS C2 (Proficiency)"
    ]

    /// CEFR level to order mapping (ensures proper sort order in DeckListView)
    private let deckOrders = [
        "A1": 100, // After sample deck (order: 0)
        "A2": 200,
        "B1": 300,
        "B2": 400,
        "C1": 500,
        "C2": 600
    ]

    /// Valid CEFR levels
    private let validLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]

    /// Initialize with a model context
    ///
    /// - Parameter modelContext: The SwiftData model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Deck Management

    /// Get or create a deck for a specific CEFR level
    ///
    /// **Logic**:
    /// 1. Check if deck already exists for the level
    /// 2. If exists, return it
    /// 3. If not, create a new deck with the appropriate name
    ///
    /// - Parameter level: The CEFR level (A1, A2, B1, B2, C1, C2)
    /// - Returns: The deck for the specified level
    /// - Throws: `DeckManagerError.invalidCEFRLevel` if the level is not valid
    func getDeck(for level: String) throws -> Deck {
        // Validate CEFR level
        guard self.validLevels.contains(level), let deckName = deckNames[level] else {
            throw DeckManagerError.invalidCEFRLevel(level)
        }

        // Check if deck already exists
        let descriptor = FetchDescriptor<Deck>(
            predicate: #Predicate<Deck> { deck in
                deck.name == deckName
            }
        )

        if let existingDeck = try? modelContext.fetch(descriptor).first {
            Self.logger.info("Found existing deck for level \(level): \(deckName)")
            return existingDeck
        }

        // Create new deck with explicit order for proper sorting
        Self.logger.info("Creating new deck for level \(level): \(deckName)")
        let deck = Deck(
            name: deckName,
            icon: "book.fill",
            order: deckOrders[level] ?? 100
        )
        self.modelContext.insert(deck)
        try self.modelContext.save()

        return deck
    }

    /// Create all six IELTS decks at once
    ///
    /// **Use Case**: Initial setup when importing IELTS vocabulary for the first time.
    ///
    /// - Returns: Dictionary mapping CEFR levels to their decks
    /// - Throws: SwiftData errors if save fails
    func createAllDecks() throws -> [String: Deck] {
        Self.logger.info("Creating all six IELTS decks")

        var decks: [String: Deck] = [:]

        for level in self.validLevels {
            decks[level] = try self.getDeck(for: level)
        }

        Self.logger.info("Successfully created/verified \(decks.count) IELTS decks")
        return decks
    }

    /// Get all IELTS decks
    ///
    /// **Use Case**: Displaying IELTS deck list in UI.
    ///
    /// - Returns: Array of all IELTS decks, ordered by CEFR level (A1 → C2)
    func getAllDecks() throws -> [Deck] {
        var decks: [Deck] = []

        for level in self.validLevels {
            try decks.append(self.getDeck(for: level))
        }

        return decks
    }

    /// Check if a deck exists for a specific CEFR level
    ///
    /// - Parameter level: The CEFR level to check
    /// - Returns: true if the deck exists, false otherwise
    func deckExists(for level: String) -> Bool {
        guard self.validLevels.contains(level), let deckName = deckNames[level] else {
            return false
        }
        let descriptor = FetchDescriptor<Deck>(
            predicate: #Predicate<Deck> { deck in
                deck.name == deckName
            }
        )

        do {
            let existingDecks = try modelContext.fetch(descriptor)
            return !existingDecks.isEmpty
        } catch {
            Self.logger.error("Failed to check deck existence for \(level): \(error)")
            return false
        }
    }

    /// Delete a deck for a specific CEFR level
    ///
    /// **Warning**: This will delete the deck and all its associated flashcards.
    ///
    /// - Parameter level: The CEFR level whose deck should be deleted
    /// - Throws: `DeckManagerError.invalidCEFRLevel` if the level is not valid
    func deleteDeck(for level: String) throws {
        guard self.validLevels.contains(level), let deckName = deckNames[level] else {
            throw DeckManagerError.invalidCEFRLevel(level)
        }
        let descriptor = FetchDescriptor<Deck>(
            predicate: #Predicate<Deck> { deck in
                deck.name == deckName
            }
        )

        guard let deck = try modelContext.fetch(descriptor).first else {
            Self.logger.warning("No deck found to delete for level \(level)")
            return
        }

        Self.logger.info("Deleting deck for level \(level): \(deckName)")
        self.modelContext.delete(deck)
        try self.modelContext.save()

        // Invalidate statistics cache after deck deletion
        DeckStatisticsCache.shared.invalidate(deckID: deck.id)
    }

    /// Get deck name for a CEFR level
    ///
    /// - Parameter level: The CEFR level
    /// - Returns: The display name for the deck, or nil if level is invalid
    func deckName(for level: String) -> String? {
        self.deckNames[level]
    }
}

// MARK: - Deck Manager Errors

/// Errors that can occur when working with IELTS decks
enum DeckManagerError: LocalizedError, @unchecked Sendable {
    case invalidCEFRLevel(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCEFRLevel(level):
            "Invalid CEFR level: \(level). Must be one of A1, A2, B1, B2, C1, C2."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidCEFRLevel:
            "Use a valid CEFR level: A1, A2, B1, B2, C1, or C2."
        }
    }
}
