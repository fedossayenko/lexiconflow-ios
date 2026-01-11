//
//  StudySessionAndDailyStatsTests.swift
//  LexiconFlowTests
//
//  Tests for StudySession and DailyStats models
//  Covers: Creation, relationships, computed properties, validation
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for StudySession and DailyStats models
/// Uses shared container for performance - each test clears context before use
@Suite(.serialized)
@MainActor
struct StudySessionAndDailyStatsTests {
    /// Get a fresh isolated context for testing
    /// Caller should call clearAll() before use to ensure test isolation
    private func freshContext() -> ModelContext {
        TestContainers.freshContext()
    }

    // MARK: - StudySession Creation Tests

    @Test("StudySession creation with required fields")
    func studySessionCreation() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: nil,
            cardsReviewed: 0,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.id != UUID())
        #expect(session.startTime == startTime)
        #expect(session.endTime == nil)
        #expect(session.cardsReviewed == 0)
        #expect(session.modeEnum == "scheduled")
    }

    @Test("StudySession creation with convenience initializer")
    func studySessionConvenienceInit() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date()
        let session = StudySession(startTime: startTime, mode: .scheduled)

        context.insert(session)
        try context.save()

        #expect(session.startTime == startTime)
        #expect(session.modeEnum == "scheduled")
        #expect(session.cardsReviewed == 0)
        #expect(session.endTime == nil)
    }

    @Test("StudySession with all study modes")
    func studySessionAllModes() throws {
        let context = self.freshContext()
        try context.clearAll()

        let scheduledSession = StudySession(startTime: Date(), mode: .scheduled)
        let learningSession = StudySession(startTime: Date(), mode: .learning)
        let cramSession = StudySession(startTime: Date(), mode: .cram)

        context.insert(scheduledSession)
        context.insert(learningSession)
        context.insert(cramSession)
        try context.save()

        #expect(scheduledSession.modeEnum == "scheduled")
        #expect(learningSession.modeEnum == "learning")
        #expect(cramSession.modeEnum == "cram")

        #expect(scheduledSession.mode == .scheduled)
        #expect(learningSession.mode == .learning)
        #expect(cramSession.mode == .cram)
    }

    @Test("StudySession mode computed property getter")
    func studySessionModeGetter() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            cardsReviewed: 0,
            modeEnum: "cram"
        )

        context.insert(session)
        try context.save()

        #expect(session.mode == .cram)
    }

    @Test("StudySession mode computed property setter")
    func studySessionModeSetter() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)

        context.insert(session)
        try context.save()

        #expect(session.modeEnum == "scheduled")

        session.mode = .learning

        #expect(session.modeEnum == "learning")
        #expect(session.mode == .learning)
    }

    @Test("StudySession with completed session")
    func studySessionCompleted() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-600) // 10 minutes ago
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 15,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.endTime == endTime)
        #expect(session.cardsReviewed == 15)
        #expect(session.isActive == false)
    }

    // MARK: - StudySession Duration Tests

    @Test("StudySession durationSeconds for completed session")
    func studySessionDurationSeconds() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-323) // 5m 23s ago
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(abs(session.durationSeconds - 323) < 1) // Allow 1s tolerance
    }

    @Test("StudySession durationSeconds for active session")
    func studySessionDurationSecondsActive() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)

        context.insert(session)
        try context.save()

        #expect(session.durationSeconds == 0)
    }

    @Test("StudySession durationFormatted - seconds only")
    func studySessionDurationFormattedSeconds() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-23)
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 3,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.durationFormatted == "23s")
    }

    @Test("StudySession durationFormatted - minutes only")
    func studySessionDurationFormattedMinutes() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-300) // 5 minutes
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.durationFormatted == "5m")
    }

    @Test("StudySession durationFormatted - minutes and seconds")
    func studySessionDurationFormattedMinutesAndSeconds() throws {
        let context = self.freshContext()
        try context.clearAll()

        let startTime = Date().addingTimeInterval(-323) // 5m 23s
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.durationFormatted == "5m 23s")
    }

    @Test("StudySession isActive computed property")
    func studySessionIsActive() throws {
        let context = self.freshContext()
        try context.clearAll()

        let activeSession = StudySession(startTime: Date(), mode: .scheduled)
        let completedSession = StudySession(
            id: UUID(),
            startTime: Date().addingTimeInterval(-100),
            endTime: Date(),
            cardsReviewed: 5,
            modeEnum: "scheduled"
        )

        context.insert(activeSession)
        context.insert(completedSession)
        try context.save()

        #expect(activeSession.isActive == true)
        #expect(completedSession.isActive == false)
    }

    // MARK: - StudySession Relationships Tests

    @Test("StudySession-reviewsLog relationship")
    func studySessionReviewsLogRelationship() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)
        context.insert(session)

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review1 = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review1.card = flashcard
        review1.studySession = session
        context.insert(review1)

        let review2 = FlashcardReview(
            rating: 2,
            scheduledDays: 3.0,
            elapsedDays: 1.0
        )
        review2.card = flashcard
        review2.studySession = session
        context.insert(review2)

        try context.save()

        #expect(session.reviewsLog.count == 2)
        #expect(session.reviewsLog.allSatisfy { $0.studySession === session })
    }

    @Test("StudySession-deck relationship")
    func studySessionDeckRelationship() throws {
        let context = self.freshContext()
        try context.clearAll()

        let deck = Deck(name: "Spanish", icon: "🇪🇸")
        context.insert(deck)

        let session = StudySession(startTime: Date(), mode: .scheduled)
        session.deck = deck
        context.insert(session)

        try context.save()

        #expect(session.deck?.name == "Spanish")
        #expect(session.deck?.icon == "🇪🇸")
    }

    @Test("StudySession with no deck")
    func studySessionNoDeck() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)
        context.insert(session)
        try context.save()

        #expect(session.deck == nil)
    }

    @Test("StudySession-dailyStats relationship")
    func studySessionDailyStatsRelationship() throws {
        let context = self.freshContext()
        try context.clearAll()

        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 5,
            studyTimeSeconds: 300,
            retentionRate: 0.85
        )
        context.insert(dailyStats)

        let session = StudySession(startTime: Date(), mode: .scheduled)
        session.dailyStats = dailyStats
        context.insert(session)

        try context.save()

        #expect(session.dailyStats?.id == dailyStats.id)
        #expect(session.dailyStats?.cardsLearned == 5)
    }

    @Test("StudySession with no dailyStats")
    func studySessionNoDailyStats() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)
        context.insert(session)
        try context.save()

        #expect(session.dailyStats == nil)
    }

    // MARK: - StudySession Cascade Delete Tests

    @Test("Deleting study session nullifies reviews")
    func deleteStudySessionNullifiesReviews() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(startTime: Date(), mode: .scheduled)
        context.insert(session)

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        review.studySession = session
        context.insert(review)

        try context.save()

        let reviewId = review.id

        // Delete session
        context.delete(session)
        try context.save()

        // Review should be nullified (studySession = nil) but still exist
        let reviews = try context.fetch(FetchDescriptor<FlashcardReview>())
        let nullifiedReview = reviews.first { $0.id == reviewId }

        #expect(nullifiedReview != nil)
        #expect(nullifiedReview?.studySession == nil)
        #expect(nullifiedReview?.card != nil) // Card relationship preserved
    }

    @Test("Deleting study session nullifies dailyStats")
    func deleteStudySessionNullifiesDailyStats() throws {
        let context = self.freshContext()
        try context.clearAll()

        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 5,
            studyTimeSeconds: 300
        )
        context.insert(dailyStats)

        let session = StudySession(startTime: Date(), mode: .scheduled)
        session.dailyStats = dailyStats
        context.insert(session)

        try context.save()

        let statsId = dailyStats.id

        // Delete session
        context.delete(session)
        try context.save()

        // DailyStats should exist with nullified session
        let allStats = try context.fetch(FetchDescriptor<DailyStats>())
        let stats = allStats.first { $0.id == statsId }

        #expect(stats != nil)
        #expect(stats?.studySessions.isEmpty == true)
    }

    // MARK: - DailyStats Creation Tests

    @Test("DailyStats creation with required fields")
    func dailyStatsCreation() throws {
        let context = self.freshContext()
        try context.clearAll()

        let date = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let stats = DailyStats(
            id: UUID(),
            date: date,
            cardsLearned: 10,
            studyTimeSeconds: 600,
            retentionRate: 0.85
        )

        context.insert(stats)
        try context.save()

        #expect(stats.id != UUID())
        #expect(stats.date == date)
        #expect(stats.cardsLearned == 10)
        #expect(stats.studyTimeSeconds == 600)
        #expect(stats.retentionRate == 0.85)
    }

    @Test("DailyStats creation with minimal fields")
    func dailyStatsCreationMinimal() throws {
        let context = self.freshContext()
        try context.clearAll()

        let date = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let stats = DailyStats(
            id: UUID(),
            date: date,
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: nil
        )

        context.insert(stats)
        try context.save()

        #expect(stats.cardsLearned == 0)
        #expect(stats.studyTimeSeconds == 0)
        #expect(stats.retentionRate == nil)
    }

    @Test("DailyStats creation with convenience initializer")
    func dailyStatsConvenienceInit() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            cardsLearned: 15,
            studyTimeSeconds: 900,
            retentionRate: 0.92
        )

        context.insert(stats)
        try context.save()

        // Date should be normalized to midnight
        let expectedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        #expect(stats.date == expectedDate)
        #expect(stats.cardsLearned == 15)
        #expect(stats.studyTimeSeconds == 900)
        #expect(stats.retentionRate == 0.92)
    }

    // MARK: - DailyStats Computed Properties Tests

    @Test("DailyStats studyTimeFormatted - seconds only")
    func dailyStatsStudyTimeFormattedSeconds() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 45
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "45s")
    }

    @Test("DailyStats studyTimeFormatted - minutes only")
    func dailyStatsStudyTimeFormattedMinutes() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 300
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "5m")
    }

    @Test("DailyStats studyTimeFormatted - minutes and seconds")
    func dailyStatsStudyTimeFormattedMinutesAndSeconds() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 323
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "5m 23s")
    }

    @Test("DailyStats studyTimeFormatted - hours only")
    func dailyStatsStudyTimeFormattedHours() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 3600
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "1h")
    }

    @Test("DailyStats studyTimeFormatted - hours and minutes")
    func dailyStatsStudyTimeFormattedHoursAndMinutes() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 3900 // 1h 5m
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "1h 5m")
    }

    @Test("DailyStats studyTimeFormatted - hours, minutes, seconds")
    func dailyStatsStudyTimeFormattedFull() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 3753 // 1h 2m 33s
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studyTimeFormatted == "1h 2m 33s")
    }

    @Test("DailyStats retentionRateFormatted")
    func dailyStatsRetentionRateFormatted() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: 0.85
        )

        context.insert(stats)
        try context.save()

        #expect(stats.retentionRateFormatted == "85%")
    }

    @Test("DailyStats retentionRateFormatted when nil")
    func dailyStatsRetentionRateFormattedNil() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: nil
        )

        context.insert(stats)
        try context.save()

        #expect(stats.retentionRateFormatted == nil)
    }

    @Test("DailyStats hasActivity with various combinations")
    func dailyStatsHasActivity() throws {
        let context = self.freshContext()
        try context.clearAll()

        // Activity from cardsLearned
        let stats1 = DailyStats(
            date: Date(),
            cardsLearned: 5,
            studyTimeSeconds: 0,
            retentionRate: nil
        )

        // Activity from studyTimeSeconds
        let stats2 = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 300,
            retentionRate: nil
        )

        // Activity from retentionRate
        let stats3 = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: 0.8
        )

        // No activity
        let stats4 = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: nil
        )

        context.insert(stats1)
        context.insert(stats2)
        context.insert(stats3)
        context.insert(stats4)
        try context.save()

        #expect(stats1.hasActivity == true)
        #expect(stats2.hasActivity == true)
        #expect(stats3.hasActivity == true)
        #expect(stats4.hasActivity == false)
    }

    // MARK: - DailyStats Relationships Tests

    @Test("DailyStats-studySessions relationship")
    func dailyStatsStudySessionsRelationship() throws {
        let context = self.freshContext()
        try context.clearAll()

        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 10,
            studyTimeSeconds: 600
        )
        context.insert(dailyStats)

        let session1 = StudySession(startTime: Date(), mode: .scheduled)
        session1.dailyStats = dailyStats
        context.insert(session1)

        let session2 = StudySession(startTime: Date(), mode: .learning)
        session2.dailyStats = dailyStats
        context.insert(session2)

        try context.save()

        #expect(dailyStats.studySessions.count == 2)
        #expect(dailyStats.studySessions.allSatisfy { $0.dailyStats?.id == dailyStats.id })
    }

    @Test("DailyStats with no study sessions")
    func dailyStatsNoStudySessions() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0
        )

        context.insert(stats)
        try context.save()

        #expect(stats.studySessions.isEmpty == true)
    }

    // MARK: - DailyStats Cascade Delete Tests

    @Test("Deleting dailyStats nullifies study sessions")
    func deleteDailyStatsNullifiesStudySessions() throws {
        let context = self.freshContext()
        try context.clearAll()

        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 10,
            studyTimeSeconds: 600
        )
        context.insert(dailyStats)

        let session = StudySession(startTime: Date(), mode: .scheduled)
        session.dailyStats = dailyStats
        context.insert(session)

        try context.save()

        let sessionId = session.id

        // Delete dailyStats
        context.delete(dailyStats)
        try context.save()

        // Session should exist with nullified dailyStats
        let sessions = try context.fetch(FetchDescriptor<StudySession>())
        let nullifiedSession = sessions.first { $0.id == sessionId }

        #expect(nullifiedSession != nil)
        #expect(nullifiedSession?.dailyStats == nil)
    }

    // MARK: - Integration Tests

    @Test("Full integration: Session, Reviews, DailyStats, Deck")
    func fullIntegration() throws {
        let context = self.freshContext()
        try context.clearAll()

        // Create deck
        let deck = Deck(name: "Test Deck", icon: "📚")
        context.insert(deck)

        // Create daily stats
        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 5,
            studyTimeSeconds: 300,
            retentionRate: 0.85
        )
        context.insert(dailyStats)

        // Create study session
        let startTime = Date().addingTimeInterval(-300)
        let endTime = Date()
        let session = StudySession(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            cardsReviewed: 10,
            modeEnum: "scheduled"
        )
        session.deck = deck
        session.dailyStats = dailyStats
        context.insert(session)

        // Create flashcard
        let flashcard = Flashcard(word: "test", definition: "test")
        flashcard.deck = deck
        context.insert(flashcard)

        // Create reviews
        for i in 0 ..< 10 {
            let review = FlashcardReview(
                rating: i % 4,
                scheduledDays: Double(i),
                elapsedDays: 1.0
            )
            review.card = flashcard
            review.studySession = session
            context.insert(review)
        }

        try context.save()

        // Verify all relationships
        #expect(session.deck?.id == deck.id)
        #expect(session.dailyStats?.id == dailyStats.id)
        #expect(session.reviewsLog.count == 10)
        #expect(dailyStats.studySessions.count == 1)
        #expect(deck.studySessions.count == 1)
        #expect(flashcard.reviewLogs.count == 10)
    }

    @Test("Multiple sessions per day aggregation")
    func multipleSessionsPerDay() throws {
        let context = self.freshContext()
        try context.clearAll()

        let normalizedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let dailyStats = DailyStats(
            date: normalizedDate,
            cardsLearned: 20,
            studyTimeSeconds: 1200,
            retentionRate: 0.9
        )
        context.insert(dailyStats)

        // Create multiple sessions for the same day
        for i in 1 ... 3 {
            let session = StudySession(
                id: UUID(),
                startTime: Date().addingTimeInterval(-Double(i * 300)),
                endTime: Date().addingTimeInterval(-Double((i - 1) * 300)),
                cardsReviewed: i * 5,
                modeEnum: "scheduled"
            )
            session.dailyStats = dailyStats
            context.insert(session)
        }

        try context.save()

        #expect(dailyStats.studySessions.count == 3)
        #expect(dailyStats.cardsLearned == 20)
        #expect(dailyStats.studyTimeSeconds == 1200)
    }

    // MARK: - Validation Tests

    @Test("StudySession with zero cards reviewed is valid")
    func studySessionZeroCardsReviewed() throws {
        let context = self.freshContext()
        try context.clearAll()

        let session = StudySession(
            id: UUID(),
            startTime: Date().addingTimeInterval(-60),
            endTime: Date(),
            cardsReviewed: 0,
            modeEnum: "scheduled"
        )

        context.insert(session)
        try context.save()

        #expect(session.cardsReviewed == 0)
        #expect(session.durationSeconds > 0)
    }

    @Test("DailyStats with zero values is valid")
    func dailyStatsZeroValues() throws {
        let context = self.freshContext()
        try context.clearAll()

        let stats = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: nil
        )

        context.insert(stats)
        try context.save()

        #expect(stats.hasActivity == false)
        #expect(stats.studyTimeFormatted == "0s")
    }

    @Test("DailyStats retentionRate boundary values")
    func dailyStatsRetentionRateBoundaries() throws {
        let context = self.freshContext()
        try context.clearAll()

        let statsPerfect = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: 1.0
        )

        let statsZero = DailyStats(
            date: Date(),
            cardsLearned: 0,
            studyTimeSeconds: 0,
            retentionRate: 0.0
        )

        context.insert(statsPerfect)
        context.insert(statsZero)
        try context.save()

        #expect(statsPerfect.retentionRateFormatted == "100%")
        #expect(statsZero.retentionRateFormatted == "0%")
    }
}
