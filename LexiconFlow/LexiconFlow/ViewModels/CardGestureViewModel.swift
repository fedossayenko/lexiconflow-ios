//
//  CardGestureViewModel.swift
//  LexiconFlow
//
//  Manages gesture state for flashcard swipe interactions.
//

import Combine
import SwiftUI

// MARK: - Card Gesture ViewModel

// View model for tracking and updating flashcard swipe gesture state.
//
// **Overview:**
// Provides visual feedback state based on drag direction and progress.
// Maps 4-directional swipes to FSRS ratings with appropriate visual effects.
//
// ## Design Rationale
//
// **Swipe Threshold (100pt):**
// - Based on iOS HIG minimum touch target (44pt) × 2.5 for comfortable swipe
// - Requires deliberate gesture action (prevents accidental swipes)
// - Balanced for thumb reach on typical iPhone screen widths
// - Maps to FSRS rating commit point
//
// **Minimum Distance (15pt):**
// - Filters out accidental touches while maintaining responsiveness
// - Below 15pt: No direction detected (dead zone for jitter)
// - Above 15pt: Direction detection begins
// - Triggers initial visual feedback (5% swelling)
//
// **Rotation (5° max at threshold):**
// - Subtle 3D perspective without causing motion sickness
// - Calculated as: `translation.width / 50` (100pt / 50 = 2° for most swipes)
// - Provides tactile feedback through visual depth
// - Limited to prevent disorientation
//
// **Scale Effects:**
// - **Good (right):** +15% swelling (positive reinforcement)
// - **Again (left):** -20% shrinking (negative feedback)
// - **Easy (up):** +10% swelling + 20% fade (levitation effect)
// - **Hard (down):** +5% swelling + 10% darkening (weight effect)
// - **Drag feedback:** +5% swelling (eliminates dead zone feel)
//
// ## Sensitivity Mapping
//
// Dynamic gesture constants adjust swipe thresholds based on user preference:
//
// | Sensitivity | Threshold (pt) | Min Distance (pt) | Behavior |
// |-------------|----------------|-------------------|----------|
// | 0.5× (Low)  | 200            | 30                | 2× harder to trigger |
// | 1.0× (Default) | 100        | 15                | Original thresholds |
// | 2.0× (High) | 50             | 7.5               | 50% easier to trigger |
//
// **Formula:** `adjustedValue = baseValue / sensitivity`
//
// **Note:** Visual effects (scale multipliers, rotation, tints) remain constant
// across sensitivity levels to maintain consistent visual feedback.
//
// ## Visual Feedback Mapping
//
// - **Right (Good):** Green tint, 15% swelling, 2° tilt
// - **Left (Again):** Red tint, 20% shrinking, 2° tilt
// - **Up (Easy):** Blue tint, 10% swelling, 20% fade (levitation)
// - **Down (Hard):** Orange tint (40%), 5% swelling, 10% darkening
// - **None:** Subtle 5% swelling (drag feedback only)

// MARK: - Gesture State

/// Single struct containing all gesture state for efficient batching
///
/// **Performance**: Groups 5 separate @Published properties into one struct
/// This reduces view update overhead from 5 triggers to 1 per frame during gestures
struct GestureState: Equatable {
    /// Current offset of the card from center
    var offset: CGSize = .zero

    /// Scale factor applied to the card during swipe
    var scale: CGFloat = 1.0

    /// Rotation angle in degrees during swipe
    var rotation: Double = 0.0

    /// Opacity of the card during swipe
    var opacity: Double = 1.0

    /// Tint color overlay based on swipe direction
    var tintColor: Color = .clear

    /// Default initial state
    static let initial = GestureState()
}

@MainActor
class CardGestureViewModel: ObservableObject {
    // MARK: - Published Properties

    /// PERFORMANCE: Single @Published struct instead of 5 separate properties
    /// This batches all gesture state updates into a single view refresh per frame
    /// reducing view updates from 5 to 1 during drag gestures (60-120hz)
    @Published private(set) var gestureState: GestureState = .init()

    /// Binding for InteractiveGlassModifier compatibility
    /// Provides a binding to offset that updates the internal gestureState
    var offsetBinding: Binding<CGSize> {
        Binding(
            get: { self.gestureState.offset },
            set: { self.gestureState.offset = $0 }
        )
    }

    /// Convenience accessors for backward compatibility with existing views
    var offset: CGSize { self.gestureState.offset }
    var scale: CGFloat { self.gestureState.scale }
    var rotation: Double { self.gestureState.rotation }
    var opacity: Double { self.gestureState.opacity }
    var tintColor: Color { self.gestureState.tintColor }

    // MARK: - Constants (Dynamic)

    /// Dynamic gesture constants based on user sensitivity preference
    ///
    /// **Sensitivity Mapping:**
    /// - Higher sensitivity (e.g., 2.0x) = lower threshold = easier to trigger
    /// - Lower sensitivity (e.g., 0.5x) = higher threshold = harder to trigger
    private var gestureConstants: GestureConstants {
        let sensitivity = AppSettings.gestureSensitivity

        return GestureConstants(
            // Adjust thresholds inversely with sensitivity:
            // - Higher sensitivity = lower threshold (easier to trigger)
            // - Lower sensitivity = higher threshold (harder to trigger)
            minimumSwipeDistance: 15.0 / sensitivity,
            swipeThreshold: 100.0 / sensitivity,

            // Scale multipliers remain constant
            goodSwipeScaleMultiplier: 0.15,
            againSwipeScaleMultiplier: 0.2,
            easySwipeScaleMultiplier: 0.1,
            hardSwipeScaleMultiplier: 0.05,
            dragFeedbackScaleMultiplier: 0.05,

            // Visual effects remain constant
            standardTintOpacity: 0.3,
            hardSwipeTintOpacity: 0.4,
            easySwipeFadeMultiplier: 0.2,
            hardSwipeDarkenMultiplier: 0.1,

            // Rotation remains constant
            rotationDivisor: 50
        )
    }

    /// Gesture-related constants (now dynamically computed)
    private struct GestureConstants {
        let minimumSwipeDistance: CGFloat
        let swipeThreshold: CGFloat
        let goodSwipeScaleMultiplier: CGFloat
        let againSwipeScaleMultiplier: CGFloat
        let easySwipeScaleMultiplier: CGFloat
        let hardSwipeScaleMultiplier: CGFloat
        let dragFeedbackScaleMultiplier: CGFloat
        let standardTintOpacity: Double
        let hardSwipeTintOpacity: Double
        let easySwipeFadeMultiplier: Double
        let hardSwipeDarkenMultiplier: Double
        let rotationDivisor: CGFloat
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

        let constants = self.gestureConstants
        guard max(horizontal, vertical) >= constants.minimumSwipeDistance else { return .none }

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
    /// **PERFORMANCE**: Builds new GestureState in a single allocation and assigns once
    /// This triggers exactly ONE view refresh instead of 5 separate updates
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
        let constants = self.gestureConstants
        let direction = self.detectDirection(translation: translation)
        let distance = max(abs(translation.width), abs(translation.height))
        let progress = min(distance / constants.swipeThreshold, 1.0)

        // Build new state (single allocation)
        var newState = self.gestureState
        newState.offset = translation

        switch direction {
        case .right:
            // Good rating - Green tint, swelling effect
            newState.scale = 1.0 + (progress * constants.goodSwipeScaleMultiplier)
            newState.tintColor = .green.opacity(progress * constants.standardTintOpacity)
            newState.rotation = Double(translation.width / constants.rotationDivisor)

        case .left:
            // Again rating - Red tint, shrinking effect
            newState.scale = 1.0 - (progress * constants.againSwipeScaleMultiplier)
            newState.tintColor = .red.opacity(progress * constants.standardTintOpacity)
            newState.rotation = Double(translation.width / constants.rotationDivisor)

        case .up:
            // Easy rating - Blue tint, lightening effect
            newState.scale = 1.0 + (progress * constants.easySwipeScaleMultiplier)
            newState.tintColor = .blue.opacity(progress * constants.standardTintOpacity)
            newState.opacity = 1.0 - (progress * constants.easySwipeFadeMultiplier)

        case .down:
            // Hard rating - Orange tint, heavy effect
            newState.scale = 1.0 + (progress * constants.hardSwipeScaleMultiplier)
            newState.tintColor = .orange.opacity(progress * constants.hardSwipeTintOpacity)
            newState.opacity = min(1.0 + (progress * constants.hardSwipeDarkenMultiplier), 1.0)

        case .none:
            // No clear direction yet - show subtle dragging feedback
            // This eliminates the dead zone feeling for small movements
            newState.scale = 1.0 + (progress * constants.dragFeedbackScaleMultiplier)
            newState.tintColor = .clear
            newState.rotation = 0
        }

        // Single assignment triggers one view refresh
        self.gestureState = newState
    }

    /// Handles gesture change and returns result for haptic feedback.
    ///
    /// - Parameter value: The drag gesture value
    /// - Returns: Gesture result with direction and progress, or nil if no clear direction
    ///
    /// This method combines direction detection, progress calculation, and state update
    /// into a single call for cleaner view code.
    func handleGestureChange(_ value: DragGesture.Value) -> GestureResult? {
        let constants = self.gestureConstants
        let direction = self.detectDirection(translation: value.translation)
        guard direction != .none else { return nil }

        let distance = max(abs(value.translation.width), abs(value.translation.height))
        let progress = min(distance / constants.swipeThreshold, 1.0)

        self.updateGestureState(translation: value.translation)
        return GestureResult(direction: direction, progress: progress)
    }

    /// Resets all gesture state to default values.
    ///
    /// **PERFORMANCE**: Single assignment resets all state at once
    /// Called when gesture is cancelled or card snaps back to center.
    func resetGestureState() {
        self.gestureState = GestureState.initial
    }

    /// Checks if translation exceeds swipe threshold.
    ///
    /// - Parameter translation: Current gesture translation vector
    /// - Returns: True if swipe should be committed
    func shouldCommitSwipe(translation: CGSize) -> Bool {
        let constants = self.gestureConstants
        let distance = max(abs(translation.width), abs(translation.height))
        return distance >= constants.swipeThreshold
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
