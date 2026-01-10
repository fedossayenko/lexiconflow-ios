//
//  LexiconFlowApp.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
//

import OSLog
import SwiftData
import SwiftUI
import UIKit

/// Empty model for minimal fallback container when all storage attempts fail
@Model
final class EmptyModel {
    init() {}
}

@main
struct LexiconFlowApp: App {
    /// Pre-initialized empty container for absolute worst case fallback
    /// This is used when even runtime container creation fails
    ///
    /// **Fallback Strategy:**
    /// 1. Try standard in-memory container with EmptyModel
    /// 2. Try minimal container with empty schema
    /// 3. Last resort: accept that SwiftData is broken and return truly minimal container
    private static let emptyFallbackContainer: ModelContainer = {
        let logger = Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        // Attempt 1: Standard in-memory container with EmptyModel
        if let container = try? ModelContainer(for: EmptyModel.self, configurations: configuration) {
            return container
        }

        // Attempt 2: Minimal schema configuration (no models)
        let minimalConfig = ModelConfiguration(
            schema: Schema([]),
            isStoredInMemoryOnly: true,
            allowsSave: false
        )

        if let container = try? ModelContainer(for: EmptyModel.self, configurations: minimalConfig) {
            logger.critical("Using minimal fallback container - SwiftData partially broken")
            return container
        }

        // Attempt 3: Empty schema only (no EmptyModel)
        if let container = try? ModelContainer(for: Schema([]), configurations: [minimalConfig]) {
            logger.critical("Using empty schema container - SwiftData severely broken")
            return container
        }

        // Attempt 4: Absolute last resort with diagnostic
        // At this point SwiftData is fundamentally broken on this device
        let diagnostic = """
        FATAL: SwiftData cannot create any ModelContainer.
        This indicates a corrupted iOS installation or incompatible device.
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        #if DEBUG
            // In DEBUG builds, crash immediately for diagnostics
            fatalError(diagnostic)
        #else
            // In RELEASE, log critical error and attempt one final time
            // This will likely crash, but with better diagnostics
            logger.critical("\(diagnostic)")

            // Final attempt: this WILL crash if SwiftData is broken, but that's unavoidable
            // The app cannot function without ANY container
            do {
                return try ModelContainer(for: EmptyModel.self, configurations: configuration)
            } catch {
                logger.critical("Final fallback attempt failed: \(error.localizedDescription)")
                // We must return something - this will crash on first use but with clear logging
                return try! ModelContainer(for: EmptyModel.self, configurations: configuration)
            }
        #endif
    }()

    /// Scene phase for app lifecycle management
    @Environment(\.scenePhase) private var scenePhase

    /// Background task for aggregating DailyStats
    @State private var aggregationTask: Task<Void, Never>?
    /// Shared SwiftData ModelContainer for the entire app
    /// - Persists to SQLite database (not in-memory)
    /// - CloudKit sync: DISABLED (will be enabled in Phase 4)
    /// - Migration: Automatic lightweight migration (SwiftData handles schema changes)
    ///
    /// **Migration History (Lightweight Migrations Handled Automatically by SwiftData):**
    /// - V1 → V2: Added `translation: String?` field to Flashcard
    /// - V2 → V3: Added `cefrLevel: String?` field to Flashcard
    /// - V3 → V4: Added `lastReviewDate: Date?` field to FSRSState
    /// - V3 → V4: Added `GeneratedSentence` and `DailyStats` models
    ///
    /// **Lightweight Migration Criteria:**
    /// SwiftData automatically handles migrations that:
    /// - Add new properties (optional or with default values)
    /// - Remove properties
    /// - Add new models
    /// - Remove empty models
    ///
    /// All LexiconFlow schema changes meet these criteria, so no explicit migration plan is needed.
    var sharedModelContainer: ModelContainer = {
        let logger = Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")

        // Define the schema with all models
        // SwiftData automatically handles lightweight migrations
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
            StudySession.self,
            DailyStats.self,
            GeneratedSentence.self,
            CachedTranslation.self
        ])

        // Attempt 1: Try persistent SQLite storage (primary)
        let persistentConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            // Log critical failure
            logger.critical("Failed to create persistent ModelContainer: \(error.localizedDescription)")
            Analytics.trackError("model_container_persistent_failed", error: error)
        }

        // Attempt 2: Fallback to in-memory storage (data loss on app quit)
        let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            logger.warning("Using in-memory storage due to persistent storage failure")
            Analytics.trackEvent("model_container_in_memory_fallback")
            return container
        } catch {
            // Log critical failure
            logger.critical("Failed to create in-memory ModelContainer: \(error.localizedDescription)")
            Analytics.trackError("model_container_in_memory_failed", error: error)
        }

        // Attempt 3: Last resort - create minimal container (allows error UI to show)
        // This will allow the app to launch but models will be unavailable
        logger.critical("All ModelContainer creation attempts failed. Creating minimal fallback container.")

        // Create container with empty schema as absolute last resort
        // This prevents crash but allows error UI to be shown to the user
        // Empty schema means no models are available
        do {
            let minimalContainer = try ModelContainer(for: EmptyModel.self)
            logger.critical("Minimal container created successfully. App will run with no data persistence.")
            Analytics.trackEvent("model_container_minimal_fallback")
            return minimalContainer
        } catch {
            // Last resort: return pre-initialized empty container
            // User will see error UI but app won't crash
            logger.critical("All ModelContainer creation attempts failed: \(error.localizedDescription)")
            Analytics.trackIssue(
                "model_container_utter_failure",
                message: "Even minimal container failed, using pre-initialized empty container"
            )
            // Return pre-initialized empty container - app will show error UI to user
            return emptyFallbackContainer
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(self.preferredColorScheme)
                .task {
                    await self.ensureDefaultDeckExists()
                    await self.ensureIELTSVocabularyExists()

                    // Clear expired translation cache
                    await QuickTranslationService.shared.clearExpiredCache(container: self.sharedModelContainer)
                }
        }
        .modelContainer(self.sharedModelContainer)
        .onChange(of: self.scenePhase) { oldPhase, newPhase in
            self.handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    /// Returns the preferred color scheme based on user settings
    private var preferredColorScheme: ColorScheme? {
        switch AppSettings.darkMode {
        case .system:
            nil // Follow system preference
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// Ensures a default deck exists for new users
    @MainActor
    private func ensureDefaultDeckExists() async {
        let context = self.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Deck>()
        let existingDecks: [Deck]
        do {
            existingDecks = try context.fetch(descriptor)
        } catch {
            Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
                .error("Failed to fetch existing decks: \(error.localizedDescription)")
            Analytics.trackError("fetch_existing_decks_failed", error: error)
            return
        }

        if existingDecks.isEmpty {
            let defaultDeck = Deck(
                name: "My Vocabulary",
                icon: "book.fill",
                order: 0
            )
            context.insert(defaultDeck)
            do {
                try context.save()
                Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
                    .info("Created default deck: My Vocabulary")
                Analytics.trackEvent("default_deck_created")
            } catch {
                Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
                    .error("Failed to save default deck: \(error.localizedDescription)")
                Analytics.trackError("save_default_deck_failed", error: error)
            }
        }
    }

    /// Ensures IELTS vocabulary decks exist on first launch
    ///
    /// **Workflow**:
    /// 1. Check if pre-population flag is true (early return)
    /// 2. Check if IELTS decks already exist (handles re-install)
    /// 3. Import vocabulary automatically if needed
    /// 4. Set flag after successful import
    /// 5. Track success/failure with Analytics
    ///
    /// **Idempotent**: Safe to call multiple times, only imports once
    /// **Background**: Runs async to avoid blocking app launch
    /// **Graceful Degradation**: Logs errors but doesn't crash app
    @MainActor
    private func ensureIELTSVocabularyExists() async {
        // Don't import if already completed
        guard !AppSettings.hasPrepopulatedIELTS else {
            Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")
                .debug("IELTS vocabulary already pre-populated, skipping")
            return
        }

        let context = self.sharedModelContainer.mainContext
        let logger = Logger(subsystem: "com.lexiconflow.app", category: "LexiconFlowApp")

        // Check if IELTS decks already exist (handles re-install scenario)
        let deckManager = IELTSDeckManager(modelContext: context)
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        let existingDecks = levels.filter { level in
            deckManager.deckExists(for: level)
        }

        if !existingDecks.isEmpty {
            logger.info("Found \(existingDecks.count) existing IELTS decks, marking as pre-populated")
            AppSettings.hasPrepopulatedIELTS = true
            return
        }

        logger.info("Starting automatic IELTS vocabulary pre-population")

        do {
            // Check if vocabulary file exists
            guard Bundle.main.url(
                forResource: "ielts-vocabulary-smartool",
                withExtension: "json"
            ) != nil else {
                logger.error("IELTS vocabulary file not found in bundle")
                Analytics.trackError("ielts_file_missing", error: IELTSImportError.fileNotFound)
                return // Don't set flag - will retry on next launch
            }

            // Import vocabulary in background
            let importer = IELTSVocabularyImporter(modelContext: context)
            let result = try await importer.importAllVocabulary()

            // Mark as completed
            AppSettings.hasPrepopulatedIELTS = true

            logger.info("""
            ✅ IELTS vocabulary pre-population complete:
            - Imported: \(result.importedCount)
            - Failed: \(result.failedCount)
            - Duration: \(String(format: "%.2f", result.duration))s
            """)

            Analytics.trackEvent("ielts_auto_import_complete", metadata: [
                "imported_count": "\(result.importedCount)",
                "failed_count": "\(result.failedCount)",
                "duration_seconds": String(format: "%.2f", result.duration)
            ])

        } catch {
            logger.error("❌ IELTS vocabulary pre-population failed: \(error.localizedDescription)")

            Analytics.trackError("ielts_auto_import_failed", error: error)

            // Don't set flag - will retry on next launch
            // App remains functional with default deck
        }
    }

    /// Handles app lifecycle phase changes.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Reset haptic engine when app goes to background to free resources
            HapticService.shared.reset()

            // Deactivate audio session to prevent AVAudioSession error 4099
            SpeechService.shared.cleanup()

            // Aggregate DailyStats from completed StudySession records
            // This runs in the background to prepare pre-aggregated statistics for dashboard
            // Cancel any existing aggregation task before starting a new one
            self.aggregationTask?.cancel()
            self.aggregationTask = Task {
                await self.aggregateDailyStatsInBackground()
            }
        case .active:
            // Restart haptic engine when app returns to foreground
            if oldPhase == .background || oldPhase == .inactive {
                HapticService.shared.restartEngine()

                // Reactivate audio session for text-to-speech
                SpeechService.shared.restartEngine()
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
