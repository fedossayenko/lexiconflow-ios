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
            StudySession.self,
            DailyStats.self,
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
            // Absolute last resort - if even empty model fails, crash is unavoidable
            logger.critical("Minimal container creation failed: \(error.localizedDescription)")
            Analytics.trackError("model_container_minimal_failed", error: error)
            // At this point, there's no way to recover - crash with clear message
            fatalError("Could not create minimal ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await ensureDefaultDeckExists()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    /// Ensures a default deck exists for new users
    @MainActor
    private func ensureDefaultDeckExists() async {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Deck>()
        let existingDecks = (try? context.fetch(descriptor)) ?? []

        if existingDecks.isEmpty {
            let defaultDeck = Deck(
                name: "My Vocabulary",
                icon: "book.fill",
                order: 0
            )
            context.insert(defaultDeck)
            try? context.save()
            Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
                .info("Created default deck: My Vocabulary")
            Analytics.trackEvent("default_deck_created")
        }
    }

    /// Handles app lifecycle phase changes.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Reset haptic engine when app goes to background to free resources
            HapticService.shared.reset()

            // Aggregate DailyStats from completed StudySession records
            // This runs in the background to prepare pre-aggregated statistics for dashboard
            Task {
                await aggregateDailyStatsInBackground()
            }
        case .active:
            // Restart haptic engine when app returns to foreground
            if oldPhase == .background || oldPhase == .inactive {
                HapticService.shared.restartEngine()
            }
        default:
            break
        }
    }

    /// Aggregate DailyStats from StudySession records in the background
    ///
    /// Called when app backgrounds to maintain pre-aggregated statistics for dashboard performance.
    /// This ensures the dashboard loads quickly even with large amounts of study data.
    ///
    /// **Why Background?**: Aggregation can be expensive with many sessions. Running it when
    /// the app backgrounds ensures it doesn't block UI interactions and completes before the
    /// next app launch.
    private func aggregateDailyStatsInBackground() async {
        let logger = Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")

        logger.debug("Starting background DailyStats aggregation")

        // Create a new background context for this operation
        // IMPORTANT: Create new context for background operations, not mainContext
        let context = ModelContext(sharedModelContainer)

        // Call StatisticsService to aggregate sessions
        do {
            let aggregatedCount = try await StatisticsService.shared.aggregateDailyStats(context: context)

            if aggregatedCount > 0 {
                logger.info("Background aggregation complete: \(aggregatedCount) days updated")
            } else {
                logger.debug("Background aggregation complete: No new sessions to aggregate")
            }
        } catch {
            logger.error("Background aggregation failed: \(error.localizedDescription)")
            Analytics.trackError("background_aggregate_daily_stats", error: error)
        }
    }
}
