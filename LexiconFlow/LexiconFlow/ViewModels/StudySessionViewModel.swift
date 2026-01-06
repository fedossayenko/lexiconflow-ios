//
//  StudySessionViewModel.swift
//  LexiconFlow
//
//  Manages study session state and coordinates with Scheduler
//

import Foundation
import SwiftData
import Combine

// MARK: - StudySessionError

/// Errors that can occur during a study session
enum StudySessionError: LocalizedError, Sendable {
    case reviewSaveFailed(underlying: String)
    case invalidRating(Int)

    var errorDescription: String? {
        switch self {
        case .reviewSaveFailed:
            return "Failed to save review. Please try again."
        case .invalidRating(let rating):
            return "Invalid rating: \(rating). Must be between 0 and 3."
        }
    }

    var failureReason: String? {
        switch self {
        case .reviewSaveFailed(let message):
            return "Underlying error: \(message)"
        case .invalidRating:
            return "Rating value out of valid range (0-3)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .reviewSaveFailed:
            return "Try again. If the problem persists, check your network connection and storage."
        case .invalidRating:
            return "Only use the rating buttons provided (Again, Hard, Good, Easy)."
        }
    }
}

/// Manages the state of an active study session
@MainActor
final class StudySessionViewModel: ObservableObject {
    private let scheduler: Scheduler
    private let mode: StudyMode
    private let decks: [Deck]

    @Published private(set) var cards: [Flashcard] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isComplete = false
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: Error?

    /// The current card being displayed
    var currentCard: Flashcard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    /// Progress through the session (e.g., "3 / 20")
    var progress: String {
        "\(currentIndex + 1) / \(cards.count)"
    }

    /// Whether there are more cards to review
    var hasMoreCards: Bool {
        currentIndex < cards.count
    }

    /// Initialize with multiple decks for study session
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - decks: Array of decks to study from (empty array = no cards)
    ///   - mode: Study mode (scheduled or learning)
    init(modelContext: ModelContext, decks: [Deck] = [], mode: StudyMode) {
        self.mode = mode
        self.decks = decks
        self.scheduler = Scheduler(modelContext: modelContext)
    }

    /// Load cards for the study session
    func loadCards() {
        cards = scheduler.fetchCards(for: decks, mode: mode, limit: 20)
        currentIndex = 0
        isComplete = cards.isEmpty
    }

    /// Submit a rating for a specific card
    func submitRating(_ rating: Int, card: Flashcard) async {
        guard !isProcessing else {
            return
        }

        // Validate rating is within FSRS range (0-3)
        guard (0...3).contains(rating) else {
            lastError = StudySessionError.invalidRating(rating)
            return
        }

        isProcessing = true
        defer {
            isProcessing = false
        }

        // Capture result and check for errors
        let result = await scheduler.processReview(
            flashcard: card,
            rating: rating,
            mode: mode
        )

        // Only advance if the review was saved successfully
        guard result != nil else {
            lastError = StudySessionError.reviewSaveFailed(
                underlying: "Review processing failed - check logs for details"
            )
            return
        }

        // Clear any previous error on success
        lastError = nil
        currentIndex += 1

        if currentIndex >= cards.count {
            isComplete = true
        }
    }

    /// Preview the due dates for all rating options
    func previewRatings() async -> [Int: Date] {
        guard let card = currentCard else { return [:] }
        return await scheduler.previewRatings(for: card)
    }

    /// Reset the session (e.g., to start over)
    func reset() {
        currentIndex = 0
        isComplete = false
    }
}

// MARK: - Backward Compatibility

extension StudySessionViewModel {
    /// Convenience initializer for single-deck sessions (backward compatibility)
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - deck: Single deck to study from (nil = no cards)
    ///   - mode: Study mode (scheduled or learning)
    convenience init(modelContext: ModelContext, deck: Deck?, mode: StudyMode) {
        if let deck = deck {
            self.init(modelContext: modelContext, decks: [deck], mode: mode)
        } else {
            self.init(modelContext: modelContext, decks: [], mode: mode)
        }
    }
}
