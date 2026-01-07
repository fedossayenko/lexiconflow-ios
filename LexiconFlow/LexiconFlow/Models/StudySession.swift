//
//  StudySession.swift
//  LexiconFlow
//
//  Study session tracking for analytics and progress monitoring
//

import SwiftData
import Foundation

/// A record of a complete study session
///
/// StudySession tracks when a user opens the study view, reviews cards,
/// and completes the session. This data is essential for:
/// - Statistics dashboard (study time, streaks, retention)
/// - Analytics and progress tracking
/// - Understanding user behavior patterns
/// - Performance monitoring
///
/// Each session contains:
/// - Start and end timestamps
/// - Number of cards reviewed
/// - Links to all reviews performed during the session
/// - Study mode (scheduled vs cram)
@Model
final class StudySession {
    /// Unique identifier for this session
    var id: UUID

    /// When the study session started
    var startTime: Date

    /// When the study session ended (nil until session completes)
    var endTime: Date?

    /// Number of cards reviewed during this session
    var cardsReviewed: Int

    /// Study mode used for this session
    /// - "scheduled": Standard FSRS scheduled reviews
    /// - "cram": Practice mode (doesn't update FSRS state)
    var modeEnum: String

    /// All reviews performed during this session
    /// - Deleting session cascades to disassociate reviews (kept for analytics)
    /// - Inverse defined on FlashcardReview to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify) var reviewsLog: [FlashcardReview] = []

    /// The deck studied in this session (optional - may be all cards)
    /// - Deleting deck sets this to nil (session history preserved)
    /// - Inverse defined on Deck.studySessions to avoid circular reference
    /// - SwiftData auto-initializes this property
    @Relationship(deleteRule: .nullify) var deck: Deck?

    /// The aggregated daily stats record for this session (optional)
    /// - Deleting DailyStats sets this to nil (session history preserved)
    /// - Inverse defined on DailyStats.studySessions
    /// - SwiftData auto-initializes this property
    /// - Populated by StatisticsService during aggregation
    @Relationship(deleteRule: .nullify) var dailyStats: DailyStats?

    // MARK: - Computed Properties

    /// Type-safe access to study mode enum
    var mode: StudyMode {
        get {
            switch modeEnum {
            case "scheduled": return .scheduled
            case "learning": return .learning
            case "cram": return .cram
            default: return .scheduled
            }
        }
        set {
            switch newValue {
            case .scheduled: modeEnum = "scheduled"
            case .learning: modeEnum = "learning"
            case .cram: modeEnum = "cram"
            }
        }
    }

    /// Duration of the study session in seconds
    /// - Returns 0 if session hasn't ended yet
    var durationSeconds: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }

    /// Human-readable duration (e.g., "5m 23s")
    var durationFormatted: String {
        let seconds = Int(durationSeconds)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes == 0 {
            return "\(remainingSeconds)s"
        } else if remainingSeconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    /// Whether this session is currently active
    var isActive: Bool {
        endTime == nil
    }

    // MARK: - Initialization

    /// Initialize a new study session
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - startTime: When session started (defaults to now)
    ///   - endTime: When session ended (nil for active sessions)
    ///   - cardsReviewed: Number of cards reviewed
    ///   - modeEnum: Study mode as string ("scheduled", "learning", or "cram")
    init(id: UUID = UUID(),
         startTime: Date = Date(),
         endTime: Date? = nil,
         cardsReviewed: Int = 0,
         modeEnum: String = "scheduled") {

        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.cardsReviewed = cardsReviewed
        self.modeEnum = modeEnum
    }

    /// Initialize with StudyMode enum
    convenience init(startTime: Date = Date(),
                     mode: StudyMode = .scheduled) {
        let modeString: String
        switch mode {
        case .scheduled: modeString = "scheduled"
        case .learning: modeString = "learning"
        case .cram: modeString = "cram"
        }

        self.init(id: UUID(),
                  startTime: startTime,
                  endTime: nil,
                  cardsReviewed: 0,
                  modeEnum: modeString)
    }
}
