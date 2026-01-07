//
//  TimeoutHelper.swift
//  LexiconFlow
//
//  Timeout utility for async operations to prevent infinite hangs
//

import Foundation

/// Error thrown when an async operation exceeds its time limit
struct TimeoutError: LocalizedError {
    let duration: TimeInterval

    var errorDescription: String? {
        "Operation timed out after \(duration) seconds"
    }
}

/// Executes an async operation with a timeout limit
///
/// **Usage**:
/// ```swift
/// try await withTimeout(seconds: 10) {
///     // Your async operation here
///     try await someAsyncFunction()
/// }
/// ```
///
/// **Parameters**:
/// - seconds: Maximum duration to wait before timing out
/// - operation: The async operation to execute
///
/// **Returns**: The result of the operation if it completes in time
///
/// **Throws**: `TimeoutError` if the operation exceeds the time limit,
///            or rethrows any error from the operation itself
///
/// **Thread Safety**: This function uses `withThrowingTaskGroup` which is
///                   thread-safe and handles concurrent task execution
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(duration: seconds)
        }

        // Add operation task
        group.addTask {
            try await operation()
        }

        // Return first completed result
        guard let result = try await group.next() else {
            throw TimeoutError(duration: seconds)
        }
        group.cancelAll()
        return result
    }
}
