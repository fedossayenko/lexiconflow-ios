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
import OSLog
import SwiftData

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

    /// Cram mode: Practice mode that doesn't update FSRS state
    /// - Only logs reviews for analytics
    /// - Doesn't modify due dates or intervals
    case cram
}

/// Deck statistics containing due, new, and total card counts
///
/// **Performance**: Single-fetch aggregation eliminates 3 separate O(n) queries
/// **Usage**: Returned by `fetchDeckStatistics(for:)` for efficient deck list rendering
struct DeckStatistics: Sendable {
    /// Number of cards currently due for review
    let due: Int

    /// Number of new cards awaiting initial review
    let new: Int

    /// Total number of cards in the deck
    let total: Int
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
    ///   - deck: Optional deck to filter cards (nil = all decks)
    ///   - mode: Study mode (scheduled, learning, or cram)
    ///   - limit: Maximum number of cards to return (defaults to AppSettings.studyLimit)
    /// - Returns: Array of flashcards ready for review
    func fetchCards(for deck: Deck? = nil, mode: StudyMode = .scheduled, limit: Int? = nil) -> [Flashcard] {
        let effectiveLimit = limit ?? AppSettings.studyLimit
        switch mode {
        case .scheduled:
            return fetchDueCards(for: deck, limit: effectiveLimit)
        case .learning:
            return fetchNewCards(for: deck, limit: effectiveLimit)
        case .cram:
            return fetchCramCards(for: deck, limit: effectiveLimit)
        }
    }

    /// Fetch cards ready for study from multiple decks
    ///
    /// - Parameters:
    ///   - decks: Array of decks to filter cards (empty = no cards)
    ///   - mode: Study mode (scheduled, learning, or cram)
    ///   - limit: Maximum number of cards to return (defaults to AppSettings.studyLimit)
    /// - Returns: Array of flashcards ready for review from selected decks
    func fetchCards(for decks: [Deck], mode: StudyMode = .scheduled, limit: Int? = nil) -> [Flashcard] {
        // Early return: no decks selected
        guard !decks.isEmpty else {
            logger.info("No decks selected, returning empty card list")
            return []
        }

        let effectiveLimit = limit ?? AppSettings.studyLimit
        switch mode {
        case .scheduled:
            return fetchDueCards(for: decks, limit: effectiveLimit)
        case .learning:
            return fetchNewCards(for: decks, limit: effectiveLimit)
        case .cram:
            return fetchCramCards(for: decks, limit: effectiveLimit)
        }
    }

    /// Fetch cards that are due for scheduled review
    ///
    /// Due cards are those that need review (review/learning/relearning states).
    /// New cards are excluded as they haven't been learned yet.
    ///
    /// - Parameters:
    ///   - deck: Optional deck to filter cards (nil = all decks)
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of due flashcards, sorted by due date ascending
    private func fetchDueCards(for deck: Deck? = nil, limit: Int) -> [Flashcard] {
        let now = Date()

        // Capture deck ID for in-memory filtering
        let deckID = deck?.id

        // Query FSRSState at DB level for due cards (simple predicate)
        let statePredicate = #Predicate<FSRSState> { state in
            state.dueDate <= now && state.stateEnum != "new"
        }

        let sortBy = [SortDescriptor(\FSRSState.dueDate, order: .forward)]
        var stateDescriptor = FetchDescriptor<FSRSState>(sortBy: sortBy)
        stateDescriptor.predicate = statePredicate

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by deck in-memory (avoid multi-level optional in predicate)
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Filter by deck in-memory
                if let deckID, card.deck?.id != deckID {
                    return nil
                }
                return card
            }

            return Array(cards.prefix(limit))
        } catch {
            Analytics.trackError("fetch_due_cards", error: error)
            logger.error("Error fetching due cards: \(error)")
            return []
        }
    }

    /// Fetch new cards for initial learning phase
    ///
    /// New cards are those that have never been reviewed (stateEnum == "new").
    /// These cards go through FSRS learning steps before graduating to review state.
    ///
    /// - Parameters:
    ///   - deck: Optional deck to filter cards (nil = all decks)
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of new flashcards, sorted by creation date ascending (oldest first)
    private func fetchNewCards(for deck: Deck? = nil, limit: Int) -> [Flashcard] {
        // Capture deck ID for in-memory filtering
        let deckID = deck?.id

        // Query FSRSState at DB level for new cards (simple predicate)
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum == "new"
            }
        )

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by deck in-memory (avoid multi-level optional in predicate)
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Filter by deck in-memory
                if let deckID, card.deck?.id != deckID {
                    return nil
                }
                return card
            }

            // Sort by creation date (oldest first)
            let sorted = cards.sorted { $0.createdAt < $1.createdAt }
            return Array(sorted.prefix(limit))
        } catch {
            Analytics.trackError("fetch_new_cards", error: error)
            logger.error("Error fetching new cards: \(error)")
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

    // MARK: - Deck Statistics

    /// Fetch deck statistics with single-query aggregation
    ///
    /// **Performance**: Eliminates 3 separate O(n) queries by aggregating in one pass
    /// **Optimization**: Fetches all deck states once, calculates due/new/total counts in-memory
    ///
    /// - Parameter deck: The deck to fetch statistics for
    /// - Returns: DeckStatistics containing due, new, and total card counts
    func fetchDeckStatistics(for deck: Deck) -> DeckStatistics {
        let deckID = deck.id
        let now = Date()

        // Fetch all states for this deck in a single query
        // Note: SwiftData limitations with multi-level optionals prevent deck filtering at DB level
        let stateDescriptor = FetchDescriptor<FSRSState>()

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Filter to this deck and aggregate all counts in a single pass
            var due = 0, new = 0, total = 0

            for state in states {
                guard let card = state.card else { continue }
                guard card.deck?.id == deckID else { continue }

                total += 1

                if state.stateEnum == FlashcardState.new.rawValue {
                    new += 1
                } else if state.dueDate <= now {
                    due += 1
                }
            }

            return DeckStatistics(due: due, new: new, total: total)

        } catch {
            Analytics.trackError("deck_statistics_fetch", error: error)
            logger.error("Error fetching deck statistics: \(error)")
            return DeckStatistics(due: 0, new: 0, total: 0)
        }
    }

    /// Fetch statistics for multiple decks in a single query
    ///
    /// **Performance Optimization**: Eliminates N+1 query problem in deck list rendering
    /// Instead of 3 queries per deck (N*3 total), performs 1 query for all decks
    ///
    /// - Parameter decks: Array of decks to fetch statistics for
    /// - Returns: Dictionary mapping deck ID to DeckStatistics
    func fetchDeckStatistics(for decks: [Deck]) -> [UUID: DeckStatistics] {
        let deckIDs = Set(decks.map(\.id))
        let now = Date()

        // Single query fetches all states for all requested decks
        let stateDescriptor = FetchDescriptor<FSRSState>()

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Group by deck in memory (O(n) where n = total states across all decks)
            var results: [UUID: DeckStatistics] = [:]

            for state in states {
                guard let card = state.card else { continue }
                guard let cardDeckID = card.deck?.id else { continue }
                guard deckIDs.contains(cardDeckID) else { continue }

                // Get current stats (or create new)
                let current = results[cardDeckID] ?? DeckStatistics(due: 0, new: 0, total: 0)

                // Accumulate counts
                var newDue = current.due
                var newCards = current.new
                let newTotal = current.total + 1

                if state.stateEnum == FlashcardState.new.rawValue {
                    newCards += 1
                } else if state.dueDate <= now {
                    newDue += 1
                }

                results[cardDeckID] = DeckStatistics(due: newDue, new: newCards, total: newTotal)
            }

            // Fill in empty decks with zeros (decks with no cards)
            for deck in decks where results[deck.id] == nil {
                results[deck.id] = DeckStatistics(due: 0, new: 0, total: 0)
            }

            return results

        } catch {
            Analytics.trackError("deck_statistics_batch_fetch", error: error)
            logger.error("Error fetching batch deck statistics: \(error)")

            // Return zero stats for all decks on error
            var errorResults: [UUID: DeckStatistics] = [:]
            for deck in decks {
                errorResults[deck.id] = DeckStatistics(due: 0, new: 0, total: 0)
            }
            return errorResults
        }
    }

    /// Count due cards for a specific deck
    ///
    /// - Parameter deck: The deck to count cards for
    /// - Returns: Number of cards currently due for review in the deck
    func dueCardCount(for deck: Deck) -> Int {
        fetchDeckStatistics(for: deck).due
    }

    /// Count new cards for a specific deck
    ///
    /// - Parameter deck: The deck to count cards for
    /// - Returns: Number of new cards awaiting initial review in the deck
    func newCardCount(for deck: Deck) -> Int {
        fetchDeckStatistics(for: deck).new
    }

    /// Count total cards for a specific deck
    ///
    /// - Parameter deck: The deck to count cards for
    /// - Returns: Total number of cards in the deck
    func totalCardCount(for deck: Deck) -> Int {
        fetchDeckStatistics(for: deck).total
    }

    /// Fetch cards for cram (practice) mode from a single deck
    ///
    /// Cram mode returns all cards for practice without considering due dates.
    /// Reviews are logged but FSRS state is not updated.
    ///
    /// - Parameters:
    ///   - deck: Optional deck to filter cards (nil = all decks)
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of flashcards for cram practice
    private func fetchCramCards(for deck: Deck? = nil, limit: Int) -> [Flashcard] {
        let deckID = deck?.id

        // Query all cards (no state filter for cram mode)
        let stateDescriptor = FetchDescriptor<FSRSState>()

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by deck in-memory
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Filter by deck in-memory
                if let deckID, card.deck?.id != deckID {
                    return nil
                }
                return card
            }

            // Randomize order for variety in cram mode
            // Use O(k) randomSample instead of O(n) shuffled().prefix for better performance
            return cards.randomSample(limit)
        } catch {
            Analytics.trackError("fetch_cram_cards", error: error)
            logger.error("Error fetching cram cards: \(error)")
            return []
        }
    }

    // MARK: - Multi-Deck Card Fetching

    /// Fetch cards that are due for scheduled review from multiple decks
    ///
    /// - Parameters:
    ///   - decks: Array of decks to filter cards
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of due flashcards, sorted by due date ascending
    private func fetchDueCards(for decks: [Deck], limit: Int) -> [Flashcard] {
        let now = Date()

        // Extract deck IDs for in-memory filtering
        let deckIDs = Set(decks.map(\.id))

        // Query FSRSState at DB level for due cards (simple predicate)
        let statePredicate = #Predicate<FSRSState> { state in
            state.dueDate <= now && state.stateEnum != "new"
        }

        let sortBy = [SortDescriptor(\FSRSState.dueDate, order: .forward)]
        var stateDescriptor = FetchDescriptor<FSRSState>(sortBy: sortBy)
        stateDescriptor.predicate = statePredicate

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by selected decks in-memory
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Only include cards from selected decks
                guard let deckID = card.deck?.id, deckIDs.contains(deckID) else {
                    return nil
                }
                return card
            }

            return Array(cards.prefix(limit))
        } catch {
            Analytics.trackError("fetch_due_cards_multi", error: error)
            logger.error("Error fetching due cards for multiple decks: \(error)")
            return []
        }
    }

    /// Fetch new cards for initial learning phase from multiple decks
    ///
    /// - Parameters:
    ///   - decks: Array of decks to filter cards
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of new flashcards, sorted by creation date ascending (oldest first)
    private func fetchNewCards(for decks: [Deck], limit: Int) -> [Flashcard] {
        // Extract deck IDs for in-memory filtering
        let deckIDs = Set(decks.map(\.id))

        // Query FSRSState at DB level for new cards (simple predicate)
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum == "new"
            }
        )

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by selected decks in-memory
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Only include cards from selected decks
                guard let deckID = card.deck?.id, deckIDs.contains(deckID) else {
                    return nil
                }
                return card
            }

            // Sort by creation date (oldest first)
            let sorted = cards.sorted { $0.createdAt < $1.createdAt }
            return Array(sorted.prefix(limit))
        } catch {
            Analytics.trackError("fetch_new_cards_multi", error: error)
            logger.error("Error fetching new cards for multiple decks: \(error)")
            return []
        }
    }

    /// Fetch cards for cram (practice) mode from multiple decks
    ///
    /// Cram mode returns all cards for practice without considering due dates.
    /// Reviews are logged but FSRS state is not updated.
    ///
    /// - Parameters:
    ///   - decks: Array of decks to filter cards
    ///   - limit: Maximum number of cards to return
    /// - Returns: Array of flashcards for cram practice
    private func fetchCramCards(for decks: [Deck], limit: Int) -> [Flashcard] {
        let deckIDs = Set(decks.map(\.id))

        // Query all cards (no state filter for cram mode)
        let stateDescriptor = FetchDescriptor<FSRSState>()

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Convert to cards and filter by selected decks in-memory
            let cards = states.compactMap { state -> Flashcard? in
                guard let card = state.card else {
                    self.logger.warning("FSRSState with nil card relationship detected")
                    return nil
                }
                // Only include cards from selected decks
                guard let deckID = card.deck?.id, deckIDs.contains(deckID) else {
                    return nil
                }
                return card
            }

            // Randomize order for variety in cram mode
            // Use O(k) randomSample instead of O(n) shuffled().prefix for better performance
            return cards.randomSample(limit)
        } catch {
            Analytics.trackError("fetch_cram_cards_multi", error: error)
            logger.error("Error fetching cram cards for multiple decks: \(error)")
            return []
        }
    }

    // MARK: - Multi-Deck Counting

    /// Count total due cards across multiple decks
    ///
    /// - Parameter decks: Array of decks to count cards for
    /// - Returns: Number of cards currently due for review in selected decks
    func dueCardCount(for decks: [Deck]) -> Int {
        guard !decks.isEmpty else { return 0 }

        let now = Date()
        let deckIDs = Set(decks.map(\.id))

        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.dueDate <= now && state.stateEnum != "new"
            }
        )

        do {
            let states = try modelContext.fetch(stateDescriptor)
            return states.count(where: { state in
                guard let card = state.card else { return false }
                guard let deckID = card.deck?.id else { return false }
                return deckIDs.contains(deckID)
            })
        } catch {
            Analytics.trackError("due_card_count_multi", error: error)
            logger.error("Error counting due cards for multiple decks: \(error)")
            return 0
        }
    }

    /// Count total new cards across multiple decks
    ///
    /// - Parameter decks: Array of decks to count cards for
    /// - Returns: Number of new cards awaiting initial review in selected decks
    func newCardCount(for decks: [Deck]) -> Int {
        guard !decks.isEmpty else { return 0 }

        let deckIDs = Set(decks.map(\.id))

        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum == "new"
            }
        )

        do {
            let states = try modelContext.fetch(stateDescriptor)
            return states.count(where: { state in
                guard let card = state.card else { return false }
                guard let deckID = card.deck?.id else { return false }
                return deckIDs.contains(deckID)
            })
        } catch {
            Analytics.trackError("new_card_count_multi", error: error)
            logger.error("Error counting new cards for multiple decks: \(error)")
            return 0
        }
    }

    /// Count total cards across multiple decks
    ///
    /// - Parameter decks: Array of decks to count cards for
    /// - Returns: Total number of cards in selected decks
    func totalCardCount(for decks: [Deck]) -> Int {
        guard !decks.isEmpty else { return 0 }

        let deckIDs = Set(decks.map(\.id))

        let stateDescriptor = FetchDescriptor<FSRSState>()

        do {
            let states = try modelContext.fetch(stateDescriptor)

            // Filter by deck in-memory
            return states.count(where: { state in
                guard let card = state.card else { return false }
                guard let deckID = card.deck?.id else { return false }
                return deckIDs.contains(deckID)
            })
        } catch {
            Analytics.trackError("total_card_count_multi", error: error)
            logger.error("Error counting total cards for multiple decks: \(error)")
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
    /// 4. Creates a FlashcardReview entry linked to the study session
    /// 5. Saves changes to the database
    ///
    /// - Parameters:
    ///   - flashcard: The flashcard being reviewed
    ///   - rating: The user's rating (0=Again, 1=Hard, 2=Good, 3=Easy)
    ///   - mode: Study mode (scheduled, learning, or cram)
    ///   - studySession: The active study session (optional, for analytics)
    /// - Returns: The created FlashcardReview entry (or nil if save failed)
    func processReview(
        flashcard: Flashcard,
        rating: Int,
        mode: StudyMode = .scheduled,
        studySession: StudySession? = nil
    ) async -> FlashcardReview? {
        let now = Date()

        // Validate: flashcard must have FSRSState
        guard flashcard.fsrsState != nil else {
            logger.error("Cannot process review: FSRSState is nil for \(flashcard.word)")
            return nil
        }

        // In cram mode, only log the review without updating FSRS
        if mode == .cram {
            // Calculate actual elapsed days for analytics accuracy
            // Safe optional chaining with map to avoid force unwrap crashes
            let elapsedDays = flashcard.fsrsState?.lastReviewDate
                .map { DateMath.elapsedDays(since: $0) } ?? 0

            let log = FlashcardReview(
                rating: rating,
                reviewDate: now,
                scheduledDays: 0, // No scheduling in cram mode
                elapsedDays: elapsedDays
            )
            log.card = flashcard
            log.studySession = studySession
            modelContext.insert(log)

            // CRITICAL: Propagate save errors instead of silent failure
            do {
                try modelContext.save()
                // Invalidate statistics cache after review
                StatisticsService.shared.invalidateCache()
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
            // Get DTO from FSRSWrapper (same @MainActor, no await needed)
            let result = try FSRSWrapper.shared.processReview(
                flashcard: flashcard,
                rating: rating,
                now: now
            )

            // Apply the DTO updates to our SwiftData model
            applyFSRSResult(result, to: flashcard, at: now, rating: rating)

            // Create review log
            let log = FlashcardReview(
                rating: rating,
                reviewDate: now,
                scheduledDays: result.scheduledDays,
                elapsedDays: result.elapsedDays
            )
            log.card = flashcard
            log.studySession = studySession
            modelContext.insert(log)

            // Save changes
            try modelContext.save()

            // Invalidate statistics cache after review
            StatisticsService.shared.invalidateCache()

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
    /// **Performance**: Updates lastReviewDate and cached counters (totalReviews, totalLapses)
    /// for O(1) future access. Eliminates O(n) reviewLog scan in FSRSWrapper.toFSCard().
    ///
    /// **Concurrency**: Runs on @MainActor, safe to mutate SwiftData models.
    ///
    /// - Parameters:
    ///   - result: The FSRSReviewResult DTO from FSRSWrapper
    ///   - flashcard: The flashcard to update
    ///   - now: Current time (for lastReviewDate cache)
    ///   - rating: The user's rating (for incrementing lapse counter)
    private func applyFSRSResult(_ result: FSRSReviewResult, to flashcard: Flashcard, at now: Date, rating: Int) {
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

        // PERFORMANCE: Update cached counters for O(1) access
        // Eliminates O(n) reviewLog scan in FSRSWrapper.toFSCard()
        state.totalReviews += 1
        if rating == 0 {
            state.totalLapses += 1
        }

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
        FSRSWrapper.shared.previewRatings(flashcard: flashcard)
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
            // Get DTO from FSRSWrapper (same @MainActor, no await needed)
            let result = FSRSWrapper.shared.resetFlashcard(flashcard)

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

// MARK: - Array Performance Extensions

extension Array {
    /// Returns k random elements using reservoir sampling (O(k) where k << count)
    ///
    /// **Performance:** For 20 cards from 1000: 20x faster than shuffled().prefix()
    /// **Algorithm:** Fisher-Yates partial shuffle - only shuffles first k elements
    ///
    /// - Parameter k: Number of random elements to return
    /// - Returns: Array of k random elements
    ///
    /// **Example:**
    /// ```swift
    /// let cards = Array(0..<1000)
    /// let sample = cards.randomSample(20)  // O(20) instead of O(1000)
    /// ```
    func randomSample(_ k: Int) -> [Element] {
        guard k > 0 else { return [] }
        guard k < count else { return shuffled() }

        var result = Array(prefix(k))
        result.reserveCapacity(k)

        // Fisher-Yates partial shuffle: only shuffle first k elements
        for i in k ..< count {
            let j = Int.random(in: 0 ... i)
            if j < k {
                result[j] = self[i]
            }
        }

        return result
    }
}
