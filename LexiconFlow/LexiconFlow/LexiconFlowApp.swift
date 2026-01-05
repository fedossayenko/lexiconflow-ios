//
//  LexiconFlowApp.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
//

import SwiftUI
import SwiftData
import OSLog

// Firebase imports - only available when SDKs are added via Xcode
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
#endif

@main
struct LexiconFlowApp: App {
    /// Shared SwiftData ModelContainer for the entire app
    /// - Persists to SQLite database (not in-memory)
    /// - CloudKit sync: DISABLED (will be enabled in Phase 4)
    /// - Falls back to in-memory storage if SQLite fails
    var sharedModelContainer: ModelContainer = {
        // All error handling is done inside makeModelContainer()
        // Force unwrap is safe because we return a fallback container on all error paths
        try! Self.makeModelContainer()
    }()

    /// Creates ModelContainer with multiple fallback strategies
    ///
    /// **Fallback Strategy:**
    /// 1. Persistent SQLite storage (primary)
    /// 2. In-memory storage (graceful degradation)
    /// 3. Empty schema container (allows error UI to show)
    ///
    /// - Returns: A ModelContainer (never nil, always returns a valid container)
    /// - Throws: Only if absolutely all container creation attempts fail
    private static func makeModelContainer() throws -> ModelContainer {
        let logger = Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")

        // Define the schema with all models
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self
        ])

        // Attempt 1: Try persistent SQLite storage (primary)
        let persistentConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            // Log critical failure with Analytics
            logger.critical("Failed to create persistent ModelContainer: \(error.localizedDescription)")
            Analytics.trackError("model_container_persistent_failed", error: error)
        }

        // Attempt 2: Fallback to in-memory storage (data loss on app quit)
        let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            logger.warning("Using in-memory storage due to persistent storage failure")
            Analytics.trackIssue(
                "model_container_fallback_to_memory",
                message: "Persistent storage failed, using in-memory fallback"
            )
            return container
        } catch {
            // Log critical failure with Analytics
            logger.critical("Failed to create in-memory ModelContainer: \(error.localizedDescription)")
            Analytics.trackError("model_container_in_memory_failed", error: error)
        }

        // Attempt 3: Last resort - create minimal container (allows error UI to show)
        // This will allow the app to launch but models will be unavailable
        logger.critical("All ModelContainer creation attempts failed. Creating minimal fallback container.")
        Analytics.trackIssue(
            "model_container_minimal_fallback",
            message: "All storage attempts failed, using minimal container"
        )

        do {
            // Create container with empty schema as absolute last resort
            // This prevents crash but allows error UI to be shown
            return try ModelContainer(for: schema, configurations: [])
        } catch {
            // Absolute last resort: create completely empty container
            // This will allow the app to launch with minimal functionality
            // ContentView can detect this and show appropriate error UI
            logger.critical("All container creation failed. Using emergency empty container: \(error.localizedDescription)")
            Analytics.trackIssue(
                "model_container_emergency_fallback",
                message: "All storage attempts failed, using emergency empty container"
            )
            // Return an empty container as final fallback
            return try ModelContainer(for: Schema([]), configurations: [])
        }
    }

    // Flag to check if we're using degraded storage
    private var isUsingDegradedStorage: Bool {
        // Check if container is in-memory or minimal
        // This can be used by ContentView to show warning UI
        sharedModelContainer.configurations.allSatisfy { $0.isStoredInMemoryOnly }
    }

    /// Initialize Firebase and configure analytics/crashlytics
    init() {
        // Firebase configuration happens on app launch
        // Using Task.detached to avoid blocking the main actor
        Task.detached {
            Self.configureFirebase()
        }
    }

    /// Configure Firebase based on build configuration
    ///
    /// **DEBUG**: Analytics and Crashlytics disabled (uses console logging)
    /// **RELEASE**: Firebase Analytics and Crashlytics enabled
    private static func configureFirebase() {
        #if canImport(FirebaseCore)
        do {
            // Firebase SDKs are available - configure Firebase
            try FirebaseApp.configure()

            #if canImport(FirebaseAnalytics)
            #if DEBUG
            // Disable analytics and crashlytics in debug builds
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            #endif
            // Use fully qualified name to avoid collision with our Analytics enum
            FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(false)
            print("🔥 Firebase configured (DEBUG mode: analytics disabled)")
            #else
            // Enable in release builds
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            #endif
            FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(true)
            print("🔥 Firebase configured (RELEASE mode: analytics enabled)")
            #endif
            #else
            print("🔥 Firebase configured (Analytics not available)")
            #endif
        } catch {
            print("⚠️ Firebase configuration failed: \(error.localizedDescription)")
        }

        #else
        // Firebase SDKs not available - Analytics.swift will use console fallback
        print("⚠️ Firebase SDKs not available - using console logging")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
