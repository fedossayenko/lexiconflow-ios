//
//  FSRSConstants.swift
//  LexiconFlow
//
//  Constants for FSRS state to eliminate magic strings
//  Provides type-safe alternatives to string literals
//

import Foundation

/// FSRS-related constants for type safety
enum FSRSConstants {
    /// Raw value for "new" card state
    static let newStateRawValue = FlashcardState.new.rawValue

    /// Raw value for "learning" card state
    static let learningStateRawValue = FlashcardState.learning.rawValue

    /// Raw value for "review" card state
    static let reviewStateRawValue = FlashcardState.review.rawValue

    /// Raw value for "relearning" card state
    static let relearningStateRawValue = FlashcardState.relearning.rawValue

    /// All state raw values for comparison
    static let allStateRawValues: Set<String> = [
        newStateRawValue,
        learningStateRawValue,
        reviewStateRawValue,
        relearningStateRawValue
    ]

    /// Validate if a string is a valid state
    static func isValidState(_ value: String) -> Bool {
        allStateRawValues.contains(value)
    }
}

/// SwiftData predicate helpers for FSRS queries
enum FSRSPredicates {
    /// Predicate for cards that are due (not new and due date passed)
    static var dueCardsPredicate: String {
        "dueDate <= now AND stateEnum != '\(FSRSConstants.newStateRawValue)'"
    }

    /// Predicate for cards that are not new (for cram mode)
    static var notNewPredicate: String {
        "stateEnum != '\(FSRSConstants.newStateRawValue)'"
    }
}
