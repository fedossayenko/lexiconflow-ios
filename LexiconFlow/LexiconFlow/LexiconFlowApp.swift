//
//  LexiconFlowApp.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct LexiconFlowApp: App {
    /// Shared SwiftData ModelContainer for the entire app
    /// - Persists to SQLite database (not in-memory)
    /// - CloudKit sync: DISABLED (will be enabled in Phase 4)
    /// - Falls back to in-memory storage if SQLite fails
    var sharedModelContainer: ModelContainer = {
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
            // If this somehow fails, we have no choice but to crash
            // This should never happen with an empty configuration
            logger.critical("Minimal container creation failed: \(error.localizedDescription)")
            fatalError("Could not create any ModelContainer: \(error)")
        }
    }()

    // Flag to check if we're using degraded storage
    private var isUsingDegradedStorage: Bool {
        // Check if container is in-memory or minimal
        // This can be used by ContentView to show warning UI
        sharedModelContainer.configurations.allSatisfy { $0.isStoredInMemoryOnly }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
