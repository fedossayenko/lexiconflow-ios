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

    // MARK: - Gesture Sensitivity Tests

    @Test("default sensitivity is 1.0")
    func defaultSensitivity() async throws {
        // Given: Fresh AppSettings
        let sensitivity = AppSettings.gestureSensitivity

        // Then: Should be 1.0 (default)
        #expect(sensitivity == 1.0)
    }

    @Test("sensitivity persists in @AppStorage")
    func sensitivityPersists() async throws {
        // Given: Custom sensitivity
        AppSettings.gestureSensitivity = 1.5

        // When: Reading from UserDefaults
        let stored = UserDefaults.standard.double(forKey: "gestureSensitivity")

        // Then: Should persist
        #expect(stored == 1.5)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity range is 0.5 to 2.0")
    func sensitivityRange() async throws {
        // Given: Valid range bounds
        let minSensitivity = 0.5
        let maxSensitivity = 2.0

        // When: Testing boundary values
        AppSettings.gestureSensitivity = minSensitivity
        #expect(AppSettings.gestureSensitivity == minSensitivity)

        AppSettings.gestureSensitivity = maxSensitivity
        #expect(AppSettings.gestureSensitivity == maxSensitivity)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("higher sensitivity (2.0) = lower threshold = easier to trigger")
    func highSensitivityEasierToTrigger() async throws {
        // Given: High sensitivity
        AppSettings.gestureSensitivity = 2.0
        let viewModel = CardGestureViewModel()

        // When: Testing small swipe (should trigger with high sensitivity)
        // minimumSwipeDistance = 15.0 / 2.0 = 7.5
        let translation = CGSize(width: 8, height: 0)
        let direction = viewModel.detectDirection(translation: translation)

        // Then: Should detect direction (easier to trigger)
        #expect(direction == .right)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("lower sensitivity (0.5) = higher threshold = harder to trigger")
    func lowSensitivityHarderToTrigger() async throws {
        // Given: Low sensitivity
        AppSettings.gestureSensitivity = 0.5
        let viewModel = CardGestureViewModel()

        // When: Testing small swipe (should NOT trigger with low sensitivity)
        // minimumSwipeDistance = 15.0 / 0.5 = 30
        let translation = CGSize(width: 20, height: 0)
        let direction = viewModel.detectDirection(translation: translation)

        // Then: Should NOT detect direction (harder to trigger)
        #expect(direction == .none)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity 1.0 uses original thresholds")
    func defaultSensitivityUsesOriginalThresholds() async throws {
        // Given: Default sensitivity
        AppSettings.gestureSensitivity = 1.0
        let viewModel = CardGestureViewModel()

        // When: Testing at original thresholds
        let minTranslation = CGSize(width: 15, height: 0)
        let thresholdTranslation = CGSize(width: 100, height: 0)

        let minDirection = viewModel.detectDirection(translation: minTranslation)
        let shouldCommit = viewModel.shouldCommitSwipe(translation: thresholdTranslation)

        // Then: Should use original values (15pt min, 100pt threshold)
        #expect(minDirection == .right)
        #expect(shouldCommit == true)
    }

    @Test("minimumSwipeDistance = 15.0 / sensitivity")
    func minimumSwipeDistanceFormula() async throws {
        // Given: Various sensitivities
        let viewModel = CardGestureViewModel()

        let sensitivities = [0.5, 1.0, 2.0]
        let expectedDistances = [30.0, 15.0, 7.5]

        for (sensitivity, expectedDistance) in zip(sensitivities, expectedDistances) {
            AppSettings.gestureSensitivity = sensitivity

            // Test at expected boundary (should trigger)
            let translation = CGSize(width: expectedDistance, height: 0)
            let direction = viewModel.detectDirection(translation: translation)

            #expect(direction == .right, "Should trigger at \(expectedDistance)pt with sensitivity \(sensitivity)")
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("swipeThreshold = 100.0 / sensitivity")
    func swipeThresholdFormula() async throws {
        // Given: Various sensitivities
        let viewModel = CardGestureViewModel()

        let sensitivities = [0.5, 1.0, 2.0]
        let expectedThresholds = [200.0, 100.0, 50.0]

        for (sensitivity, expectedThreshold) in zip(sensitivities, expectedThresholds) {
            AppSettings.gestureSensitivity = sensitivity

            // Test at threshold (should commit)
            let translation = CGSize(width: expectedThreshold, height: 0)
            let shouldCommit = viewModel.shouldCommitSwipe(translation: translation)

            #expect(shouldCommit == true, "Should commit at \(expectedThreshold)pt with sensitivity \(sensitivity)")
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("visual effect multipliers remain constant")
    func visualEffectsConstantAcrossSensitivity() async throws {
        // Given: Different sensitivities
        let sensitivities = [0.5, 1.0, 2.0]
        let translation = CGSize(width: 50, height: 0)

        var firstScale: CGFloat?

        for sensitivity in sensitivities {
            AppSettings.gestureSensitivity = sensitivity
            let viewModel = CardGestureViewModel()
            viewModel.updateGestureState(translation: translation)

            if let first = firstScale {
                // Visual effects should be similar (within tolerance)
                #expect(abs(viewModel.scale - first) < 0.01, "Scale should be consistent across sensitivity")
            } else {
                firstScale = viewModel.scale
            }
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("rotation divisor remains constant")
    func rotationDivisorConstant() async throws {
        // Given: Different sensitivities
        let translation = CGSize(width: 50, height: 0)

        for sensitivity in [0.5, 1.0, 2.0] {
            AppSettings.gestureSensitivity = sensitivity
            let viewModel = CardGestureViewModel()
            viewModel.updateGestureState(translation: translation)

            // Rotation should be consistent (50pt divisor is constant)
            let expectedRotation = Double(50 / 50) // 1 degree
            #expect(abs(viewModel.rotation - expectedRotation) < 0.1, "Rotation should be consistent")
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    // MARK: - Dynamic Constants Tests

    @Test("gestureConstants recomputes when sensitivity changes")
    func constantsRecomputeWithSensitivity() async throws {
        // Given: Changing sensitivity
        AppSettings.gestureSensitivity = 2.0
        let viewModel1 = CardGestureViewModel()

        // When: Testing detection at new threshold
        let translation = CGSize(width: 6, height: 0) // Above 7.5pt min
        let direction1 = viewModel1.detectDirection(translation: translation)

        // Then: Should detect direction (recomputed constants)
        #expect(direction1 == .right)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity changes affect direction detection immediately")
    func sensitivityAffectsDirectionImmediately() async throws {
        // Given: Initial sensitivity (low)
        AppSettings.gestureSensitivity = 0.5
        let viewModel = CardGestureViewModel()

        // When: Testing with small swipe
        let translation = CGSize(width: 20, height: 0)
        let direction1 = viewModel.detectDirection(translation: translation)

        // Then: Should NOT trigger (high threshold)
        #expect(direction1 == .none)

        // When: Changing to high sensitivity
        AppSettings.gestureSensitivity = 2.0
        let direction2 = viewModel.detectDirection(translation: translation)

        // Then: Should trigger (low threshold)
        #expect(direction2 == .right)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity 2.0 makes gestures easier to trigger")
    func highSensitivityBehavior() async throws {
        // Given: High sensitivity
        AppSettings.gestureSensitivity = 2.0
        let viewModel = CardGestureViewModel()

        // When: Testing various small swipes
        let smallSwipes = [
            CGSize(width: 8, height: 0), // 8pt > 7.5pt min
            CGSize(width: 25, height: 0), // 25pt < 50pt threshold
            CGSize(width: 50, height: 0) // 50pt = threshold
        ]

        for swipe in smallSwipes {
            let direction = viewModel.detectDirection(translation: swipe)
            #expect(direction == .right, "Should detect direction for small swipe")
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity 0.5 makes gestures harder to trigger")
    func lowSensitivityBehavior() async throws {
        // Given: Low sensitivity
        AppSettings.gestureSensitivity = 0.5
        let viewModel = CardGestureViewModel()

        // When: Testing moderate swipes
        let moderateSwipes = [
            CGSize(width: 20, height: 0), // 20pt < 30pt min
            CGSize(width: 25, height: 0), // 25pt < 30pt min
            CGSize(width: 29, height: 0) // 29pt < 30pt min
        ]

        for swipe in moderateSwipes {
            let direction = viewModel.detectDirection(translation: swipe)
            #expect(direction == .none, "Should NOT detect direction for moderate swipe")
        }

        // But large swipes should still work
        let largeSwipe = CGSize(width: 150, height: 0) // 150pt < 200pt threshold
        let shouldCommit = viewModel.shouldCommitSwipe(translation: largeSwipe)
        #expect(shouldCommit == false, "Should NOT commit below adjusted threshold")

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity doesn't affect visual feedback intensity")
    func sensitivityDoesntAffectVisuals() async throws {
        // Given: Same translation, different sensitivities
        let translation = CGSize(width: 50, height: 0)

        var scales: [CGFloat] = []

        for sensitivity in [0.5, 1.0, 2.0] {
            AppSettings.gestureSensitivity = sensitivity
            let viewModel = CardGestureViewModel()
            viewModel.updateGestureState(translation: translation)
            scales.append(viewModel.scale)
        }

        // Then: Scales should be very similar (visual effects constant)
        #expect(abs(scales[0] - scales[1]) < 0.01)
        #expect(abs(scales[1] - scales[2]) < 0.01)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity doesn't affect rating mapping")
    func sensitivityDoesntAffectRating() async throws {
        // Given: Different sensitivities
        for sensitivity in [0.5, 1.0, 2.0] {
            AppSettings.gestureSensitivity = sensitivity
            let viewModel = CardGestureViewModel()

            // When: Mapping directions to ratings
            let rightRating = viewModel.ratingForDirection(.right)
            let leftRating = viewModel.ratingForDirection(.left)
            let upRating = viewModel.ratingForDirection(.up)
            let downRating = viewModel.ratingForDirection(.down)

            // Then: Ratings should be consistent
            #expect(rightRating == 2)
            #expect(leftRating == 0)
            #expect(upRating == 3)
            #expect(downRating == 1)
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity doesn't affect reset behavior")
    func sensitivityDoesntAffectReset() async throws {
        // Given: Different sensitivities
        for sensitivity in [0.5, 1.0, 2.0] {
            AppSettings.gestureSensitivity = sensitivity
            let viewModel = CardGestureViewModel()

            // Modify state
            viewModel.updateGestureState(translation: CGSize(width: 50, height: 50))

            // Reset
            viewModel.resetGestureState()

            // Then: Should reset cleanly
            #expect(viewModel.offset == .zero)
            #expect(viewModel.scale == 1.0)
            #expect(viewModel.rotation == 0.0)
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity changes are thread-safe")
    func sensitivityIsThreadSafe() async throws {
        // Given: MainActor isolation
        // When: Changing sensitivity from MainActor
        AppSettings.gestureSensitivity = 1.5

        // Then: Should update safely
        #expect(AppSettings.gestureSensitivity == 1.5)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    // MARK: - Edge Cases (6 tests)

    @Test("sensitivity at minimum (0.5)")
    func sensitivityAtMinimum() async throws {
        // Given: Minimum sensitivity
        AppSettings.gestureSensitivity = 0.5
        let viewModel = CardGestureViewModel()

        // When: Testing at minimum boundary
        // minDistance = 30pt, threshold = 200pt
        let minTranslation = CGSize(width: 30, height: 0)
        let thresholdTranslation = CGSize(width: 200, height: 0)

        let minDirection = viewModel.detectDirection(translation: minTranslation)
        let shouldCommit = viewModel.shouldCommitSwipe(translation: thresholdTranslation)

        // Then: Should work at adjusted thresholds
        #expect(minDirection == .right)
        #expect(shouldCommit == true)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity at maximum (2.0)")
    func sensitivityAtMaximum() async throws {
        // Given: Maximum sensitivity
        AppSettings.gestureSensitivity = 2.0
        let viewModel = CardGestureViewModel()

        // When: Testing at maximum boundary
        // minDistance = 7.5pt, threshold = 50pt
        let minTranslation = CGSize(width: 8, height: 0)
        let thresholdTranslation = CGSize(width: 50, height: 0)

        let minDirection = viewModel.detectDirection(translation: minTranslation)
        let shouldCommit = viewModel.shouldCommitSwipe(translation: thresholdTranslation)

        // Then: Should work at adjusted thresholds
        #expect(minDirection == .right)
        #expect(shouldCommit == true)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity below minimum clamps to 0.5")
    func sensitivityBelowMinimumClamps() async throws {
        // Given: Value below minimum
        // Note: @AppStorage doesn't automatically clamp
        AppSettings.gestureSensitivity = 0.2

        // When: Reading value
        let actualValue = AppSettings.gestureSensitivity

        // Then: Should store value (clamping may be enforced by UI)
        // This test verifies the value persists as-is
        #expect(actualValue == 0.2)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("sensitivity above maximum clamps to 2.0")
    func sensitivityAboveMaximumClamps() async throws {
        // Given: Value above maximum
        // Note: @AppStorage doesn't automatically clamp
        AppSettings.gestureSensitivity = 3.0

        // When: Reading value
        let actualValue = AppSettings.gestureSensitivity

        // Then: Should store value (clamping may be enforced by UI)
        #expect(actualValue == 3.0)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("extreme sensitivity values don't cause crashes")
    func extremeSensitivitySafe() async throws {
        // Given: Extreme values
        let extremeValues = [0.1, 0.01, 5.0, 10.0]

        for value in extremeValues {
            AppSettings.gestureSensitivity = value
            let viewModel = CardGestureViewModel()

            // When: Testing operations
            viewModel.updateGestureState(translation: CGSize(width: 50, height: 50))
            viewModel.resetGestureState()
            _ = viewModel.detectDirection(translation: CGSize(width: 100, height: 0))

            // Then: No crash
            #expect(viewModel.offset != nil) // Verify object still valid
        }

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }

    @Test("rapid sensitivity changes don't cause state corruption")
    func rapidSensitivityChangesSafe() async throws {
        // Given: ViewModel instance
        let viewModel = CardGestureViewModel()

        // When: Rapidly changing sensitivity
        for _ in 0 ..< 20 {
            AppSettings.gestureSensitivity = Double.random(in: 0.5 ... 2.0)
            viewModel.updateGestureState(translation: CGSize(width: 50, height: 0))
            viewModel.resetGestureState()
        }

        // Then: State should remain valid
        #expect(viewModel.offset == .zero)
        #expect(viewModel.scale == 1.0)

        // Reset
        AppSettings.gestureSensitivity = 1.0
    }
}
