//
//  MasteryLevel.swift
//  LexiconFlow
//
//  Mastery level classification based on FSRS stability
//

import Foundation

/// Mastery level classification for vocabulary cards
///
/// Maps FSRS stability values to intuitive mastery levels:
/// - **Beginner**: 0-3 days (new cards, short-term retention)
/// - **Intermediate**: 3-14 days (developing retention)
/// - **Advanced**: 14-30 days (strong retention)
/// - **Mastered**: 30+ days (long-term mastery)
enum MasteryLevel: String, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case mastered

    /// Initialize from FSRS stability value
    init(stability: Double) {
        switch stability {
        case 0 ..< 3.0:
            self = .beginner
        case 3.0 ..< 14.0:
            self = .intermediate
        case 14.0 ..< 30.0:
            self = .advanced
        default:
            self = .mastered
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
