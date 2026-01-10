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
        "Retry operation failed with unexpected error type: \(underlyingError.localizedDescription)"
    }

    init(_ error: any Error) {
        underlyingError = error
    }

    /// Create a type mismatch error with expected and actual type information
    ///
    /// Used when a retry operation throws an error that doesn't match the declared ErrorType.
    /// This indicates a programming error in the operation's type signature.
    ///
    /// - Parameters:
    ///   - expected: The expected error type name
    ///   - actual: The actual error type that was thrown
    /// - Returns: A RetryManagerError with descriptive information
    public static func typeMismatch(expected: String, actual: String) -> RetryManagerError {
        let error = NSError(
            domain: "com.lexiconflow.retrymanager",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Type mismatch: expected \(expected), got \(actual). Check operation signature.",
                "expectedType": expected,
                "actualType": actual
            ]
        )
        return RetryManagerError(error)
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
        var lastUntypedError: (any Error)?

        // Always execute at least once, then retry up to maxRetries times
        while attempt <= maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    logger.info("\(logContext): Succeeded on attempt \(attempt + 1)")
                }
                return .success(result)
            } catch let error as ErrorType {
                lastError = error
                lastUntypedError = nil
                guard isRetryable(error) else {
                    logger.error("\(logContext): Non-retryable error - \(error.localizedDescription)")
                    return .failure(error)
                }
                attempt += 1
                if attempt <= maxRetries {
                    logger.info("\(logContext): Retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries + 1))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1000000000))
                    delay *= 2
                } else {
                    logger.error("\(logContext): Failed after \(maxRetries) retries")
                    return .failure(error)
                }
            } catch {
                // Unexpected error type that doesn't match ErrorType
                // This could be CancellationError or other system errors
                lastUntypedError = error
                lastError = nil
                logger.warning("\(logContext): Unexpected error type '\(type(of: error))' - \(error.localizedDescription)")
                attempt += 1
                if attempt <= maxRetries {
                    logger.info("\(logContext): Retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries + 1))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1000000000))
                    delay *= 2
                }
            }
        }

        // Return appropriate error after exhausting retries
        if let error = lastError {
            logger.error("\(logContext): Failed after \(maxRetries) retries (typed error)")
            return .failure(error)
        }

        if let untypedError = lastUntypedError {
            logger.error("\(logContext): Failed with unexpected error type after \(maxRetries) retries")
            // Create a wrapper NSError for the untyped error
            let wrapperError = NSError(
                domain: "com.lexiconflow.retrymanager",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected error type during retry: \(untypedError.localizedDescription)",
                    "underlyingError": "\(untypedError)",
                    "expectedType": "\(ErrorType.self)",
                    "actualType": "\(type(of: untypedError))"
                ]
            )
            // Try to cast to ErrorType - if it fails, this indicates a programming error
            // in the operation's error type signature
            if let typedError = wrapperError as? ErrorType {
                return .failure(typedError)
            } else {
                // Programming error: operation signature doesn't match thrown errors
                logger.critical("\(logContext): Type mismatch - cannot wrap error as \(ErrorType.self)")
                // As last resort, use a force cast with swiftlint suppression
                // This WILL crash if ErrorType is incompatible, which surfaces the programming error
                // swiftlint:disable:next force_cast
                return .failure(wrapperError as! ErrorType)
            }
        }

        // Should never reach here, but handle gracefully
        logger.critical("\(logContext): No error captured after failed retries - logic error")
        let logicError = NSError(
            domain: "com.lexiconflow.retrymanager",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Retry logic error: completed retries without capturing error",
                "logContext": logContext
            ]
        )
        // swiftlint:disable:next force_cast
        return .failure(logicError as! ErrorType)
    }
}
