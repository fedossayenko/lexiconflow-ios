//
//  RetryManager.swift
//  LexiconFlow
//
//  Generic retry manager with exponential backoff
//  Handles transient errors (rate limits, network issues)
//

import Foundation
import OSLog

/// Generic retry manager with exponential backoff
///
/// Provides configurable retry logic for operations that may fail due to
/// transient issues like rate limits or network problems.
///
/// **Features:**
/// - Exponential backoff (delay doubles after each retry)
/// - Configurable max retries and initial delay
/// - Customizable retryable error detection
/// - Logging at each retry attempt
///
/// **Example:**
/// ```swift
/// let result = await RetryManager.executeWithRetry(
///     maxRetries: 3,
///     initialDelay: 0.5,
///     operation: {
///         try await apiCall()
///     },
///     isRetryable: { error in
///         error.isRetryable
///     },
///     logContext: "API call",
///     logger: logger
/// )
/// ```
enum RetryManager {

    /// Execute an operation with retry and exponential backoff
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - initialDelay: Initial delay before first retry in seconds (default: 0.5)
    ///   - operation: The async operation to execute (may throw)
    ///   - isRetryable: Closure that determines if an error should trigger retry
    ///   - logContext: Description for logging (e.g., "translation", "sentence generation")
    ///   - logger: Logger instance for debug output
    ///
    /// - Returns: Result<Output, ErrorType> - success or failure after all retries
    ///
    /// **Retry Behavior:**
    /// 1. Execute operation
    /// 2. On success: return `.success(result)` immediately
    /// 3. On error with `isRetryable == true`: sleep with exponential backoff, then retry
    /// 4. On error with `isRetryable == false`: return `.failure(error)` immediately
    /// 5. After max retries: return `.failure(lastError)`
    ///
    /// **Backoff Formula:** `delay = initialDelay * (2 ^ attemptNumber)`
    /// - Attempt 0: 0.5s (if failed)
    /// - Attempt 1: 1.0s
    /// - Attempt 2: 2.0s
    static func executeWithRetry<Output, ErrorType: Error>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 0.5,
        operation: @escaping () async throws -> Output,
        isRetryable: @escaping (ErrorType) -> Bool,
        logContext: String,
        logger: Logger
    ) async -> Result<Output, ErrorType> {
        var attempt = 0
        var delay = initialDelay
        var lastError: ErrorType?

        while attempt < maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    logger.info("\(logContext): Succeeded on attempt \(attempt + 1)")
                }
                return .success(result)
            } catch let error as ErrorType {
                lastError = error
                guard isRetryable(error) else {
                    logger.error("\(logContext): Non-retryable error - \(error.localizedDescription)")
                    return .failure(error)
                }
                attempt += 1
                if attempt < maxRetries {
                    logger.info("\(logContext): Retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                } else {
                    logger.error("\(logContext): Failed after \(maxRetries) retries")
                    return .failure(error)
                }
            } catch {
                // Unknown error type that doesn't match ErrorType
                logger.error("\(logContext): Unknown error type - \(error.localizedDescription)")
                // For unknown errors, we cannot continue retrying
                // Attempt to convert or fail gracefully
                break
            }
        }

        // If we exited the loop with an unknown error or exhausted retries
        if let error = lastError {
            return .failure(error)
        }

        // This should never happen - operation should have either succeeded or failed
        // If we reach here, there's a bug in the retry logic
        fatalError("RetryManager completed without success or failure - this should never happen")
    }
}
