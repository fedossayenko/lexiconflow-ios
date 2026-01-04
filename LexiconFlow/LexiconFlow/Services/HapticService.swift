//
//  HapticService.swift
//  LexiconFlow
//
//  Provides haptic feedback for card swipe gestures and completion events.
//

import UIKit

/// Service for generating haptic feedback during study sessions.
///
/// Provides directional haptic feedback during card swipes and confirmation
/// haptics when ratings are submitted.
@MainActor
class HapticService {

    /// Shared singleton instance.
    static let shared = HapticService()

    /// Direction of swipe gesture for haptic mapping.
    enum SwipeDirection {
        case right   // Good rating
        case left    // Again rating
        case up      // Easy rating
        case down    // Hard rating
    }

    private init() {}

    /// Triggers haptic feedback during swipe gesture.
    ///
    /// - Parameters:
    ///   - direction: The direction of the swipe
    ///   - progress: Normalized progress value (0-1) based on swipe distance
    ///
    /// Haptic intensity scales with progress, with minimum threshold of 0.3
    /// to prevent overuse during small movements.
    func triggerSwipe(direction: SwipeDirection, progress: CGFloat) {
        guard progress > 0.3 else { return }

        let generator: UIImpactFeedbackGenerator

        switch direction {
        case .right:  // Good - Medium impact
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .left:   // Again - Light impact
            generator = UIImpactFeedbackGenerator(style: .light)
        case .up:     // Easy - Heavy impact
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .down:   // Hard - Medium impact
            generator = UIImpactFeedbackGenerator(style: .medium)
        }

        generator.prepare()
        generator.impactOccurred(intensity: progress)
    }

    /// Triggers success haptic when card is rated positively.
    ///
    /// Uses notification feedback pattern for clear success confirmation.
    func triggerSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Triggers warning haptic when card is marked for repetition.
    ///
    /// Uses notification feedback pattern to indicate card needs more review.
    func triggerWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Triggers error haptic for critical events.
    ///
    /// Uses notification feedback pattern for error states.
    func triggerError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
