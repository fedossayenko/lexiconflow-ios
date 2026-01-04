//
//  Flashcard.swift
//  LexiconFlow
//
//  Core flashcard model representing a vocabulary item
//

import SwiftData
import Foundation

/// A flashcard containing vocabulary information and FSRS scheduling state
///
/// Flashcards are the primary entity in the system, representing individual
/// vocabulary items to be learned. Each flashcard has:
/// - The vocabulary word and its definition
/// - Optional phonetic pronunciation and image
/// - FSRS algorithm state for scheduling
/// - Relationship to a deck (optional, for organization)
/// - History of reviews
///
/// Note: Named `Flashcard` instead of `Card` to avoid naming collision
/// with the FSRS library's `Card` type.
@Model
final class Flashcard {
    /// Unique identifier for this card
    var id: UUID

    /// The vocabulary word to learn
    var word: String

    /// Definition or meaning of the word
    var definition: String

    /// Phonetic pronunciation (IPA notation) - optional
    var phonetic: String?

    /// Associated image data (stored separately for performance)
    @Attribute(.externalStorage) var imageData: Data?

    /// When this card was created
    var createdAt: Date

    // MARK: - Relationships

    /// The deck this card belongs to (optional for CloudKit compatibility)
    /// - Inverse defined on Deck.cards to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify) var deck: Deck?

    /// All review logs for this card
    /// - Deleting card cascades to delete all logs
    /// - Inverse defined on FlashcardReview.card to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .cascade) var reviewLogs: [FlashcardReview] = []

    /// FSRS algorithm state for this card (one-to-one)
    /// - Inverse defined on FSRSState.card to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship var fsrsState: FSRSState?

    // MARK: - Initialization

    /// Initialize a new vocabulary card
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - word: The vocabulary word
    ///   - definition: Definition or meaning
    ///   - phonetic: IPA pronunciation (optional)
    ///   - imageData: Image data for visual learning (optional)
    ///   - createdAt: Creation timestamp (defaults to now)
    init(id: UUID = UUID(),
         word: String,
         definition: String,
         phonetic: String? = nil,
         imageData: Data? = nil,
         createdAt: Date = Date()) {

        self.id = id
        self.word = word
        self.definition = definition
        self.phonetic = phonetic
        self.imageData = imageData
        self.createdAt = createdAt
        // Relationships are auto-initialized by SwiftData
    }
}
