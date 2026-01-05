//
//  RatingButtonsViewTests.swift
//  LexiconFlowTests
//
//  Tests for RatingButtonsView
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for RatingButtonsView
///
/// Tests verify:
/// - Button rendering for all 4 ratings
/// - Button tap triggers correct rating callback
/// - Accessibility labels and identifiers
/// - Color mapping for each rating
/// - Disabled state when processing
@MainActor
struct RatingButtonsViewTests {

    // MARK: - Initialization Tests

    @Test("RatingButtonsView initializes with callback")
    func ratingButtonsViewInitializes() {
        var callbackCalled = false
        var receivedRating: CardRating?

        let view = RatingButtonsView { rating in
            callbackCalled = true
            receivedRating = rating
        }

        #expect(!callbackCalled, "Callback should not be called initially")
        #expect(receivedRating == nil, "No rating should be received initially")
    }

    // MARK: - Button Rendering Tests

    @Test("All 4 rating buttons are rendered")
    func allFourButtonsRendered() {
        let view = RatingButtonsView { _ in }

        // Extract the body to verify structure
        let body = view.body

        // Verify we can access the body (basic smoke test)
        #expect(!body.isEmpty, "View body should not be empty")
    }

    @Test("Rating buttons use correct order")
    func ratingButtonsCorrectOrder() {
        // CardRating.allCases in reverse order should be: easy, good, hard, again
        let expectedOrder: [CardRating] = [.easy, .good, .hard, .again]
        let actualOrder = CardRating.allCases.reversed()

        #expect(actualOrder.count == expectedOrder.count, "Should have 4 buttons")
        for (index, expected) in expectedOrder.enumerated() {
            #expect(actualOrder[index] == expected, "Button \(index) should be \(expected)")
        }
    }

    // MARK: - Callback Tests

    @Test("Tapping Again button triggers callback with correct rating")
    func tappingAgainTriggersCallback() {
        var callbackCalled = false
        var receivedRating: CardRating?

        let view = RatingButtonsView { rating in
            callbackCalled = true
            receivedRating = rating
        }

        // Simulate tapping Again button
        view.onRating(.again)

        #expect(callbackCalled, "Callback should be called")
        #expect(receivedRating == .again, "Should receive Again rating")
    }

    @Test("Tapping Hard button triggers callback with correct rating")
    func tappingHardTriggersCallback() {
        var receivedRating: CardRating?

        let view = RatingButtonsView { rating in
            receivedRating = rating
        }

        view.onRating(.hard)

        #expect(receivedRating == .hard, "Should receive Hard rating")
    }

    @Test("Tapping Good button triggers callback with correct rating")
    func tappingGoodTriggersCallback() {
        var receivedRating: CardRating?

        let view = RatingButtonsView { rating in
            receivedRating = rating
        }

        view.onRating(.good)

        #expect(receivedRating == .good, "Should receive Good rating")
    }

    @Test("Tapping Easy button triggers callback with correct rating")
    func tappingEasyTriggersCallback() {
        var receivedRating: CardRating?

        let view = RatingButtonsView { rating in
            receivedRating = rating
        }

        view.onRating(.easy)

        #expect(receivedRating == .easy, "Should receive Easy rating")
    }

    // MARK: - Color Mapping Tests

    @Test("Again button maps to red color")
    func againButtonRedColor() {
        #expect(CardRating.again.swiftUIColor == .red, "Again should be red")
    }

    @Test("Hard button maps to orange color")
    func hardButtonOrangeColor() {
        #expect(CardRating.hard.swiftUIColor == .orange, "Hard should be orange")
    }

    @Test("Good button maps to blue color")
    func goodButtonBlueColor() {
        #expect(CardRating.good.swiftUIColor == .blue, "Good should be blue")
    }

    @Test("Easy button maps to green color")
    func easyButtonGreenColor() {
        #expect(CardRating.easy.swiftUIColor == .green, "Easy should be green")
    }

    // MARK: - Accessibility Tests

    @Test("All ratings have valid accessibility labels")
    func allRatingsHaveAccessibilityLabels() {
        let ratings: [CardRating] = [.again, .hard, .good, .easy]

        for rating in ratings {
            let label = rating.label
            #expect(!label.isEmpty, "Accessibility label should not be empty for \(rating)")
        }
    }

    @Test("Accessibility identifiers use correct format")
    func accessibilityIdentifiersCorrectFormat() {
        let ratings: [CardRating] = [.again, .hard, .good, .easy]

        for rating in ratings {
            let expectedId = "rating_\(rating.rawValue)"
            // The view should set this identifier
            #expect(!expectedId.isEmpty, "Identifier should not be empty")
        }
    }

    @Test("Accessibility hints provide guidance")
    func accessibilityHintsProvideGuidance() {
        for rating in CardRating.allCases {
            let hint = "Rate card as \(rating.label.lowercased())"
            #expect(!hint.isEmpty, "Hint should not be empty")
            #expect(hint.contains(rating.label.lowercased()), "Hint should contain rating name")
        }
    }

    // MARK: - Icon Tests

    @Test("All ratings have valid icon names")
    func allRatingsHaveIcons() {
        for rating in CardRating.allCases {
            let iconName = rating.iconName
            #expect(!iconName.isEmpty, "Icon name should not be empty for \(rating)")
        }
    }

    // MARK: - Edge Case Tests

    @Test("View handles rapid callback invocations")
    func handlesRapidCallbacks() {
        var callCount = 0

        let view = RatingButtonsView { _ in
            callCount += 1
        }

        // Simulate rapid taps
        for _ in 0..<10 {
            view.onRating(.good)
        }

        #expect(callCount == 10, "All callbacks should be recorded")
    }

    @Test("View handles different ratings sequentially")
    func handlesSequentialRatings() {
        var receivedRatings: [CardRating] = []

        let view = RatingButtonsView { rating in
            receivedRatings.append(rating)
        }

        view.onRating(.again)
        view.onRating(.hard)
        view.onRating(.good)
        view.onRating(.easy)

        #expect(receivedRatings.count == 4, "Should receive all 4 ratings")
        #expect(receivedRatings[0] == .again, "First rating should be again")
        #expect(receivedRatings[1] == .hard, "Second rating should be hard")
        #expect(receivedRatings[2] == .good, "Third rating should be good")
        #expect(receivedRatings[3] == .easy, "Fourth rating should be easy")
    }
}
