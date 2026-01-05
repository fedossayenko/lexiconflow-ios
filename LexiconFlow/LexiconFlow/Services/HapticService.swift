//
//  HapticService.swift
//  LexiconFlow
//
//  Provides haptic feedback for card swipe gestures and completion events.
//

import UIKit
import CoreHaptics

/// Service for generating haptic feedback during study sessions.
///
/// Provides directional haptic feedback during card swipes and confirmation
/// haptics when ratings are submitted. Uses CoreHaptics for custom patterns
/// with UIKit fallback for basic feedback.
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

    /// CoreHaptics engine for custom haptic patterns.
    private var hapticEngine: CHHapticEngine?

    /// Flag indicating if CoreHaptics is supported and available.
    private var supportsHaptics: Bool {
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Cached haptic generators for performance (UIKit fallback)
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?

    private init() {
        setupHapticEngine()
    }

    /// Sets up the CoreHaptics engine with proper error handling.
    ///
    /// Attempts to create and start a CHHapticEngine for custom haptic patterns.
    /// Falls back gracefully to UIKit haptics if CoreHaptics is unavailable.
    private func setupHapticEngine() {
        guard supportsHaptics else {
            logger.debug("CoreHaptics not supported on this device")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()

            // Observe engine stop handler to restart if needed
            hapticEngine?.stoppedHandler = { [weak self] reason in
                logger.warning("Haptic engine stopped: \(reason.rawValue)")
                self?.restartHapticEngine()
            }

            // Observe engine reset handler for configuration changes
            hapticEngine?.resetHandler = { [weak self] in
                logger.info("Haptic engine reset - reconfiguring")
                self?.restartHapticEngine()
            }

            try hapticEngine?.start()
            logger.debug("CoreHaptics engine started successfully")
        } catch {
            logger.warning("Failed to create CoreHaptics engine: \(error.localizedDescription)")
            hapticEngine = nil
        }
    }

    /// Restarts the haptic engine after it stops or resets.
    ///
    /// Called automatically by the stoppedHandler and resetHandler.
    private func restartHapticEngine() {
        guard supportsHaptics else { return }

        do {
            try hapticEngine?.start()
            logger.debug("CoreHaptics engine restarted")
        } catch {
            logger.warning("Failed to restart CoreHaptics engine: \(error.localizedDescription)")
        }
    }

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
        generator.impactOccurred(intensity: progress * AppSettings.hapticIntensity)
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

    /// Resets cached haptic generators and stops the haptic engine.
    ///
    /// Call this method to release cached generators, such as when receiving
    /// a memory warning or when the app backgrounds.
    func reset() {
        // Stop CoreHaptics engine
        hapticEngine?.stop()
        hapticEngine = nil

        // Release UIKit generators
        lightGenerator = nil
        mediumGenerator = nil
        heavyGenerator = nil
    }
}
