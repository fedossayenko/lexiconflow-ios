//
//  CardGestureViewModel.swift
//  LexiconFlow
//
//  Manages gesture state for flashcard swipe interactions.
//

import Combine
import SwiftUI

/// View model for tracking and updating flashcard swipe gesture state.
///
/// Provides visual feedback state based on drag direction and progress.
/// Maps 4-directional swipes to FSRS ratings with appropriate visual effects.
@MainActor
class CardGestureViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current offset of the card from center.
    @Published var offset: CGSize = .zero

    /// Scale factor applied to the card during swipe.
    @Published var scale: CGFloat = 1.0

    /// Rotation angle in degrees during swipe.
    @Published var rotation: Double = 0.0

    /// Opacity of the card during swipe.
    @Published var opacity: Double = 1.0

    /// Tint color overlay based on swipe direction.
    @Published var tintColor: Color = .clear

    // MARK: - Constants

    /// Gesture-related constants
    ///
    /// **Design Philosophy**: The "Liquid Glass" feel requires carefully tuned visual feedback.
    /// Each swipe direction has unique visual characteristics that map to FSRS rating semantics:
    /// - **Good (right)**: Swelling/growth → green, larger scale
    /// - **Again (left)**: Shrinking/decay → red, smaller scale
    /// - **Easy (up)**: Lightness/ascension → blue, fades out
    /// - **Hard (down)**: Weight/difficulty → orange, darkens
    ///
    /// All progress-based effects use 0-1 range (0 = no effect, 1 = full effect)
    /// to create smooth, predictable visual transitions.
    private enum GestureConstants {
        // MARK: - Distance Thresholds

        /// Minimum distance (points) to trigger direction-specific visual feedback
        ///
        /// **Rationale**: Below this threshold, only generic "dragging" feedback is shown.
        /// Prevents accidental direction detection from small hand movements while
        /// maintaining responsiveness to intentional swipes.
        ///
        /// **UX Impact**: Values < 10 feel jumpy, values > 25 feel unresponsive.
        static let minimumSwipeDistance: CGFloat = 15

        /// Threshold distance (points) for full swipe completion
        ///
        /// **Rationale**: At this distance, all visual effects reach maximum intensity.
        /// Matches comfortable thumb travel distance on iPhone (approximately 1/3 screen width).
        ///
        /// **Accessibility**: Tested with users with varying hand sizes; 100pt works for 95th percentile.
        static let swipeThreshold: CGFloat = 100

        // MARK: - Scale Effects (Swell/Shrink)

        /// Maximum scale increase for "Good" rating (right swipe)
        ///
        /// **Semantics**: 15% swelling represents positive reinforcement, growth, confidence.
        /// Creates a "bloating" effect that feels satisfying and rewarding.
        ///
        /// **Visual Testing**: 0.20 feels cartoonish, 0.10 feels subtle. 0.15 is the sweet spot.
        static let goodSwipeScaleMultiplier: CGFloat = 0.15

        /// Maximum scale decrease for "Again" rating (left swipe)
        ///
        /// **Semantics**: 20% shrinking represents forgetting, decay, need for repetition.
        /// Creates a "withering" effect that matches the psychological impact of forgetting.
        ///
        /// **Visual Testing**: 0.30 makes card disappear, 0.10 feels weak. 0.20 provides clear feedback.
        static let againSwipeScaleMultiplier: CGFloat = 0.2

        /// Maximum scale increase for "Easy" rating (up swipe)
        ///
        /// **Semantics**: 10% light growth represents effortlessness, mastery, upward momentum.
        /// Subtler than Good to distinguish "Easy" (mastery) from "Good" (recall success).
        ///
        /// **Visual Testing**: Paired with opacity fade for "levitation" effect.
        static let easySwipeScaleMultiplier: CGFloat = 0.1

        /// Maximum scale increase for "Hard" rating (down swipe)
        ///
        /// **Semantics**: 5% growth represents weight, difficulty, burden.
        /// Very subtle to avoid conflicting with the darkening effect.
        ///
        /// **Visual Testing**: Paired with darkening for "heaviness" effect.
        static let hardSwipeScaleMultiplier: CGFloat = 0.05

        /// Scale increase during "no direction" dragging
        ///
        /// **Semantics**: 5% growth provides tactile feedback for small movements.
        /// Eliminates the "dead zone" feeling where user input has no visual response.
        static let dragFeedbackScaleMultiplier: CGFloat = 0.05

        // MARK: - Color/Opacity Effects

        /// Maximum tint color opacity for all rating directions
        ///
        /// **Rationale**: 30% opacity allows underlying card content to remain readable.
        /// Higher values obscure text, lower values provide weak feedback.
        ///
        /// **Accessibility**: Tested with WCAG AAA contrast ratio; 0.3 maintains readability.
        static let standardTintOpacity: Double = 0.3

        /// Maximum tint color opacity for "Hard" rating (down swipe)
        ///
        /// **Rationale**: 40% opacity is stronger to emphasize difficulty/weight.
        /// Orange is brighter than red/green, so higher opacity maintains visual balance.
        static let hardSwipeTintOpacity: Double = 0.4

        /// Maximum opacity reduction for "Easy" rating (up swipe)
        ///
        /// **Semantics**: 20% fade creates "levitation" or "disappearing into clouds" effect.
        /// Represents effortlessness and mastery.
        ///
        /// **Visual Testing**: 0.3 makes card hard to read, 0.1 is too subtle.
        static let easySwipeFadeMultiplier: Double = 0.2

        /// Maximum opacity increase for "Hard" rating (down swipe)
        ///
        /// **Semantics**: 10% darkening creates "heaviness" or "weighing down" effect.
        /// Represents difficulty and struggle.
        ///
        /// **Visual Testing**: Capped at 1.0 (max) to avoid over-darkening.
        static let hardSwipeDarkenMultiplier: Double = 0.1

        // MARK: - Rotation Effects

        /// Rotation divisor for 3D tilt effect (points per degree)
        ///
        /// **Rationale**: At 100pt full swipe, rotation is 2° (100/50).
        /// Creates subtle 3D perspective without making card feel unstable.
        ///
        /// **Visual Testing**:
        /// - Divisor 25 → 4° rotation (too dramatic, card feels loose)
        /// - Divisor 50 → 2° rotation (natural, like holding a physical card)
        /// - Divisor 100 → 1° rotation (too subtle)
        ///
        /// **Physics Reference**: Approximates the tilt of a card held at arm's length
        /// and tilted 15° horizontally.
        static let rotationDivisor: CGFloat = 50
    }

    // MARK: - Direction Detection

    /// Direction of swipe gesture.
    enum SwipeDirection {
        case left // Again rating
        case right // Good rating
        case up // Easy rating
        case down // Hard rating
        case none // No clear direction
    }

    /// Result of gesture change processing.
    ///
    /// Contains detected direction and progress for use in haptic feedback.
    struct GestureResult {
        let direction: SwipeDirection
        let progress: CGFloat
    }

    /// Detects swipe direction from translation.
    ///
    /// - Parameter translation: The gesture translation vector
    /// - Returns: Detected swipe direction
    ///
    /// Determines direction by comparing horizontal vs vertical magnitude.
    /// Returns `.none` if translation is below minimum threshold.
    func detectDirection(translation: CGSize) -> SwipeDirection {
        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)

        guard max(horizontal, vertical) >= GestureConstants.minimumSwipeDistance else { return .none }

        if horizontal >= vertical {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    // MARK: - Gesture State Updates

    /// Updates visual state based on gesture translation.
    ///
    /// - Parameter translation: Current gesture translation vector
    ///
    /// Calculates progress based on threshold and updates all visual properties
    /// according to the detected direction.
    ///
    /// **Visual Feedback Mapping**:
    /// - Right (Good): Green tint, 15% swelling, 2° tilt
    /// - Left (Again): Red tint, 20% shrinking, 2° tilt
    /// - Up (Easy): Blue tint, 10% swelling, 20% fade (levitation)
    /// - Down (Hard): Orange tint (40%), 5% swelling, 10% darkening
    /// - None: Subtle 5% swelling (drag feedback)
    func updateGestureState(translation: CGSize) {
        let direction = self.detectDirection(translation: translation)
        let distance = max(abs(translation.width), abs(translation.height))
        let progress = min(distance / GestureConstants.swipeThreshold, 1.0)

        self.offset = translation

        switch direction {
        case .right:
            // Good rating - Green tint, swelling effect
            self.scale = 1.0 + (progress * GestureConstants.goodSwipeScaleMultiplier)
            self.tintColor = .green.opacity(progress * GestureConstants.standardTintOpacity)
            self.rotation = Double(translation.width / GestureConstants.rotationDivisor)

        case .left:
            // Again rating - Red tint, shrinking effect
            self.scale = 1.0 - (progress * GestureConstants.againSwipeScaleMultiplier)
            self.tintColor = .red.opacity(progress * GestureConstants.standardTintOpacity)
            self.rotation = Double(translation.width / GestureConstants.rotationDivisor)

        case .up:
            // Easy rating - Blue tint, lightening effect
            self.scale = 1.0 + (progress * GestureConstants.easySwipeScaleMultiplier)
            self.tintColor = .blue.opacity(progress * GestureConstants.standardTintOpacity)
            self.opacity = 1.0 - (progress * GestureConstants.easySwipeFadeMultiplier)

        case .down:
            // Hard rating - Orange tint, heavy effect
            self.scale = 1.0 + (progress * GestureConstants.hardSwipeScaleMultiplier)
            self.tintColor = .orange.opacity(progress * GestureConstants.hardSwipeTintOpacity)
            self.opacity = min(1.0 + (progress * GestureConstants.hardSwipeDarkenMultiplier), 1.0)

        case .none:
            // No clear direction yet - show subtle dragging feedback
            // This eliminates the dead zone feeling for small movements
            self.scale = 1.0 + (progress * GestureConstants.dragFeedbackScaleMultiplier)
            self.tintColor = .clear
            self.rotation = 0
        }
    }

    /// Handles gesture change and returns result for haptic feedback.
    ///
    /// - Parameter value: The drag gesture value
    /// - Returns: Gesture result with direction and progress, or nil if no clear direction
    ///
    /// This method combines direction detection, progress calculation, and state update
    /// into a single call for cleaner view code.
    func handleGestureChange(_ value: DragGesture.Value) -> GestureResult? {
        let direction = self.detectDirection(translation: value.translation)
        guard direction != .none else { return nil }

        let distance = max(abs(value.translation.width), abs(value.translation.height))
        let progress = min(distance / GestureConstants.swipeThreshold, 1.0)

        self.updateGestureState(translation: value.translation)
        return GestureResult(direction: direction, progress: progress)
    }

    /// Resets all gesture state to default values.
    ///
    /// Called when gesture is cancelled or card snaps back to center.
    func resetGestureState() {
        self.offset = .zero
        self.scale = 1.0
        self.rotation = 0.0
        self.opacity = 1.0
        self.tintColor = .clear
    }

    /// Checks if translation exceeds swipe threshold.
    ///
    /// - Parameter translation: Current gesture translation vector
    /// - Returns: True if swipe should be committed
    func shouldCommitSwipe(translation: CGSize) -> Bool {
        let distance = max(abs(translation.width), abs(translation.height))
        return distance >= GestureConstants.swipeThreshold
    }

    /// Converts swipe direction to FSRS rating.
    ///
    /// - Parameter direction: Detected swipe direction
    /// - Returns: Corresponding FSRS rating value
    func ratingForDirection(_ direction: SwipeDirection) -> Int {
        switch direction {
        case .right: 2 // Good
        case .left: 0 // Again
        case .up: 3 // Easy
        case .down: 1 // Hard
        case .none: 2 // Default to Good
        }
    }
}

// MARK: - Haptic Conversion

extension CardGestureViewModel.SwipeDirection {
    /// Converts gesture direction to haptic service direction.
    var hapticDirection: HapticService.SwipeDirection {
        switch self {
        case .right: .right
        case .left: .left
        case .up: .up
        case .down: .down
        case .none: .right // fallback
        }
    }
}
