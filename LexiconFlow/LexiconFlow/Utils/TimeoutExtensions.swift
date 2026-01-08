//
//  TimeoutExtensions.swift
//  LexiconFlow
//
//  Timeout utilities for Swift Concurrency
//  Provides withTimeout() wrapper for async operations
//

import Foundation

/// Error thrown when an operation times out
enum TimeoutError: Error, Sendable {
    case timedOut(TimeInterval)
}

extension TimeoutError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .timedOut(seconds):
            return "Operation timed out after \(seconds) seconds"
        }
    }
}

/// Execute an async operation with a timeout
///
/// - Parameters:
///   - seconds: Maximum duration to wait before timing out
///   - operation: The async operation to execute
///
/// - Returns: The result of the operation
///
/// - Throws: `TimeoutError.timedOut` if the operation doesn't complete within the specified duration
///
/// **Example:**
/// ```swift
/// try await withTimeout(seconds: 5) {
///     try await slowOperation()
/// }
/// ```
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the operation task
        group.addTask {
            try await operation()
        }

        // Add the timeout task
        group.addTask { [seconds] in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1000000000))
            throw TimeoutError.timedOut(seconds)
        }

        // Return the first result (either operation success or timeout)
        // Safe to unwrap because we know at least one task will complete
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut(seconds)
        }

        // Cancel the other task
        group.cancelAll()

        return result
    }
}
