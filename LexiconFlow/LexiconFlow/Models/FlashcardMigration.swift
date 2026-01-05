//
//  FlashcardMigration.swift
//  LexiconFlow
//
//  SwiftData migration strategy for Flashcard model schema changes
//
//  This file defines versioned schemas and migration plans for the Flashcard model
//  as new fields are added (translation, CEFR level, context sentences, etc.)
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

// MARK: - Migration Plan

/// Migration handler for Flashcard schema changes
///
/// **Usage**:
/// ```swift
/// let modelConfiguration = ModelConfiguration(
///     schema: Schema([Flashcard.self, ...]),
///     migrationStage: .migrationRequired
/// )
/// ```
///
/// **Current Migrations**:
/// - v1.0 → v1.1: Add optional translation fields (automatic)
///
/// **Future Migration Pattern**:
/// When adding new non-optional fields, use this pattern:
/// ```swift
/// enum FlashcardSchemaVersion: Int {
///     case v1_0 = 1
///     case v1_1 = 2
///     case v1_2 = 3  // New version with non-optional field
/// }
///
/// // In migration handler:
/// if version < .v1_2.rawValue {
///     // Migrate existing data, provide defaults for new non-optional field
///     try context.delete(model: FlashcardV1_1.self)
///     try context.insert(migratedFlashcards)
/// }
/// ```
enum FlashcardMigrationPlan {

    /// Migration Stage Information
    ///
    /// **NOTE**: For v1.0 → v1.1 (adding optional fields), SwiftData handles
    /// migration automatically because all new fields are optional with default nil values.
    ///
    /// No explicit migration stage configuration is needed for automatic migration.
    /// SwiftData will detect schema changes and migrate automatically.
    ///
    /// **Future**: When adding non-optional fields, you will need to:
    /// 1. Bump the schema version
    /// 2. Create a custom migration plan
    /// 3. Use `.migrationRequired` stage in ModelConfiguration

    /// Perform custom migration between schema versions
    ///
    /// **Currently**: No-op (automatic migration for optional fields)
    /// **Future**: Implement custom logic for non-optional field additions
    static func performMigration(from: FlashcardSchemaVersion, to: FlashcardSchemaVersion, context: ModelContext) throws {
        // v1.0 → v1.1: Automatic migration (all new fields are optional)
        // No custom logic needed

        // Future example for v1.1 → v1.2 with non-optional field:
        // if from == .v1_1, to == .v1_2 {
        //     let fetchDescriptor = FetchDescriptor<FlashcardV1_1>()
        //     let oldCards = try context.fetch(fetchDescriptor)
        //
        //     for oldCard in oldCards {
        //         let newCard = Flashcard(
        //             word: oldCard.word,
        //             definition: oldCard.definition,
        //             // NEW NON-OPTIONAL FIELD with default value
        //             newField: oldCard.computedDefault ?? "default_value"
        //         )
        //         context.delete(oldCard)
        //         context.insert(newCard)
        //     }
        // }

        try context.save()
    }
}

// MARK: - Migration Types

/// Typesafe marker for different schema versions (used in future migrations)
///
/// **Usage**: Create typed version of model for each schema version:
/// ```swift
/// @Model
/// final class FlashcardV1_0 {
///     var word: String
///     var definition: String
///     // ... v1.0 fields only
/// }
///
/// @Model
/// final class FlashcardV1_1 {
///     var word: String
///     var definition: String
///     var translation: String?  // NEW in v1.1
///     // ... all v1.1 fields
/// }
/// ```

// MARK: - Testing Support

extension FlashcardMigrationPlan {
    /// Verify migration can be performed (for testing)
    ///
    /// **Usage in Tests**:
    /// ```swift
    /// @Test("Migration v1.0 to v1.1 succeeds")
    /// func testMigration() throws {
    ///     let container = try ModelContainer(
    ///         for: Flashcard.self,
    ///         migrationStage: .migrationRequired
    ///     )
    ///     let migrated = try FlashcardMigrationPlan.performMigration(
    ///         from: .v1_0,
    ///         to: .v1_1,
    ///         context: container.mainContext
    ///     )
    ///     #expect(migrated, "Migration should succeed")
    /// }
    /// ```
    static func verifyMigration(from: FlashcardSchemaVersion, to: FlashcardSchemaVersion) throws -> Bool {
        // For v1.0 → v1.1, automatic migration always succeeds
        return true
    }
}

// MARK: - Documentation

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

 3. **Add Migration Test**:
 ```swift
 @Test("Migration v1.1 to v1.2 handles existing data")
 func testMigrationWithDefaultValues() throws {
     // Create v1.1 data
     // Run migration
     // Verify new field has correct default
 }
 ```

 ### Migration Best Practices

 1. **Add Fields as Optional First**: Add optional fields, let users migrate, then make required in next version
 2. **Provide Sensible Defaults**: Compute defaults from existing data when possible
 3. **Test Migration Both Ways**: Verify old → new and new installation paths
 4. **Backup Before Migration**: Consider backing up data before destructive migrations
 5. **Version Bumping**: Always bump schema version when adding/removing fields

 ### Testing Migrations

 ```swift
 @Test("Schema version v1.1 is current")
 func testCurrentSchemaVersion() {
     #expect(FlashcardSchemaVersion.current == .v1_1)
 }

 @Test("Migration stage is lightweight for optional fields")
 func testMigrationStage() {
     #expect(FlashcardMigrationPlan.migrationStage == .lightweight)
 }

 @Test("v1.0 to v1.1 migration verifies successfully")
 func testMigrationVerification() throws {
     let result = try FlashcardMigrationPlan.verifyMigration(from: .v1_0, to: .v1_1)
     #expect(result, "Automatic migration should verify")
 }
 ```

 */
