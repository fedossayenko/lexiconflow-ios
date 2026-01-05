//
//  FlashcardView.swift
//  LexiconFlow
//
//  Displays card with tap-to-flip animation and swipe gestures.
//

import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    // MARK: - Gesture State

    @State private var gestureViewModel = CardGestureViewModel()
    @State private var isDragging = false
    @State private var lastHapticTime = Date()
    @Namespace private var morphingNamespace

    // MARK: - Morphing Animation State

    /// Current scale during flip animation (0.95-1.0)
    @State private var flipScale: CGFloat = 1.0
    /// Current rotation angle during flip animation
    @State private var flipRotation: Double = 0

    // MARK: - Constants

    /// Animation-related constants
    private enum AnimationConstants {
        /// Spring response for commit animation
        static let commitSpringResponse: Double = 0.3
        /// Spring damping for commit animation
        static let commitSpringDamping: CGFloat = 0.7
        /// Spring response for cancel animation
        static let cancelSpringResponse: Double = 0.4
        /// Spring damping for cancel animation
        static let cancelSpringDamping: CGFloat = 0.7
        /// Haptic throttle interval (max haptics per second)
        static let hapticThrottleInterval: TimeInterval = 0.08
        /// Progress threshold distance calculation
        static let swipeThreshold: CGFloat = 100

        // MARK: - Morphing Transition Constants

        /// Spring response for flip morphing animation (lower = snappier feel)
        static let flipSpringResponse: Double = 0.26
        /// Spring damping fraction for flip (higher = less oscillation, more controlled)
        static let flipSpringDamping: CGFloat = 0.78
        /// Initial scale at midpoint of flip (creates depth effect)
        static let flipScaleMidpoint: CGFloat = 0.95
        /// Rotation angle during flip (creates 3D morphing effect)
        static let flipRotationAngle: Double = 180
    }

    /// Determines glass thickness based on FSRS stability.
    ///
    /// Visualizes memory strength through glass morphism:
    /// - Thin glass (fragile) for low stability (< 10)
    /// - Regular glass for medium stability (10-50)
    /// - Thick glass (stable) for high stability (> 50)
    private var glassThickness: GlassThickness {
        guard let stability = card.fsrsState?.stability else {
            return .thin // Default for new cards
        }

        if stability < 10 {
            return .thin // Fragile
        } else if stability <= 50 {
            return .regular // Standard
        } else {
            return .thick // Stable
        }
    }

    /// Callback when user completes a swipe gesture with CardRating.
    var onSwipe: ((CardRating) -> Void)?

    /// Combined scale effect that accounts for both flip morphing and gesture feedback
    private var combinedScale: CGFloat {
        flipScale * gestureViewModel.scale
    }

    var body: some View {
        ZStack {
            if isFlipped {
                CardBackView(card: card)
                    .matchedGeometryEffect(id: "cardFace", in: morphingNamespace)
                    .transition(.opacity.combined(with: .scale))
            } else {
                CardFrontView(card: card)
                    .matchedGeometryEffect(id: "cardFace", in: morphingNamespace)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .background(Color(.systemBackground))
        .conditionalGlassEffect(glassThickness)
        // Combined morphing and gesture effects
        .scaleEffect(combinedScale)
        .rotation3DEffect(.degrees(flipRotation), axis: (x: 0, y: 1, z: 0))
        .offset(x: gestureViewModel.offset.width, y: gestureViewModel.offset.height)
        .rotationEffect(.degrees(gestureViewModel.rotation))
        .opacity(gestureViewModel.opacity)
        .overlay(
            gestureViewModel.tintColor
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        // Gesture handling - use simultaneousGesture to allow tap to work
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    isDragging = true

                    guard let result = gestureViewModel.handleGestureChange(value) else { return }

                    let now = Date()
                    if now.timeIntervalSince(lastHapticTime) >= AnimationConstants.hapticThrottleInterval {
                        HapticService.shared.triggerSwipe(
                            direction: result.direction.hapticDirection,
                            progress: result.progress
                        )
                        lastHapticTime = now
                    }
                }
                .onEnded { value in
                    let direction = gestureViewModel.detectDirection(translation: value.translation)
                    let distance = max(abs(value.translation.width), abs(value.translation.height))
                    let shouldCommit = gestureViewModel.shouldCommitSwipe(translation: value.translation)

                    if shouldCommit {
                        // Commit swipe
                        let rating = gestureViewModel.ratingForDirection(direction)

                        // Success haptic for good/easy ratings
                        if rating == .good || rating == .easy {
                            HapticService.shared.triggerSuccess()
                        } else {
                            HapticService.shared.triggerWarning()
                        }

                        // Reset with animation
                        withAnimation(.spring(response: AnimationConstants.commitSpringResponse, dampingFraction: AnimationConstants.commitSpringDamping)) {
                            gestureViewModel.resetGestureState()
                        }
                        isDragging = false

                        // Notify parent
                        onSwipe?(rating)
                    } else {
                        // Cancel swipe - snap back
                        withAnimation(.spring(response: AnimationConstants.cancelSpringResponse, dampingFraction: AnimationConstants.cancelSpringDamping)) {
                            gestureViewModel.resetGestureState()
                        }
                        isDragging = false
                    }
                }
        )
        .onTapGesture {
            // Only allow tap to flip if not currently dragging
            guard !isDragging else { return }

            // Sequential animation: first flip with scale, then scale back
            // Using two separate animations for proper sequencing
            withAnimation(.spring(response: AnimationConstants.flipSpringResponse, dampingFraction: AnimationConstants.flipSpringDamping)) {
                isFlipped.toggle()
                flipRotation = isFlipped ? AnimationConstants.flipRotationAngle : 0
                // Subtle scale change for depth perception during morph
                flipScale = isFlipped ? AnimationConstants.flipScaleMidpoint : 1.0
            }

            // Second animation: scale back to normal after flip completes
            // Use a state-driven approach instead of DispatchQueue
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(AnimationConstants.flipSpringResponse * 1_000_000_000))
                withAnimation(.spring(response: AnimationConstants.flipSpringResponse, dampingFraction: AnimationConstants.flipSpringDamping)) {
                    flipScale = 1.0
                }
            }
        }
        .accessibilityLabel(isFlipped ? "Card back showing definition" : "Card front showing word")
        .accessibilityHint("Double tap to flip card, or swipe in any direction to rate")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("flashcard")
    }
}

#Preview {
    FlashcardView(
        card: Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time",
            phonetic: "/əˈfem(ə)rəl/"
        ),
        isFlipped: .constant(false),
        onSwipe: { rating in
            print("Rated: \(rating.label)")
        }
    )
    .padding()
}
