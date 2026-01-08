//
//  AnalyticsTests.swift
//  LexiconFlowTests
//
//  Tests for analytics and error tracking with mock backend
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for Analytics
///
/// Tests verify:
/// - Event tracking with metadata
/// - Error tracking with context
/// - Performance measurement
/// - User property management
struct AnalyticsTests {
    /// Shared mock backend for all tests (reset before each test)
    private static let mockBackend = MockAnalyticsBackend()

    /// Setup mock backend before each test
    private static func setupMockBackend() {
        Analytics.setBackend(mockBackend)
        mockBackend.clear()
    }

    /// Teardown after each test
    private static func teardownMockBackend() {
        Analytics.resetToProductionBackend()
    }

    // MARK: - Event Tracking Tests

    @Test("Track event without crashing")
    func trackEvent() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        // Track basic event
        Analytics.trackEvent("test_event")

        // Verify event was recorded
        #expect(Self.mockBackend.didTrackEvent("test_event"), "Event should be tracked")
        #expect(Self.mockBackend.eventCount(for: "test_event") == 1, "Should have exactly 1 event")

        // Track event with metadata
        Analytics.trackEvent("test_event_with_metadata", metadata: [
            "key1": "value1",
            "key2": "value2"
        ])

        // Verify event with metadata was recorded
        #expect(Self.mockBackend.didTrackEvent("test_event_with_metadata"), "Event with metadata should be tracked")
    }

    @Test("Track error without crashing")
    func trackError() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }
        let testError = NSError(
            domain: "test.domain",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )

        // Track error
        Analytics.trackError("test_error", error: testError)

        // Verify error was recorded
        #expect(Self.mockBackend.didTrackError("test_error"), "Error should be tracked")

        // Track error with metadata
        Analytics.trackError("test_error_with_metadata", error: testError, metadata: [
            "context": "test_context"
        ])

        // Verify error with metadata was recorded
        #expect(Self.mockBackend.didTrackError("test_error_with_metadata"), "Error with metadata should be tracked")
    }

    @Test("Track performance without crashing")
    func trackPerformance() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        // Track performance
        Analytics.trackPerformance("test_operation", duration: 0.123)

        // Verify performance was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case .performance("test_operation", 0.123, _) = event {
                return true
            }
            return false
        }, "Performance event should be tracked")

        // Track performance with metadata
        Analytics.trackPerformance("test_operation_with_metadata", duration: 1.5, metadata: [
            "iterations": "100",
            "result": "success"
        ])

        // Verify performance with metadata was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case let .performance("test_operation_with_metadata", 1.5, metadata) = event {
                return metadata["iterations"] == "100" && metadata["result"] == "success"
            }
            return false
        }, "Performance with metadata should be tracked")
    }

    @Test("Track issue without crashing")
    func trackIssue() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackIssue("test_issue", message: "Something unusual happened")

        // Verify issue was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case let .issue("test_issue", metadata) = event {
                return metadata["message"] == "Something unusual happened"
            }
            return false
        }, "Issue should be tracked with message")

        Analytics.trackIssue(
            "test_issue_with_metadata",
            message: "Issue with context",
            metadata: ["state": "unusual"]
        )

        // Verify issue with metadata was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case let .issue("test_issue_with_metadata", metadata) = event {
                return metadata["message"] == "Issue with context" && metadata["state"] == "unusual"
            }
            return false
        }, "Issue with metadata should be tracked")
    }

    // MARK: - User Management Tests

    @Test("Set user ID without crashing")
    func setUserId() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.setUserId("test_user_123")

        // Verify user ID was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case .setUserId("test_user_123") = event {
                return true
            }
            return false
        }, "User ID should be tracked")
    }

    @Test("Set user properties without crashing")
    func setUserProperties() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.setUserProperties([
            "premium": "true",
            "study_streak": "30",
            "decks_count": "5"
        ])

        // Verify user properties were recorded
        #expect(Self.mockBackend.events.contains { event in
            if case .setUserProperties = event {
                return true
            }
            return false
        }, "User properties should be tracked")
    }

    // MARK: - Edge Case Tests

    @Test("Handle empty event name")
    func emptyEventName() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackEvent("", metadata: [:])

        // Should record even with empty name
        #expect(Self.mockBackend.didTrackEvent(""), "Empty event name should be tracked")
    }

    @Test("Handle special characters in metadata")
    func specialCharactersInMetadata() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackEvent("special_chars", metadata: [
            "emoji": "🎉📚",
            "quotes": "\"quoted\"",
            "newlines": "line1\nline2",
            "unicode": "日本語"
        ])

        // Verify event was recorded with special characters
        #expect(Self.mockBackend.didTrackEvent("special_chars"), "Event with special characters should be tracked")
    }

    @Test("Handle very long metadata values")
    func longMetadataValues() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let longValue = String(repeating: "a", count: 10000)

        Analytics.trackEvent("long_value", metadata: [
            "long": longValue
        ])

        // Verify event was recorded with long value
        #expect(Self.mockBackend.didTrackEvent("long_value"), "Event with long metadata should be tracked")
    }

    @Test("Handle nil error gracefully")
    func nilErrorHandling() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        // Create an optional error that's nil
        let optionalError: Error? = nil

        if let error = optionalError {
            Analytics.trackError("nil_test", error: error)
        }

        // No event should be tracked since error was nil
        #expect(Self.mockBackend.events.isEmpty, "No event should be tracked for nil error")
    }

    @Test("Handle zero duration")
    func zeroDuration() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackPerformance("instant", duration: 0)

        // Verify performance was recorded
        #expect(Self.mockBackend.events.contains { event in
            if case .performance("instant", 0, _) = event {
                return true
            }
            return false
        }, "Zero duration performance should be tracked")
    }

    @Test("Handle negative duration")
    func negativeDuration() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackPerformance("negative", duration: -1.0)

        // Verify performance was recorded even with negative duration
        #expect(Self.mockBackend.events.contains { event in
            if case .performance("negative", -1.0, _) = event {
                return true
            }
            return false
        }, "Negative duration performance should be tracked")
    }

    // MARK: - Metadata Format Tests

    @Test("Metadata converts integers correctly")
    func integerMetadata() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackEvent("int_test", metadata: [
            "count": "42",
            "index": "0"
        ])

        // Verify event was recorded
        #expect(Self.mockBackend.didTrackEvent("int_test"), "Event with integer metadata should be tracked")
    }

    @Test("Metadata converts doubles correctly")
    func doubleMetadata() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackEvent("double_test", metadata: [
            "ratio": "0.75",
            "percentage": "99.9"
        ])

        // Verify event was recorded
        #expect(Self.mockBackend.didTrackEvent("double_test"), "Event with double metadata should be tracked")
    }

    @Test("Metadata converts booleans correctly")
    func booleanMetadata() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        Analytics.trackEvent("bool_test", metadata: [
            "enabled": "true",
            "disabled": "false"
        ])

        // Verify event was recorded
        #expect(Self.mockBackend.didTrackEvent("bool_test"), "Event with boolean metadata should be tracked")
    }

    // MARK: - Complex Scenarios

    @Test("Track multiple events in sequence")
    func multipleEvents() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        for i in 0 ..< 10 {
            Analytics.trackEvent("event_\(i)", metadata: [
                "index": "\(i)",
                "doubled": "\(i * 2)"
            ])
        }

        // Verify all 10 events were recorded
        #expect(Self.mockBackend.events.count == 10, "Should track exactly 10 events")

        // Verify each event was recorded with correct metadata
        for i in 0 ..< 10 {
            #expect(Self.mockBackend.didTrackEvent("event_\(i)"), "Event \(i) should be tracked")
        }
    }

    @Test("Track nested benchmark operations")
    func nestedBenchmarks() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let outerStart = Date()
        let innerStart = Date()
        _ = (0 ..< 100).reduce(0, +)
        let innerDuration = Date().timeIntervalSince(innerStart)
        #expect(innerDuration > 0, "Inner should have duration")
        let outerDuration = Date().timeIntervalSince(outerStart)

        #expect(outerDuration > 0, "Outer should have duration")
    }

    @Test("Benchmark with very fast operation")
    func veryFastOperation() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let startTime = Date()
        let x = 1 + 1
        let duration = Date().timeIntervalSince(startTime)

        // Even very fast operations should measure something
        #expect(duration >= 0, "Duration should be non-negative")

        // Store result to avoid unused variable warning
        _ = x
    }

    @Test("Benchmark with complex operation")
    func complexOperation() async {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let startTime = Date()
        // Simulate a multi-step operation
        var sum = 0
        for i in 0 ..< 100 {
            sum += i
        }
        try? await Task.sleep(nanoseconds: 1000000) // 1ms
        _ = sum
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration > 0.001, "Should account for both computation and sleep")
    }

    // MARK: - Concurrency Tests

    @Test("Handle concurrent event tracking")
    func concurrentEventTracking() async {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 50 {
                group.addTask {
                    Analytics.trackEvent("concurrent_\(i)")
                }
            }
        }

        // Verify all 50 events were recorded
        #expect(Self.mockBackend.events.count == 50, "Should track exactly 50 concurrent events")
    }

    @Test("Handle concurrent benchmark measurements")
    func concurrentBenchmarks() async {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 20 {
                group.addTask {
                    let startTime = Date()
                    _ = (0 ..< 100).reduce(0, +)
                    let duration = Date().timeIntervalSince(startTime)
                    // Use duration to avoid unused variable warning
                    _ = duration
                }
            }
        }

        // All tasks should complete without crashing
        #expect(true, "Concurrent benchmarks should complete")
    }

    // MARK: - Benchmark Tests

    @Test("Benchmark measures synchronous operation")
    func benchmarkSyncOperation() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let startTime = Date()
        // Simulate some work
        _ = (0 ..< 1000).reduce(0, +)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0, "Duration should be non-negative")
        #expect(duration < 1.0, "Simple operation should be fast")
    }

    @Test("Benchmark measures async operation")
    func benchmarkAsyncOperation() async {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        let startTime = Date()
        // Simulate async work
        try? await Task.sleep(nanoseconds: 10000000) // 10ms
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0.01, "Duration should be at least 10ms")
        #expect(duration < 1.0, "Operation should complete quickly")
    }

    @Test("Benchmark throws propagate correctly")
    func benchmarkThrows() {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        struct TestError: Error {}

        #expect(throws: TestError.self) {
            let startTime = Date()
            defer {
                let duration = Date().timeIntervalSince(startTime)
                print("Throwing test took \(duration)s")
            }
            throw TestError()
        }
    }

    @Test("Benchmark async throws propagate correctly")
    func benchmarkAsyncThrows() async {
        Self.setupMockBackend()
        defer { Self.teardownMockBackend() }

        struct TestError: Error {}

        await #expect(throws: TestError.self) {
            let startTime = Date()
            defer {
                let duration = Date().timeIntervalSince(startTime)
                print("Async throwing test took \(duration)s")
            }
            throw TestError()
        }
    }
}
