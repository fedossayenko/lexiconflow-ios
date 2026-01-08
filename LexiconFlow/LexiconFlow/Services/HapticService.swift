//
//  HapticService.swift
//  LexiconFlow
//
//  Provides haptic feedback for card swipe gestures and completion events.
//

import UIKit
import CoreHaptics
import OSLog

/// Logger for haptic service output
private let logger = Logger(subsystem: "com.lexiconflow.haptics", category: "HapticService")

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

    // MARK: - Haptic Intensity Profiles

    /// Haptic intensity profiles for different feedback types
    ///
    /// These constants define the intensity multipliers and thresholds
    /// used throughout the haptic feedback system.
    private enum HapticProfile {
        /// Subtle feedback for low-importance interactions
        static let subtle: CGFloat = 0.3

        /// Light feedback for secondary actions (Again rating)
        static let light: CGFloat = 0.4

        /// Medium feedback for primary actions (Good, Hard ratings)
        static let medium: CGFloat = 0.7

        /// Strong feedback for important actions (Easy rating)
        static let strong: CGFloat = 0.9

        /// Maximum intensity for critical feedback (success confirmation)
        static let maximum: CGFloat = 1.0

        /// Minimum swipe progress to trigger haptic (30%)
        /// Prevents overuse during small, unintentional movements
        static let minimumSwipeProgress: CGFloat = 0.3
    }

    // MARK: - Properties

    /// Cached haptic generators for performance (UIKit fallback)
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?

    /// CoreHaptics engine (iOS 13+)
    private var hapticEngine: CHHapticEngine?

    /// Flag to prevent recursive setupHapticEngine() calls
    private var isSettingUpEngine = false

    /// Device capability detection
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {
        setupHapticEngine()
    }

    /// Sets up the CoreHaptics engine with graceful failure handling.
    private func setupHapticEngine() {
        guard supportsHaptics else { return }
        guard !isSettingUpEngine else { return }
        isSettingUpEngine = true
        defer { isSettingUpEngine = false }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.stoppedHandler = { reason in
                logger.info("Haptic engine stopped: \(reason.rawValue)")
            }
            hapticEngine?.resetHandler = { [weak self] in
                logger.info("Haptic engine reset handler triggered")
                self?.setupHapticEngine()
            }
            try hapticEngine?.start()
            logger.info("CoreHaptics engine started successfully")
        } catch {
            logger.error("Failed to create haptic engine: \(error)")
            Analytics.trackError("haptic_engine_failed", error: error)
            hapticEngine = nil
        }
    }

    // MARK: - Custom Haptic Patterns

    /// Creates a haptic pattern for swipe right (Good rating).
    /// Pattern: Rising intensity with medium sharpness for positive feedback.
    private func createSwipeRightPattern(intensity: CGFloat) throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * HapticProfile.medium)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a haptic pattern for swipe left (Again rating).
    /// Pattern: Light, soft haptic indicating the card needs more practice.
    private func createSwipeLeftPattern(intensity: CGFloat) throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * HapticProfile.light)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a haptic pattern for swipe up (Easy rating).
    /// Pattern: Heavy, sharp haptic indicating the card was very easy.
    private func createSwipeUpPattern(intensity: CGFloat) throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * HapticProfile.strong)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(HapticProfile.maximum))
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a haptic pattern for swipe down (Hard rating).
    /// Pattern: Medium intensity with lower sharpness indicating difficulty.
    private func createSwipeDownPattern(intensity: CGFloat) throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * 0.6)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a success haptic pattern (double tap).
    /// Pattern: Two distinct taps with decreasing intensity.
    private func createSuccessPattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(HapticProfile.maximum)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(HapticProfile.medium))
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(HapticProfile.medium)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.1
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a warning haptic pattern.
    /// Pattern: Single tap with medium intensity for attention.
    private func createWarningPattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates an error haptic pattern.
    /// Pattern: Sharp, intense tap for critical feedback.
    private func createErrorPattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Creates a streak chime haptic pattern.
    /// Pattern: Rising harmonic progression for streak milestones.
    /// Higher streak values produce higher pitch (intensity) haptics.
    private func createStreakChimePattern(streakCount: Int) throws -> CHHapticPattern {
        // Harmonic progression: higher pitch for longer streaks
        // Intensity ranges from 0.5 (streak 5) to 1.0 (streak 30+)
        let intensity = min(0.5 + (Double(min(streakCount, 30)) / 60.0), 1.0)

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0
            ),
            // Secondary tap for celebratory effect
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * 0.7)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.15
            )
        ]
        return try CHHapticPattern(events: events, parameters: [])
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
    /// Haptic intensity scales with progress, with minimum threshold
    /// to prevent overuse during small movements.
    func triggerSwipe(direction: SwipeDirection, progress: CGFloat) {
        guard AppSettings.hapticEnabled else { return }
        guard progress > HapticProfile.minimumSwipeProgress else { return }

        // Try CoreHaptics first
        if let engine = hapticEngine {
            triggerCoreHapticSwipe(direction: direction, progress: progress, engine: engine)
        } else {
            // Fall back to UIKit
            triggerUIKitSwipe(direction: direction, progress: progress)
        }
    }

    /// Triggers haptic feedback using CoreHaptics engine.
    private func triggerCoreHapticSwipe(direction: SwipeDirection, progress: CGFloat, engine: CHHapticEngine) {
        do {
            let pattern: CHHapticPattern
            switch direction {
            case .right:
                pattern = try createSwipeRightPattern(intensity: progress)
            case .left:
                pattern = try createSwipeLeftPattern(intensity: progress)
            case .up:
                pattern = try createSwipeUpPattern(intensity: progress)
            case .down:
                pattern = try createSwipeDownPattern(intensity: progress)
            }

            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            logger.error("Failed to play CoreHaptics swipe: \(error)")
            Analytics.trackError("haptic_swipe_failed", error: error)
            // Fallback to UIKit on failure
            triggerUIKitSwipe(direction: direction, progress: progress)
        }
    }

    /// Triggers haptic feedback using UIKit generators (fallback).
    private func triggerUIKitSwipe(direction: SwipeDirection, progress: CGFloat) {
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
    /// Uses custom CoreHaptics pattern with double tap for clear success confirmation.
    func triggerSuccess() {
        guard AppSettings.hapticEnabled else { return }

        if let engine = hapticEngine {
            do {
                let pattern = try createSuccessPattern()
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                logger.error("Failed to play CoreHaptics success: \(error)")
                Analytics.trackError("haptic_success_failed", error: error)
                triggerUIKitSuccess()
            }
        } else {
            triggerUIKitSuccess()
        }
    }

    /// Triggers warning haptic when card is marked for repetition.
    ///
    /// Uses custom CoreHaptics pattern to indicate card needs more review.
    func triggerWarning() {
        guard AppSettings.hapticEnabled else { return }

        if let engine = hapticEngine {
            do {
                let pattern = try createWarningPattern()
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                logger.error("Failed to play CoreHaptics warning: \(error)")
                Analytics.trackError("haptic_warning_failed", error: error)
                triggerUIKitWarning()
            }
        } else {
            triggerUIKitWarning()
        }
    }

    /// Triggers error haptic for critical events.
    ///
    /// Uses custom CoreHaptics pattern with sharp, intense tap for critical feedback.
    func triggerError() {
        guard AppSettings.hapticEnabled else { return }

        if let engine = hapticEngine {
            do {
                let pattern = try createErrorPattern()
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                logger.error("Failed to play CoreHaptics error: \(error)")
                Analytics.trackError("haptic_error_failed", error: error)
                triggerUIKitError()
            }
        } else {
            triggerUIKitError()
        }
    }

    /// Triggers streak chime haptic for study streak milestones.
    ///
    /// Uses harmonic progression with increasing intensity for longer streaks.
    /// - Parameter streakCount: Current streak count (should be milestone: 5, 10, 15, 20...)
    func triggerStreakChime(streakCount: Int) {
        guard AppSettings.hapticEnabled else { return }

        if let engine = hapticEngine {
            do {
                let pattern = try createStreakChimePattern(streakCount: streakCount)
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                logger.info("Streak chime played for streak: \(streakCount)")
            } catch {
                logger.error("Failed to play CoreHaptics streak chime: \(error)")
                Analytics.trackError("streak_chime_failed", error: error)
                triggerUIKitStreakChime(streakCount: streakCount)
            }
        } else {
            triggerUIKitStreakChime(streakCount: streakCount)
        }
    }

    /// Triggers light haptic for subtle interactions.
    ///
    /// Uses light impact generator for gentle feedback on UI changes
    /// like filter switches or toggle states.
    func triggerLight() {
        guard AppSettings.hapticEnabled else { return }

        // Use UIKit light impact (simple and efficient)
        let generator = getGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - UIKit Fallback Methods

    /// Triggers success haptic using UIKit (fallback).
    private func triggerUIKitSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Triggers warning haptic using UIKit (fallback).
    private func triggerUIKitWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Triggers error haptic using UIKit (fallback).
    private func triggerUIKitError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Triggers streak chime using UIKit (fallback).
    private func triggerUIKitStreakChime(streakCount: Int) {
        // Use notification feedback for streak milestones
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Resets cached haptic generators and stops the haptic engine.
    ///
    /// Call this method to release cached generators, such as when receiving
    /// a memory warning or when the app backgrounds.
    func reset() {
        // Stop and release haptic engine
        hapticEngine?.stop()
        hapticEngine = nil

        // Release cached UIKit generators
        lightGenerator = nil
        mediumGenerator = nil
        heavyGenerator = nil

        logger.info("HapticService reset completed")
    }

    /// Shuts down the haptic engine permanently.
    ///
    /// Call this when the app is terminating to clean up resources.
    func shutdown() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    /// Restarts the haptic engine after it was stopped (e.g., app returns from background).
    func restartEngine() {
        setupHapticEngine()
    }
}
