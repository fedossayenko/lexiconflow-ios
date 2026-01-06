//
//  Scheduler.swift
//  LexiconFlow
//
//  Main scheduler API for coordinating FSRS operations with SwiftData
//  Provides high-level interface for review processing
//
//  Updated to use DTO pattern from FSRSWrapper for better concurrency
//

import Foundation
import SwiftData
import OSLog

/// Study mode determines how cards are selected and processed
enum StudyMode: Sendable {
    /// Scheduled mode: Cards due for review based on FSRS algorithm
    /// - Updates FSRS state after each review
    /// - Respects due dates and intervals
    case scheduled

    /// Learning mode: New cards only (initial learning phase)
    /// - Updates FSRS state after each review
    /// - Cards go through learning steps before graduating to review state
    /// - Ordered by creation date (oldest first)
    case learning

    /// Cram mode: Review cards regardless of due date
    /// - Does NOT update FSRS state (for temporary review)
    /// - Selects cards by lowest stability (least learned)
    case cram
}

/// Scheduler for managing card reviews and study sessions
///
/// This class provides the main interface for:
/// - Fetching cards for study (scheduled or cram mode)
/// - Processing card reviews with FSRS algorithm
/// - Creating review logs
///
/// **Architecture**: Runs on @MainActor to safely mutate SwiftData models.
/// Receives DTOs from FSRSWrapper actor and applies updates on main thread.
@MainActor
final class Scheduler {
    /// The SwiftData model context
    private let modelContext: ModelContext

    /// Logger for scheduler operations
    private let logger = Logger(subsystem: "com.lexiconflow.scheduler", category: "Scheduler")

    /// Initialize scheduler with a model context
    ///
    /// - Parameter modelContext: SwiftData model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Card Fetching

    /// Fetch cards ready for study
    ///
    /// - Parameters:
    ///   - mode: Study mode (scheduled, learning, or cram)
    ///   - limit: Maximum number of cards to return (defaults to AppSettings.studyLimit)
    /// - Returns: Array of flashcards ready for review
    func fetchCards(mode: StudyMode = .scheduled, limit: Int? = nil) -> [Flashcard] {
        let effectiveLimit = limit ?? AppSettings.studyLimit
        switch mode {
        case .scheduled:
            return fetchDueCards(limit: effectiveLimit)
        case .learning:
            return fetchNewCards(limit: effectiveLimit)
        case .cram:
            return fetchCramCards(limit: effectiveLimit)
        }
    }

    /// Fetch cards that are due for scheduled review
    ///
    /// Due cards are those that need review (review/learning/relearning states).
    /// New cards are excluded as they haven't been learned yet.
    ///
    /// - Parameter limit: Maximum number of cards to return
    /// - Returns: Array of due flashcards, sorted by due date ascending
    private func fetchDueCards(limit: Int) -> [Flashcard] {
        let now = Date()
        let predicate = #Predicate<FSRSState> { state in
            state.dueDate <= now && state.stateEnum != "new"
        }
        let sortBy = [SortDescriptor(\FSRSState.dueDate, order: .forward)]
        return fetchCards(limit: limit, predicate: predicate, sortBy: sortBy, errorName: "fetch_due_cards")
    }

    /// Fetch cards for cram mode (lowest stability first)
    ///
    /// Cram mode ignores due dates and selects cards that need
    /// the most review based on stability (memory strength).
    /// Includes new cards so they can be studied immediately.
    ///
    /// - Parameter limit: Maximum number of cards to return
    /// - Returns: Array of flashcards sorted by stability ascending
    private func fetchCramCards(limit: Int) -> [Flashcard] {
        let sortBy = [SortDescriptor(\FSRSState.stability, order: .forward)]
        return fetchCards(limit: limit, predicate: nil, sortBy: sortBy, errorName: "fetch_cram_cards")
    }

    /// Fetch new cards for initial learning phase
    ///
    /// New cards are those that have never been reviewed (stateEnum == "new").
    /// These cards go through FSRS learning steps before graduating to review state.
    ///
    /// - Parameter limit: Maximum number of cards to return
    /// - Returns: Array of new flashcards, sorted by creation date ascending (oldest first)
    private func fetchNewCards(limit: Int) -> [Flashcard] {
        // Fetch states where stateEnum == "new"
        let predicate = #Predicate<FSRSState> { state in
            state.stateEnum == "new"
        }

        // Use sort descriptor at database level for better performance
        var stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: predicate,
            sortBy: [SortDescriptor(\FSRSState.card?.createdAt, order: .forward)]
        )

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards, logging any nil relationships
            let cards = states.compactMap { state -> Flashcard? in
                if let card = state.card {
                    return card
                } else {
                    logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
            }

            return Array(cards.prefix(limit))
        } catch {
            Analytics.trackError("fetch_new_cards", error: error)
            logger.error("Error fetching new cards: \(error)")
            return []
        }
    }

    /// Generic fetch method for cards with configurable predicate and sort
    ///
    /// - Parameters:
    ///   - limit: Maximum number of cards to return
    ///   - predicate: Optional predicate to filter FSRS states
    ///   - sortBy: Sort descriptors for ordering
    ///   - errorName: Name for error tracking
    /// - Returns: Array of flashcards matching the criteria
    private func fetchCards(
        limit: Int,
        predicate: Predicate<FSRSState>?,
        sortBy: [SortDescriptor<FSRSState>],
        errorName: String
    ) -> [Flashcard] {
        var stateDescriptor = FetchDescriptor<FSRSState>(sortBy: sortBy)
        if let predicate = predicate {
            stateDescriptor.predicate = predicate
        }

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards, logging any nil relationships
            let cards = states.compactMap { state -> Flashcard? in
                if let card = state.card {
                    return card
                } else {
                    logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
            }

            return Array(cards.prefix(limit))
        } catch {
            Analytics.trackError(errorName, error: error)
            logger.error("Error fetching cards: \(error)")
            return []
        }
    }

    /// Count total due cards
    ///
    /// Due cards are those that need review (review/learning/relearning states).
    /// New cards are excluded as they haven't been learned yet.
    ///
    /// - Returns: Number of cards currently due for review
    func dueCardCount() -> Int {
        let now = Date()

        // Count cards with dueDate <= now, excluding new cards
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.dueDate <= now && state.stateEnum != "new"
            }
        )

        do {
            return try modelContext.fetchCount(stateDescriptor)
        } catch {
            Analytics.trackError("due_card_count", error: error)
            logger.error("Error counting due cards: \(error)")
            return 0
        }
    }

    /// Count total new cards available for learning
    ///
    /// New cards are those that have never been reviewed (stateEnum == "new").
    ///
    /// - Returns: Number of new cards awaiting initial review
    func newCardCount() -> Int {
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum == "new"
            }
        )

        do {
            return try modelContext.fetchCount(stateDescriptor)
        } catch {
            Analytics.trackError("new_card_count", error: error)
            logger.error("Error counting new cards: \(error)")
            return 0
        }
    }

    // MARK: - Review Processing

    /// Process a flashcard review
    ///
    /// This method:
    /// 1. Calls the FSRS algorithm to get updated state values (via DTO)
    /// 2. Applies the updates to the SwiftData flashcard model
    /// 3. Updates the lastReviewDate cache
    /// 4. Creates a FlashcardReview entry
    /// 5. Saves changes to the database
    ///
    /// In cram mode, the rating is logged but FSRS state is NOT updated.
    /// In scheduled or learning mode, FSRS state is updated based on rating.
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard being reviewed
    ///   - rating: The user's rating (0=Again, 1=Hard, 2=Good, 3=Easy)
    ///   - mode: Study mode (scheduled, learning, or cram)
    /// - Returns: The created FlashcardReview entry (or nil if save failed)
    func processReview(
        flashcard: Flashcard,
        rating: Int,
        mode: StudyMode = .scheduled
    ) async -> FlashcardReview? {
        let now = Date()

        // Validate: flashcard must have FSRSState for non-cram modes
        guard mode == .cram || flashcard.fsrsState != nil else {
            logger.error("Cannot process review: FSRSState is nil for \(flashcard.word)")
            return nil
        }

        // In cram mode, only log the review without updating FSRS
        if mode == .cram {
            // Calculate actual elapsed days for analytics accuracy
            let elapsedDays = flashcard.fsrsState?.lastReviewDate != nil
                ? DateMath.elapsedDays(since: flashcard.fsrsState!.lastReviewDate!)
                : 0

            let log = FlashcardReview(
                rating: rating,
                reviewDate: now,
                scheduledDays: 0, // No scheduling in cram mode
                elapsedDays: elapsedDays
            )
            log.card = flashcard
            modelContext.insert(log)

            // CRITICAL: Propagate save errors instead of silent failure
            do {
                try modelContext.save()
                return log
            } catch {
                Analytics.trackError("save_cram_review", error: error, metadata: [
                    "rating": "\(rating)",
                    "card": flashcard.word
                ])
                logger.error("Failed to save cram review: \(error)")
                // In production: show user alert
                return nil
            }
        }

        // In scheduled or learning mode, run the FSRS algorithm
        do {
            // Get DTO from FSRSWrapper actor
            let result = try await FSRSWrapper.shared.processReview(
                flashcard: flashcard,
                rating: rating,
                now: now
            )

            // Apply the DTO updates to our SwiftData model
            applyFSRSResult(result, to: flashcard, at: now)

            // Create review log
            let log = FlashcardReview(
                rating: rating,
                reviewDate: now,
                scheduledDays: result.scheduledDays,
                elapsedDays: result.elapsedDays
            )
            log.card = flashcard
            modelContext.insert(log)

            // Save changes
            try modelContext.save()

            Analytics.trackEvent("card_reviewed", metadata: [
                "rating": "\(rating)",
                "state": result.stateEnum,
                "stability": String(format: "%.2f", result.stability),
                "difficulty": String(format: "%.2f", result.difficulty)
            ])

            return log
        } catch {
            Analytics.trackError("process_review", error: error, metadata: [
                "rating": "\(rating)",
                "card": flashcard.word
            ])
            logger.error("Error processing review: \(error)")
            return nil
        }
    }

    /// Apply FSRS result DTO to a flashcard model
    ///
    /// **Performance**: Updates lastReviewDate cache for O(1) future access.
    /// **Concurrency**: Runs on @MainActor, safe to mutate SwiftData models.
    ///
    /// - Parameters:
    ///   - result: The FSRSReviewResult DTO from FSRSWrapper
    ///   - flashcard: The flashcard to update
    ///   - now: Current time (for lastReviewDate cache)
    private func applyFSRSResult(_ result: FSRSReviewResult, to flashcard: Flashcard, at now: Date) {
        // Get or create FSRSState
        let state: FSRSState
        if let existingState = flashcard.fsrsState {
            state = existingState
        } else {
            state = FSRSState(
                stability: result.stability,
                difficulty: result.difficulty,
                retrievability: result.retrievability,
                dueDate: result.dueDate,
                stateEnum: result.stateEnum
            )
            modelContext.insert(state)
            flashcard.fsrsState = state
        }

        // Apply updates from DTO
        state.stability = result.stability
        state.difficulty = result.difficulty
        state.retrievability = result.retrievability
        state.dueDate = result.dueDate
        state.stateEnum = result.stateEnum

        // PERFORMANCE: Update cache for next time (O(1) access)
        state.lastReviewDate = now
    }

    /// Preview the due dates for all 4 rating options
    ///
    /// This allows the UI to show users what will happen with each rating
    /// before they actually rate the card.
    ///
    /// - Parameter flashcard: The flashcard to preview
    /// - Returns: Dictionary mapping ratings to due dates
    func previewRatings(for flashcard: Flashcard) async -> [Int: Date] {
        return await FSRSWrapper.shared.previewRatings(flashcard: flashcard)
    }

    /// Reset a flashcard to new state (forgetting)
    ///
    /// This is useful for relearning cards or starting over.
    ///
    /// - Parameter flashcard: The flashcard to reset
    /// - Returns: True if save succeeded, false otherwise
    @discardableResult
    func resetFlashcard(_ flashcard: Flashcard) async -> Bool {
        do {
            // Get DTO from FSRSWrapper actor
            let result = await FSRSWrapper.shared.resetFlashcard(flashcard)

            // Apply the DTO updates
            if let state = flashcard.fsrsState {
                state.stability = result.stability
                state.difficulty = result.difficulty
                state.retrievability = result.retrievability
                state.dueDate = result.dueDate
                state.stateEnum = result.stateEnum
                state.lastReviewDate = nil // Reset last review on forget
            }

            try modelContext.save()

            Analytics.trackEvent("card_reset", metadata: [
                "card": flashcard.word
            ])

            return true
        } catch {
            Analytics.trackError("reset_card", error: error, metadata: [
                "card": flashcard.word
            ])
            logger.error("Failed to save reset: \(error)")
            return false
        }
    }
}
