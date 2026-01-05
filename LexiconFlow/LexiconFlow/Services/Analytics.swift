//
//  Analytics.swift
//  LexiconFlow
//
//  Crash and error analytics integration
//  Provides interface for tracking events and errors
//
//  **Provider Pattern**: Switches between console (DEBUG) and Firebase (RELEASE)
//  **Firebase Integration**: Requires Firebase SDK via SPM (see README.md)
//

import Foundation
import OSLog

// Firebase imports - conditional compilation
// These will only be compiled if the SDKs are available via SPM
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

/// Analytics and crash reporting service
///
/// **Architecture**: Provider pattern that switches between console (DEBUG)
/// and Firebase Analytics + Crashlytics (RELEASE) based on build configuration.
///
/// **Development**: Console-based logging for debugging.
/// **Production**: Firebase Analytics for events, Crashlytics for crashes.
enum Analytics {

    /// Logger for console analytics output
    private static let logger = Logger(subsystem: "com.lexiconflow.analytics", category: "Analytics")

    /// Current analytics provider (determined by build configuration)
    #if DEBUG
    private static let provider: AnalyticsProvider = .console
    #else
    private static let provider: AnalyticsProvider = .firebase
    #endif

    // MARK: - Event Tracking

    /// Track a user event or action
    ///
    /// - Parameters:
    ///   - name: Event name (e.g., "card_reviewed", "deck_created")
    ///   - metadata: Optional key-value pairs for additional context
    static func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        switch provider {
        case .console:
            consoleTrackEvent(name, metadata: metadata)
        case .firebase:
            firebaseTrackEvent(name, metadata: metadata)
        }
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
        switch provider {
        case .console:
            consoleTrackError(name, error: error, metadata: metadata)
        case .firebase:
            firebaseTrackError(name, error: error, metadata: metadata)
        }
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
        switch provider {
        case .console:
            consoleTrackIssue(name, message: message, metadata: metadata)
        case .firebase:
            firebaseTrackIssue(name, message: message, metadata: metadata)
        }
    }

    // MARK: - User Identification

    /// Set the current user ID for analytics
    ///
    /// - Parameter userId: Unique user identifier
    static func setUserId(_ userId: String) {
        switch provider {
        case .console:
            consoleSetUserId(userId)
        case .firebase:
            firebaseSetUserId(userId)
        }
    }

    /// Set user properties for segmentation
    ///
    /// - Parameter properties: Dictionary of user properties
    static func setUserProperties(_ properties: [String: Any]) {
        switch provider {
        case .console:
            consoleSetUserProperties(properties)
        case .firebase:
            firebaseSetUserProperties(properties)
        }
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
        switch provider {
        case .console:
            consoleTrackPerformance(name, duration: duration, metadata: metadata)
        case .firebase:
            firebaseTrackPerformance(name, duration: duration, metadata: metadata)
        }
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

// MARK: - Analytics Provider

/// Analytics provider options
///
/// **console**: OSLog-based logging for development and testing
/// **firebase**: Firebase Analytics + Crashlytics for production
private enum AnalyticsProvider {
    case console
    case firebase
}

// MARK: - Console Implementation

private extension Analytics {

    static func consoleTrackEvent(_ name: String, metadata: [String: String]) {
        let logMessage: String
        if metadata.isEmpty {
            logMessage = "Event: \(name)"
        } else {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage = "Event: \(name) [\(metadataString)]"
        }
        logger.info("\(logMessage)")
    }

    static func consoleTrackError(
        _ name: String,
        error: Error,
        metadata: [String: String]
    ) {
        let errorMessage = error.localizedDescription
        var fullMetadata = metadata
        fullMetadata["error_description"] = errorMessage
        fullMetadata["error_type"] = String(describing: type(of: error))

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.error("❌ Error: \(name) [\(metadataString)]")
    }

    static func consoleTrackIssue(
        _ name: String,
        message: String,
        metadata: [String: String]
    ) {
        var fullMetadata = metadata
        fullMetadata["message"] = message

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.warning("⚠️ Issue: \(name) [\(metadataString)]")
    }

    static func consoleSetUserId(_ userId: String) {
        logger.info("Set User ID: \(userId)")
    }

    static func consoleSetUserProperties(_ properties: [String: Any]) {
        let propertyString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("Set User Properties: [\(propertyString)]")
    }

    static func consoleTrackPerformance(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]
    ) {
        var fullMetadata = metadata
        fullMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("⏱ Performance: \(name) [\(metadataString)]")
    }
}

// MARK: - Firebase Implementation

private extension Analytics {

    static func firebaseTrackEvent(_ name: String, metadata: [String: String]) {
        #if canImport(FirebaseAnalytics)
        // Convert String metadata to [String: Any] for Firebase
        // Use fully qualified name to avoid collision with our Analytics enum
        let firebaseMetadata: [String: Any] = metadata.reduce(into: [:]) { $0[$1.key] = $1.value }
        FirebaseAnalytics.Analytics.logEvent(name, parameters: firebaseMetadata)
        #else
        // Fallback to console if Firebase SDK not available
        logger.warning("⚠️ Firebase Analytics not available - using console fallback")
        consoleTrackEvent(name, metadata: metadata)
        #endif
    }

    static func firebaseTrackError(
        _ name: String,
        error: Error,
        metadata: [String: String]
    ) {
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()

        // Set custom keys for additional context
        for (key, value) in metadata {
            crashlytics.setCustomValue(value, forKey: key)
        }

        // Record the error (non-fatal)
        crashlytics.record(error: error)

        // Also log to Analytics
        #if canImport(FirebaseAnalytics)
        var errorMetadata = metadata
        errorMetadata["error_name"] = name
        errorMetadata["error_description"] = error.localizedDescription
        // Use fully qualified name to avoid collision
        FirebaseAnalytics.Analytics.logEvent("error_logged", parameters: errorMetadata)
        #endif
        #else
        logger.warning("⚠️ Firebase Crashlytics not available - using console fallback")
        consoleTrackError(name, error: error, metadata: metadata)
        #endif
    }

    static func firebaseTrackIssue(
        _ name: String,
        message: String,
        metadata: [String: String]
    ) {
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()

        // Set custom keys
        for (key, value) in metadata {
            crashlytics.setCustomValue(value, forKey: key)
        }

        // Record as non-fatal error
        let nsError = NSError(domain: "com.lexiconflow.issues", code: 0, userInfo: [
            NSLocalizedDescriptionKey: message,
            "issue_name": name
        ])
        crashlytics.record(error: nsError)
        #else
        logger.warning("⚠️ Firebase Crashlytics not available - using console fallback")
        consoleTrackIssue(name, message: message, metadata: metadata)
        #endif
    }

    static func firebaseSetUserId(_ userId: String) {
        #if canImport(FirebaseAnalytics)
        // Use fully qualified name to avoid collision
        FirebaseAnalytics.Analytics.setUserID(userId)
        #endif

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif

        #if !canImport(FirebaseAnalytics) && !canImport(FirebaseCrashlytics)
        logger.warning("⚠️ Firebase not available - using console fallback")
        consoleSetUserId(userId)
        #endif
    }

    static func firebaseSetUserProperties(_ properties: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        for (key, value) in properties {
            if let stringValue = value as? String {
                // Use fully qualified name to avoid collision
                FirebaseAnalytics.Analytics.setUserProperty(stringValue, forName: key)
            }
        }
        #else
        logger.warning("⚠️ Firebase Analytics not available - using console fallback")
        consoleSetUserProperties(properties)
        #endif
    }

    static func firebaseTrackPerformance(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]
    ) {
        #if canImport(FirebasePerformance)
        let trace = Performance.startTrace(name: name)
        trace?.stop()

        // Log to Analytics as well
        #if canImport(FirebaseAnalytics)
        var perfMetadata = metadata
        perfMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)
        // Use fully qualified name to avoid collision
        FirebaseAnalytics.Analytics.logEvent("performance_metric", parameters: perfMetadata)
        #endif
        #else
        logger.warning("⚠️ Firebase Performance not available - using console fallback")
        consoleTrackPerformance(name, duration: duration, metadata: metadata)
        #endif
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
