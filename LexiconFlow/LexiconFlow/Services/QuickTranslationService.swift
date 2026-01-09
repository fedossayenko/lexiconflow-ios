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
///
/// **Usage:**
/// ```swift
/// let result = try await QuickTranslationService.shared.translate(
///     flashcard: card,
///     modelContext: modelContext
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
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "QuickTranslation")

    /// Translation cache TTL (30 days)
    private enum CacheConstants {
        /// Cache expiration time in seconds (30 days)
        static let cacheTTL: TimeInterval = 30 * 24 * 60 * 60

        /// Maximum cache size (optional: limit to prevent DB bloat)
        static let maxCacheSize: Int = 10000
    }

    // MARK: - Types

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
            if self.isCacheHit {
                "Cached • expires \(self.cacheExpirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "soon")"
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
        self.logger.info("QuickTranslationService initialized with 30-day cache TTL")
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
    /// **Parameters:**
    ///   - flashcard: The flashcard to translate (uses `.word` property)
    ///   - modelContext: SwiftData context for cache operations
    ///
    /// **Returns:** QuickTranslationResult with translation and metadata
    ///
    /// **Throws:**
    ///   - `.emptyWord` if flashcard.word is empty
    ///   - `.languagePackMissing` if language packs not downloaded
    ///   - `.offlineNoCache` if device offline and no cached translation
    ///   - `.translationFailed` if translation operation fails
    func translate(
        flashcard: Flashcard,
        modelContext: ModelContext
    ) async throws -> QuickTranslationResult {
        // Input validation
        let word = flashcard.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            self.logger.warning("Translation attempted with empty word")
            throw QuickTranslationError.emptyWord
        }

        // Get configured languages from AppSettings
        let sourceLanguage = await AppSettings.translationSourceLanguage
        let targetLanguage = await AppSettings.translationTargetLanguage

        self.logger.debug("Translating '\(word)' from \(sourceLanguage) to \(targetLanguage)")

        // Step 1: Check cache
        if let cachedTranslation = self.findCachedTranslation(
            word: word,
            source: sourceLanguage,
            target: targetLanguage,
            modelContext: modelContext
        ) {
            self.logger.info("Cache HIT for '\(word)'")

            return QuickTranslationResult(
                translatedText: cachedTranslation.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                isCacheHit: true,
                cacheExpirationDate: cachedTranslation.expiresAt
            )
        }

        self.logger.info("Cache MISS for '\(word)', performing fresh translation")

        // Step 2: Fresh translation
        let translatedText: String
        do {
            translatedText = try await OnDeviceTranslationService.shared.translate(
                text: word,
                from: sourceLanguage,
                to: targetLanguage
            )
        } catch let error as OnDeviceTranslationError {
            // Map OnDeviceTranslationError to QuickTranslationError
            switch error {
            case .languagePackNotAvailable:
                self.logger.error("Language pack not available")
                throw QuickTranslationError.languagePackMissing(
                    source: sourceLanguage,
                    target: targetLanguage
                )
            case .unsupportedLanguagePair:
                self.logger.error("Unsupported language pair")
                throw QuickTranslationError.languagePackMissing(
                    source: sourceLanguage,
                    target: targetLanguage
                )
            case .translationFailed:
                self.logger.error("Translation failed: \(error.localizedDescription)")
                throw QuickTranslationError.translationFailed(reason: error.localizedDescription)
            case .languagePackDownloadFailed, .emptyInput:
                self.logger.error("Translation error: \(error.localizedDescription)")
                throw QuickTranslationError.translationFailed(reason: error.localizedDescription)
            }
        } catch {
            self.logger.error("Unexpected translation error: \(error.localizedDescription)")
            throw QuickTranslationError.translationFailed(reason: error.localizedDescription)
        }

        // Step 3: Save to cache
        await self.saveToCache(
            word: word,
            translatedText: translatedText,
            source: sourceLanguage,
            target: targetLanguage,
            modelContext: modelContext
        )

        return QuickTranslationResult(
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isCacheHit: false,
            cacheExpirationDate: nil
        )
    }

    /// Request language pack download for configured languages
    ///
    /// **Usage:** Call this when QuickTranslationError.languagePackMissing is thrown
    ///
    /// **Throws:** Propagates errors from OnDeviceTranslationService
    func requestLanguagePackDownload() async throws {
        let source = await AppSettings.translationSourceLanguage
        let target = await AppSettings.translationTargetLanguage

        self.logger.info("Requesting language pack download for \(source) → \(target)")

        // Try to download target language (most likely missing)
        try await OnDeviceTranslationService.shared.requestLanguageDownload(target)
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
    func clearExpiredCache(modelContext: ModelContext) async {
        let now = Date()

        let fetchDescriptor = FetchDescriptor<CachedTranslation>(
            predicate: #Predicate<CachedTranslation> { translation in
                translation.expiresAt < now
            }
        )

        do {
            let expiredTranslations = try modelContext.fetch(fetchDescriptor)

            for translation in expiredTranslations {
                modelContext.delete(translation)
            }

            if !expiredTranslations.isEmpty {
                try modelContext.save()
                self.logger.info("Cleared \(expiredTranslations.count) expired translations from cache")
            }
        } catch {
            self.logger.error("Failed to clear expired cache: \(error.localizedDescription)")
            await Analytics.trackError("quick_translation_cache_cleanup_failed", error: error)
        }
    }

    // MARK: - Private Helpers

    /// Find valid cached translation for word and language pair
    ///
    /// **Returns:** `nil` if no valid cache entry exists
    private func findCachedTranslation(
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
            self.logger.error("Failed to fetch cached translation: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save translation to cache with 30-day expiration
    private func saveToCache(
        word: String,
        translatedText: String,
        source: String,
        target: String,
        modelContext: ModelContext
    ) async {
        do {
            let cachedTranslation = try CachedTranslation(
                sourceWord: word,
                translatedText: translatedText,
                sourceLanguage: source,
                targetLanguage: target,
                ttlDays: 30
            )

            modelContext.insert(cachedTranslation)
            try modelContext.save()

            self.logger.info("Saved translation to cache: '\(word)' → '\(translatedText)'")
        } catch {
            self.logger.error("Failed to save translation to cache: \(error.localizedDescription)")
            await Analytics.trackError("quick_translation_cache_save_failed", error: error)
        }
    }
}
