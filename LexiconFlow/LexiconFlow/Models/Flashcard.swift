//
//  Flashcard.swift
//  LexiconFlow
//
//  Core flashcard model representing a vocabulary item
//

import Foundation
import SwiftData

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

    // MARK: - Translation Fields

    /// Translation of the word into target language
    /// Used by both on-device (iOS 26 Translation) and cloud (Z.ai) services
    var translation: String?

    /// CEFR level (A1, A2, B1, B2, C1, C2) for vocabulary categorization
    /// - nil for user-created cards or cards without CEFR annotation
    /// - Used for IELTS vocabulary decks and difficulty filtering
    /// - Validated against allowed values: A1, A2, B1, B2, C1, C2
    var cefrLevel: String?

    // MARK: - Bidirectional Learning Fields

    /// Card type for bidirectional learning (Recognition/Production modes)
    /// - nil for existing cards (defaults to forward/Recognition mode)
    /// - "forward" = English→Russian (Recognition mode)
    /// - "reverse" = Russian→English (Production mode)
    ///
    /// **Pedagogical Basis**:
    /// - Recognition (Forward): Builds receptive vocabulary (reading, listening)
    /// - Production (Reverse): Builds productive vocabulary (speaking, writing)
    ///
    /// **Implementation Note**: Stored as String? for backward compatibility
    var cardTypeRaw: String?

    // MARK: - Optional Fields

    /// Phonetic pronunciation (IPA notation) - optional
    var phonetic: String?

    /// Associated image data (stored separately for performance)
    @Attribute(.externalStorage) var imageData: Data?

    /// When this card was created
    var createdAt: Date

    // MARK: - Relationships

    /// The deck this card belongs to (optional for CloudKit compatibility)
    ///
    /// **Nil Value**: Card is orphaned (deck was deleted, or card created without deck)
    /// **Delete Rule**: .nullify ensures cards persist when deck is deleted (preserves FSRS progress)
    /// **Orphan Management**: Orphaned cards are visible in "Orphaned Cards" section
    /// **Inverse**: Defined on Deck.cards to avoid circular macro expansion
    /// **SwiftData**: Auto-initializes this property
    @Relationship(deleteRule: .nullify) var deck: Deck?

    /// All review logs for this card
    /// - Deleting card cascades to delete all logs
    /// - Inverse defined on FlashcardReview.card to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .cascade) var reviewLogs: [FlashcardReview] = []

    /// FSRS algorithm state for this card (one-to-one)
    /// - Inverse defined on FSRSState.card to avoid circular reference
    /// - SwiftData auto-initializes this property
    /// - CRITICAL: Cascade delete ensures orphaned FSRSState records are cleaned up
    /// - NOTE: Only define inverse on ONE side (FSRSState) to avoid circular macro expansion
    @Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

    /// AI-generated context sentences for this card (one-to-many)
    /// - Inverse defined on GeneratedSentence.flashcard to avoid circular reference
    /// - SwiftData auto-initializes this property
    /// - Cascade delete: deleting card removes all generated sentences
    /// - Sentences have 7-day TTL expiration
    @Relationship(deleteRule: .cascade) var generatedSentences: [GeneratedSentence] = []

    // MARK: - Initialization

    /// Initialize a new vocabulary card
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - word: The vocabulary word
    ///   - definition: Definition or meaning
    ///   - translation: Translation into target language (optional)
    ///   - phonetic: IPA pronunciation (optional)
    ///   - imageData: Image data for visual learning (optional)
    ///   - createdAt: Creation timestamp (defaults to now)
    init(
        id: UUID = UUID(),
        word: String,
        definition: String,
        translation: String? = nil,
        phonetic: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.definition = definition
        self.translation = translation
        self.phonetic = phonetic
        self.imageData = imageData
        self.createdAt = createdAt
        // Relationships are auto-initialized by SwiftData
    }

    // MARK: - Computed Properties

    /// Card type for bidirectional learning (Recognition/Production modes)
    ///
    /// **Returns**: `CardType` value (defaults to `.forward` if cardTypeRaw is nil)
    ///
    /// **Backward Compatibility**: Existing cards with `cardTypeRaw = nil` default to `.forward` (Recognition mode)
    var cardType: CardType {
        get { CardType(rawValue: self.cardTypeRaw ?? CardType.forward.rawValue) ?? .forward }
        set { self.cardTypeRaw = newValue.rawValue }
    }

    // MARK: - CEFR Level Validation

    /// Validates and sets CEFR level for this flashcard
    ///
    /// - Parameter level: The CEFR level to set (A1, A2, B1, B2, C1, C2), or nil to clear
    /// - Throws: `FlashcardError.invalidCEFRLevel` if the level is not valid
    func setCEFRLevel(_ level: String?) throws {
        guard let level else {
            self.cefrLevel = nil
            return
        }

        let validLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        guard validLevels.contains(level) else {
            throw FlashcardError.invalidCEFRLevel(level)
        }

        self.cefrLevel = level
    }
}

// MARK: - Flashcard Errors

/// Errors that can occur when working with flashcards
enum FlashcardError: LocalizedError, @unchecked Sendable {
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

// MARK: - Card Type

/// Card type for bidirectional learning (Recognition/Production modes)
enum CardType: String, Codable, Sendable {
    /// Forward card: English→Russian (Recognition mode)
    case forward

    /// Reverse card: Russian→English (Production mode)
    case reverse

    /// Display name for UI
    var displayName: String {
        switch self {
        case .forward: "Recognition"
        case .reverse: "Production"
        }
    }

    /// SF Symbol icon for UI
    var iconName: String {
        switch self {
        case .forward: "arrow.right"
        case .reverse: "arrow.left"
        }
    }

    /// Arrow symbol for visual direction indicator
    var arrowSymbol: String {
        switch self {
        case .forward: "→"
        case .reverse: "←"
        }
    }
}
