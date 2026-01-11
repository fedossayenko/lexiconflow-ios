//
//  WidgetDataManager.swift
//  LexiconFlow
//
//  Manages shared data for Widgets and App Intents using App Groups.
//

import Foundation
import OSLog
import WidgetKit

/// A manager for synchronizing extensive app state with Widget Extensions and App Intents.
///
/// This singleton manages writing `WidgetPayload` data to the App Group container so that
/// extensions (which run in a separate process) can display up-to-date information.
final class WidgetDataManager {
    /// Shared singleton instance
    static let shared = WidgetDataManager()

    /// Logger for widget data operations
    private let logger = Logger(subsystem: "com.lexiconflow.LexiconFlow", category: "WidgetDataManager")

    /// App Group Identifier
    /// Ideally this should come from a configuration file or plist, but hardcoded for now.
    /// Format: group.{bundleId}
    private let appGroupId = "group.com.lexiconflow.LexiconFlow"

    /// UserDefaults suite for the App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: self.appGroupId)
    }

    // MARK: - Keys

    private enum Keys {
        static let payload = "widget_payload_v1"
    }

    private init() {}

    // MARK: - Public API

    /// Writes the latest stats to shared storage and reloads widget timelines.
    /// - Parameters:
    ///   - dueCount: Number of cards due for review immediately.
    ///   - streakCount: Current study streak in days.
    ///   - lastStudyDate: The timestamp of the last completed review.
    func updateStats(dueCount: Int, streakCount: Int, lastStudyDate: Date?) {
        let payload = WidgetPayload(
            dueCount: dueCount,
            streakCount: streakCount,
            lastStudyDate: lastStudyDate,
            updatedAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(payload)
            self.sharedDefaults?.set(data, forKey: Keys.payload)
            self.logger.info("Successfully updated widget payload: Due=\(dueCount), Streak=\(streakCount)")

            // Reload all widgets
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.logger.error("Failed to encode WidgetPayload: \(error.localizedDescription)")
        }
    }

    /// Reads the current payload from shared storage.
    /// Useful for Widgets to fetch data synchronously.
    func getCurrentPayload() -> WidgetPayload? {
        guard let data = sharedDefaults?.data(forKey: Keys.payload) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WidgetPayload.self, from: data)
        } catch {
            self.logger.error("Failed to decode WidgetPayload: \(error.localizedDescription)")
            return nil
        }
    }
}

/// The data model shared between App and Widgets
struct WidgetPayload: Codable {
    /// Number of cards pending review
    let dueCount: Int

    /// Current daily streak
    let streakCount: Int

    /// When the user last studied
    let lastStudyDate: Date?

    /// When this payload was written
    let updatedAt: Date
}
