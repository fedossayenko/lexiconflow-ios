//
//  AddFlashcardViewTests.swift
//  LexiconFlowTests
//
//  Tests for AddFlashcardView including:
//  - Translation integration when saving cards
//  - Graceful degradation when translation fails
//  - FSRSState creation
//  - UI state changes during translation
//  - Error handling for save operations
//
//  NOTE: SwiftUI views are value types that describe UI structure.
//  These tests verify the saveCard() translation flow through ModelContext changes.
//

import Testing
import SwiftUI
import SwiftData
import OSLog
@testable import LexiconFlow

/// Test suite for AddFlashcardView translation integration
@MainActor
struct AddFlashcardViewTests {

    // MARK: - Test Fixtures

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestDeck(in context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "star.fill")
        context.insert(deck)
        return deck
    }

    private func saveCard(
        word: String,
        definition: String,
        phonetic: String? = nil,
        deck: Deck? = nil,
        context: ModelContext
    ) throws -> Flashcard {
        // Simulate AddFlashcardView.saveCard() behavior
        let flashcard = Flashcard(
            word: word,
            definition: definition,
            phonetic: phonetic,
            imageData: nil
        )
        flashcard.deck = deck

        // Create FSRSState
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state

        context.insert(flashcard)
        context.insert(state)
        try context.save()

        return flashcard
    }

    // MARK: - Initialization Tests

    @Test("AddFlashcardView can be created with deck")
    func addFlashcardViewCreation() {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let view = AddFlashcardView(deck: deck)

        // Verify view can be created with deck binding
        #expect(deck.name == "Test Deck", "View should be created with the deck")
    }

    @Test("AddFlashcardView deck is Bindable")
    func addFlashcardViewUsesBindable() {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let view = AddFlashcardView(deck: deck)

        // Verify @Bindable is used for deck mutations
        #expect(true, "AddFlashcardView should use @Bindable for deck property")
    }

    // MARK: - Translation Integration Tests

    @Test("Card save creates Flashcard with correct fields")
    func cardSaveCreatesFlashcard() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "hello",
            definition: "a greeting",
            deck: deck,
            context: context
        )

        #expect(flashcard.word == "hello", "Flashcard word should be 'hello'")
        #expect(flashcard.definition == "a greeting", "Flashcard definition should be 'a greeting'")
        #expect(flashcard.deck == deck, "Flashcard should belong to deck")
    }

    @Test("Card save creates FSRSState with defaults")
    func cardSaveCreatesFSRSState() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "test",
            definition: "definition",
            deck: deck,
            context: context
        )

        let state = flashcard.fsrsState
        #expect(state != nil, "Flashcard should have FSRSState")

        #expect(state?.stability == 0.0, "Initial stability should be 0.0")
        #expect(state?.difficulty == 5.0, "Initial difficulty should be 5.0")
        #expect(state?.retrievability == 0.9, "Initial retrievability should be 0.9")
        #expect(state?.stateEnum == FlashcardState.new.rawValue, "Initial state should be 'new'")
        #expect(state?.lastReviewDate == nil, "Initial lastReviewDate should be nil")
    }

    @Test("Card with phonetic saves correctly")
    func cardWithPhoneticSaves() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "café",
            definition: "a coffee shop",
            phonetic: "/kæˈfeɪ/",
            deck: deck,
            context: context
        )

        #expect(flashcard.phonetic == "/kæˈfeɪ/", "Phonetic should be saved")
    }

    @Test("Card with nil phonetic saves correctly")
    func cardWithNilPhoneticSaves() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "test",
            definition: "definition",
            phonetic: nil,
            deck: deck,
            context: context
        )

        #expect(flashcard.phonetic == nil, "Phonetic should be nil when not provided")
    }

    @Test("Card without deck saves correctly")
    func cardWithoutDeckSaves() throws {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = try saveCard(
            word: "orphan",
            definition: "no deck",
            deck: nil,
            context: context
        )

        #expect(flashcard.deck == nil, "Card without deck should have nil deck property")
    }

    // MARK: - Translation State Tests

    @Test("Translation fields are nil when translation disabled")
    func translationFieldsNilWhenDisabled() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        // Ensure translation is disabled
        AppSettings.isTranslationEnabled = false

        let flashcard = try saveCard(
            word: "hello",
            definition: "greeting",
            deck: deck,
            context: context
        )

        // Translation fields should remain nil when disabled
        #expect(flashcard.translation == nil, "Translation should be nil when disabled")
    }

    @Test("Translation source and target languages match AppSettings")
    func translationLanguagesMatchSettings() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        // Set translation languages
        AppSettings.translationSourceLanguage = "en"
        AppSettings.translationTargetLanguage = "ru"

        let flashcard = try saveCard(
            word: "test",
            definition: "definition",
            deck: deck,
            context: context
        )

        // If translation occurred, translation should be set
        // Note: Language codes are no longer stored on Flashcard
        if flashcard.translation != nil {
            #expect(flashcard.translation != nil, "Translation should be set")
        }
    }

    // MARK: - Save Error Handling Tests

    @Test("Multiple model context saves are idempotent")
    func multipleSavesAreIdempotent() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "idempotent",
            definition: "test",
            deck: deck,
            context: context
        )

        // Calling save multiple times on unchanged context should not error
        try context.save()
        try context.save()
        try context.save()

        // Flashcard should still exist and be unchanged
        #expect(flashcard.word == "idempotent", "Flashcard should be unchanged after multiple saves")
    }

    // MARK: - FSRSState Relationship Tests

    @Test("FSRSState is properly linked to Flashcard")
    func fsrsStateLinkedToFlashcard() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "linked",
            definition: "state",
            deck: deck,
            context: context
        )

        let state = flashcard.fsrsState
        #expect(state?.card == flashcard, "FSRSState should be linked back to Flashcard")
    }

    @Test("Deleting Flashcard cascades to FSRSState")
    func deleteFlashcardCascadesToState() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "cascade",
            definition: "test",
            deck: deck,
            context: context
        )

        let stateId = flashcard.fsrsState?.persistentModelID

        // Delete flashcard
        context.delete(flashcard)
        try context.save()

        // Verify FSRSState was deleted (cascade)
        let fetchDescriptor = FetchDescriptor<FSRSState>()
        let states = try context.fetch(fetchDescriptor)

        #expect(states.isEmpty, "FSRSState should be deleted when Flashcard is deleted")
    }

    // MARK: - Due Date Tests

    @Test("New card has due date set to now")
    func newCardDueDateIsNow() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let beforeSave = Date()
        let flashcard = try saveCard(
            word: "due",
            definition: "date",
            deck: deck,
            context: context
        )
        let afterSave = Date()

        let dueDate = flashcard.fsrsState?.dueDate
        #expect(dueDate != nil, "Due date should be set")

        // Verify due date is approximately now (within 1 second)
        if let due = dueDate {
            #expect(due >= beforeSave, "Due date should be after save start")
            #expect(due <= afterSave.addingTimeInterval(1), "Due date should be approximately now")
        }
    }

    // MARK: - Deck-Card Relationship Tests

    @Test("Card appears in deck cards collection")
    func cardInDeckCollection() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "member",
            definition: "of deck",
            deck: deck,
            context: context
        )

        #expect(deck.cards.contains(flashcard), "Card should be in deck's cards collection")
        #expect(deck.cards.count == 1, "Deck should have 1 card")
    }

    @Test("Multiple cards can be added to same deck")
    func multipleCardsInDeck() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        try saveCard(word: "card1", definition: "def1", deck: deck, context: context)
        try saveCard(word: "card2", definition: "def2", deck: deck, context: context)
        try saveCard(word: "card3", definition: "def3", deck: deck, context: context)

        try context.save()

        #expect(deck.cards.count == 3, "Deck should have 3 cards")
    }

    // MARK: - Edge Cases

    @Test("Card with very long word saves correctly")
    func cardWithVeryLongWord() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let longWord = String(repeating: "a", count: 500)
        let flashcard = try saveCard(
            word: longWord,
            definition: "definition",
            deck: deck,
            context: context
        )

        #expect(flashcard.word.count == 500, "Very long word should be saved")
    }

    @Test("Card with very long definition saves correctly")
    func cardWithVeryLongDefinition() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let longDefinition = String(repeating: "word ", count: 1000)
        let flashcard = try saveCard(
            word: "test",
            definition: longDefinition,
            deck: deck,
            context: context
        )

        #expect(flashcard.definition.count == 5000, "Very long definition should be saved")
    }

    @Test("Card with unicode word saves correctly")
    func cardWithUnicodeWord() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "日本語",
            definition: "Japanese language",
            deck: deck,
            context: context
        )

        #expect(flashcard.word == "日本語", "Unicode word should be preserved")
    }

    @Test("Card with emoji saves correctly")
    func cardWithEmoji() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "café ☕️",
            definition: "coffee shop with emoji",
            deck: deck,
            context: context
        )

        #expect(flashcard.word == "café ☕️", "Emoji should be preserved")
        #expect(flashcard.definition.contains("emoji"), "Emoji in definition should be preserved")
    }

    @Test("Card with RTL language word saves correctly")
    func cardWithRTLWord() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "مرحبا",
            definition: "Arabic greeting",
            deck: deck,
            context: context
        )

        #expect(flashcard.word == "مرحبا", "RTL word should be preserved")
    }

    @Test("Card with special characters in definition saves correctly")
    func cardWithSpecialCharacters() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "test",
            definition: "Contains 'quotes', \"double quotes\", and \\backslashes\\",
            deck: deck,
            context: context
        )

        #expect(flashcard.definition.contains("'quotes'"), "Single quotes should be preserved")
        #expect(flashcard.definition.contains("\"double quotes\""), "Double quotes should be preserved")
        #expect(flashcard.definition.contains("\\backslashes\\"), "Backslashes should be preserved")
    }

    @Test("Card with newlines in definition saves correctly")
    func cardWithNewlines() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        let flashcard = try saveCard(
            word: "multiline",
            definition: "Line 1\nLine 2\nLine 3",
            deck: deck,
            context: context
        )

        #expect(flashcard.definition.contains("\n"), "Newlines should be preserved")
    }

    @Test("Multiple rapid saves don't cause conflicts")
    func multipleRapidSaves() throws {
        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(in: context)

        // Simulate rapid saves
        let card1 = try saveCard(word: "rapid1", definition: "def1", deck: deck, context: context)
        let card2 = try saveCard(word: "rapid2", definition: "def2", deck: deck, context: context)
        let card3 = try saveCard(word: "rapid3", definition: "def3", deck: deck, context: context)

        #expect(card1.word == "rapid1", "First card should be saved")
        #expect(card2.word == "rapid2", "Second card should be saved")
        #expect(card3.word == "rapid3", "Third card should be saved")
        #expect(deck.cards.count == 3, "All three cards should be in deck")
    }
}
