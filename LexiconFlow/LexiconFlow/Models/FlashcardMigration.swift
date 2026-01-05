//
//  FlashcardMigration.swift
//  LexiconFlow
//
//  SwiftData migration strategy for Flashcard model schema changes
//

import SwiftData
import Foundation

// MARK: - Model Versioning

/// Schema version enumeration for Flashcard model
enum FlashcardSchemaVersion: Int {
    /// v1.0 - Initial schema (word, definition, phonetic, imageData)
    case v1_0 = 1

    /// v1.1 - Added translation fields (translation, sourceLanguage, targetLanguage, cefrLevel, contextSentence)
    case v1_1 = 2

    /// Current schema version
    static var current: FlashcardSchemaVersion {
        return .v1_1
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
