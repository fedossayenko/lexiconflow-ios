//
//  CachedTranslation.swift
//  LexiconFlow
//
//  Cached translation for quick tap-to-translate feature
//

import Foundation
import OSLog
import SwiftData

/// Cached translation result with expiration
///
/// **Design:**
/// - Global cache: Not tied to specific flashcards
/// - 30-day TTL: Long expiration for offline capability
/// - Unique constraint: One entry per (word, source, target) triplet
/// - Automatic cleanup: Expired entries filtered out
///
/// **Cache Invalidation:**
/// - Does NOT invalidate when languages change (cached translations remain valid)
/// - User can manually clear cache in Settings (future enhancement)
///
/// **Thread Safety:**
/// - ⚠️ **NOT Sendable** - SwiftData `@Model` classes are not `Sendable` by default
/// - Must remain on `@MainActor` or single actor context for thread-safe access
/// - `QuickTranslationService` returns `QuickTranslationResult` DTO (Sendable), NOT this model
/// - ModelContext operations must happen on the same context that created the instance
/// - Never pass `CachedTranslation` instances across actor boundaries
///
/// **Correct Usage Pattern:**
/// ```swift
/// // ✅ CORRECT: Service returns DTO, not model
/// actor QuickTranslationService {
///     func translate(...) async throws -> QuickTranslationResult {
///         // Extract values from model, return DTO struct
///         return QuickTranslationResult(
///             translatedText: cachedTranslation.translatedText,
///             // ... other fields
///         )
///     }
/// }
///
/// // ❌ AVOID: Returning model from actor
/// actor MyActor {
///     func getCachedTranslation() -> CachedTranslation { ... }  // DON'T DO THIS
/// }
/// ```
@Model
final class CachedTranslation {
    // MARK: - Index

    /// Compound index on (sourceWord, sourceLanguage, targetLanguage)
    /// Optimizes cache lookup queries from O(n) to O(log n)
    /// This is the primary query pattern for cache hits
    #Index<CachedTranslation>([\.sourceWord, \.sourceLanguage, \.targetLanguage])

    // MARK: - Properties

    /// Unique identifier for this cache entry
    var id: UUID

    /// The source word that was translated
    var sourceWord: String

    /// The translated text
    var translatedText: String

    /// Source language code (e.g., "en")
    var sourceLanguage: String

    /// Target language code (e.g., "es")
    var targetLanguage: String

    /// When this translation was cached
    var cachedAt: Date

    /// When this cache entry expires (30-day TTL)
    var expiresAt: Date

    // MARK: - Computed Properties

    /// Whether this cache entry has expired
    var isExpired: Bool {
        Date() > self.expiresAt
    }

    /// Days remaining until expiration (negative if expired)
    var daysUntilExpiration: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self.expiresAt).day ?? 0
    }

    // MARK: - Initialization

    /// Valid TTL range for validation
    private static let validTTLRange = 1 ... 365 // 1 day to 1 year

    /// Shared logger for all CachedTranslation instances
    private static let logger = Logger(subsystem: "com.lexiconflow.cache", category: "CachedTranslation")

    /// Initialize a new cached translation
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - sourceWord: The source word that was translated
    ///   - translatedText: The translated text
    ///   - sourceLanguage: Source language code (e.g., "en")
    ///   - targetLanguage: Target language code (e.g., "es")
    ///   - cachedAt: Cache timestamp (defaults to now)
    ///   - ttlDays: Time-to-live in days (defaults to 30)
    ///
    /// - Throws: CachedTranslationError if validation fails
    init(
        id: UUID = UUID(),
        sourceWord: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        cachedAt: Date = Date(),
        ttlDays: Int = 30
    ) throws {
        // Validate source word
        let trimmedWord = sourceWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else {
            throw CachedTranslationError.emptySourceWord
        }

        // Validate translated text
        let trimmedTranslation = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranslation.isEmpty else {
            throw CachedTranslationError.emptyTranslatedText
        }

        // Validate language codes
        let trimmedSource = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty, !trimmedTarget.isEmpty else {
            throw CachedTranslationError.invalidLanguageCode
        }

        // Validate TTL
        guard Self.validTTLRange.contains(ttlDays) else {
            throw CachedTranslationError.invalidTTL(ttlDays)
        }

        self.id = id
        self.sourceWord = trimmedWord
        self.translatedText = trimmedTranslation
        self.sourceLanguage = trimmedSource
        self.targetLanguage = trimmedTarget
        self.cachedAt = cachedAt
        self.expiresAt = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: ttlDays,
            to: cachedAt
        ) ?? cachedAt
    }
}

// MARK: - Validation Errors

/// Errors that can occur during CachedTranslation validation
enum CachedTranslationError: LocalizedError, Equatable, Sendable {
    case emptySourceWord
    case emptyTranslatedText
    case invalidLanguageCode
    case invalidTTL(Int)

    var errorDescription: String? {
        switch self {
        case .emptySourceWord:
            "Source word cannot be empty"
        case .emptyTranslatedText:
            "Translated text cannot be empty"
        case .invalidLanguageCode:
            "Language code cannot be empty"
        case let .invalidTTL(ttl):
            "Invalid TTL: \(ttl). Must be between 1 and 365 days"
        }
    }

    var failureReason: String? {
        switch self {
        case .emptySourceWord:
            "Validation failed during cache creation"
        case .emptyTranslatedText:
            "Validation failed during cache creation"
        case .invalidLanguageCode:
            "Invalid ISO language code format"
        case .invalidTTL:
            "TTL value outside acceptable range"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptySourceWord:
            "Provide a non-empty source word"
        case .emptyTranslatedText:
            "Provide a non-empty translation"
        case .invalidLanguageCode:
            "Use valid ISO language codes (e.g., 'en', 'es')"
        case .invalidTTL:
            "Use TTL between 1 and 365 days (default: 30)"
        }
    }
}
