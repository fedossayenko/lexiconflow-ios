//
//  NetworkSession.swift
//  LexiconFlow
//
//  Protocol for network session abstraction
//  Enables testing with MockNetworkSession
//

import Foundation

/// Protocol for network session abstraction
///
/// This protocol abstracts URLSession to enable:
/// - Dependency injection for testing
/// - Mock network responses in unit tests
/// - Recording and inspection of network requests
///
/// Conformance: URLSession automatically conforms via extension
public protocol NetworkSession: Sendable {
    /// Perform data task with URLRequest
    ///
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Tuple of (Data, URLResponse)
    /// - Throws: Network errors from the underlying session
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extend URLSession to conform to NetworkSession
///
/// This enables URLSession.shared to be used wherever NetworkSession is required
extension URLSession: NetworkSession {}
