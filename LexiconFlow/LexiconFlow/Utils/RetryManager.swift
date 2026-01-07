//
//  RetryManager.swift
//  LexiconFlow
//
//  Generic retry manager with exponential backoff
//  Handles transient errors (rate limits, network issues)
//

import Foundation
import OSLog

/// Wrapper error for type-mismatched errors in retry operations
///
/// When an operation throws an error that doesn't match the expected ErrorType,
/// this wrapper preserves the original error while conforming to the required type.
public struct RetryManagerError: Error {
    /// The underlying error that couldn't be typed
    public let underlyingError: any Error

    /// Human-readable description
    public var localizedDescription: String {
        return "Retry operation failed with unexpected error type: \(underlyingError.localizedDescription)"
    }

    init(_ error: any Error) {
        self.underlyingError = error
    }
}

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
/// - Type-safe error handling with wrapper for mismatches
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
                // This is a programming error - operation should throw ErrorType
                logger.error("\(logContext): Operation threw unexpected error type - \(error.localizedDescription)")
                // Cannot continue without typed error for Result return type
                // Exit loop and return last known error or fail
                break
            }
        }

        // Return the last error if we have one
        if let error = lastError {
            return .failure(error)
        }

        // If we reach here, operation repeatedly threw non-ErrorType errors
        // This indicates a programming error in the operation signature
        // Log critical failure and return an error if possible
        logger.critical("\(logContext): Operation signature mismatch - cannot convert errors to expected type")
        // Since we can't create an arbitrary ErrorType, we need to try one more time
        // and let any type mismatch crash at runtime (programming error)
        do {
            return .success(try await operation())
        } catch let error as ErrorType {
            return .failure(error)
        } catch {
            // Programming error: operation signature doesn't match declared ErrorType
            // This should never happen in production with correct type annotations
            fatalError("Operation threw \(type(of: error)) but expected \(ErrorType.self). Check operation signature.")
        }
    }
}
