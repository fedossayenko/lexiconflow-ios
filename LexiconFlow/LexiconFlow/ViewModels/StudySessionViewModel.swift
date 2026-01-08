//
//  StudySessionViewModel.swift
//  LexiconFlow
//
//  Manages study session state and coordinates with Scheduler
//

import Foundation
import SwiftData
import Combine
import OSLog

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
    private let modelContext: ModelContext
    private let decks: [Deck]
    private let logger = Logger(subsystem: "com.lexiconflow.session", category: "StudySessionViewModel")

    @Published private(set) var cards: [Flashcard] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isComplete = false
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: Error?

    /// The current study session record (created when cards are loaded)
    private var currentStudySession: StudySession?

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
        self.modelContext = modelContext
        self.decks = decks
        self.scheduler = Scheduler(modelContext: modelContext)
    }

    /// Load cards for the study session
    func loadCards() {
        cards = scheduler.fetchCards(for: decks, mode: mode, limit: AppSettings.studyLimit)
        currentIndex = 0
        isComplete = cards.isEmpty

        // Create study session record if cards were loaded
        if !cards.isEmpty {
            createStudySession()
        }
    }

    /// Create a new StudySession record
    private func createStudySession() {
        let session = StudySession(startTime: Date(), mode: mode)
        modelContext.insert(session)

        do {
            try modelContext.save()
            currentStudySession = session
            logger.info("Created study session: \(session.id)")
        } catch {
            Analytics.trackError("create_study_session", error: error)
            logger.error("Failed to create study session: \(error)")
            // Continue without session tracking - don't block study
        }
    }

    /// Finalize the study session (set end time and card count)
    func finalizeSession() {
        guard let session = currentStudySession, session.isActive else {
            return
        }

        session.endTime = Date()
        session.cardsReviewed = currentIndex

        do {
            try modelContext.save()
            logger.info("Finalized study session: \(session.id) with \(self.currentIndex) cards")
        } catch {
            Analytics.trackError("finalize_study_session", error: error)
            logger.error("Failed to finalize study session: \(error)")
        }

        currentStudySession = nil
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
            mode: mode,
            studySession: currentStudySession
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
            // Auto-finalize when session completes
            finalizeSession()
        }
    }

    /// Preview the due dates for all rating options
    func previewRatings() async -> [Int: Date] {
        guard let card = currentCard else { return [:] }
        return await scheduler.previewRatings(for: card)
    }

    /// Reset the session (e.g., to start over)
    func reset() {
        // Finalize existing session if active
        finalizeSession()

        // Reset state
        currentIndex = 0
        isComplete = false
    }

    /// Clean up when view is dismissed (finalizes session if still active)
    func cleanup() {
        finalizeSession()
    }
}
