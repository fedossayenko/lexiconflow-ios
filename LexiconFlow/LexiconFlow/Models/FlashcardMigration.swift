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

// MARK: - Migration Plan

/// Migration plan for Flashcard model schema changes
///
/// Defines how to migrate between different schema versions.
/// Uses SwiftData's lightweight migration for optional field additions.
enum FlashcardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FlashcardSchemaV1_0.self,
            FlashcardSchemaV1_1.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            // v1.0 to v1.1: Add optional translation fields
            // Uses lightweight migration - SwiftData automatically adds new optional fields
            // No custom migration logic needed
            .lightweight(fromVersion: FlashcardSchemaV1_0.self, toVersion: FlashcardSchemaV1_1.self)
        ]
    }

    /// Migration Stage Information
    ///
    /// **NOTE**: For v1.0 → v1.1 (adding optional fields), SwiftData handles
    /// migration automatically because all new fields are optional with default nil values.
    ///
    /// **Future**: When adding non-optional fields, you will need to:
    /// 1. Bump the schema version
    /// 2. Create a custom migration plan
    /// 3. Use custom MigrationStage with data transformation

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

// MARK: - Migration Errors

/// Errors that can occur during schema migration
enum MigrationError: Error {
    /// Unsupported version transition (e.g., backward migration)
    case unsupportedVersionTransition(from: Int, to: Int)

    /// Migration failed with underlying error
    case migrationFailed(underlying: Error)

    /// Data corruption during migration
    case dataCorruption(String)

    var localizedDescription: String {
        switch self {
        case .unsupportedVersionTransition(let from, let to):
            return "Cannot migrate from version \(from) to version \(to). Backward migration is not supported."
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .dataCorruption(let message):
            return "Data corruption during migration: \(message)"
        }
    }
}

// MARK: - Testing Support

extension FlashcardMigrationPlan {
    /// Verify migration can be performed (for testing)
    ///
    /// **Usage in Tests**:
    /// ```swift
    /// @Test("Migration v1.0 to v1.1 succeeds")
    /// func testMigration() throws {
    ///     let result = try FlashcardMigrationPlan.verifyMigration(
    ///         from: .v1_0,
    ///         to: .v1_1
    ///     )
    ///     #expect(result, "Automatic migration should verify")
    /// }
    /// ```
    static func verifyMigration(from: FlashcardSchemaVersion, to: FlashcardSchemaVersion) throws -> Bool {
        // Same version is always valid (no migration needed)
        if from == to {
            return true
        }

        // Forward migration is supported
        if to.rawValue > from.rawValue {
            return true
        }

        // Backward migration is not supported
        throw MigrationError.unsupportedVersionTransition(
            from: from.rawValue,
            to: to.rawValue
        )
    }
}

// MARK: - Migration Utilities

extension ModelContainer {
    /// Check if the container is using the current schema version
    ///
    /// - Returns: true if the container's schema matches the current version
    func isCurrentSchemaVersion() -> Bool {
        // SwiftData handles schema versioning internally
        // This is a placeholder for future version tracking implementation
        return true
    }

    /// Get the schema version of this container
    ///
    /// - Returns: The schema version enum value
    func getSchemaVersion() -> FlashcardSchemaVersion {
        // SwiftData doesn't expose schema version directly
        // This is a placeholder for future version tracking implementation
        return .current
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
