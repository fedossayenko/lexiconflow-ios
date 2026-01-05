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
            playCustomPattern(events: events)

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
            playCustomPattern(events: events)

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
            playCustomPattern(events: events)

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
            playCustomPattern(events: events)
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

        playCustomPattern(events: events)
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
        intensity: Float = AppSettings.hapticIntensity
    ) {
        guard AppSettings.hapticEnabled else { return }

        // Try CoreHaptics custom pattern first
        if supportsHaptics, let engine = hapticEngine {
            do {
                // Scale event intensities by the provided intensity multiplier
                let scaledEvents = events.map { event -> CHHapticEvent in
                    let scaledParameters = event.parameters.map { param -> CHHapticEventParameter in
                        if param.parameterID == .hapticIntensity {
                            return CHHapticEventParameter(
                                parameterID: .hapticIntensity,
                                value: param.value * intensity
                            )
                        }
                        return param
                    }
                    return CHHapticEvent(
                        eventType: event.eventType,
                        parameters: scaledParameters,
                        relativeTime: event.relativeTime,
                        duration: event.duration
                    )
                }

                // Create pattern from scaled events
                let pattern = try CHHapticPattern(events: scaledEvents, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                logger.debug("Playing custom haptic pattern with \(events.count) events")
                return
            } catch {
                logger.warning("Failed to play custom haptic pattern: \(error.localizedDescription)")
                Analytics.trackError("custom_haptic_failed", error: error)
                // Fall through to UIKit fallback
            }
        }

        // Fallback: trigger the first event as a UIKit impact
        guard let firstEvent = events.first else { return }

        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let eventIntensity = firstEvent.parameters.first { $0.parameterID == .hapticIntensity }?.value ?? 1.0

        // Map intensity to impact style
        switch eventIntensity {
        case 0.0..<0.4: style = .light
        case 0.4..<0.7: style = .medium
        default: style = .heavy
        }

        let generator = getGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(eventIntensity * intensity))
    }
}
