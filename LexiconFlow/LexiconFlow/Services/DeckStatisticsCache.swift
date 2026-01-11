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
    private let ttl: TimeInterval = 30.0

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
            logger.debug("Cache miss: no timestamp (cache empty)")
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)
        guard age < ttl else {
            logger.debug("Cache miss: TTL exceeded (\(age)s > \(ttl)s)")
            return nil
        }

        let stats = cache[deckID]
        if stats != nil {
            logger.debug("Cache hit: deck \(deckID)")
        } else {
            logger.debug("Cache miss: deck \(deckID) not in cache")
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
        cache[deckID] = stats
        timestamp = Date()
        logger.debug("Cache set: deck \(deckID) (due: \(stats.due), new: \(stats.new), total: \(stats.total))")
    }

    /// Store multiple statistics in cache in a single operation.
    ///
    /// Updates the global timestamp to now, marking all cached entries as fresh.
    /// More efficient than calling `set(_:for:)` multiple times.
    ///
    /// - Parameter statistics: Dictionary mapping deck IDs to their statistics
    func setBatch(_ statistics: [UUID: DeckStatistics]) {
        cache.merge(statistics) { _, new in new }
        timestamp = Date()
        logger.debug("Cache batch: \(statistics.count) decks")
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
            cache.removeValue(forKey: deckID)
            logger.debug("Cache invalidated: deck \(deckID)")
        } else {
            cache.removeAll()
            timestamp = nil
            logger.debug("Cache cleared: all decks")
        }
    }

    /// Check if cache entry exists and is still valid for a specific deck.
    ///
    /// - Parameter deckID: The deck's UUID to check
    /// - Returns: `true` if cache has a valid entry for this deck
    func isValid(deckID: UUID) -> Bool {
        get(deckID: deckID) != nil
    }

    /// Get the age of the cache in seconds.
    ///
    /// - Returns: Age in seconds, or `nil` if cache is empty
    func age() -> TimeInterval? {
        guard let timestamp else { return nil }
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Testing Support

#if DEBUG
    extension DeckStatisticsCache {
        /// Clear all cache entries without logging (for testing).
        func clearForTesting() {
            cache.removeAll()
            timestamp = nil
        }

        /// Set a custom TTL for testing purposes.
        func setTTLForTesting(_: TimeInterval) {
            // Note: This would require making ttl mutable, omitted for thread safety
        }

        /// Get current cache size for testing.
        var size: Int {
            cache.count
        }
    }
#endif
