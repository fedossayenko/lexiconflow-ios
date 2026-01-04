//
//  StudySessionViewModel.swift
//  LexiconFlow
//
//  Manages study session state and coordinates with Scheduler
//

import Foundation
import SwiftData
import Combine

/// Manages the state of an active study session
@MainActor
final class StudySessionViewModel: ObservableObject {
    private let scheduler: Scheduler
    private let mode: StudyMode

    @Published private(set) var cards: [Flashcard] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isComplete = false
    @Published private(set) var isProcessing = false

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

    init(modelContext: ModelContext, mode: StudyMode) {
        self.mode = mode
        self.scheduler = Scheduler(modelContext: modelContext)
    }

    /// Load cards for the study session
    func loadCards() {
        cards = scheduler.fetchCards(mode: mode, limit: 20)
        currentIndex = 0
        isComplete = cards.isEmpty
    }

    /// Submit a rating for the current card
    func submitRating(_ rating: Int) async {
        guard let card = currentCard, !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        _ = await scheduler.processReview(
            flashcard: card,
            rating: rating,
            mode: mode
        )

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
