//
//  TimeoutExtensionsTests.swift
//  LexiconFlowTests
//
//  Tests for TimeoutExtensions.swift
//  Verify timeout behavior, cancellation, and error propagation
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for TimeoutExtensions
///
/// Tests verify:
/// - Operations complete successfully before timeout
/// - TimeoutError thrown when operation exceeds time limit
/// - Task cancellation when timeout occurs
/// - Operation errors are properly propagated
@MainActor
struct TimeoutExtensionsTests {
    // MARK: - Success Before Timeout

    @Test("withTimeout completes successfully before timeout")
    func successBeforeTimeout() async throws {
        // Operation that completes well before timeout
        let result = try await withTimeout(seconds: 1.0) {
            "completed"
        }

        #expect(result == "completed", "Operation should complete and return value")
    }

    @Test("withTimeout completes operation that returns complex type")
    func complexReturnType() async throws {
        struct TestData: Sendable, Equatable {
            let id: Int
            let name: String
        }

        let expected = TestData(id: 42, name: "test")
        let result = try await withTimeout(seconds: 1.0) {
            expected
        }

        #expect(result == expected, "Complex return type should be preserved")
    }

    // MARK: - Timeout Behavior

    @Test("withTimeout throws TimeoutError when operation exceeds time")
    func timeoutExceeded() async throws {
        // Operation that takes longer than timeout
        let timeoutError = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 0.1) {
                try await Task.sleep(nanoseconds: 500000000) // 0.5 seconds
                return "should not complete"
            }
        }

        #expect(timeoutError != nil, "Should throw TimeoutError")
        #expect(
            timeoutError is TimeoutError,
            "Should throw TimeoutError, not \(type(of: timeoutError))"
        )
    }

    @Test("withTimeout includes timeout duration in error")
    func timeoutErrorContainsDuration() async throws {
        let timeoutDuration: TimeInterval = 0.2

        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: timeoutDuration) {
                try await Task.sleep(nanoseconds: 1000000000) // 1 second
                return "late"
            }
        }

        if let timeoutError = error as? TimeoutError {
            switch timeoutError {
            case let .timedOut(seconds):
                #expect(seconds == timeoutDuration, "Timeout duration should match")
            }
        } else {
            #expect(Bool(false), "Should be TimeoutError.timedOut")
        }
    }

    // MARK: - Cancellation

    @Test("withTimeout cancels operation when timeout occurs")
    func cancellationOnTimeout() async throws {
        var taskWasCancelled = false

        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 0.1) {
                // Long-running operation that checks for cancellation
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(50))
                }
                taskWasCancelled = true
                throw CancellationError()
            }
        }

        #expect(taskWasCancelled, "Operation task should be cancelled when timeout occurs")
        #expect(error != nil, "Should throw error (CancellationError or TimeoutError)")
    }

    // MARK: - Error Propagation

    @Test("withTimeout propagates operation errors")
    func operationErrorPropagation() async throws {
        enum TestError: Error, Sendable {
            case operationFailed
        }

        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 1.0) {
                throw TestError.operationFailed
            }
        }

        #expect(error != nil, "Should propagate operation error")
        #expect(
            error is TestError,
            "Should preserve original error type, not \(type(of: error))"
        )

        if let testError = error as? TestError {
            #expect(testError == .operationFailed, "Should preserve error case")
        }
    }

    @Test("withTimeout propagates operation errors immediately")
    func immediateErrorPropagation() async throws {
        enum ImmediateError: Error, Sendable {
            case instantFailure
        }

        let startTime = Date()
        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 5.0) {
                throw ImmediateError.instantFailure
            }
        }
        let duration = Date().timeIntervalSince(startTime)

        #expect(error is ImmediateError, "Should throw immediate error")
        #expect(
            duration < 1.0,
            "Should fail immediately, not wait for timeout (took \(duration)s)"
        )
    }

    // MARK: - Edge Cases

    @Test("withTimeout handles zero-second timeout")
    func zeroSecondTimeout() async throws {
        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 0.0) {
                try await Task.sleep(nanoseconds: 100000000) // 0.1 seconds
                return "slow"
            }
        }

        #expect(error != nil, "Zero timeout should trigger immediately")
    }

    @Test("withTimeout handles very short timeout")
    func veryShortTimeout() async throws {
        let error = await TimeoutErrorResult.capture {
            try await withTimeout(seconds: 0.001) { // 1ms
                try await Task.sleep(nanoseconds: 100000000) // 100ms
                return "too slow"
            }
        }

        #expect(error != nil, "Very short timeout should trigger")
    }

    @Test("withTimeout handles successful async operation")
    func asyncOperationSuccess() async throws {
        let expected = 42

        let result = try await withTimeout(seconds: 1.0) {
            try await Task.sleep(nanoseconds: 10000000) // 0.01 seconds
            return expected
        }

        #expect(result == expected, "Async operation should complete")
    }

    @Test("withTimeout handles concurrent operations")
    func concurrentOperations() async throws {
        // Run multiple timeout operations concurrently
        func operation(_ id: Int) async throws -> Int {
            try await withTimeout(seconds: 1.0) {
                try await Task.sleep(nanoseconds: 10000000)
                return id
            }
        }

        async let r1 = operation(1)
        async let r2 = operation(2)
        async let r3 = operation(3)

        let (v1, v2, v3) = try await (r1, r2, r3)

        #expect(v1 == 1, "First operation should complete")
        #expect(v2 == 2, "Second operation should complete")
        #expect(v3 == 3, "Third operation should complete")
    }
}

// MARK: - Test Helper

/// Helper for capturing errors from async throwing operations
@MainActor
enum TimeoutErrorResult {
    static func capture(_ operation: @escaping @Sendable () async throws -> some Sendable) async -> Error? {
        do {
            _ = try await operation()
            return nil
        } catch {
            return error
        }
    }
}
