//
//  QuickTranslationService.swift
//  LexiconFlow
//
//  Quick tap-to-translate service with caching for flashcard translation
//

import Foundation
import OSLog
import SwiftData

/// Service for rapid flashcard translation with 30-day caching
///
/// **Design Philosophy:**
/// - Speed: Cache-first strategy for instant results
/// - Privacy: On-device translation only (no cloud API)
/// - Resilience: Graceful degradation when offline
/// - Transparency: Clear cache hit/miss indication
/// - Concurrency: Actor-isolated with DTO pattern for SwiftData safety
///
/// **Usage:**
/// ```swift
/// let request = FlashcardTranslationRequest(
///     word: card.word,
///     flashcardID: card.persistentModelID
/// )
/// let result = try await QuickTranslationService.shared.translate(
///     request: request,
///     container: modelContext.container
/// )
///
/// if result.isCacheHit {
///     print("Translation from cache: \(result.translatedText)")
/// } else {
///     print("Fresh translation: \(result.translatedText)")
/// }
/// ```
actor QuickTranslationService {
    // MARK: - Singleton

    static let shared = QuickTranslationService()

    /// Logger for debugging and monitoring
    ///
    /// **Note:** Static logger allows access from nonisolated helper functions
    /// without crossing actor boundaries.
    private static let logger = Logger(subsystem: "com.lexiconflow.translation", category: "QuickTranslation")

    /// Translation cache TTL (30 days)
    private enum CacheConstants {
        /// Cache expiration time in seconds (30 days)
        static let cacheTTL: TimeInterval = 30 * 24 * 60 * 60

        /// Maximum cache size (optional: limit to prevent DB bloat)
        static let maxCacheSize: Int = 10000
    }

    // MARK: - Types

    /// Data transfer object for flashcard translation request
    ///
    /// **Why DTO?** SwiftData models cannot cross actor boundaries safely.
    /// This Sendable struct contains only the data needed for translation.
    struct FlashcardTranslationRequest: Sendable {
        /// The word to translate
        let word: String

        /// Flashcard identifier for context (optional)
        let flashcardID: PersistentIdentifier?
    }

    /// Result of a quick translation operation
    struct QuickTranslationResult: Sendable {
        /// The translated text
        let translatedText: String

        /// Source language code (e.g., "en")
        let sourceLanguage: String

        /// Target language code (e.g., "es")
        let targetLanguage: String

        /// Whether this result came from cache (true) or fresh translation (false)
        let isCacheHit: Bool

        /// Cache expiration date (nil if fresh translation)
        let cacheExpirationDate: Date?

        /// Human-readable status message for UI
        var statusMessage: String {
            if isCacheHit {
                "Cached • expires \(cacheExpirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "soon")"
            } else {
                "Fresh translation"
            }
        }
    }

    /// Error types specific to quick translation
    enum QuickTranslationError: LocalizedError, Sendable {
        /// Flashcard word is empty or invalid
        case emptyWord

        /// Translation not available in cache and device is offline
        case offlineNoCache

        /// Language pack not downloaded
        case languagePackMissing(source: String, target: String)

        /// Translation operation failed
        case translationFailed(reason: String)

        var errorDescription: String? {
            switch self {
            case .emptyWord:
                "Cannot translate empty word"
            case .offlineNoCache:
                "Offline: no cached translation available"
            case let .languagePackMissing(source, target):
                "Language pack not available for \(source) → \(target)"
            case let .translationFailed(reason):
                "Translation failed: \(reason)"
            }
        }

        var failureReason: String? {
            switch self {
            case .emptyWord:
                "Input validation failed"
            case .offlineNoCache:
                "No cached translation and device offline"
            case .languagePackMissing:
                "Required language pack not downloaded"
            case .translationFailed:
                "On-device translation framework error"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .emptyWord:
                "Select a valid flashcard"
            case .offlineNoCache:
                "Connect to internet or use previously translated cards"
            case let .languagePackMissing(source, target):
                "Download language packs for \(source) or \(target) in Settings"
            case .translationFailed:
                "Try again or use shorter text"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        Self.logger.info("QuickTranslationService initialized with 30-day cache TTL")
    }

    // MARK: - Public API

    /// Translate a flashcard word with cache-first strategy
    ///
    /// **Flow:**
    /// 1. Check SwiftData for valid cached translation (30-day TTL)
    /// 2. If cache hit → return immediately with isCacheHit: true
    /// 3. If cache miss → call OnDeviceTranslationService
    /// 4. Save fresh translation to SwiftData cache
    /// 5. Return with isCacheHit: false
    ///
    /// **Actor Isolation:**
    /// - SwiftData operations run on MainActor via `await MainActor.run`
    /// - This prevents passing ModelContext (MainActor-bound) across actor boundaries
    /// - DTO pattern ensures thread-safe data transfer
    ///
    /// **Parameters:**
    ///   - request: FlashcardTranslationRequest DTO with word to translate
    ///   - container: ModelContainer for creating contexts on MainActor
    ///
    /// **Returns:** QuickTranslationResult with translation and metadata
    ///
    /// **Throws:**
    ///   - `.emptyWord` if request.word is empty
    ///   - `.languagePackMissing` if language packs not downloaded
    ///   - `.offlineNoCache` if device offline and no cached translation
    ///   - `.translationFailed` if translation operation fails
    func translate(
        request: FlashcardTranslationRequest,
        container: ModelContainer
    ) async throws -> QuickTranslationResult {
        // Check for cancellation at entry point
        try Task.checkCancellation()

        // Input validation
        let word = request.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            Self.logger.warning("Translation attempted with empty word")
            throw QuickTranslationError.emptyWord
        }

        // Get configured languages from AppSettings
        let sourceLanguage = await AppSettings.translationSourceLanguage
        let targetLanguage = await AppSettings.translationTargetLanguage

        Self.logger.debug("Translating '\(word)' from \(sourceLanguage) to \(targetLanguage)")

        // Check for cancellation before expensive operations
        try Task.checkCancellation()

        // Step 1: Check cache (on MainActor for SwiftData safety)
        if let cachedResult = await checkCache(
            word: word,
            source: sourceLanguage,
            target: targetLanguage,
            container: container
        ) {
            Self.logger.info("Cache HIT for '\(word)'")
            return cachedResult
        }

        Self.logger.info("Cache MISS for '\(word)', performing fresh translation")

        // Check for cancellation before expensive translation
        try Task.checkCancellation()

        // Step 2: Fresh translation
        let translatedText = try await performFreshTranslation(
            word: word,
            source: sourceLanguage,
            target: targetLanguage
        )

        // Step 3: Save to cache (on MainActor for SwiftData safety)
        await saveTranslationToCacheInBackground(
            word: word,
            translatedText: translatedText,
            source: sourceLanguage,
            target: targetLanguage,
            container: container
        )

        return QuickTranslationResult(
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isCacheHit: false,
            cacheExpirationDate: nil
        )
    }

    // MARK: - Private Translation Helpers

    /// Check cache for existing translation
    private nonisolated func checkCache(
        word: String,
        source: String,
        target: String,
        container: ModelContainer
    ) async -> QuickTranslationResult? {
        await MainActor.run {
            let context = ModelContext(container)
            return self.findCachedTranslation(
                word: word,
                source: source,
                target: target,
                modelContext: context
            ).map { cached in
                QuickTranslationResult(
                    translatedText: cached.translatedText,
                    sourceLanguage: source,
                    targetLanguage: target,
                    isCacheHit: true,
                    cacheExpirationDate: cached.expiresAt
                )
            }
        }
    }

    /// Perform fresh translation with error mapping
    private func performFreshTranslation(
        word: String,
        source: String,
        target: String
    ) async throws -> String {
        do {
            return try await OnDeviceTranslationService.shared.translate(
                text: word,
                from: source,
                to: target
            )
        } catch let error as OnDeviceTranslationError {
            throw mapTranslationError(error, source: source, target: target)
        } catch {
            Self.logger.error("Unexpected translation error: \(error.localizedDescription)")
            throw QuickTranslationError.translationFailed(reason: error.localizedDescription)
        }
    }

    /// Map OnDeviceTranslationError to QuickTranslationError
    private func mapTranslationError(
        _ error: OnDeviceTranslationError,
        source: String,
        target: String
    ) -> QuickTranslationError {
        switch error {
        case .languagePackNotAvailable, .unsupportedLanguagePair:
            Self.logger.error("Language pack not available")
            return .languagePackMissing(source: source, target: target)
        case .translationFailed, .languagePackDownloadFailed, .emptyInput:
            Self.logger.error("Translation error: \(error.localizedDescription)")
            return .translationFailed(reason: error.localizedDescription)
        }
    }

    /// Save translation to cache in background (fire and forget)
    private nonisolated func saveTranslationToCacheInBackground(
        word: String,
        translatedText: String,
        source: String,
        target: String,
        container: ModelContainer
    ) async {
        await MainActor.run {
            let context = ModelContext(container)
            Task {
                await self.saveToCache(
                    word: word,
                    translatedText: translatedText,
                    source: source,
                    target: target,
                    modelContext: context
                )
            }
        }
    }

    /// Check if language packs are available for quick translation
    ///
    /// **Returns:** `true` if both source and target language packs are downloaded
    func areLanguagePacksAvailable() async -> Bool {
        let source = await AppSettings.translationSourceLanguage
        let target = await AppSettings.translationTargetLanguage

        let sourceAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(source)
        let targetAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(target)

        return sourceAvailable && targetAvailable
    }

    /// Clear expired translations from cache (maintenance operation)
    ///
    /// **Usage:** Call periodically (e.g., app launch) to clean up expired entries
    ///
    /// **Actor Isolation:** SwiftData operations run on MainActor via `await MainActor.run`
    func clearExpiredCache(container: ModelContainer) async {
        await MainActor.run {
            let context = ModelContext(container)
            let now = Date()

            let fetchDescriptor = FetchDescriptor<CachedTranslation>(
                predicate: #Predicate<CachedTranslation> { translation in
                    translation.expiresAt < now
                }
            )

            do {
                let expiredTranslations = try context.fetch(fetchDescriptor)

                for translation in expiredTranslations {
                    context.delete(translation)
                }

                if !expiredTranslations.isEmpty {
                    try context.save()
                    Self.logger.info("Cleared \(expiredTranslations.count) expired translations from cache")
                }
            } catch {
                Self.logger.error("Failed to clear expired cache: \(error.localizedDescription)")
                Analytics.trackError("quick_translation_cache_cleanup_failed", error: error)
            }
        }
    }

    // MARK: - Private Helpers

    /// Find valid cached translation for word and language pair
    ///
    /// **Returns:** `nil` if no valid cache entry exists
    ///
    /// **Actor Isolation:** `nonisolated` - safe to call from any actor context
    /// since ModelContext is already bound to the calling actor.
    private nonisolated func findCachedTranslation(
        word: String,
        source: String,
        target: String,
        modelContext: ModelContext
    ) -> CachedTranslation? {
        let now = Date()

        let fetchDescriptor = FetchDescriptor<CachedTranslation>(
            predicate: #Predicate<CachedTranslation> { translation in
                translation.sourceWord == word &&
                    translation.sourceLanguage == source &&
                    translation.targetLanguage == target &&
                    translation.expiresAt > now
            }
        )

        do {
            let results = try modelContext.fetch(fetchDescriptor)
            return results.first // Return most recent valid entry
        } catch {
            Self.logger.error("Failed to fetch cached translation: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save translation to cache with 30-day expiration
    ///
    /// **Cache Management:**
    /// - Enforces `maxCacheSize` limit (10,000 entries)
    /// - Implements LRU eviction when cache is full (deletes oldest 10%)
    /// - Logs cache size for monitoring
    ///
    /// **Actor Isolation:** `nonisolated` - safe to call from any actor context
    /// since ModelContext is already bound to the calling actor.
    private nonisolated func saveToCache(
        word: String,
        translatedText: String,
        source: String,
        target: String,
        modelContext: ModelContext
    ) async {
        do {
            // 1. Check cache size before inserting
            let countDescriptor = FetchDescriptor<CachedTranslation>()
            let currentCount = try modelContext.fetchCount(countDescriptor)

            // 2. Enforce cache size limit
            if currentCount >= CacheConstants.maxCacheSize {
                Self.logger.info("Cache full (\(currentCount)/\(CacheConstants.maxCacheSize)), evicting oldest entries")

                // Fetch oldest entries (LRU eviction)
                let deleteDescriptor = FetchDescriptor<CachedTranslation>(
                    sortBy: [SortDescriptor(\.cachedAt, order: .forward)]
                )
                let entriesToDelete = try modelContext.fetch(deleteDescriptor)

                // Delete oldest 10% of cache
                let deleteCount = max(1, entriesToDelete.count / 10)
                for i in 0 ..< deleteCount {
                    modelContext.delete(entriesToDelete[i])
                }

                try modelContext.save()
                Self.logger.info("Evicted \(deleteCount) oldest cache entries")
            }

            // 3. Insert new entry
            let cachedTranslation = try CachedTranslation(
                sourceWord: word,
                translatedText: translatedText,
                sourceLanguage: source,
                targetLanguage: target,
                ttlDays: 30
            )

            modelContext.insert(cachedTranslation)
            try modelContext.save()

            Self.logger.info("Saved translation to cache: '\(word)' → '\(translatedText)' (size: \(currentCount + 1)/\(CacheConstants.maxCacheSize))")
        } catch {
            Self.logger.error("Failed to save translation to cache: \(error.localizedDescription)")
            await Analytics.trackError("quick_translation_cache_save_failed", error: error)
        }
    }
}
