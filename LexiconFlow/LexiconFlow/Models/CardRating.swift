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
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    /// System icon for UI display
    var iconName: String {
        switch self {
        case .again: "xmark.circle.fill"
        case .hard: "exclamationmark.triangle.fill"
        case .good: "checkmark.circle.fill"
        case .easy: "star.fill"
        }
    }

    /// Accent color for UI display
    var color: String {
        switch self {
        case .again: "red"
        case .hard: "orange"
        case .good: "blue"
        case .easy: "green"
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
        case .again: Rating.again // FSRS value: 1
        case .hard: Rating.hard // FSRS value: 2
        case .good: Rating.good // FSRS value: 3
        case .easy: Rating.easy // FSRS value: 4
        }
    }

    /// Create from FSRS Rating
    static func from(fsrs rating: Rating) -> CardRating {
        switch rating {
        case .manual: .again // Should not happen, default to again
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
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
