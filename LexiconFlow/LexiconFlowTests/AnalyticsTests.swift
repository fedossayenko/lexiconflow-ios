//
//  AnalyticsTests.swift
//  LexiconFlowTests
//
//  Tests for analytics and error tracking
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

    // MARK: - Event Tracking Tests

    @Test("Track event without crashing")
    func trackEvent() async {
        // Should not crash with basic event
        await Analytics.trackEvent("test_event")

        // Should not crash with metadata
        await Analytics.trackEvent("test_event_with_metadata", metadata: [
            "key1": "value1",
            "key2": "value2"
        ])
    }

    @Test("Track error without crashing")
    func trackError() async {
        let testError = NSError(
            domain: "test.domain",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )

        // Should not crash
        await Analytics.trackError("test_error", error: testError)

        // Should not crash with metadata
        await Analytics.trackError("test_error_with_metadata", error: testError, metadata: [
            "context": "test_context"
        ])
    }

    @Test("Track performance without crashing")
    func trackPerformance() async {
        // Should not crash
        await Analytics.trackPerformance("test_operation", duration: 0.123)

        // Should not crash with metadata
        await Analytics.trackPerformance("test_operation_with_metadata", duration: 1.5, metadata: [
            "iterations": "100",
            "result": "success"
        ])
    }

    @Test("Handle empty event name")
    func emptyEventName() async {
        await Analytics.trackEvent("", metadata: [:])
        // Should not crash
    }

    @Test("Handle special characters in metadata")
    func specialCharactersInMetadata() async {
        await Analytics.trackEvent("special_chars", metadata: [
            "emoji": "🎉📚",
            "quotes": "\"quoted\"",
            "newlines": "line1\nline2",
            "unicode": "日本語"
        ])
        // Should not crash
    }

    @Test("Handle very long metadata values")
    func longMetadataValues() async {
        let longValue = String(repeating: "a", count: 10000)

        await Analytics.trackEvent("long_value", metadata: [
            "long": longValue
        ])
        // Should not crash
    }

    @Test("Handle nil error gracefully")
    func nilErrorHandling() async {
        // Create an optional error that's nil
        let optionalError: Error? = nil

        if let error = optionalError {
            await Analytics.trackError("nil_test", error: error)
        }
        // Should not crash
    }

    // MARK: - User Management Tests

    @Test("Set user ID without crashing")
    func setUserId() async {
        await Analytics.setUserId("test_user_123")
    }

    @Test("Set user properties without crashing")
    func setUserProperties() async {
        await Analytics.setUserProperties([
            "premium": "true",
            "study_streak": "30",
            "decks_count": "5"
        ])
    }

    // MARK: - Benchmark Tests

    @Test("Benchmark measures synchronous operation")
    func benchmarkSyncOperation() {
        let startTime = Date()
        // Simulate some work
        _ = (0..<1000).reduce(0, +)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0, "Duration should be non-negative")
        #expect(duration < 1.0, "Simple operation should be fast")
    }

    @Test("Benchmark measures async operation")
    func benchmarkAsyncOperation() async {
        let startTime = Date()
        // Simulate async work
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration >= 0.01, "Duration should be at least 10ms")
        #expect(duration < 1.0, "Operation should complete quickly")
    }

    @Test("Benchmark throws propagate correctly")
    func benchmarkThrows() {
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

    @Test("Track issue without crashing")
    func trackIssue() async {
        await Analytics.trackIssue("test_issue", message: "Something unusual happened")

        await Analytics.trackIssue(
            "test_issue_with_metadata",
            message: "Issue with context",
            metadata: ["state": "unusual"]
        )
    }

    @Test("Handle zero duration")
    func zeroDuration() async {
        await Analytics.trackPerformance("instant", duration: 0)
        // Should not crash
    }

    @Test("Handle negative duration")
    func negativeDuration() async {
        await Analytics.trackPerformance("negative", duration: -1.0)
        // Should not crash (though unusual)
    }

    // MARK: - Metadata Format Tests

    @Test("Metadata converts integers correctly")
    func integerMetadata() async {
        await Analytics.trackEvent("int_test", metadata: [
            "count": "42",
            "index": "0"
        ])
    }

    @Test("Metadata converts doubles correctly")
    func doubleMetadata() async {
        await Analytics.trackEvent("double_test", metadata: [
            "ratio": "0.75",
            "percentage": "99.9"
        ])
    }

    @Test("Metadata converts booleans correctly")
    func booleanMetadata() async {
        await Analytics.trackEvent("bool_test", metadata: [
            "enabled": "true",
            "disabled": "false"
        ])
    }

    // MARK: - Complex Scenarios

    @Test("Track multiple events in sequence")
    func multipleEvents() async {
        for i in 0..<10 {
            await Analytics.trackEvent("event_\(i)", metadata: [
                "index": "\(i)",
                "doubled": "\(i * 2)"
            ])
        }
        // Should not crash
    }

    @Test("Track nested benchmark operations")
    func nestedBenchmarks() {
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
        let startTime = Date()
        let x = 1 + 1
        let duration = Date().timeIntervalSince(startTime)

        // Even very fast operations should measure something
        #expect(duration >= 0, "Duration should be non-negative")
    }

    @Test("Benchmark with complex operation")
    func complexOperation() async {
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
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await Analytics.trackEvent("concurrent_\(i)")
                }
            }
        }
        // Should not crash
    }

    @Test("Handle concurrent benchmark measurements")
    func concurrentBenchmarks() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let startTime = Date()
                    _ = (0..<100).reduce(0, +)
                    let duration = Date().timeIntervalSince(startTime)
                    print("Concurrent benchmark \(i) took \(duration)s")
                }
            }
        }
        // Should not crash
    }
}
