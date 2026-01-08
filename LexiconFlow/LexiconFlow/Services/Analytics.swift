//
//  Analytics.swift
//  LexiconFlow
//
//  Crash and error analytics integration
//  Provides interface for tracking events and errors
//
//  Current Implementation: Console-based logging for development
//  Production Integration: Tracked separately (see project roadmap)
//

import Foundation
import OSLog

/// Analytics and crash reporting service
///
/// **Architecture**: Provides a unified interface for analytics that can
/// be swapped with different providers (Firebase, Sentry, custom backend).
///
/// **Current Implementation**: Console-based logging for development.
/// **Production**: Should integrate Firebase Crashlytics or Sentry.
///
/// **Testing**: Supports dependency injection via `setBackend()` for unit tests.
enum Analytics {
    /// Logger for analytics output
    private static let logger = Logger(subsystem: "com.lexiconflow.analytics", category: "Analytics")

    /// Current analytics backend (defaults to production implementation)
    private static var backend: AnalyticsBackend = ProductionAnalyticsBackend()

    /// Set a custom analytics backend (for testing)
    ///
    /// - Parameter backend: The analytics backend to use
    /// - Note: This should only be called in tests. Production code uses the default.
    static func setBackend(_ backend: AnalyticsBackend) {
        Self.backend = backend
    }

    /// Reset to the production backend (for test cleanup)
    static func resetToProductionBackend() {
        backend = ProductionAnalyticsBackend()
    }

    // MARK: - Event Tracking

    /// Track a user event or action
    ///
    /// **Why async**: Analytics tracking may involve network calls to remote services.
    /// Making this async allows callers to await without blocking UI.
    ///
    /// - Parameters:
    ///   - name: Event name (e.g., "card_reviewed", "deck_created")
    ///   - metadata: Optional key-value pairs for additional context
    static func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        backend.trackEvent(name, metadata: metadata)
    }

    /// Track an error or exception
    ///
    /// **Why async**: Error tracking may involve network calls to remote services.
    /// Making this async allows callers to await without blocking UI.
    ///
    /// - Parameters:
    ///   - name: Error name or location (e.g., "save_review_failed")
    ///   - error: The Swift Error
    ///   - metadata: Optional additional context
    static func trackError(
        _ name: String,
        error: Error,
        metadata: [String: String] = [:]
    ) {
        backend.trackError(name, error: error, metadata: metadata)
    }

    /// Track a non-fatal issue
    ///
    /// Use this for issues that don't crash the app but are worth monitoring.
    ///
    /// **Why async**: Issue tracking may involve network calls to remote services.
    ///
    /// - Parameters:
    ///   - name: Issue name
    ///   - message: Description of the issue
    ///   - metadata: Optional additional context
    static func trackIssue(
        _ name: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        backend.trackIssue(name, message: message, metadata: metadata)
    }

    // MARK: - User Identification

    /// Set the current user ID for analytics
    ///
    /// **Why async**: User identification may involve network calls to remote services.
    ///
    /// - Parameter userId: Unique user identifier
    static func setUserId(_ userId: String) {
        backend.setUserId(userId)
    }

    /// Set user properties for segmentation
    ///
    /// **Why async**: Setting properties may involve network calls to remote services.
    ///
    /// - Parameter properties: Dictionary of user properties
    static func setUserProperties(_ properties: [String: Any]) {
        backend.setUserProperties(properties)
    }

    // MARK: - Performance Tracking

    /// Track performance metrics
    ///
    /// **Why async**: Performance tracking may involve network calls to remote services.
    ///
    /// - Parameters:
    ///   - name: Metric name (e.g., "review_latency", "query_time")
    ///   - duration: Duration in seconds
    ///   - metadata: Optional additional context
    static func trackPerformance(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        backend.trackPerformance(name, duration: duration, metadata: metadata)
    }

    /// Measure and track a block of code's execution time
    ///
    /// **Why async**: Returns async function to support async blocks and await performance tracking.
    ///
    /// - Parameters:
    ///   - name: Metric name
    ///   - block: Code to measure (can be async)
    /// - Returns: The result of the block
    static func measure<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)

        trackPerformance(name, duration: duration)

        return result
    }
}
