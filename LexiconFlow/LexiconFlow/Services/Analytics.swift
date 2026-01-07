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
/// **Production**: Provider integration tracked in project roadmap.
enum Analytics {

    /// Logger for analytics output
    private static let logger = Logger(subsystem: "com.lexiconflow.analytics", category: "Analytics")

    // MARK: - Event Tracking

    /// Track a user event or action
    ///
    /// **Why async**: Analytics tracking may involve network calls to remote services.
    /// Making this async allows callers to await without blocking UI.
    ///
    /// - Parameters:
    ///   - name: Event name (e.g., "card_reviewed", "deck_created")
    ///   - metadata: Optional key-value pairs for additional context
    static func trackEvent(_ name: String, metadata: [String: String] = [:]) async {
        let logMessage: String
        if metadata.isEmpty {
            logMessage = "Event: \(name)"
        } else {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage = "Event: \(name) [\(metadataString)]"
        }

        logger.info("\(logMessage)")

        // Provider integration: FirebaseAnalytics.logEvent(), Sentry.capture(), etc.
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
    ) async {
        let errorMessage = error.localizedDescription
        var fullMetadata = metadata
        fullMetadata["error_description"] = errorMessage
        fullMetadata["error_type"] = String(describing: type(of: error))

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.error("❌ Error: \(name) [\(metadataString)]")

        // Provider integration: Crashlytics.crashlytics().record(), SentrySDK.capture(error:)
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
    ) async {
        var fullMetadata = metadata
        fullMetadata["message"] = message

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.warning("⚠️ Issue: \(name) [\(metadataString)]")

        // Provider integration: SentrySDK.capture(message:)
    }

    // MARK: - User Identification

    /// Set the current user ID for analytics
    ///
    /// **Why async**: User identification may involve network calls to remote services.
    ///
    /// - Parameter userId: Unique user identifier
    static func setUserId(_ userId: String) async {
        logger.info("Set User ID: \(userId)")
        // Provider integration: Analytics.setUserID(), SentrySDK.setUser()
    }

    /// Set user properties for segmentation
    ///
    /// **Why async**: Setting properties may involve network calls to remote services.
    ///
    /// - Parameter properties: Dictionary of user properties
    static func setUserProperties(_ properties: [String: Any]) async {
        let propertyString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("Set User Properties: [\(propertyString)]")
        // Provider integration: Analytics.setUserProperties(), SentrySDK.setContext()
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
    ) async {
        var fullMetadata = metadata
        fullMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("⏱ Performance: \(name) [\(metadataString)]")

        // Provider integration: FirebasePerformance.startTrace(), SentrySDK.startTransaction()
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

        await trackPerformance(name, duration: duration)

        return result
    }
}
