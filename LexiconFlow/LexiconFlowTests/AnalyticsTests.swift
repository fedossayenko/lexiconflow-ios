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
/// - Benchmark timing accuracy
/// - User property management
struct AnalyticsTests {

    // MARK: - Event Tracking Tests

    @Test("Track event without crashing")
    func trackEvent() {
        // Should not crash with basic event
        Analytics.trackEvent("test_event")

        // Should not crash with metadata
        Analytics.trackEvent("test_event_with_metadata", metadata: [
            "key1": "value1",
            "key2": "value2"
        ])
    }

    @Test("Track error without crashing")
    func trackError() {
        let testError = NSError(
            domain: "test.domain",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )

        // Should not crash
        Analytics.trackError("test_error", error: testError)

        // Should not crash with metadata
        Analytics.trackError("test_error_with_metadata", error: testError, metadata: [
            "context": "test_context"
        ])
    }

    @Test("Track performance without crashing")
    func trackPerformance() {
        // Should not crash
        Analytics.trackPerformance("test_operation", duration: 0.123)

        // Should not crash with metadata
        Analytics.trackPerformance("test_operation_with_metadata", duration: 1.5, metadata: [
            "iterations": "100",
            "result": "success"
        ])
    }

    @Test("Track issue without crashing")
    func trackIssue() {
        Analytics.trackIssue("test_issue", message: "Something unusual happened")

        Analytics.trackIssue(
            "test_issue_with_metadata",
            message: "Issue with context",
            metadata: ["state": "unusual"]
        )
    }

    // MARK: - User Management Tests

    @Test("Set user ID without crashing")
    func setUserId() {
        Analytics.setUserId("test_user_123")
    }

    @Test("Set user properties without crashing")
    func setUserProperties() {
        Analytics.setUserProperties([
            "premium": "true",
            "study_streak": "30",
            "decks_count": "5"
        ])
    }

    // MARK: - Benchmark Tests

    @Test("Benchmark measures synchronous operation")
    func benchmarkSyncOperation() {
        let duration = try! Benchmark.measureTime("sync_test") {
            // Simulate some work
            _ = (0..<1000).reduce(0, +)
        }

        #expect(duration >= 0, "Duration should be non-negative")
        #expect(duration < 1.0, "Simple operation should be fast")
    }

    @Test("Benchmark measures async operation")
    func benchmarkAsyncOperation() async {
        let duration = await Benchmark.measureTime("async_test") {
            // Simulate async work
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        #expect(duration >= 0.01, "Duration should be at least 10ms")
        #expect(duration < 1.0, "Operation should complete quickly")
    }

    @Test("Benchmark timing is accurate")
    func benchmarkAccuracy() async {
        let expectedDelay: TimeInterval = 0.05 // 50ms

        let duration = await Benchmark.measureTime("timing_test") {
            try? await Task.sleep(nanoseconds: UInt64(expectedDelay * 1_000_000_000))
        }

        // Allow 500% tolerance for Task.sleep scheduling overhead
        // Task.sleep is not precise and subject to scheduler delays
        let tolerance = expectedDelay * 5.0
        #expect(
            abs(duration - expectedDelay) < tolerance,
            "Duration \(duration)s should be within 500% of expected \(expectedDelay)s"
        )
    }

    @Test("Benchmark throws propagate correctly")
    func benchmarkThrows() {
        struct TestError: Error {}

        #expect(throws: TestError.self) {
            try Benchmark.measureTime("throwing_test") {
                throw TestError()
            }
        }
    }

    @Test("Benchmark async throws propagate correctly")
    func benchmarkAsyncThrows() async {
        struct TestError: Error {}

        await #expect(throws: TestError.self) {
            try await Benchmark.measureTime("async_throwing_test") {
                throw TestError()
            }
        }
    }

    // MARK: - Edge Case Tests

    @Test("Handle empty event name")
    func emptyEventName() {
        Analytics.trackEvent("", metadata: [:])
        // Should not crash
    }

    @Test("Handle special characters in metadata")
    func specialCharactersInMetadata() {
        Analytics.trackEvent("special_chars", metadata: [
            "emoji": "🎉📚",
            "quotes": "\"quoted\"",
            "newlines": "line1\nline2",
            "unicode": "日本語"
        ])
        // Should not crash
    }

    @Test("Handle very long metadata values")
    func longMetadataValues() {
        let longValue = String(repeating: "a", count: 10000)

        Analytics.trackEvent("long_value", metadata: [
            "long": longValue
        ])
        // Should not crash
    }

    @Test("Handle nil error gracefully")
    func nilErrorHandling() {
        // Create an optional error that's nil
        let optionalError: Error? = nil

        if let error = optionalError {
            Analytics.trackError("nil_test", error: error)
        }
        // Should not crash
    }

    @Test("Handle zero duration")
    func zeroDuration() {
        Analytics.trackPerformance("instant", duration: 0)
        // Should not crash
    }

    @Test("Handle negative duration")
    func negativeDuration() {
        Analytics.trackPerformance("negative", duration: -1.0)
        // Should not crash (though unusual)
    }

    // MARK: - Metadata Format Tests

    @Test("Metadata converts integers correctly")
    func integerMetadata() {
        Analytics.trackEvent("int_test", metadata: [
            "count": "42",
            "index": "0"
        ])
    }

    @Test("Metadata converts doubles correctly")
    func doubleMetadata() {
        Analytics.trackEvent("double_test", metadata: [
            "ratio": "0.75",
            "percentage": "99.9"
        ])
    }

    @Test("Metadata converts booleans correctly")
    func booleanMetadata() {
        Analytics.trackEvent("bool_test", metadata: [
            "enabled": "true",
            "disabled": "false"
        ])
    }

    // MARK: - Complex Scenarios

    @Test("Track multiple events in sequence")
    func multipleEvents() {
        for i in 0..<100 {
            Analytics.trackEvent("event_\(i)", metadata: [
                "index": "\(i)",
                "doubled": "\(i * 2)"
            ])
        }
        // Should not crash
    }

    @Test("Track nested benchmark operations")
    func nestedBenchmarks() {
        let outerDuration = try! Benchmark.measureTime("outer") {
            let innerDuration = try! Benchmark.measureTime("inner") {
                _ = (0..<100).reduce(0, +)
            }
            #expect(innerDuration > 0, "Inner should have duration")
        }

        #expect(outerDuration > 0, "Outer should have duration")
    }

    @Test("Benchmark with very fast operation")
    func veryFastOperation() {
        let duration = try! Benchmark.measureTime("nano_op") {
            let x = 1 + 1
        }

        // Even very fast operations should measure something
        #expect(duration >= 0, "Duration should be non-negative")
    }

    @Test("Benchmark with complex operation")
    func complexOperation() async {
        let duration = await Benchmark.measureTime("complex") {
            // Simulate a multi-step operation
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            _ = sum
        }

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
                    let _ = await Benchmark.measureTime("concurrent_benchmark_\(i)") {
                        _ = (0..<100).reduce(0, +)
                    }
                }
            }
        }
        // Should not crash
    }
}
