//
//  AnalyticsBackend.swift
//  LexiconFlow
//
//  Protocol for analytics backend implementation
//  Enables dependency injection for testing
//

import Foundation
import OSLog

/// Protocol defining the analytics backend interface
///
/// This protocol allows Analytics to be tested by providing a mock implementation
/// that records calls instead of sending them to a real analytics provider.
protocol AnalyticsBackend {
    /// Track a user event or action
    func trackEvent(_ name: String, metadata: [String: String])

    /// Track an error or exception
    func trackError(_ name: String, error: Error, metadata: [String: String])

    /// Track a non-fatal issue
    func trackIssue(_ name: String, message: String, metadata: [String: String])

    /// Set the current user ID for analytics
    func setUserId(_ userId: String)

    /// Set user properties for segmentation
    func setUserProperties(_ properties: [String: Any])

    /// Track performance metrics
    func trackPerformance(_ name: String, duration: TimeInterval, metadata: [String: String])
}

/// Production implementation using OSLog
final class ProductionAnalyticsBackend: AnalyticsBackend {
    private let logger = Logger(subsystem: "com.lexiconflow.analytics", category: "Analytics")

    func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        let logMessage: String
        if metadata.isEmpty {
            logMessage = "Event: \(name)"
        } else {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage = "Event: \(name) [\(metadataString)]"
        }
        logger.info("\(logMessage)")
    }

    func trackError(_ name: String, error: Error, metadata: [String: String] = [:]) {
        let errorMessage = error.localizedDescription
        var fullMetadata = metadata
        fullMetadata["error_description"] = errorMessage
        fullMetadata["error_type"] = String(describing: type(of: error))

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.error("❌ Error: \(name) [\(metadataString)]")
    }

    func trackIssue(_ name: String, message: String, metadata: [String: String] = [:]) {
        var fullMetadata = metadata
        fullMetadata["message"] = message

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.warning("⚠️ Issue: \(name) [\(metadataString)]")
    }

    func setUserId(_ userId: String) {
        logger.info("Set User ID: \(userId)")
    }

    func setUserProperties(_ properties: [String: Any]) {
        let propertyString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("Set User Properties: [\(propertyString)]")
    }

    func trackPerformance(_ name: String, duration: TimeInterval, metadata: [String: String] = [:]) {
        var fullMetadata = metadata
        fullMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)

        let metadataString = fullMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("⏱ Performance: \(name) [\(metadataString)]")
    }
}

/// Mock implementation for testing
///
/// Records all analytics calls for verification in tests.
final class MockAnalyticsBackend: AnalyticsBackend, @unchecked Sendable {
    /// Thread-safe storage for recorded events
    private var _events: [AnalyticsEvent] = []
    private let lock = NSLock()

    /// All recorded analytics events
    var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        record(AnalyticsEvent.event(name, metadata))
    }

    func trackError(_ name: String, error: Error, metadata: [String: String] = [:]) {
        var fullMetadata = metadata
        fullMetadata["error_description"] = error.localizedDescription
        fullMetadata["error_type"] = String(describing: type(of: error))
        record(AnalyticsEvent.error(name, fullMetadata))
    }

    func trackIssue(_ name: String, message: String, metadata: [String: String] = [:]) {
        var fullMetadata = metadata
        fullMetadata["message"] = message
        record(AnalyticsEvent.issue(name, fullMetadata))
    }

    func setUserId(_ userId: String) {
        record(AnalyticsEvent.setUserId(userId))
    }

    func setUserProperties(_ properties: [String: Any]) {
        record(AnalyticsEvent.setUserProperties(properties))
    }

    func trackPerformance(_ name: String, duration: TimeInterval, metadata: [String: String] = [:]) {
        var fullMetadata = metadata
        fullMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)
        record(AnalyticsEvent.performance(name, duration, fullMetadata))
    }

    /// Clear all recorded events
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        _events.removeAll()
    }

    private func record(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        _events.append(event)
    }

    // MARK: - Verification Helpers

    /// Check if a specific event was recorded
    func didTrackEvent(_ name: String) -> Bool {
        events.contains { event in
            if case let .event(eventName, _) = event {
                return eventName == name
            }
            return false
        }
    }

    /// Check if a specific error was recorded
    func didTrackError(_ name: String) -> Bool {
        events.contains { event in
            if case let .error(errorName, _) = event {
                return errorName == name
            }
            return false
        }
    }

    /// Get count of recorded events
    func eventCount(for name: String) -> Int {
        events.count(where: { event in
            if case let .event(eventName, _) = event {
                return eventName == name
            }
            return false
        })
    }
}

/// Recorded analytics event types
enum AnalyticsEvent: Equatable, Sendable {
    case event(String, [String: String])
    case error(String, [String: String])
    case issue(String, [String: String])
    case setUserId(String)
    case setUserProperties([String: Any])
    case performance(String, TimeInterval, [String: String])

    /// Custom equality for setUserProperties with [String: Any]
    static func == (lhs: AnalyticsEvent, rhs: AnalyticsEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.event(lName, lMeta), .event(rName, rMeta)):
            lName == rName && lMeta == rMeta
        case let (.error(lName, lMeta), .error(rName, rMeta)):
            lName == rName && lMeta == rMeta
        case let (.issue(lName, lMeta), .issue(rName, rMeta)):
            lName == rName && lMeta == rMeta
        case let (.setUserId(lId), .setUserId(rId)):
            lId == rId
        case let (.performance(lName, lDur, lMeta), .performance(rName, rDur, rMeta)):
            lName == rName && lDur == rDur && lMeta == rMeta
        case (.setUserProperties, .setUserProperties):
            // For properties, just check that both are the same type
            // Exact comparison of [String: Any] is complex
            true
        default:
            false
        }
    }
}
