//
//  MockNetworkSession.swift
//  LexiconFlowTests
//
//  Mock NetworkSession for testing network behavior
//  Supports request recording, response stubbing, latency simulation, and error injection
//

import Foundation
import Testing

/// Mock implementation of NetworkSession for testing
///
/// Features:
/// - Stub specific responses by URL or request matcher
/// - Simulate network latency
/// - Inject errors for testing error handling
/// - Record all requests for verification
/// - Control behavior per-test with reset capability
actor MockNetworkSession: NetworkSession {

    // MARK: - Response Types

    /// Defines mock response behavior
    enum MockResponse: Sendable {
        /// Return success with data
        case success(Data)

        /// Return failure with error
        case failure(Error)

        /// Simulate network latency (in seconds)
        case latency(TimeInterval)

        /// Simulate specific HTTP status code
        case httpStatus(Int, Data? = nil)
    }

    // MARK: - Properties

    /// Stored mock responses keyed by URL string
    private var responses: [String: MockResponse] = [:]

    /// Default response when no specific mock is found
    private var defaultResponse: MockResponse?

    /// Recorded requests for verification
    private(set) var recordedRequests: [URLRequest] = []

    /// Enable/disable request recording
    var isRecordingEnabled: Bool = true

    // MARK: - Public Methods

    /// Initialize empty mock session
    init() {}

    /// Set mock response for specific URL
    ///
    /// - Parameters:
    ///   - url: The URL to match
    ///   - response: The mock response to return
    func setResponse(for url: String, response: MockResponse) {
        responses[url] = response
    }

    /// Set mock response using URL pattern
    ///
    /// - Parameters:
    ///   - pattern: String pattern to match in URL
    ///   - response: The mock response to return
    func setResponse(containing pattern: String, response: MockResponse) {
        responses[pattern] = response
    }

    /// Set default response for unmatched requests
    ///
    /// - Parameter response: The default mock response
    func setDefaultResponse(_ response: MockResponse) {
        self.defaultResponse = response
    }

    /// Clear all mock responses
    func clearResponses() {
        responses.removeAll()
        defaultResponse = nil
    }

    /// Clear recorded requests
    func clearRequests() {
        recordedRequests.removeAll()
    }

    /// Reset all state (responses and requests)
    func reset() {
        clearResponses()
        clearRequests()
        isRecordingEnabled = true
    }

    /// Get recorded requests matching URL pattern
    ///
    /// - Parameter pattern: String pattern to match
    /// - Returns: Array of matching requests
    func requests(containing pattern: String) -> [URLRequest] {
        recordedRequests.filter { request in
            request.url?.absoluteString.contains(pattern) ?? false
        }
    }

    /// Get number of requests to specific URL
    ///
    /// - Parameter url: The URL to count
    /// - Returns: Number of requests
    func requestCount(for url: String) -> Int {
        recordedRequests.filter { $0.url?.absoluteString == url }.count
    }

    // MARK: - NetworkSession Conformance

    /// Perform mock data request
    ///
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Tuple of (Data, URLResponse)
    /// - Throws: Mock errors based on configured responses
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Record request if enabled
        if isRecordingEnabled {
            recordedRequests.append(request)
        }

        // Find matching mock response
        let response = findResponse(for: request)

        // Handle response
        switch response {
        case .success(let data):
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (data, httpResponse)

        case .failure(let error):
            throw error

        case .latency(let seconds):
            // Simulate network delay
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (Data(), httpResponse)

        case .httpStatus(let statusCode, let data):
            let responseData = data ?? Data()
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (responseData, httpResponse)
        }
    }

    // MARK: - Private Methods

    /// Find mock response for request
    ///
    /// - Parameter request: The request to match
    /// - Returns: MockResponse or default if no match
    private func findResponse(for request: URLRequest) -> MockResponse {
        guard let urlString = request.url?.absoluteString else {
            return defaultResponse ?? .failure(NSError(domain: "MockNetworkSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URL in request"]))
        }

        // Try exact URL match
        if let response = responses[urlString] {
            return response
        }

        // Try partial match (longest pattern first)
        let sortedKeys = responses.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if urlString.contains(key) {
                return responses[key]!
            }
        }

        // Return default or error
        return defaultResponse ?? .failure(NSError(domain: "MockNetworkSession", code: -2, userInfo: [NSLocalizedDescriptionKey: "No mock response for URL: \(urlString)"]))
    }
}

// MARK: - Test Helpers

extension MockNetworkSession {
    /// Create successful JSON response
    ///
    /// - Parameter object: Encodable object to serialize
    /// - Returns: MockResponse.success with JSON data
    static func jsonResponse<T: Encodable>(_ object: T) -> MockResponse {
        do {
            let data = try JSONEncoder().encode(object)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    /// Create HTTP error response
    ///
    /// - Parameter statusCode: HTTP status code
    /// - Returns: MockResponse.httpStatus
    static func httpError(_ statusCode: Int) -> MockResponse {
        return .httpStatus(statusCode, nil)
    }

    /// Create network error
    ///
    /// - Parameter description: Error description
    /// - Returns: MockResponse.failure with NSError
    static func networkError(description: String) -> MockResponse {
        let error = NSError(
            domain: "MockNetworkSession",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
        return .failure(error)
    }
}
