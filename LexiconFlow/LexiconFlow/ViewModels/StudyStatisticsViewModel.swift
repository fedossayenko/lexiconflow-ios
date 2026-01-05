//
//  StudyStatisticsViewModel.swift
//  LexiconFlow
//
//  Provides study statistics for display in settings and dashboard.
//

import Foundation
import SwiftData
import OSLog
import Combine

@MainActor
class StudyStatisticsViewModel: ObservableObject {
    @Published var todayStudied: Int = 0
    @Published var streakDays: Int = 0
    @Published var totalCards: Int = 0
    @Published var dueCount: Int = 0
    @Published var isLoading: Bool = true

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.lexiconflow.statistics", category: "StudyStatistics")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadStatistics()
    }

    /// Refreshes all statistics from the database
    func loadStatistics() {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load today's study count
            todayStudied = loadTodayReviews()

            // Load total cards
            totalCards = loadTotalCards()

            // Load due cards
            dueCount = loadDueCards()

            // Calculate streak
            streakDays = calculateStreak()

            logger.info("Statistics loaded: today=\(self.todayStudied), total=\(self.totalCards), due=\(self.dueCount), streak=\(self.streakDays)")
        } catch {
            logger.error("Failed to load statistics: \(error)")
            Analytics.trackError("statistics_load_failed", error: error)
        }
    }

    // MARK: - Private Query Methods

    /// Loads the count of reviews completed today
    private func loadTodayReviews() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let predicate = #Predicate<FlashcardReview> {
            $0.reviewDate >= today
        }

        let descriptor = FetchDescriptor<FlashcardReview>(
            predicate: predicate
        )

        do {
            let reviews = try modelContext.fetch(descriptor)
            return reviews.count
        } catch {
            logger.error("Failed to fetch today's reviews: \(error)")
            return 0
        }
    }

    /// Loads the total count of all flashcards
    private func loadTotalCards() -> Int {
        let descriptor = FetchDescriptor<Flashcard>()

        do {
            let cards = try modelContext.fetch(descriptor)
            return cards.count
        } catch {
            logger.error("Failed to fetch total cards: \(error)")
            return 0
        }
    }

    /// Loads the count of cards due for review
    private func loadDueCards() -> Int {
        let now = Date()

        let predicate = #Predicate<Flashcard> {
            $0.fsrsState?.dueDate ?? now <= now
        }

        let descriptor = FetchDescriptor<Flashcard>(
            predicate: predicate
        )

        do {
            let cards = try modelContext.fetch(descriptor)
            return cards.count
        } catch {
            logger.error("Failed to fetch due cards: \(error)")
            return 0
        }
    }

    /// Calculates the current study streak (consecutive days with reviews)
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var streak = 0
        var currentDate = today

        // Check backwards from today
        for dayOffset in 0..<365 { // Max 1 year streak
            if dayOffset > 0 {
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            }

            let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

            let predicate = #Predicate<FlashcardReview> {
                $0.reviewDate >= currentDate && $0.reviewDate < dayEnd
            }

            let descriptor = FetchDescriptor<FlashcardReview>(
                predicate: predicate
            )

            do {
                let reviews = try modelContext.fetch(descriptor)
                if reviews.isEmpty {
                    // No reviews on this day - check if it's today (still early)
                    if dayOffset == 0 {
                        continue // Today doesn't break streak
                    } else {
                        break // Streak broken
                    }
                } else {
                    streak += 1
                }
            } catch {
                logger.error("Failed to check reviews for \(currentDate): \(error)")
                break
            }
        }

        return streak
    }
}
