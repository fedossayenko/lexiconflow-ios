//
//  DeckStatisticsCache.swift
//  LexiconFlow
//
//  Cache service for deck statistics to reduce expensive database queries.
//  Provides 30-second TTL to balance freshness with performance.
//

import Foundation
import OSLog

/// Cache service for deck statistics with TTL-based invalidation.
///
/// **Performance**: Reduces expensive database queries from O(n) full table scans
/// to O(1) cache lookups. Critical for fixing tab switching lag and "gesture timeout" errors.
///
/// **Usage**:
/// ```swift
/// // Check cache first
/// if let cached = DeckStatisticsCache.shared.get(deckID: deck.id) {
///     return cached
/// }
///
/// // Fetch from database
/// let stats = fetchFromDatabase()
///
/// // Store in cache
/// DeckStatisticsCache.shared.set(stats, for: deck.id)
/// ```
///
/// **Invalidation**: Call `invalidate()` after:
/// - Processing a card review
/// - Importing new cards
/// - Deleting a deck
/// - Editing deck contents
@MainActor
final class DeckStatisticsCache: Sendable {
    /// Shared singleton instance for app-wide cache access
    static let shared = DeckStatisticsCache()

    private let logger = Logger(subsystem: "com.lexiconflow.cache", category: "DeckStatisticsCache")

    /// Cache storage mapping deck ID to statistics
    private var cache: [UUID: DeckStatistics] = [:]

    /// Timestamp of last cache update (nil = cache is empty/invalid)
    private var timestamp: Date?

    /// Time-to-live for cache entries in seconds
    ///
    /// **Trade-off**: 30 seconds balances freshness (for due card updates) with
    /// performance (avoiding repeated queries during rapid tab/mode switching).
    private var ttl: TimeInterval = 30.0

    private init() {}

    // MARK: - Public API

    /// Retrieve cached statistics for a specific deck.
    ///
    /// Returns `nil` if:
    /// - No entry exists for this deck ID
    /// - Cache has expired (TTL exceeded)
    /// - Cache has been invalidated
    ///
    /// - Parameter deckID: The deck's UUID to look up
    /// - Returns: Cached `DeckStatistics` if valid, `nil` otherwise
    func get(deckID: UUID) -> DeckStatistics? {
        guard let timestamp else {
            self.logger.debug("Cache miss: no timestamp (cache empty)")
            Analytics.trackEvent("deck_statistics_cache_miss", metadata: ["reason": "empty"])
            return nil
        }

        // Use mock time in tests if provided
        let now = Self.currentTime()
        let age = now.timeIntervalSince(timestamp)
        guard age < self.ttl else {
            self.logger.debug("Cache miss: TTL exceeded (\(age)s > \(self.ttl)s)")
            Analytics.trackEvent("deck_statistics_cache_miss", metadata: [
                "reason": "ttl_expired",
                "age_seconds": String(format: "%.1f", age)
            ])
            return nil
        }

        let stats = self.cache[deckID]
        if stats != nil {
            self.logger.debug("Cache hit: deck \(deckID)")
            Analytics.trackEvent("deck_statistics_cache_hit", metadata: [
                "deck_id": deckID.uuidString,
                "age_seconds": String(format: "%.1f", age)
            ])
        } else {
            self.logger.debug("Cache miss: deck \(deckID) not in cache")
            Analytics.trackEvent("deck_statistics_cache_miss", metadata: [
                "reason": "not_in_cache",
                "deck_id": deckID.uuidString
            ])
        }
        return stats
    }

    /// Store statistics in cache for a specific deck.
    ///
    /// Updates the global timestamp to now, marking all cached entries as fresh.
    ///
    /// - Parameters:
    ///   - stats: The statistics to cache
    ///   - deckID: The deck's UUID to associate with these statistics
    func set(_ stats: DeckStatistics, for deckID: UUID) {
        self.cache[deckID] = stats
        self.timestamp = Self.currentTime()
        self.logger.debug("Cache set: deck \(deckID) (due: \(stats.due), new: \(stats.new), total: \(stats.total))")
        Analytics.trackEvent("deck_statistics_cache_set", metadata: [
            "deck_id": deckID.uuidString,
            "due": String(stats.due),
            "new": String(stats.new),
            "total": String(stats.total)
        ])
    }

    /// Store multiple statistics in cache in a single operation.
    ///
    /// Updates the global timestamp to now, marking all cached entries as fresh.
    /// More efficient than calling `set(_:for:)` multiple times.
    ///
    /// - Parameter statistics: Dictionary mapping deck IDs to their statistics
    func setBatch(_ statistics: [UUID: DeckStatistics]) {
        self.cache.merge(statistics) { _, new in new }
        self.timestamp = Self.currentTime()
        self.logger.debug("Cache batch: \(statistics.count) decks")
    }

    /// Invalidate cache for a specific deck or entire cache.
    ///
    /// Call this after:
    /// - Processing a card review (invalidate specific deck)
    /// - Importing new cards (invalidate all)
    /// - Deleting a deck (invalidate specific deck)
    /// - Editing deck contents (invalidate specific deck)
    ///
    /// - Parameter deckID: Optional deck ID to invalidate. If `nil`, clears entire cache.
    func invalidate(deckID: UUID? = nil) {
        if let deckID {
            self.cache.removeValue(forKey: deckID)
            self.logger.debug("Cache invalidated: deck \(deckID)")
            Analytics.trackEvent("deck_statistics_cache_invalidate", metadata: [
                "scope": "single_deck",
                "deck_id": deckID.uuidString
            ])
        } else {
            let count = self.cache.count
            self.cache.removeAll()
            self.timestamp = nil
            self.logger.debug("Cache cleared: all decks")
            Analytics.trackEvent("deck_statistics_cache_invalidate", metadata: [
                "scope": "all_decks",
                "previous_count": String(count)
            ])
        }
    }

    /// Check if cache entry exists and is still valid for a specific deck.
    ///
    /// - Parameter deckID: The deck's UUID to check
    /// - Returns: `true` if cache has a valid entry for this deck
    func isValid(deckID: UUID) -> Bool {
        self.get(deckID: deckID) != nil
    }

    /// Get the age of the cache in seconds.
    ///
    /// - Returns: Age in seconds, or `nil` if cache is empty
    func age() -> TimeInterval? {
        guard let timestamp else { return nil }
        // Use mock time in tests if provided
        let now = Self.currentTime()
        return now.timeIntervalSince(timestamp)
    }
}

// MARK: - Testing Support

#if DEBUG
    extension DeckStatisticsCache {
        /// Mock time provider for deterministic TTL testing.
        ///
        /// **Usage**:
        /// ```swift
        /// var mockDate = Date()
        /// DeckStatisticsCache.setTimeProviderForTesting { mockDate }
        ///
        /// // Advance time to test TTL expiration
        /// mockDate = mockDate.addingTimeInterval(31)
        /// ```
        private static var timeProvider: (() -> Date)?

        /// Set a custom time provider for testing.
        ///
        /// **WARNING**: Only use in tests. This affects the singleton instance globally.
        /// Always call `resetTimeProvider()` in test teardown.
        ///
        /// - Parameter provider: Closure that returns the current mock date
        static func setTimeProviderForTesting(_ provider: @escaping () -> Date) {
            self.timeProvider = provider
        }

        /// Reset the time provider to use system time (for test cleanup).
        static func resetTimeProvider() {
            self.timeProvider = nil
        }

        /// Get the current time, using mock provider if set.
        ///
        /// - Returns: Current time from mock provider (if set) or system time
        static func currentTime() -> Date {
            self.timeProvider?() ?? Date()
        }

        /// Clear all cache entries without logging (for testing).
        func clearForTesting() {
            self.cache.removeAll()
            self.timestamp = nil
        }

        /// Set a custom TTL for testing purposes.
        ///
        /// **WARNING**: Only use in tests. Production code should use default 30s TTL.
        /// Making `ttl` mutable is safe because `@MainActor` ensures thread safety.
        ///
        /// - Parameter ttl: Custom time-to-live in seconds
        func setTTLForTesting(_ ttl: TimeInterval) {
            self.ttl = ttl
            self.logger.debug("TTL set to \(ttl)s for testing")
        }

        /// Reset TTL to default value (for test cleanup).
        func resetTTL() {
            self.ttl = 30.0
            self.logger.debug("TTL reset to 30s (default)")
        }

        /// Get current cache size for testing.
        var size: Int {
            self.cache.count
        }
    }
#endif
