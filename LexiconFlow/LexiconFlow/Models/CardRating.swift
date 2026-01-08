//
//  CardRating.swift
//  LexiconFlow
//
//  Type-safe rating system with FSRS conversion
//  Eliminates magic numbers and provides single source of truth
//

import Foundation
import FSRS

/// User-facing card rating for reviews
///
/// This enum provides type safety and eliminates magic numbers
/// throughout the codebase. The values map to user actions:
/// - **Again**: I forgot this (reset to learning)
/// - **Hard**: I remembered but it was difficult
/// - **Good**: Normal recall, no issues
/// - **Easy**: I remembered this effortlessly
enum CardRating: Int, CaseIterable {
    /// User failed to recall, reset to learning state
    case again = 0

    /// User remembered but with significant effort
    case hard = 1

    /// Normal successful recall
    case good = 2

    /// Effortless recall, item is easy
    case easy = 3

    /// User-friendly label for UI display
    var label: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    /// System icon for UI display
    var iconName: String {
        switch self {
        case .again: return "xmark.circle.fill"
        case .hard: return "exclamationmark.triangle.fill"
        case .good: return "checkmark.circle.fill"
        case .easy: return "star.fill"
        }
    }

    /// Accent color for UI display
    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "blue"
        case .easy: return "green"
        }
    }

    /// Convert to FSRS Rating (1-4 scale)
    ///
    /// **Important**: FSRS uses 1-4 where:
    /// - 1 = Again (manual=0 exists but we don't use it)
    /// - 2 = Hard
    /// - 3 = Good
    /// - 4 = Easy
    var toFSRS: Rating {
        switch self {
        case .again: return Rating.again // FSRS value: 1
        case .hard: return Rating.hard // FSRS value: 2
        case .good: return Rating.good // FSRS value: 3
        case .easy: return Rating.easy // FSRS value: 4
        }
    }

    /// Create from FSRS Rating
    static func from(fsrs rating: Rating) -> CardRating {
        switch rating {
        case .manual: return .again // Should not happen, default to again
        case .again: return .again
        case .hard: return .hard
        case .good: return .good
        case .easy: return .easy
        }
    }

    /// Validate integer rating is in valid range
    static func validate(_ rating: Int) -> CardRating {
        guard let valid = CardRating(rawValue: rating) else {
            return .good // Default to good for invalid input
        }
        return valid
    }
}
