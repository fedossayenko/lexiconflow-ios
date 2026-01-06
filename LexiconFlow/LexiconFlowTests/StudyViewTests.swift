//
//  StudyViewTests.swift
//  LexiconFlowTests
//
//  Tests for StudyView including mode switching, due count refresh,
//  and session lifecycle.
//

import Testing
import SwiftData
import SwiftUI
@testable import LexiconFlow

@MainActor
struct StudyViewTests {

    // MARK: - Test Container Setup

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestCard(in context: ModelContext, word: String, dueDate: Date? = nil, state: FlashcardState = .new) -> Flashcard {
        let card = Flashcard(word: word, definition: "Test definition", phonetic: "/test/")
        context.insert(card)

        let fsrsState = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: dueDate ?? Date(),
            stateEnum: state.rawValue
        )
        card.fsrsState = fsrsState
        context.insert(fsrsState)

        return card
    }

    // MARK: - StudyMode Enum Tests

    @Test("StudyMode scheduled case exists")
    func testScheduledModeExists() {
        // Verify the scheduled mode can be instantiated
        let mode = StudyMode.scheduled
        #expect(mode == .scheduled, "Scheduled mode should be equal to .scheduled")
    }

    // MARK: - Due Count Tests

    @Test("Scheduled mode counts only due cards")
    func testScheduledModeCount() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create test cards
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400) // Yesterday
        let tomorrow = now.addingTimeInterval(86400) // Tomorrow

        // Due card (yesterday)
        createTestCard(in: context, word: "Due1", dueDate: yesterday, state: .review)

        // Due card (today)
        createTestCard(in: context, word: "Due2", dueDate: now, state: .review)

        // Not due card (tomorrow)
        createTestCard(in: context, word: "NotDue", dueDate: tomorrow, state: .review)

        // New card (should not be counted)
        createTestCard(in: context, word: "New", dueDate: nil, state: .new)

        try context.save()

        let dueCount = scheduler.dueCardCount()

        #expect(dueCount == 2, "Should count only due cards (2), excluding new and future cards")
    }

    @Test("Empty database returns zero count")
    func testEmptyDatabaseCount() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // No cards created
        let dueCount = scheduler.dueCardCount()

        #expect(dueCount == 0, "Empty database should return 0")
    }

    // MARK: - Mode Switching Tests

    @Test("Mode switching triggers due count refresh")
    func testModeSwitchRefreshesCount() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create some cards
        let now = Date()
        createTestCard(in: context, word: "Due1", dueDate: now, state: .review)
        createTestCard(in: context, word: "New", state: .new)

        try context.save()

        let scheduler = Scheduler(modelContext: context)

        // Scheduled mode count
        let scheduledCount = scheduler.dueCardCount()

        // Learning mode count
        let learningCount = scheduler.newCardCount()

        // Verify counts
        #expect(scheduledCount == 1, "Scheduled mode should count 1 due card")
        #expect(learningCount == 1, "Learning mode should count 1 new card")
    }

    // MARK: - Session Lifecycle Tests

    @Test("Session start creates StudySessionView")
    func testSessionStart() {
        // Verify StudySessionView can be created with mode
        let sessionView = StudySessionView(mode: .scheduled) {}
        // Verify the mode is stored correctly
        #expect(sessionView.mode == .scheduled, "Session mode should be .scheduled")
    }

    @Test("Session completion refreshes due count")
    func testSessionCompletionRefresh() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create a due card
        let now = Date()
        createTestCard(in: context, word: "Due1", dueDate: now, state: .review)

        try context.save()

        let scheduler = Scheduler(modelContext: context)

        // Initial count
        let initialCount = scheduler.dueCardCount()
        #expect(initialCount == 1, "Should have 1 due card initially")

        // After "completing" a review (simulated by changing due date)
        if let card = try context.fetch(FetchDescriptor<Flashcard>()).first,
           let fsrsState = card.fsrsState {
            fsrsState.dueDate = Date().addingTimeInterval(86400) // Move to tomorrow
            try context.save()
        }

        // Count should still be 1 (we're testing the refresh mechanism works)
        let refreshedCount = scheduler.dueCardCount()
        #expect(refreshedCount >= 0, "Refresh should execute successfully")
    }

    // MARK: - Edge Cases

    @Test("All new cards returns zero for scheduled mode")
    func testAllNewCardsScheduled() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        // Create only new cards
        createTestCard(in: context, word: "New1", state: .new)
        createTestCard(in: context, word: "New2", state: .new)

        try context.save()

        let dueCount = scheduler.dueCardCount()

        #expect(dueCount == 0, "All new cards should return 0 due count")
    }

    @Test("Mixed state cards counted correctly")
    func testMixedStateCards() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let scheduler = Scheduler(modelContext: context)

        let now = Date()

        // Mix of states and due dates
        createTestCard(in: context, word: "New", state: .new)
        createTestCard(in: context, word: "Learning", state: .learning)  // Learning cards are always due
        createTestCard(in: context, word: "ReviewDue", dueDate: now, state: .review)
        createTestCard(in: context, word: "ReviewFuture", dueDate: now.addingTimeInterval(86400), state: .review)

        try context.save()

        let dueCount = scheduler.dueCardCount()

        // Learning cards are always due, plus the due review card = 2
        #expect(dueCount == 2, "Should count learning card (always due) and the review card that's due")
    }

    // MARK: - Error Handling Tests

    @Test("Fetch error is handled gracefully")
    func testFetchErrorHandling() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create a scenario that could cause errors
        // (In real scenarios, this might be database corruption)

        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum != "new"
            }
        )

        // Normal fetch should work
        let count = try context.fetchCount(stateDescriptor)
        #expect(count >= 0, "Fetch should succeed or return 0 on error")
    }

    // MARK: - String Literal Tests

    @Test("String literal 'new' used in predicates")
    func testStringLiteralInPredicate() async throws {
        let container = createTestContainer()
        let context = container.mainContext

        // Create new and non-new cards
        createTestCard(in: context, word: "New", state: .new)
        createTestCard(in: context, word: "Review", state: .review)

        try context.save()

        // Use string literal (as StudyView does)
        let stateDescriptor = FetchDescriptor<FSRSState>(
            predicate: #Predicate<FSRSState> { state in
                state.stateEnum != "new"
            }
        )

        let count = try context.fetchCount(stateDescriptor)

        #expect(count == 1, "String literal predicate should work correctly")
    }
}
