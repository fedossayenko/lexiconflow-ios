//
//  LexiconFlowApp.swift
//  LexiconFlow
//
//  Created by Fedir Saienko on 4.01.26.
//

import SwiftUI
import SwiftData

@main
struct LexiconFlowApp: App {
    /// Shared SwiftData ModelContainer for the entire app
    /// - Persists to SQLite database (not in-memory)
    /// - CloudKit sync: DISABLED (will be enabled in Phase 4)
    var sharedModelContainer: ModelContainer = {
        // Define the SwiftData schema with all models
        // Order matters: dependencies must be listed before dependents
        let schema = Schema([
            FSRSState.self,  // Algorithm state (referenced by Card)
            Card.self,       // Core vocabulary card
            Deck.self,       // Card container/organizer
            ReviewLog.self,  // Review history (referenced by Card)
        ])

        // Configure persistent storage (SQLite on disk)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            // Create the model container with our schema
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fatal error is appropriate here because app cannot function without persistence
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
