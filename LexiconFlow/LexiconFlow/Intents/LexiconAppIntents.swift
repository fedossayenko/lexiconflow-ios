//
//  LexiconAppIntents.swift
//  LexiconFlow
//
//  Defines App Intents for Shortcuts and Siri integration.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Study Intent

/// Intent to start a study session
struct StudyIntent: AppIntent {
    static var title: LocalizedStringResource = "Study Flashcards"
    static var description = IntentDescription("Starts a study session for due cards.")
    static var openAppWhenRun: Bool = true

    // Optional: Add parameter for specific deck if needed later

    @MainActor
    func perform() async throws -> some IntentResult {
        // Deep link handling logic will be in LexiconFlowApp
        // We return validation here.
        if let url = URL(string: "lexiconflow://study") {
            return .result(opensIntent: OpenURLIntent(url))
        } else {
            return .result()
        }
    }
}

// MARK: - Check Stats Intent

/// Intent to check study stats (suitable for Siri Snippets)
struct CheckStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Study Stats"
    static var description = IntentDescription("Shows your current streak and due cards.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Fetch stats from WidgetDataManager (fastest way, avoids spinning up full DB stack if possible,
        // but since this is in-app, we can also use StatisticsService if needed).
        // Using WidgetDataManager payload for O(1) access.

        let payload = WidgetDataManager.shared.getCurrentPayload()
        let streak = payload?.streakCount ?? 0
        let due = payload?.dueCount ?? 0

        let dialog = IntentDialog("You have a \(streak)-day streak and \(due) cards to review.")

        return .result(
            value: "Streak: \(streak), Due: \(due)",
            dialog: dialog
        )
    }
}

// MARK: - Shortcuts Provider

/// Registers default shortcuts for the app
struct LexiconShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StudyIntent(),
            phrases: [
                "Study with \(.applicationName)",
                "Review cards in \(.applicationName)",
                "Start session in \(.applicationName)"
            ],
            shortTitle: "Study Flashcards",
            systemImageName: "graduationcap.fill"
        )

        AppShortcut(
            intent: CheckStatsIntent(),
            phrases: [
                "Check my stats in \(.applicationName)",
                "How is my streak in \(.applicationName)",
                "Show due cards in \(.applicationName)"
            ],
            shortTitle: "Check Stats",
            systemImageName: "chart.bar.fill"
        )
    }
}
