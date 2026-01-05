//
//  FlashcardMigration.swift
//  LexiconFlow
//
//  SwiftData migration strategy for Flashcard model schema changes
//

import SwiftData
import Foundation

// MARK: - Schema Version Tracking

/// Schema version enumeration for Flashcard model
///
/// Tracks the evolution of the Flashcard SwiftData schema over time.
/// Each version represents a set of model definitions that can be migrated between.
enum FlashcardSchemaVersion: Int {
    /// v1.0 - Initial schema (word, definition, phonetic, imageData)
    case v1_0 = 1

    /// v1.1 - Added translation fields (translation, sourceLanguage, targetLanguage, cefrLevel, contextSentence)
    case v1_1 = 2

    /// Current schema version
    static let current: FlashcardSchemaVersion = .v1_1
}

// MARK: - Versioned Schema Definitions

/// v1.0 Schema - Initial Release
///
/// Original Flashcard model without translation support.
/// Used for migrating legacy databases to current schema.
@Model
final class FlashcardV1_0 {
    var id: UUID
    var word: String
    var definition: String
    var phonetic: String?
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var deck: Deck?
    @Relationship(deleteRule: .cascade) var reviewLogs: [FlashcardReview] = []
    @Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

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
    }
}

/// v1.0 Versioned Schema
enum FlashcardSchemaV1_0: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FlashcardV1_0.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self
        ]
    }
}

/// v1.1 Schema - Translation Feature Addition
///
/// Current Flashcard model with translation support.
/// This is the active schema used by the app.
enum FlashcardSchemaV1_1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            Flashcard.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self
        ]
    }
}

// MARK: - Migration Documentation

/*
 ## SwiftData Migration Strategy

 ### Current State (v1.1)

 **New Fields Added (Optional)**:
 - `translation: String?` - Translated word
 - `translationSourceLanguage: String?` - Source language code
 - `translationTargetLanguage: String?` - Target language code
 - `cefrLevel: String?` - CEFR level (A1-C2)
 - `contextSentence: String?` - Context example sentence

 **Migration Type**: Lightweight (automatic)
 - All new fields are optional with nil defaults
 - SwiftData handles schema migration automatically
 - No data loss or transformation required

 ### Future Migration Pattern

 **When Adding Non-Optional Fields**:

 1. **Bump Schema Version**:
 ```swift
 enum FlashcardSchemaVersion: Int {
     case v1_2 = 3  // New version
 }
 ```

 2. **Create Migration Plan**:
 ```swift
 // Change migration stage
 static var migrationStage: MigrationStage {
     return .migrationRequired  // Custom migration needed
 }

 // Implement migration logic
 static func performMigration(from: FlashcardSchemaVersion, to: FlashcardSchemaVersion, context: ModelContext) throws {
     if from == .v1_1, to == .v1_2 {
         // Fetch old model
         let oldCards = try context.fetch(FetchDescriptor<FlashcardV1_1>())

         // Transform to new model with defaults
         for oldCard in oldCards {
             let newCard = Flashcard(
                 word: oldCard.word,
                 definition: oldCard.definition,
                 newRequiredField: computeDefault(from: oldCard)
             )
             context.delete(oldCard)
             context.insert(newCard)
         }
         try context.save()
     }
 }
 ```

 ### Migration Best Practices

 1. **Add Fields as Optional First**: Add optional fields, let users migrate, then make required in next version
 2. **Provide Sensible Defaults**: Compute defaults from existing data when possible
 3. **Test Migration Both Ways**: Verify old → new and new installation paths
 4. **Backup Before Migration**: Consider backing up data before destructive migrations
 5. **Version Bumping**: Always bump schema version when adding/removing fields

 */
