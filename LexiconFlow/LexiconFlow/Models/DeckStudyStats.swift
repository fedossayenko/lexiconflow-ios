//
//  DeckStudyStats.swift
//  LexiconFlow
//
//  Shared statistics model for deck study UI components
//

import Foundation

/// Statistics for a single deck used across multiple study views
///
/// Provides a consistent data structure for displaying deck statistics
/// in selection lists, detail views, and other study-related UI components.
struct DeckStudyStats {
    /// Number of new cards available to study
    var newCount: Int = 0

    /// Number of due cards available for review
    var dueCount: Int = 0

    /// Total number of cards in the deck
    var totalCount: Int = 0
}
