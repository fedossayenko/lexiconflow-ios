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

    /// Cached haptic generators for performance
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?

    private init() {}

    /// Gets or creates a cached haptic generator for the given style.
    ///
    /// - Parameter style: The haptic feedback style
    /// - Returns: A prepared haptic generator
    private func getGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            if let g = lightGenerator { return g }
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            lightGenerator = g
            return g
        case .medium:
            if let g = mediumGenerator { return g }
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.prepare()
            mediumGenerator = g
            return g
        case .heavy:
            if let g = heavyGenerator { return g }
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.prepare()
            heavyGenerator = g
            return g
        case .soft, .rigid:
            // Handle iOS 26+ styles
            let g = UIImpactFeedbackGenerator(style: style)
            g.prepare()
            return g
        @unknown default:
            return UIImpactFeedbackGenerator(style: .medium)
        }
    }

    /// Triggers haptic feedback during swipe gesture.
    ///
    /// - Parameters:
    ///   - direction: The direction of the swipe
    ///   - progress: Normalized progress value (0-1) based on swipe distance
    ///
    /// Haptic intensity scales with progress, with minimum threshold of 0.3
    /// to prevent overuse during small movements.
    func triggerSwipe(direction: SwipeDirection, progress: CGFloat) {
        guard AppSettings.hapticEnabled else { return }
        guard progress > 0.3 else { return }

        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch direction {
        case .right: style = .medium
        case .left:  style = .light
        case .up:    style = .heavy
        case .down:  style = .medium
        }

        let generator = getGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: progress)
    }

    /// Triggers success haptic when card is rated positively.
    ///
    /// Uses notification feedback pattern for clear success confirmation.
    func triggerSuccess() {
        guard AppSettings.hapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Triggers warning haptic when card is marked for repetition.
    ///
    /// Uses notification feedback pattern to indicate card needs more review.
    func triggerWarning() {
        guard AppSettings.hapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Triggers error haptic for critical events.
    ///
    /// Uses notification feedback pattern for error states.
    func triggerError() {
        guard AppSettings.hapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Resets cached haptic generators.
    ///
    /// Call this method to release cached generators, such as when receiving
    /// a memory warning or when the app backgrounds.
    func reset() {
        lightGenerator = nil
        mediumGenerator = nil
        heavyGenerator = nil
    }
}
