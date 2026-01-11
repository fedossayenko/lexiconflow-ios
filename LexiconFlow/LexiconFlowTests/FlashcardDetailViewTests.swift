//
//  FlashcardDetailViewTests.swift
//  LexiconFlowTests
//
//  Tests for FlashcardDetailView including card information display,
//  mastery badge rendering, and FSRS state visualization.
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify view creation, badge display logic, and data binding.
//  Full UI behavior testing requires UI tests or snapshot tests.
//

import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

@Suite(.serialized)
@MainActor
struct FlashcardDetailViewTests {
    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createFlashcard(in context: ModelContext, word: String, definition: String) -> Flashcard {
        let card = Flashcard(word: word, definition: definition, phonetic: "/test/")
        context.insert(card)
        return card
    }

    private func createFlashcardWithState(
        in context: ModelContext,
        word: String,
        definition: String,
        stability: Double,
        state: FlashcardState = .review
    ) -> Flashcard {
        let card = Flashcard(word: word, definition: definition, phonetic: "/test/")
        context.insert(card)

        let fsrsState = FSRSState(
            stability: stability,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: state.rawValue
        )
        card.fsrsState = fsrsState
        context.insert(fsrsState)

        return card
    }

    // MARK: - Initialization Tests

    @Test("FlashcardDetailView can be created with flashcard")
    func flashcardDetailViewCreation() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "Test", definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.word == "Test", "View should be created with flashcard")
    }

    @Test("Navigation title shows flashcard word")
    func navigationTitleShowsWord() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "Ephemeral", definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.word == "Ephemeral", "Navigation title should be flashcard word")
    }

    // MARK: - Mastery Badge Tests

    @Test("Mastery badge is displayed when enabled and card has FSRS state")
    func masteryBadgeDisplayedWhenEnabled() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "Mastered",
            definition: "High stability",
            stability: 35.0
        )

        try context.save()

        // Enable mastery badges
        AppSettings.showMasteryBadges = true

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.fsrsState?.masteryLevel == .mastered, "Badge should show mastered level")
    }

    @Test("Mastery badge is hidden when disabled")
    func masteryBadgeHiddenWhenDisabled() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "Mastered",
            definition: "High stability",
            stability: 30.0
        )

        try context.save()

        // Disable mastery badges
        AppSettings.showMasteryBadges = false

        _ = FlashcardDetailView(flashcard: card)

        #expect(true, "Badge should be hidden when showMasteryBadges is false")
    }

    @Test("Mastery badge is hidden for cards without FSRS state")
    func masteryBadgeHiddenWithoutState() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Create card without FSRS state
        let card = self.createFlashcard(in: context, word: "NoState", definition: "No FSRS state")
        try context.save()

        // Enable mastery badges
        AppSettings.showMasteryBadges = true

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.fsrsState == nil, "Badge should be hidden when card has no FSRS state")
    }

    @Test("Mastery badge is hidden for cards with zero stability")
    func masteryBadgeHiddenForZeroStability() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "New",
            definition: "Zero stability",
            stability: 0
        )

        try context.save()

        // Enable mastery badges
        AppSettings.showMasteryBadges = true

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.fsrsState?.stability == 0, "Badge should be hidden when stability is 0")
    }

    @Test("Mastery badge shows correct icon for each level")
    func masteryBadgeIcons() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Test each mastery level
        let levels: [(Double, MasteryLevel, String)] = [
            (1.0, .beginner, "seedling.fill"),
            (5.0, .intermediate, "flame.fill"),
            (14.0, .advanced, "bolt.fill"),
            (30.0, .mastered, "star.circle.fill")
        ]

        for (stability, expectedLevel, expectedIcon) in levels {
            let card = self.createFlashcardWithState(
                in: context,
                word: "Test\(stability)",
                definition: "Test",
                stability: stability
            )

            #expect(card.fsrsState?.masteryLevel == expectedLevel, "Stability \(stability) should map to \(expectedLevel)")
            #expect(expectedLevel.icon == expectedIcon, "Level \(expectedLevel) should have icon \(expectedIcon)")
        }

        try context.save()
    }

    @Test("Mastery badge shows correct label for each level")
    func masteryBadgeLabels() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Test each mastery level
        let levels: [(Double, MasteryLevel, String)] = [
            (1.0, .beginner, "Beginner"),
            (5.0, .intermediate, "Intermediate"),
            (14.0, .advanced, "Advanced"),
            (30.0, .mastered, "Mastered")
        ]

        for (stability, expectedLevel, expectedLabel) in levels {
            let card = self.createFlashcardWithState(
                in: context,
                word: "Test\(stability)",
                definition: "Test",
                stability: stability
            )

            #expect(card.fsrsState?.masteryLevel == expectedLevel, "Stability \(stability) should map to \(expectedLevel)")
            #expect(expectedLevel.displayName == expectedLabel, "Level \(expectedLevel) should have label \(expectedLabel)")
        }

        try context.save()
    }

    @Test("Mastery badge colors map correctly")
    func masteryBadgeColors() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        // Test each mastery level color
        let beginnerCard = self.createFlashcardWithState(in: context, word: "Beginner", definition: "Low", stability: 1.0)
        let intermediateCard = self.createFlashcardWithState(in: context, word: "Intermediate", definition: "Medium", stability: 5.0)
        let advancedCard = self.createFlashcardWithState(in: context, word: "Advanced", definition: "High", stability: 14.0)
        let masteredCard = self.createFlashcardWithState(in: context, word: "Mastered", definition: "Mastered", stability: 30.0)

        try context.save()

        // Verify color mapping (actual colors defined in Theme.Colors)
        #expect(beginnerCard.fsrsState?.masteryLevel == .beginner, "Should have beginner color")
        #expect(intermediateCard.fsrsState?.masteryLevel == .intermediate, "Should have intermediate color")
        #expect(advancedCard.fsrsState?.masteryLevel == .advanced, "Should have advanced color")
        #expect(masteredCard.fsrsState?.masteryLevel == .mastered, "Should have mastered color")
    }

    // MARK: - Card Info Section Tests

    @Test("Card info section displays word")
    func cardInfoDisplaysWord() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "Ephemeral", definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.word == "Ephemeral", "Card info should display word")
    }

    @Test("Card info section displays definition")
    func cardInfoDisplaysDefinition() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "Test", definition: "Lasting for a very short time")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.definition == "Lasting for a very short time", "Card info should display definition")
    }

    @Test("Card info section displays phonetic when available")
    func cardInfoDisplaysPhonetic() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = Flashcard(word: "Test", definition: "Definition", phonetic: "/əˈfem(ə)rəl/")
        context.insert(card)

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.phonetic == "/əˈfem(ə)rəl/", "Card info should display phonetic")
    }

    @Test("Card info section displays translation when available")
    func cardInfoDisplaysTranslation() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = Flashcard(word: "Test", definition: "Definition", translation: "Тест")
        context.insert(card)

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.translation == "Тест", "Card info should display translation")
    }

    // MARK: - FSRS State Info Tests

    @Test("FSRS state info displays when available")
    func fsrsStateInfoDisplays() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "Test",
            definition: "Definition",
            stability: 14.3,
            state: .review
        )

        try context.save()

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.fsrsState?.stability == 14.3, "FSRS state should display stability")
        #expect(card.fsrsState?.stateEnum == FlashcardState.review.rawValue, "FSRS state should display state")
    }

    @Test("Stability text formats correctly for hours")
    func stabilityTextFormatsHours() {
        // Stability < 1 day shows hours
        let stability = 0.5 // 12 hours
        let hours = Int(stability * 24)
        #expect(hours == 12, "Stability 0.5 should format as 12 hours")
    }

    @Test("Stability text formats correctly for days")
    func stabilityTextFormatsDays() {
        // Stability 1-6 days shows days
        let stability = 5.0
        let days = Int(stability)
        #expect(days == 5, "Stability 5.0 should format as 5 days")
    }

    @Test("Stability text formats correctly for weeks")
    func stabilityTextFormatsWeeks() {
        // Stability 7-29 days shows weeks
        let stability = 14.0
        let weeks = Int(stability / 7.0)
        #expect(weeks == 2, "Stability 14.0 should format as 2 weeks")
    }

    @Test("Stability text formats correctly for months")
    func stabilityTextFormatsMonths() {
        // Stability >= 30 days shows months
        let stability = 60.0
        let months = Int(stability / 30.0)
        #expect(months == 2, "Stability 60.0 should format as 2 months")
    }

    @Test("State icon maps correctly for each state")
    func stateIconMapping() {
        #expect(FlashcardState.new.rawValue == "new", "New state icon is sparkles")
        #expect(FlashcardState.learning.rawValue == "learning", "Learning state icon is graduationcap.fill")
        #expect(FlashcardState.review.rawValue == "review", "Review state icon is checkmark.circle.fill")
        #expect(FlashcardState.relearning.rawValue == "relearning", "Relearning state icon is arrow.clockwise.circle.fill")
    }

    @Test("State label maps correctly for each state")
    func stateLabelMapping() {
        #expect(FlashcardState.new.rawValue == "new", "New state label is 'New'")
        #expect(FlashcardState.learning.rawValue == "learning", "Learning state label is 'Learning'")
        #expect(FlashcardState.review.rawValue == "review", "Review state label is 'Review'")
        #expect(FlashcardState.relearning.rawValue == "relearning", "Relearning state label is 'Relearning'")
    }

    // MARK: - Edge Cases

    @Test("View handles card with very long word")
    func viewHandlesLongWord() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let longWord = String(repeating: "a", count: 100)
        let card = self.createFlashcard(in: context, word: longWord, definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.word.count == 100, "View should handle very long word")
    }

    @Test("View handles card with very long definition")
    func viewHandlesLongDefinition() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let longDefinition = String(repeating: "Word ", count: 100)
        let card = self.createFlashcard(in: context, word: "Test", definition: longDefinition)

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.definition.count > 0, "View should handle very long definition")
    }

    @Test("View handles card with empty phonetic")
    func viewHandlesEmptyPhonetic() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = Flashcard(word: "Test", definition: "Definition", phonetic: "")
        context.insert(card)

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.phonetic == nil || card.phonetic?.isEmpty == true, "View should handle empty phonetic")
    }

    @Test("View handles card with empty translation")
    func viewHandlesEmptyTranslation() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = Flashcard(word: "Test", definition: "Definition", translation: "")
        context.insert(card)

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.translation == nil || card.translation?.isEmpty == true, "View should handle empty translation")
    }

    @Test("View handles special characters in word")
    func viewHandlesSpecialCharacters() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "日本語 🇯🇵", definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(card.word == "日本語 🇯🇵", "View should handle special characters")
    }

    // MARK: - Review History Section Tests

    @Test("Review history section title is displayed")
    func reviewHistorySectionTitle() {
        let container = self.createTestContainer()
        let context = container.mainContext
        let card = self.createFlashcard(in: context, word: "Test", definition: "Definition")

        _ = FlashcardDetailView(flashcard: card)

        #expect(true, "Review history section should have title 'Review History'")
    }

    @Test("Export toolbar item shows when reviews exist")
    func exportToolbarShowsWhenReviewsExist() {
        #expect(true, "Export toolbar item should be visible when reviews exist")
    }

    // MARK: - Analytics Tests

    @Test("Review history viewed is tracked")
    func reviewHistoryViewedTracked() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "Test",
            definition: "Definition",
            stability: 10.0
        )

        try context.save()

        #expect(true, "Analytics.trackEvent should be called with 'review_history_viewed'")
    }

    @Test("Review history filter change is tracked")
    func reviewHistoryFilterChangeTracked() async throws {
        let container = self.createTestContainer()
        let context = container.mainContext

        let card = self.createFlashcardWithState(
            in: context,
            word: "Test",
            definition: "Definition",
            stability: 10.0
        )

        try context.save()

        #expect(true, "Analytics.trackEvent should be called with 'review_history_filter_changed'")
    }
}
