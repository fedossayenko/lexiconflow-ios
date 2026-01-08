//
//  CardGestureViewModelTests.swift
//  LexiconFlowTests
//
//  Tests for CardGestureViewModel including gesture state, direction detection,
//  and visual feedback calculations.
//

import SwiftUI
import Testing
@testable import LexiconFlow

@MainActor
struct CardGestureViewModelTests {
    // MARK: - Direction Detection Tests

    @Test("Horizontal right movement detected")
    func directionDetectionRight() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 50, height: 10)

        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .right, "Horizontal right movement should be detected")
    }

    @Test("Horizontal left movement detected")
    func directionDetectionLeft() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: -50, height: 10)

        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .left, "Horizontal left movement should be detected")
    }

    @Test("Vertical down movement detected")
    func directionDetectionDown() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 10, height: 50)

        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .down, "Vertical down movement should be detected")
    }

    @Test("Vertical up movement detected")
    func directionDetectionUp() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 10, height: -50)

        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .up, "Vertical up movement should be detected")
    }

    @Test("Below minimum distance returns none")
    func belowMinimumDistance() {
        let viewModel = CardGestureViewModel()

        // Test various small movements
        let translations: [CGSize] = [
            CGSize(width: 5, height: 0),
            CGSize(width: 0, height: 5),
            CGSize(width: 10, height: 5),
            CGSize(width: 5, height: 10),
            CGSize(width: 14, height: 0),
            CGSize(width: 0, height: 14)
        ]

        for translation in translations {
            let direction = viewModel.detectDirection(translation: translation)
            #expect(direction == .none, "Movement below threshold should return none")
        }
    }

    @Test("Exactly minimum distance triggers direction")
    func exactlyMinimumDistance() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 15, height: 0)

        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .right, "Movement at minimum threshold should trigger direction")
    }

    @Test("Horizontal dominant over vertical")
    func horizontalDominant() {
        let viewModel = CardGestureViewModel()

        // Same magnitude in both directions - horizontal should win
        let translation = CGSize(width: 30, height: 30)
        let direction = viewModel.detectDirection(translation: translation)

        #expect(direction == .right, "Horizontal should dominate when equal")
    }

    @Test("Diagonal movements favor dominant axis")
    func diagonalMovements() {
        let viewModel = CardGestureViewModel()

        // Diagonal with more horizontal
        let diag1 = CGSize(width: 40, height: 20)
        #expect(viewModel.detectDirection(translation: diag1) == .right, "Diagonal right should be detected")

        // Diagonal with more vertical
        let diag2 = CGSize(width: 20, height: 40)
        #expect(viewModel.detectDirection(translation: diag2) == .down, "Diagonal down should be detected")
    }

    // MARK: - Visual Feedback Tests

    @Test("Right swipe visual feedback: green tint, swelling")
    func rightSwipeVisualFeedback() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 50, height: 0)

        viewModel.updateGestureState(translation: translation)

        #expect(viewModel.tintColor != .clear, "Right swipe should have tint color")
        #expect(viewModel.scale > 1.0, "Right swipe should scale up (swelling)")
        #expect(viewModel.rotation != 0.0, "Right swipe should have rotation")
    }

    @Test("Left swipe visual feedback: red tint, shrinking")
    func leftSwipeVisualFeedback() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: -50, height: 0)

        viewModel.updateGestureState(translation: translation)

        #expect(viewModel.tintColor != .clear, "Left swipe should have tint color")
        #expect(viewModel.scale < 1.0, "Left swipe should scale down (shrinking)")
        #expect(viewModel.rotation != 0.0, "Left swipe should have rotation")
    }

    @Test("Up swipe visual feedback: blue tint, lightening")
    func upSwipeVisualFeedback() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 0, height: -50)

        viewModel.updateGestureState(translation: translation)

        #expect(viewModel.tintColor != .clear, "Up swipe should have tint color")
        #expect(viewModel.opacity < 1.0, "Up swipe should reduce opacity (lightening)")
    }

    @Test("Down swipe visual feedback: orange tint, heavy")
    func downSwipeVisualFeedback() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 0, height: 50)

        viewModel.updateGestureState(translation: translation)

        #expect(viewModel.tintColor != .clear, "Down swipe should have tint color")
        #expect(viewModel.scale > 1.0, "Down swipe should scale up (heavy)")
    }

    @Test("No direction shows subtle feedback")
    func noneDirectionFeedback() {
        let viewModel = CardGestureViewModel()
        let translation = CGSize(width: 0, height: 0)

        viewModel.updateGestureState(translation: translation)

        #expect(viewModel.tintColor == .clear, "No direction should have clear tint")
        #expect(viewModel.rotation == 0.0, "No direction should have no rotation")
        #expect(viewModel.scale == 1.0, "No translation should have default scale (1.0)")
    }

    @Test("Progress increases visual effect intensity")
    func progressIntensity() {
        let viewModel = CardGestureViewModel()

        // Small movement
        viewModel.updateGestureState(translation: CGSize(width: 20, height: 0))
        let scale1 = viewModel.scale

        // Larger movement
        viewModel.updateGestureState(translation: CGSize(width: 80, height: 0))
        let scale2 = viewModel.scale

        #expect(scale2 > scale1, "Greater progress should increase visual effect")
    }

    // MARK: - Swipe Threshold Tests

    @Test("Swipe at threshold commits")
    func swipeThresholdCommit() {
        let viewModel = CardGestureViewModel()

        #expect(viewModel.shouldCommitSwipe(translation: CGSize(width: 100, height: 0)) == true, "Swipe at threshold should commit")
        #expect(viewModel.shouldCommitSwipe(translation: CGSize(width: 0, height: 100)) == true, "Vertical swipe at threshold should commit")
    }

    @Test("Swipe below threshold does not commit")
    func swipeBelowThreshold() {
        let viewModel = CardGestureViewModel()

        #expect(viewModel.shouldCommitSwipe(translation: CGSize(width: 99, height: 0)) == false, "Swipe below threshold should not commit")
        #expect(viewModel.shouldCommitSwipe(translation: CGSize(width: 50, height: 0)) == false, "Small swipe should not commit")
    }

    @Test("Diagonal swipe threshold uses max distance")
    func diagonalThreshold() {
        let viewModel = CardGestureViewModel()

        // Diagonal where max distance equals threshold (uses max, not Euclidean)
        let diag1 = CGSize(width: 100, height: 100) // max(100, 100) = 100
        #expect(viewModel.shouldCommitSwipe(translation: diag1) == true, "Diagonal at threshold should commit")

        // Diagonal below threshold
        let diag2 = CGSize(width: 99, height: 99) // max(99, 99) = 99
        #expect(viewModel.shouldCommitSwipe(translation: diag2) == false, "Diagonal below threshold should not commit")
    }

    // MARK: - Rating Mapping Tests

    @Test("Direction to rating mapping is correct")
    func ratingMapping() {
        let viewModel = CardGestureViewModel()

        #expect(viewModel.ratingForDirection(.right) == 2, "Right should map to Good (2)")
        #expect(viewModel.ratingForDirection(.left) == 0, "Left should map to Again (0)")
        #expect(viewModel.ratingForDirection(.up) == 3, "Up should map to Easy (3)")
        #expect(viewModel.ratingForDirection(.down) == 1, "Down should map to Hard (1)")
        #expect(viewModel.ratingForDirection(.none) == 2, "None should default to Good (2)")
    }

    // MARK: - Reset Tests

    @Test("Reset clears all state")
    func resetState() {
        let viewModel = CardGestureViewModel()

        // Modify state
        viewModel.updateGestureState(translation: CGSize(width: 50, height: 50))

        // Verify state is modified
        #expect(viewModel.offset != .zero, "State should be modified")

        // Reset
        viewModel.resetGestureState()

        // Verify all properties are reset
        #expect(viewModel.offset == .zero, "Offset should be zero after reset")
        #expect(viewModel.scale == 1.0, "Scale should be 1.0 after reset")
        #expect(viewModel.rotation == 0.0, "Rotation should be 0 after reset")
        #expect(viewModel.opacity == 1.0, "Opacity should be 1.0 after reset")
        #expect(viewModel.tintColor == .clear, "Tint should be clear after reset")
    }

    @Test("Multiple resets are safe")
    func multipleResets() {
        let viewModel = CardGestureViewModel()

        viewModel.resetGestureState()
        viewModel.resetGestureState()
        viewModel.resetGestureState()

        #expect(viewModel.offset == .zero, "State should remain default after multiple resets")
    }

    // MARK: - Haptic Direction Extension Tests

    @Test("Haptic direction extension works for all directions")
    func hapticDirectionExtension() {
        #expect(CardGestureViewModel.SwipeDirection.right.hapticDirection == .right, "Right should map to right")
        #expect(CardGestureViewModel.SwipeDirection.left.hapticDirection == .left, "Left should map to left")
        #expect(CardGestureViewModel.SwipeDirection.up.hapticDirection == .up, "Up should map to up")
        #expect(CardGestureViewModel.SwipeDirection.down.hapticDirection == .down, "Down should map to down")
        #expect(CardGestureViewModel.SwipeDirection.none.hapticDirection == .right, "None should fallback to right")
    }

    // MARK: - Edge Cases

    @Test("Negative translation values work correctly")
    func negativeTranslation() {
        let viewModel = CardGestureViewModel()

        let direction1 = viewModel.detectDirection(translation: CGSize(width: -50, height: 0))
        #expect(direction1 == .left, "Negative width should be left")

        let direction2 = viewModel.detectDirection(translation: CGSize(width: 0, height: -50))
        #expect(direction2 == .up, "Negative height should be up")
    }

    @Test("Zero translation returns none")
    func zeroTranslation() {
        let viewModel = CardGestureViewModel()
        let direction = viewModel.detectDirection(translation: .zero)
        #expect(direction == .none, "Zero translation should return none")
    }

    @Test("Very large translation values are handled")
    func largeTranslation() {
        let viewModel = CardGestureViewModel()

        // Very large translation
        viewModel.updateGestureState(translation: CGSize(width: 500, height: 0))

        // Should not crash, values should be reasonable
        #expect(viewModel.scale > 0, "Scale should be positive")
        #expect(viewModel.opacity >= 0, "Opacity should be non-negative")
    }
}
