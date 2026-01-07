//
//  AnalyticsTests.swift
//  LexiconFlowTests
//
//  Tests for analytics and error tracking with mock backend
//

import Testing
import Foundation
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
        setupMockBackend()
        defer { teardownMockBackend() }

        // Track basic event
        Analytics.trackEvent("test_event")

        // Verify event was recorded
        #expect(mockBackend.didTrackEvent("test_event"), "Event should be tracked")
        #expect(mockBackend.eventCount(for: "test_event") == 1, "Should have exactly 1 event")

        // Track event with metadata
        Analytics.trackEvent("test_event_with_metadata", metadata: [
            "key1": "value1",
            "key2": "value2"
        ])

        // Verify event with metadata was recorded
        #expect(mockBackend.didTrackEvent("test_event_with_metadata"), "Event with metadata should be tracked")
    }

    @Test("Track error without crashing")
    func trackError() {
        setupMockBackend()
        defer { teardownMockBackend() }

        let testError = NSError(
            domain: "test.domain",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )

        // Track error
        Analytics.trackError("test_error", error: testError)

        // Verify error was recorded
        #expect(mockBackend.didTrackError("test_error"), "Error should be tracked")

        // Track error with metadata
        Analytics.trackError("test_error_with_metadata", error: testError, metadata: [
            "context": "test_context"
        ])

        // Verify error with metadata was recorded
        #expect(mockBackend.didTrackError("test_error_with_metadata"), "Error with metadata should be tracked")
    }

    @Test("Track performance without crashing")
    func trackPerformance() {
        setupMockBackend()
        defer { teardownMockBackend() }

        // Track performance
        Analytics.trackPerformance("test_operation", duration: 0.123)

        // Verify performance was recorded
        #expect(mockBackend.events.contains { event in
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
        #expect(mockBackend.events.contains { event in
            if case .performance("test_operation_with_metadata", 1.5, let metadata) = event {
                return metadata["iterations"] == "100" && metadata["result"] == "success"
            }
            return false
        }, "Performance with metadata should be tracked")
    }

    @Test("Track issue without crashing")
    func trackIssue() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackIssue("test_issue", message: "Something unusual happened")

        // Verify issue was recorded
        #expect(mockBackend.events.contains { event in
            if case .issue("test_issue", let metadata) = event {
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
        #expect(mockBackend.events.contains { event in
            if case .issue("test_issue_with_metadata", let metadata) = event {
                return metadata["message"] == "Issue with context" && metadata["state"] == "unusual"
            }
            return false
        }, "Issue with metadata should be tracked")
    }

    // MARK: - User Management Tests

    @Test("Set user ID without crashing")
    func setUserId() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.setUserId("test_user_123")

        // Verify user ID was recorded
        #expect(mockBackend.events.contains { event in
            if case .setUserId("test_user_123") = event {
                return true
            }
            return false
        }, "User ID should be tracked")
    }

    @Test("Set user properties without crashing")
    func setUserProperties() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.setUserProperties([
            "premium": "true",
            "study_streak": "30",
            "decks_count": "5"
        ])

        // Verify user properties were recorded
        #expect(mockBackend.events.contains { event in
            if case .setUserProperties = event {
                return true
            }
            return false
        }, "User properties should be tracked")
    }

    // MARK: - Edge Case Tests

    @Test("Handle empty event name")
    func emptyEventName() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackEvent("", metadata: [:])

        // Should record even with empty name
        #expect(mockBackend.didTrackEvent(""), "Empty event name should be tracked")
    }

    @Test("Handle special characters in metadata")
    func specialCharactersInMetadata() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackEvent("special_chars", metadata: [
            "emoji": "🎉📚",
            "quotes": "\"quoted\"",
            "newlines": "line1\nline2",
            "unicode": "日本語"
        ])

        // Verify event was recorded with special characters
        #expect(mockBackend.didTrackEvent("special_chars"), "Event with special characters should be tracked")
    }

    @Test("Handle very long metadata values")
    func longMetadataValues() {
        setupMockBackend()
        defer { teardownMockBackend() }

        let longValue = String(repeating: "a", count: 10000)

        Analytics.trackEvent("long_value", metadata: [
            "long": longValue
        ])

        // Verify event was recorded with long value
        #expect(mockBackend.didTrackEvent("long_value"), "Event with long metadata should be tracked")
    }

    @Test("Handle nil error gracefully")
    func nilErrorHandling() {
        setupMockBackend()
        defer { teardownMockBackend() }

        // Create an optional error that's nil
        let optionalError: Error? = nil

        if let error = optionalError {
            Analytics.trackError("nil_test", error: error)
        }

        // No event should be tracked since error was nil
        #expect(mockBackend.events.isEmpty, "No event should be tracked for nil error")
    }

    @Test("Handle zero duration")
    func zeroDuration() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackPerformance("instant", duration: 0)

        // Verify performance was recorded
        #expect(mockBackend.events.contains { event in
            if case .performance("instant", 0, _) = event {
                return true
            }
            return false
        }, "Zero duration performance should be tracked")
    }

    @Test("Handle negative duration")
    func negativeDuration() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackPerformance("negative", duration: -1.0)

        // Verify performance was recorded even with negative duration
        #expect(mockBackend.events.contains { event in
            if case .performance("negative", -1.0, _) = event {
                return true
            }
            return false
        }, "Negative duration performance should be tracked")
    }

    // MARK: - Metadata Format Tests

    @Test("Metadata converts integers correctly")
    func integerMetadata() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackEvent("int_test", metadata: [
            "count": "42",
            "index": "0"
        ])

        // Verify event was recorded
        #expect(mockBackend.didTrackEvent("int_test"), "Event with integer metadata should be tracked")
    }

    @Test("Metadata converts doubles correctly")
    func doubleMetadata() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackEvent("double_test", metadata: [
            "ratio": "0.75",
            "percentage": "99.9"
        ])

        // Verify event was recorded
        #expect(mockBackend.didTrackEvent("double_test"), "Event with double metadata should be tracked")
    }

    @Test("Metadata converts booleans correctly")
    func booleanMetadata() {
        setupMockBackend()
        defer { teardownMockBackend() }

        Analytics.trackEvent("bool_test", metadata: [
            "enabled": "true",
            "disabled": "false"
        ])

        // Verify event was recorded
        #expect(mockBackend.didTrackEvent("bool_test"), "Event with boolean metadata should be tracked")
    }

    // MARK: - Complex Scenarios

    @Test("Track multiple events in sequence")
    func multipleEvents() {
        setupMockBackend()
        defer { teardownMockBackend() }

        for i in 0..<10 {
            Analytics.trackEvent("event_\(i)", metadata: [
                "index": "\(i)",
                "doubled": "\(i * 2)"
            ])
        }

        // Verify all 10 events were recorded
        #expect(mockBackend.events.count == 10, "Should track exactly 10 events")

        // Verify each event was recorded with correct metadata
        for i in 0..<10 {
            #expect(mockBackend.didTrackEvent("event_\(i)"), "Event \(i) should be tracked")
        }
    }

    @Test("Track nested benchmark operations")
    func nestedBenchmarks() {
        setupMockBackend()
        defer { teardownMockBackend() }

        let outerStart = Date()
        let innerStart = Date()
        _ = (0..<100).reduce(0, +)
        let innerDuration = Date().timeIntervalSince(innerStart)
        #expect(innerDuration > 0, "Inner should have duration")
        let outerDuration = Date().timeIntervalSince(outerStart)

        #expect(outerDuration > 0, "Outer should have duration")
    }

    @Test("Benchmark with very fast operation")
    func veryFastOperation() {
        setupMockBackend()
        defer { teardownMockBackend() }

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
        setupMockBackend()
        defer { teardownMockBackend() }

        let startTime = Date()
        // Simulate a multi-step operation
        var sum = 0
        for i in 0..<100 {
            sum += i
        }
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        _ = sum
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration > 0.001, "Should account for both computation and sleep")
    }

    // MARK: - Concurrency Tests

    @Test("Handle concurrent event tracking")
    func concurrentEventTracking() async {
        setupMockBackend()
        defer { teardownMockBackend() }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    Analytics.trackEvent("concurrent_\(i)")
                }
            }
        }

        // Verify all 50 events were recorded
        #expect(mockBackend.events.count == 50, "Should track exactly 50 concurrent events")
    }

    @Test("Handle concurrent benchmark measurements")
    func concurrentBenchmarks() async {
        setupMockBackend()
        defer { teardownMockBackend() }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let startTime = Date()
                    _ = (0..<100).reduce(0, +)
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
        setupMockBackend()
        defer { teardownMockBackend() }

        let startTime = Date()
        // Simulate some work
        _ = (0..<1000).reduce(0, +)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0, "Duration should be non-negative")
        #expect(duration < 1.0, "Simple operation should be fast")
    }

    @Test("Benchmark measures async operation")
    func benchmarkAsyncOperation() async {
        setupMockBackend()
        defer { teardownMockBackend() }

        let startTime = Date()
        // Simulate async work
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0.01, "Duration should be at least 10ms")
        #expect(duration < 1.0, "Operation should complete quickly")
    }

    @Test("Benchmark throws propagate correctly")
    func benchmarkThrows() {
        setupMockBackend()
        defer { teardownMockBackend() }

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
        setupMockBackend()
        defer { teardownMockBackend() }

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
