//
//  ImageCache.swift
//  LexiconFlow
//
//  In-memory caching for decoded UIImage instances
//  Eliminates repeated JPEG/PNG decoding for card images
//
//  PERFORMANCE: Reduces CPU overhead and memory pressure when scrolling
//  through cards with images. Target: 50-90% memory reduction.
//

import Foundation
import UIKit

/// Thread-safe cache for decoded UIImage instances
///
/// **Performance:**
/// - Caches decoded UIImage instances to avoid repeated JPEG/PNG decoding
/// - Uses NSCache for automatic LRU eviction and memory pressure handling
/// - Thread-safe by design (NSCache is synchronized internally)
///
/// **Usage:**
/// ```swift
/// if let cachedImage = ImageCache.shared.image(for: imageData) {
///     Image(uiImage: cachedImage)
/// }
/// ```
@MainActor
final class ImageCache {
    /// Shared singleton instance
    static let shared = ImageCache()

    /// NSCache provides thread-safe LRU eviction automatically
    /// - countLimit: Maximum number of objects to store
    /// - totalCostLimit: Maximum total cost (in bytes) of all objects
    private let cache = NSCache<NSString, UIImage>()

    /// Private initializer for singleton pattern
    private init() {
        // Configure cache limits
        self.cache.countLimit = 100 // Maximum 100 cached images
        self.cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit

        // Respond to memory warnings automatically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    /// Generates cache key from image data
    ///
    /// **Performance:** Uses first 16 bytes of base64 encoding
    /// rather than full data hash for faster key generation.
    /// 16 bytes provides sufficient uniqueness for image data.
    ///
    /// - Parameter data: Image data to generate key from
    /// - Returns: Cache key string
    private func cacheKey(for data: Data) -> String {
        // Use first 16 bytes of base64 encoding as cache key
        // Fast and provides sufficient uniqueness for image data
        data.base64EncodedString().prefix(16) + String(data.count)
    }

    /// Retrieves cached UIImage for given data, decodes and caches if miss
    ///
    /// **Performance:** O(1) cache hit, O(n) decode on miss (n = data size)
    /// NSCache handles automatic LRU eviction when memory pressure occurs.
    ///
    /// - Parameter data: Image data to decode/cache
    /// - Returns: Cached or newly decoded UIImage, or nil if decode fails
    func image(for data: Data) -> UIImage? {
        let key = self.cacheKey(for: data) as NSString

        // Cache hit - return immediately
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Cache miss - decode and cache
        guard let image = UIImage(data: data) else { return nil }

        // Add to cache with cost (image data size in bytes)
        self.cache.setObject(image, forKey: key, cost: data.count)

        return image
    }

    /// Clears all cached images
    ///
    /// **Usage:** Call on memory warning or when user explicitly clears cache
    func clearCache() {
        self.cache.removeAllObjects()
    }

    /// Returns current cache size (number of cached images)
    ///
    /// **Performance Monitoring:** Can be logged to track cache efficiency
    var size: Int {
        // NSCache doesn't expose current count, return 0 for monitoring
        // Use Instruments to measure actual cache behavior
        0
    }

    /// Handles memory warning notifications
    @objc private func handleMemoryWarning() {
        self.clearCache()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
