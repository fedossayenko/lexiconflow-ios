//
//  CardGestureViewModel.swift
//  LexiconFlow
//
//  Manages gesture state for flashcard swipe interactions.
//

import SwiftUI
import Combine

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

    /// Minimum distance to trigger swipe recognition.
    private let minimumSwipeDistance: CGFloat = 20

    /// Threshold distance for full swipe completion.
    private let swipeThreshold: CGFloat = 100

    // MARK: - Direction Detection

    /// Direction of swipe gesture.
    enum SwipeDirection {
        case left    // Again rating
        case right   // Good rating
        case up      // Easy rating
        case down    // Hard rating
        case none    // No clear direction
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

        guard max(horizontal, vertical) > minimumSwipeDistance else { return .none }

        if horizontal > vertical {
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
    func updateGestureState(translation: CGSize) {
        let direction = detectDirection(translation: translation)
        let distance = max(abs(translation.width), abs(translation.height))
        let progress = min(distance / swipeThreshold, 1.0)

        offset = translation

        switch direction {
        case .right:
            // Good rating - Green tint, swelling effect
            scale = 1.0 + (progress * 0.15)
            tintColor = .green.opacity(progress * 0.3)
            rotation = Double(translation.width / 50)

        case .left:
            // Again rating - Red tint, shrinking effect
            scale = 1.0 - (progress * 0.2)
            tintColor = .red.opacity(progress * 0.3)
            rotation = Double(translation.width / 50)

        case .up:
            // Easy rating - Blue tint, lightening effect
            scale = 1.0 + (progress * 0.1)
            tintColor = .blue.opacity(progress * 0.3)
            opacity = 1.0 - (progress * 0.2)

        case .down:
            // Hard rating - Orange tint, heavy effect
            scale = 1.0 + (progress * 0.05)
            tintColor = .orange.opacity(progress * 0.4)
            opacity = 1.0 + (progress * 0.1)

        case .none:
            break
        }
    }

    /// Resets all gesture state to default values.
    ///
    /// Called when gesture is cancelled or card snaps back to center.
    func resetGestureState() {
        offset = .zero
        scale = 1.0
        rotation = 0.0
        opacity = 1.0
        tintColor = .clear
    }

    /// Checks if translation exceeds swipe threshold.
    ///
    /// - Parameter translation: Current gesture translation vector
    /// - Returns: True if swipe should be committed
    func shouldCommitSwipe(translation: CGSize) -> Bool {
        let distance = max(abs(translation.width), abs(translation.height))
        return distance >= swipeThreshold
    }

    /// Converts swipe direction to FSRS rating.
    ///
    /// - Parameter direction: Detected swipe direction
    /// - Returns: Corresponding FSRS rating value
    func ratingForDirection(_ direction: SwipeDirection) -> Int {
        switch direction {
        case .right: return 2  // Good
        case .left:  return 0  // Again
        case .up:    return 3  // Easy
        case .down:  return 1  // Hard
        case .none:  return 2  // Default to Good
        }
    }
}
