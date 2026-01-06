//
//  LexiconFlowApp.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
//

import SwiftUI
import SwiftData
import OSLog

/// Empty model for minimal fallback container when all storage attempts fail
@Model
final class EmptyModel {
    init() {}
}

@main
struct LexiconFlowApp: App {
    /// Scene phase for app lifecycle management
    @Environment(\.scenePhase) private var scenePhase
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
            FlashcardReview.self,
            GeneratedSentence.self
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

        // Create container with empty schema as absolute last resort
        // This prevents crash but allows error UI to be shown to the user
        // Empty schema means no models are available
        do {
            let minimalContainer = try ModelContainer(for: EmptyModel.self)
            logger.critical("Minimal container created successfully. App will run with no data persistence.")
            Analytics.trackIssue(
                "model_container_complete_failure",
                message: "All storage attempts failed, using minimal container"
            )
            return minimalContainer
        } catch {
            // If even the minimal container fails, we have no choice but to crash
            // This should never happen with a simple empty model
            logger.critical("Minimal container creation failed: \(error.localizedDescription)")
            fatalError("Could not create minimal ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    /// Handles app lifecycle phase changes.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Reset haptic engine when app goes to background to free resources
            HapticService.shared.reset()
        case .active:
            // Restart haptic engine when app returns to foreground
            if oldPhase == .background || oldPhase == .inactive {
                HapticService.shared.restartEngine()
            }
        default:
            break
        }
    }
}
