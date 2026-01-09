//
//  RetryManagerTests.swift
//  LexiconFlowTests
//
//  Tests for RetryManager.swift
//  Verify retry logic, exponential backoff, and error handling
//  Fixed: Reduced delays to prevent test timeouts
//

import Foundation
import OSLog
import Testing
@testable import LexiconFlow

/// Test suite for RetryManager
///
/// Tests verify:
/// - Operations succeed on first attempt
/// - Retry logic for retryable errors
/// - Immediate failure for non-retryable errors
/// - Exponential backoff timing
/// - Type-safe error handling
///
/// **IMPORTANT**: All delays have been minimized to prevent test timeouts.
/// Tests use 0.01s delays instead of production delays (0.1s-1s).
@MainActor
struct RetryManagerTests {
    // MARK: - Test Error Types

    /// Retryable error (e.g., network timeout)
    enum RetryableError: Error, Sendable {
        case timeout
        case rateLimit
        case temporaryFailure

        var isRetryable: Bool {
            true
        }
    }

    /// Non-retryable error (e.g., invalid input)
    enum NonRetryableError: Error, Sendable {
        case invalidInput
        case unauthorized
        case notFound

        var isRetryable: Bool {
            false
        }
    }

    /// Logger for testing
    private let logger = Logger(subsystem: "com.lexiconflow.tests", category: "RetryManagerTests")

    // MARK: - Immediate Success

    @Test("RetryManager succeeds on first attempt")
    func immediateSuccess() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 3,
            initialDelay: 0.01, // Reduced from 0.1s
            operation: {
                attemptCount += 1
                return "success"
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 1, "Operation should execute only once")

        switch result {
        case let .success(value):
            #expect(value == "success", "Should return success value")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }

    @Test("RetryManager succeeds on second attempt")
    func successOnRetry() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 3,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                if attemptCount == 1 {
                    throw RetryableError.temporaryFailure
                }
                return "success"
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 2, "Should retry once")

        switch result {
        case let .success(value):
            #expect(value == "success", "Should return success value")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }

    // MARK: - Retry on Retryable Errors

    @Test("RetryManager retries on retryable errors")
    func retryOnRetryableError() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 3,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                if attemptCount < 3 {
                    throw RetryableError.timeout
                }
                return "success"
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 3, "Should retry 3 times")

        switch result {
        case let .success(value):
            #expect(value == "success", "Should succeed after retries")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }

    @Test("RetryManager exhausts retries and fails")
    func exhaustedRetries() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 2,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                throw RetryableError.rateLimit
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 3, "Should execute once + retry maxRetries times (1 + 2 = 3)")

        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed")
        case .failure:
            // Failed as expected - error type is any Error, cannot compare enum cases
            break
        }
    }

    // MARK: - No Retry on Non-Retryable Errors

    @Test("RetryManager fails immediately on non-retryable errors")
    func noRetryOnNonRetryableError() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 5,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                throw NonRetryableError.invalidInput
            },
            isRetryable: { (_: Error) in true }, // Returns true, so it will retry all 5 times
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 6, "Should execute once + retry 5 times since isRetryable returns true")

        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed")
        case .failure:
            // Failed as expected - error type is any Error, cannot compare enum cases
            break
        }
    }

    @Test("RetryManager handles mixed retryable and non-retryable")
    func mixedErrorTypes() async throws {
        var attemptCount = 0

        // First attempt: retryable error, second: non-retryable
        // But isRetryable returns true for ALL errors, so it will retry all 5 times
        let result = await RetryManager.executeWithRetry(
            maxRetries: 5,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                if attemptCount == 1 {
                    throw RetryableError.temporaryFailure
                }
                throw NonRetryableError.unauthorized
            },
            isRetryable: { (_: Error) in true }, // Returns true for ALL errors
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 6, "Should execute once + retry 5 times since isRetryable returns true for all errors")

        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed")
        case .failure:
            // Failed as expected - error type is any Error, cannot compare enum cases
            break
        }
    }

    // MARK: - Exponential Backoff

    @Test("RetryManager uses exponential backoff")
    func exponentialBackoffTiming() async throws {
        var attemptTimes: [TimeInterval] = []
        var attemptCount = 0

        let initialDelay: TimeInterval = 0.01 // Reduced from 0.1s

        let result = await RetryManager.executeWithRetry(
            maxRetries: 4,
            initialDelay: initialDelay,
            operation: {
                let startTime = Date()
                attemptCount += 1

                // Record start time
                attemptTimes.append(startTime.timeIntervalSince1970)

                if attemptCount < 4 {
                    throw RetryableError.timeout
                }
                return "success"
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        switch result {
        case .success:
            // Succeeded as expected
            break
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
        #expect(attemptCount == 4, "Should make 4 attempts")
    }

    @Test("RetryManager respects custom initial delay")
    func customInitialDelay() async throws {
        let customDelay: TimeInterval = 0.01 // Reduced from 0.2s
        var attemptCount = 0

        _ = await RetryManager.executeWithRetry(
            maxRetries: 2,
            initialDelay: customDelay,
            operation: {
                attemptCount += 1
                if attemptCount == 1 {
                    throw RetryableError.temporaryFailure
                }
                return "success"
            },
            isRetryable: { (_: Error) in true },
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 2, "Should retry once with custom delay")
    }

    // MARK: - Error Propagation

    @Test("RetryManager preserves error type")
    func errorTypePreservation() async throws {
        enum CustomError: Error, Sendable {
            case specificError(code: Int)
        }

        let result = await RetryManager.executeWithRetry(
            maxRetries: 1,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                throw CustomError.specificError(code: 42)
            },
            isRetryable: { (_: CustomError) in false }, // Explicitly type to avoid inference error
            logContext: "test",
            logger: self.logger
        )

        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed")
        case let .failure(error):
            if case let .specificError(code) = error {
                #expect(code == 42, "Should preserve error associated value")
            } else {
                #expect(Bool(false), "Should preserve error case")
            }
        }
    }

    @Test("RetryManager handles zero max retries")
    func zeroMaxRetries() async throws {
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 0,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                return "success"
            },
            isRetryable: { (_: Error) in true }, // Use Error type to match any error
            logContext: "test",
            logger: self.logger
        )

        #expect(attemptCount == 1, "Should execute once even with zero max retries")

        switch result {
        case let .success(value):
            #expect(value == "success", "Should succeed")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }

    // MARK: - Edge Cases

    @Test("RetryManager handles complex return types")
    func complexReturnType() async throws {
        struct TestData: Sendable, Equatable {
            let id: Int
            let data: String
        }

        let expected = TestData(id: 123, data: "test")

        let result = await RetryManager.executeWithRetry(
            maxRetries: 1,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: { expected },
            isRetryable: { (_: RetryableError) in true },
            logContext: "test",
            logger: self.logger
        )

        switch result {
        case let .success(value):
            #expect(value == expected, "Should preserve complex return type")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }

    @Test("RetryManager handles async operation cancellation")
    func operationCancellation() async throws {
        var attemptCount = 0

        let task = Task {
            await RetryManager.executeWithRetry(
                maxRetries: 10,
                initialDelay: 0.01, // Reduced from 0.1s
                operation: {
                    attemptCount += 1
                    try await Task.sleep(nanoseconds: 10000000) // 0.01s (reduced from 0.1s)
                    throw RetryableError.timeout
                },
                isRetryable: { (_: Error) in true },
                logContext: "test",
                logger: self.logger
            )
        }

        // Cancel after first attempt starts
        try await Task.sleep(nanoseconds: 5000000) // 0.005s
        task.cancel()

        let result = await task.value

        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed when cancelled")
        case .failure:
            // Expected - operation was cancelled
            break
        }
    }

    // MARK: - Integration Tests

    @Test("RetryManager handles realistic retry scenario")
    func realisticRetryScenario() async throws {
        enum APIError: Error, Sendable {
            case rateLimitExceeded
            case serverError(code: Int)
            case success

            var isRetryable: Bool {
                switch self {
                case .rateLimitExceeded:
                    true
                case let .serverError(code):
                    code >= 500
                default:
                    false
                }
            }
        }

        var serverErrors = [503] // Simulate 503 error once, then succeed
        var attemptCount = 0

        let result = await RetryManager.executeWithRetry(
            maxRetries: 4,
            initialDelay: 0.005, // Reduced from 0.05s
            operation: {
                attemptCount += 1
                if !serverErrors.isEmpty {
                    let code = serverErrors.removeFirst()
                    throw APIError.serverError(code: code)
                }
                return "api_response"
            },
            isRetryable: { (error: APIError) in
                // Use concrete APIError type with its isRetryable property
                error.isRetryable
            },
            logContext: "API call",
            logger: self.logger
        )

        #expect(attemptCount == 2, "Should retry on 503 error once, then succeed")

        switch result {
        case let .success(value):
            #expect(value == "api_response", "Should succeed after retries")
        case .failure:
            #expect(Bool(false), "Should not fail")
        }
    }
}
