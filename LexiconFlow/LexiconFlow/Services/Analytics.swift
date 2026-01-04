//
//  Analytics.swift
//  LexiconFlow
//
//  Crash and error analytics integration
//  Provides interface for tracking events and errors
//
//  Currently: Console-based placeholder
//  TODO: Integrate with Firebase Crashlytics, Sentry, or similar
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
enum Analytics {

    /// Logger for analytics output
    private static let logger = Logger(subsystem: "com.lexiconflow.analytics", category: "Analytics")

    // MARK: - Event Tracking

    /// Track a user event or action
    ///
    /// - Parameters:
    ///   - name: Event name (e.g., "card_reviewed", "deck_created")
    ///   - metadata: Optional key-value pairs for additional context
    static func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        let logMessage: String
        if metadata.isEmpty {
            logMessage = "Event: \(name)"
        } else {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage = "Event: \(name) [\(metadataString)]"
        }

        logger.info("\(logMessage)")

        // TODO: Send to analytics provider
        // FirebaseAnalytics.Analytics.logEvent(name, parameters: metadata)
    }

    /// Track an error or exception
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
        let errorMessage = error.localizedDescription
        var fullMetadata = metadata
        fullMetadata["error_description"] = errorMessage
        fullMetadata["error_type"] = String(describing: type(of: error))

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.error("❌ Error: \(name) [\(metadataString)]")

        // TODO: Send to crash reporting provider
        // Crashlytics.crashlytics().record(error: error)
        // SentrySDK.capture(error: error)
    }

    /// Track a non-fatal issue
    ///
    /// Use this for issues that don't crash the app but are worth monitoring.
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
        var fullMetadata = metadata
        fullMetadata["message"] = message

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.warning("⚠️ Issue: \(name) [\(metadataString)]")

        // TODO: Send to error tracking provider
        // SentrySDK.capture(message: message)
    }

    // MARK: - User Identification

    /// Set the current user ID for analytics
    ///
    /// - Parameter userId: Unique user identifier
    static func setUserId(_ userId: String) {
        logger.info("Set User ID: \(userId)")
        // TODO: Set user ID in analytics provider
        // Analytics.setUserID(userId)
    }

    /// Set user properties for segmentation
    ///
    /// - Parameter properties: Dictionary of user properties
    static func setUserProperties(_ properties: [String: Any]) {
        let propertyString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("Set User Properties: [\(propertyString)]")
        // TODO: Set user properties in analytics provider
    }

    // MARK: - Performance Tracking

    /// Track performance metrics
    ///
    /// - Parameters:
    ///   - name: Metric name (e.g., "review_latency", "query_time")
    ///   - duration: Duration in milliseconds
    ///   - metadata: Optional additional context
    static func trackPerformance(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        var fullMetadata = metadata
        fullMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("⏱ Performance: \(name) [\(metadataString)]")

        // TODO: Send to performance monitoring
        // FirebasePerformance.getInstance().startTrace(name)
    }

    /// Measure and track a block of code's execution time
    ///
    /// - Parameters:
    ///   - name: Metric name
    ///   - block: Code to measure
    /// - Returns: The result of the block
    static func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)

        trackPerformance(name, duration: duration)

        return result
    }
}

// MARK: - Performance Measurement Utility

/// Utility for measuring code execution time
///
/// **Usage**:
/// ```swift
/// // Standard usage (logs performance, returns result)
/// let result = try await Benchmark.measure("fsrs_process") {
///     try await FSRSWrapper.shared.processReview(...)
/// }
///
/// // Testing usage (returns duration for assertions)
/// let duration = try await Benchmark.measureTime("fsrs_process") {
///     try await FSRSWrapper.shared.processReview(...)
/// }
/// #expect(duration < 0.01)
/// ```
enum Benchmark {
    /// Measure async block execution time
    ///
    /// - Parameters:
    ///   - name: Benchmark name
    ///   - operation: Async operation to measure
    /// - Returns: Result of the operation
    static func measure<T>(
        _ name: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)

        Analytics.trackPerformance(name, duration: duration)

        return result
    }

    /// Measure synchronous block execution time
    ///
    /// - Parameters:
    ///   - name: Benchmark name
    ///   - operation: Operation to measure
    /// - Returns: Result of the operation
    static func measure<T>(
        _ name: String,
        operation: () throws -> T
    ) rethrows -> T {
        let start = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(start)

        Analytics.trackPerformance(name, duration: duration)

        return result
    }

    /// Measure async block and return duration for testing
    ///
    /// - Parameters:
    ///   - name: Benchmark name
    ///   - operation: Async operation to measure
    /// - Returns: Duration in seconds
    static func measureTime<T>(
        _ name: String,
        operation: () async throws -> T
    ) async rethrows -> TimeInterval {
        let start = Date()
        _ = try await operation()
        let duration = Date().timeIntervalSince(start)

        Analytics.trackPerformance(name, duration: duration)

        return duration
    }

    /// Measure synchronous block and return duration for testing
    ///
    /// - Parameters:
    ///   - name: Benchmark name
    ///   - operation: Operation to measure
    /// - Returns: Duration in seconds
    static func measureTime<T>(
        _ name: String,
        operation: () throws -> T
    ) rethrows -> TimeInterval {
        let start = Date()
        _ = try operation()
        let duration = Date().timeIntervalSince(start)

        Analytics.trackPerformance(name, duration: duration)

        return duration
    }
}
