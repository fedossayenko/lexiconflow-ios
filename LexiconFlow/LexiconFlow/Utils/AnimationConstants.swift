//
//  AnimationConstants.swift
//  LexiconFlow
//
//  Unified animation system for consistent motion design across the app
//

import SwiftUI

/// Unified animation constants for consistent motion design
///
/// **Design Philosophy:**
/// - Consistency: Same durations and spring values across all views
/// - Natural motion: Spring-based animations for fluid transitions
/// - Performance: Fast animations for feedback, slow for content transitions
///
/// **Usage:**
/// ```swift
/// // Standard transition
/// withAnimation(.spring(dampingFraction: AnimationConstants.springDamping)) {
///     showDetail = true
/// }
///
/// // Quick feedback
/// withAnimation(.easeInOut(duration: AnimationConstants.fastDuration)) {
///     isPressed = true
/// }
/// ```
enum AnimationConstants {
    // MARK: - Durations

    /// Default animation duration for standard transitions (0.3s)
    /// Use: Sheet presentation, state changes, list updates
    static let defaultDuration: Double = 0.3

    /// Fast animation duration for immediate feedback (0.15s)
    /// Use: Button presses, toggle switches, micro-interactions
    static let fastDuration: Double = 0.15

    /// Slow animation duration for content transitions (0.5s)
    /// Use: Cross-fades, complex layout changes, content loading
    static let slowDuration: Double = 0.5

    // MARK: - Spring Physics

    /// Spring damping fraction for natural motion (0.7)
    /// - 1.0: Critically damped (no oscillation)
    /// - 0.7: Slightly underdamped (natural feel)
    /// - 0.5: More bounce (playful feel)
    static let springDamping: Double = 0.7

    /// Spring response time for animation speed (0.3s)
    /// Lower values = slower, smoother motion
    /// Higher values = faster, snappier motion
    static let springResponse: Double = 0.3

    // MARK: - Card Animations

    /// Duration for card flip animation (0.4s)
    /// Use: Study session card reveal, flashcard detail expansion
    static let cardFlipDuration: Double = 0.4

    /// Duration for card transition between sessions (0.25s)
    /// Use: Moving to next card in study session
    static let cardTransitionDuration: Double = 0.25

    // MARK: - Predefined Animations

    /// Standard spring animation for most transitions
    static let springAnimation = Animation.spring(
        dampingFraction: springDamping,
        blendDuration: springResponse
    )

    /// Fast spring animation for snappy feedback
    static let fastSpringAnimation = Animation.spring(
        dampingFraction: springDamping,
        blendDuration: fastDuration
    )

    /// Default ease-in-out animation
    static let defaultAnimation = Animation.easeInOut(duration: defaultDuration)

    /// Fast ease-in-out animation for feedback
    static let fastAnimation = Animation.easeInOut(duration: fastDuration)

    // MARK: - Transitions

    /// Standard modal sheet transition (bottom slide with fade)
    static let modalTransition = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// Navigation push transition (right slide with fade)
    static let navigationTransition = AnyTransition.move(edge: .trailing).combined(with: .opacity)

    /// Fade transition for content updates
    static let fadeTransition = AnyTransition.opacity

    // MARK: - Helper Methods

    /// Creates a spring animation with custom damping
    /// - Parameter dampingFraction: Damping fraction (0.0-1.0)
    /// - Returns: Spring animation with specified damping
    static func spring(dampingFraction: Double) -> Animation {
        .spring(dampingFraction: dampingFraction, blendDuration: self.springResponse)
    }

    /// Creates an ease-in-out animation with custom duration
    /// - Parameter duration: Animation duration in seconds
    /// - Returns: Ease-in-out animation with specified duration
    static func easeInOut(duration: Double) -> Animation {
        .easeInOut(duration: duration)
    }
}
