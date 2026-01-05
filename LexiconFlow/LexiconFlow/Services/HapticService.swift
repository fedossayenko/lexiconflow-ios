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
/// haptics when ratings are submitted. Uses CoreHaptics for custom patterns
/// with UIKit fallback for basic feedback.
@MainActor
class HapticService {

    /// Shared singleton instance.
    static let shared = HapticService()

    /// Logger for haptic service events
    private static let logger = Logger(subsystem: "com.lexiconflow.haptics", category: "HapticService")

    /// Direction of swipe gesture for haptic mapping.
    enum SwipeDirection {
        case right   // Good rating
        case left    // Again rating
        case up      // Easy rating
        case down    // Hard rating
    }

    /// Cached haptic generators for performance (UIKit fallback)
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?

    /// CoreHaptics engine (iOS 13+)
    private var hapticEngine: CHHapticEngine?

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

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.stoppedHandler = { reason in
                Self.logger.info("Haptic engine stopped: \(reason.rawValue)")
            }
            hapticEngine?.resetHandler = { [weak self] in
                Self.logger.info("Haptic engine reset handler triggered")
                self?.setupHapticEngine()
            }
            try hapticEngine?.start()
            Self.logger.info("CoreHaptics engine started successfully")
        } catch {
            Self.logger.error("Failed to create haptic engine: \(error)")
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * 0.7)),
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * 0.4)),
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity * 0.9)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
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
            Self.logger.error("Failed to play CoreHaptics swipe: \(error)")
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
                Self.logger.error("Failed to play CoreHaptics success: \(error)")
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
                Self.logger.error("Failed to play CoreHaptics warning: \(error)")
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
                Self.logger.error("Failed to play CoreHaptics error: \(error)")
                Analytics.trackError("haptic_error_failed", error: error)
                triggerUIKitError()
            }
        } else {
            triggerUIKitError()
        }
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

        Self.logger.info("HapticService reset completed")
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

    // MARK: - Custom Haptic Patterns

    /// Creates and plays a custom haptic pattern from haptic events.
    ///
    /// This helper function enables rich, multi-event haptic feedback by combining
    /// multiple haptic events into a single pattern. Falls back to UIKit haptics
    /// if CoreHaptics is unavailable.
    ///
    /// - Parameters:
    ///   - events: Array of CHHapticEvent objects defining the pattern
    ///   - intensity: Optional intensity multiplier (0.0-1.0). Defaults to AppSettings.hapticIntensity
    ///
    /// Example usage:
    /// ```swift
    /// let events = [
    ///     CHHapticEvent(eventType: .hapticTransient, parameters: [
    ///         CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
    ///         CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
    ///     ], relativeTime: 0),
    ///     CHHapticEvent(eventType: .hapticContinuous, parameters: [
    ///         CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
    ///         CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
    ///     ], relativeTime: 0.1, duration: 0.3)
    /// ]
    /// HapticService.shared.playCustomPattern(events: events)
    /// ```
    func playCustomPattern(
        events: [CHHapticEvent],
        intensity: Float
    ) {
        guard AppSettings.hapticEnabled else { return }

        // Try CoreHaptics custom pattern first
        if supportsHaptics, let engine = hapticEngine {
            do {
                // Create pattern from events (no scaling, play as-is)
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                Self.logger.debug("Playing custom haptic pattern with \(events.count) events")
                return
            } catch {
                Self.logger.warning("Failed to play custom haptic pattern: \(error.localizedDescription)")
                Analytics.trackError("custom_haptic_failed", error: error)
                // Fall through to UIKit fallback
            }
        }

        // Fallback: trigger the first event as a UIKit impact
        guard let firstEvent = events.first else { return }

        // Extract intensity from first event's parameters (passed during initialization)
        // We'll use a default intensity mapping since we can't access event.parameters directly
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let defaultIntensity: CGFloat = 0.7 // Default medium intensity

        // Map intensity to impact style (simplified, can't access event parameters)
        switch defaultIntensity {
        case 0.0..<0.4: style = .light
        case 0.4..<0.7: style = .medium
        default: style = .heavy
        }

        let generator = getGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: defaultIntensity * CGFloat(intensity))
    }

    /// Plays rating-specific haptic feedback for card review.
    ///
    /// Each rating has a distinct haptic pattern to provide immediate,
    /// distinguishable feedback about the review outcome:
    /// - **Again**: Two sharp taps indicating reset/try again
    /// - **Hard**: Single soft tap indicating effort was required
    /// - **Good**: Single medium tap with slight decay indicating success
    /// - **Easy**: Rising intensity pattern indicating effortless recall
    ///
    /// - Parameter rating: The CardRating to generate feedback for
    func playRatingFeedback(rating: CardRating) {
        guard AppSettings.hapticEnabled else { return }

        let intensity = Float(AppSettings.hapticIntensity)

        switch rating {
        case .again:
            // Two sharp taps for "try again" feedback
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.15
                )
            ]
            playCustomPattern(events: events, intensity: intensity)

        case .hard:
            // Single soft tap indicating effort
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                )
            ]
            playCustomPattern(events: events, intensity: intensity)

        case .good:
            // Medium tap with slight decay for confident success
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.05,
                    duration: 0.15
                )
            ]
            playCustomPattern(events: events, intensity: intensity)

        case .easy:
            // Rising intensity pattern for effortless success
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.08,
                    duration: 0.2
                )
            ]
            playCustomPattern(events: events, intensity: intensity)
        }
    }

    /// Plays harmonic chime pattern for streak milestone achievements.
    ///
    /// Creates a musical "chime" effect with three ascending notes that celebrate
    /// when the user reaches a streak milestone. The pattern uses:
    /// - Three transient taps at ascending intensities (like a chime or bell)
    /// - Continuous resonance events for each note to create sustain
    /// - Precise timing (0.12s intervals) for musical quality
    ///
    /// Milestones typically occur at streak values like: 7, 14, 30, 60, 100, 365
    ///
    /// - Parameter streakCount: The current streak count (used to scale celebration)
    func playStreakMilestoneChime(streakCount: Int) {
        guard AppSettings.hapticEnabled else { return }

        let intensity = Float(AppSettings.hapticIntensity)

        // Three-note harmonic chime pattern (like a celebratory bell)
        // Notes ascend in intensity: gentle -> medium -> bright
        let events = [
            // First note: gentle chime
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.02,
                duration: 0.1
            ),

            // Second note: medium chime
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)
                ],
                relativeTime: 0.12
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.14,
                duration: 0.12
            ),

            // Third note: bright celebratory chime
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.24
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0.26,
                duration: 0.18
            )
        ]

        playCustomPattern(events: events, intensity: intensity)
    }
}
