//
//  FirebaseService.swift
//  LexiconFlow
//
//  Firebase SDK integration for secure AI proxy authentication and App Check
//
//  **Purpose**: Centralizes Firebase initialization, authentication, and App Check token management
//  for secure communication with Firebase Cloud Functions.
//
//  **Architecture**:
//  - @MainActor isolation for thread-safe access
//  - Singleton pattern for shared instance
//  - Debug/production environment handling
//
//  **Security**:
//  - App Attest (production) or Debug Provider (development)
//  - Anonymous authentication for user identification
//  - Automatic App Check token refresh
//

import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import Foundation
import OSLog

/// Firebase service manager for secure backend communication
///
/// Provides centralized Firebase SDK initialization, anonymous authentication,
/// and App Check token management for Cloud Functions requests.
@MainActor
final class FirebaseService {
    // MARK: - Singleton

    static let shared = FirebaseService()

    private let logger = Logger(subsystem: "com.lexiconflow.firebase", category: "FirebaseService")

    // MARK: - Properties

    private(set) var isConfigured = false
    private(set) var currentUserID: String?

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }

    // MARK: - Configuration

    /// Configure Firebase SDK and App Check
    ///
    /// **Must be called once at app launch** (typically in AppDelegate or App init)
    ///
    /// - Important: Call this before any other Firebase operations
    func configure() {
        guard !self.isConfigured else {
            self.logger.warning("Firebase already configured, skipping")
            return
        }

        self.logger.info("Configuring Firebase...")

        // 1. Configure Firebase Core
        FirebaseApp.configure()

        // 2. Configure App Check (platform-specific)
        self.setupAppCheck()

        // 3. Set Functions region
        Functions.functions().region = "us-central1"

        #if DEBUG
            // Use emulator in development
            self.configureEmulator()
        #endif

        self.isConfigured = true
        self.logger.info("Firebase configured successfully")
    }

    /// Configure App Check provider (platform-specific)
    private func setupAppCheck() {
        #if DEBUG
            // Debug provider for development
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)

            // Log debug token for Firebase Console
            if let debugToken = providerFactory.debugToken() {
                self.logger.debug("🔐 App Check Debug Token: \(debugToken)")
                print("🔐 App Check Debug Token: \(debugToken)")
            }

            self.logger.info("App Check configured with debug provider")
        #else
            // App Attest for production
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            self.logger.info("App Check configured with App Attest")
        #endif
    }

    /// Configure Firebase emulator for local development
    private func configureEmulator() {
        // Functions emulator
        Functions.functions().useFunctionsEmulator(withOrigin: "http://localhost:5001")

        // Auth emulator (optional)
        // Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        self.logger.debug("Firebase emulator configured")
    }

    // MARK: - Authentication

    /// Get the current authenticated user ID
    ///
    /// Returns nil if no user is signed in
    var currentUserId: String? {
        self.currentUserID ?? Auth.auth().currentUser?.uid
    }

    /// Sign in anonymously (creates a new user ID or returns existing)
    ///
    /// - Returns: The anonymous user's UID
    /// - Throws: FirebaseAuthError if sign-in fails
    ///
    /// **Usage**:
    /// ```swift
    /// let userId = try await FirebaseService.shared.signInAnonymously()
    /// ```
    func signInAnonymously() async throws -> String {
        // Return existing user if already signed in
        if let existingUserId = currentUserId {
            self.logger.debug("Already signed in: \(existingUserId)")
            return existingUserId
        }

        self.logger.info("Signing in anonymously...")

        do {
            let authDataResult = try await Auth.auth().signInAnonymously()
            let uid = authDataResult.user.uid
            self.currentUserID = uid

            self.logger.info("Signed in anonymously: \(uid)")
            return uid
        } catch {
            self.logger.error("Anonymous auth failed: \(error.localizedDescription)")
            throw FirebaseAuthError.signInFailed(underlying: error)
        }
    }

    /// Sign out the current user
    ///
    /// **Note**: For anonymous auth, this creates a new user ID on next sign-in
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUserID = nil
            self.logger.info("Signed out")
        } catch {
            self.logger.error("Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - App Check

    /// Get a fresh App Check token for Cloud Functions requests
    ///
    /// - Returns: A valid App Check token string
    /// - Throws: AppCheckError if token retrieval fails
    ///
    /// **Usage**:
    /// ```swift
    /// let appCheckToken = try await FirebaseService.shared.getAppCheckToken()
    /// ```
    func getAppCheckToken() async throws -> String {
        self.logger.debug("Fetching App Check token...")

        do {
            // For high-cost operations, use limited-use token (single-use)
            let token = try await AppCheck.appCheck().limitedUseToken()

            self.logger.debug("App Check token retrieved successfully")
            return token.token
        } catch {
            self.logger.error("App Check token fetch failed: \(error.localizedDescription)")
            throw AppCheckError.tokenFetchFailed(underlying: error)
        }
    }

    /// Get a standard App Check token (for low-cost operations)
    ///
    /// - Returns: A valid App Check token string
    /// - Throws: AppCheckError if token retrieval fails
    ///
    /// **Note**: Standard tokens can be reused within their TTL (1 hour)
    func getStandardAppCheckToken() async throws -> String {
        self.logger.debug("Fetching standard App Check token...")

        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: false)

            self.logger.debug("Standard App Check token retrieved successfully")
            return token.token
        } catch {
            self.logger.error("Standard App Check token fetch failed: \(error.localizedDescription)")
            throw AppCheckError.tokenFetchFailed(underlying: error)
        }
    }

    // MARK: - Cloud Functions

    /// Get the shared Functions instance
    ///
    /// - Returns: Configured Functions client
    var functions: Functions {
        Functions.functions()
    }

    /// Call a Cloud Function with automatic App Check token injection
    ///
    /// - Parameters:
    ///   - functionName: Name of the Cloud Function to call
    ///   - data: Data to pass to the function
    /// - Returns: The function's response data
    /// - Throws: FunctionsError if the call fails
    ///
    /// **Usage**:
    /// ```swift
    /// let response = try await FirebaseService.shared.callFunction(
    ///     "translateV2",
    ///     data: ["texts": ["hello"], "sourceLanguage": "en"]
    /// )
    /// ```
    func callFunction(
        _ functionName: String,
        data: [String: Any]
    ) async throws -> [String: Any] {
        guard let userId = currentUserId else {
            self.logger.error("Not authenticated")
            throw FirebaseAuthError.notAuthenticated
        }

        self.logger.debug("Calling Cloud Function: \(functionName)")

        do {
            let result = try await functions.httpsCallable(functionName).call(data)

            guard let response = result.data as? [String: Any] else {
                throw FunctionsError.invalidResponse
            }

            self.logger.debug("Cloud Function '\(functionName)' succeeded")
            return response
        } catch let error as FunctionsError {
            logger.error("Cloud Function '\(functionName)' failed: \(error.localizedDescription)")
            throw error
        } catch {
            self.logger.error("Cloud Function '\(functionName)' failed: \(error.localizedDescription)")
            throw FunctionsError.unknown(underlying: error)
        }
    }
}

// MARK: - Errors

/// Firebase-related errors
enum FirebaseAuthError: LocalizedError {
    case notAuthenticated
    case signInFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Not authenticated with Firebase"
        case let .signInFailed(error):
            "Sign in failed: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            "Sign in to continue"
        case .signInFailed:
            "Check your network connection and try again"
        }
    }
}

/// App Check-related errors
enum AppCheckError: LocalizedError {
    case tokenFetchFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .tokenFetchFailed(error):
            "Failed to fetch App Check token: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .tokenFetchFailed:
            "Check your network connection and try again"
        }
    }
}

/// Cloud Functions-related errors
enum FunctionsError: LocalizedError {
    case invalidResponse
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Cloud Functions"
        case let .unknown(error):
            "Cloud Functions error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            "Try again later"
        case .unknown:
            "Check your network connection and try again"
        }
    }
}
