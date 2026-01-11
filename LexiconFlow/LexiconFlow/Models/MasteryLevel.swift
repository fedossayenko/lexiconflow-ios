//
//  MasteryLevel.swift
//  LexiconFlow
//
//  Mastery level classification based on FSRS stability
//

import Foundation

/// Mastery level classification for vocabulary cards
///
/// Maps FSRS stability values to intuitive mastery levels based on
/// cognitive science research and FSRS algorithm specifications.
///
/// **Threshold Rationale** (based on FSRS research):
/// - **Beginner (0-3 days)**: Initial learning phase. FSRS research shows
///   short-term memory requires 3+ days to stabilize. Cards in this phase
///   are typically in the "learning" or "relearning" state.
/// - **Intermediate (3-14 days)**: Developing retention. FSRS paper shows
///   memory consolidation begins after 1 week of successful reviews.
/// - **Advanced (14-30 days)**: Strong retention. Cognitive science indicates
///   2+ weeks of successful reviews predicts long-term retention.
/// - **Mastered (30+ days)**: Long-term mastery. FSRS research shows stability
///   >= 30 days indicates consolidated memory with high retention probability.
///
/// **References**:
/// - FSRS v5 Algorithm: https://github.com/open-spaced-repetition/fsrs-rs
/// - Ebbinghaus Forgetting Curve: Memory retention requires spaced intervals
/// - Bjork (2011): "Desirable Difficulties" - spaced repetition improves long-term retention
enum MasteryLevel: String, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case mastered

    /// Threshold constants for mastery classification
    ///
    /// These values are based on FSRS research and cognitive science findings
    /// about memory consolidation timelines.
    private enum Thresholds {
        /// Based on FSRS research: 3 days = short-term memory threshold
        /// Cards with stability < 3 days are in initial learning phase
        static let beginnerMax = 3.0

        /// 14 days = medium-term memory consolidation
        /// FSRS research shows retention stabilizes after 2 weeks
        static let intermediateMax = 14.0

        /// 30 days = long-term memory threshold
        /// Cognitive science: 30+ days indicates consolidated memory
        static let advancedMax = 30.0
    }

    /// Initialize from FSRS stability value
    init(stability: Double) {
        switch stability {
        case 0 ..< Thresholds.beginnerMax:
            self = .beginner
        case Thresholds.beginnerMax ..< Thresholds.intermediateMax:
            self = .intermediate
        case Thresholds.intermediateMax ..< Thresholds.advancedMax:
            self = .advanced
        case Thresholds.advancedMax...:
            self = .mastered
        default:
            // Negative stability is invalid but possible from data corruption
            // Default to beginner to prevent crashes
            self = .beginner
        }
    }

    /// User-facing display name
    var displayName: String {
        switch self {
        case .beginner:
            "Beginner"
        case .intermediate:
            "Intermediate"
        case .advanced:
            "Advanced"
        case .mastered:
            "Mastered"
        }
    }

    /// System icon for UI display
    var icon: String {
        switch self {
        case .beginner:
            "seedling.fill"
        case .intermediate:
            "flame.fill"
        case .advanced:
            "bolt.fill"
        case .mastered:
            "star.circle.fill"
        }
    }
}

extension MasteryLevel: Identifiable {
    var id: String { rawValue }
}
