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

<<<<<<< HEAD
    // MARK: - Gesture State

    @StateObject private var gestureViewModel = CardGestureViewModel()
    @State private var isDragging = false
    @State private var lastHapticTime = Date()

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

    /// Callback when user completes a swipe gesture.
    var onSwipe: ((Int) -> Void)?

    var body: some View {
        ZStack {
            if isFlipped {
                CardBackView(card: card)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            } else {
                CardFrontView(card: card)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .background(Color(.systemBackground))
        .glassEffect(glassThickness)
        // Gesture visual feedback
        .offset(x: gestureViewModel.offset.width, y: gestureViewModel.offset.height)
        .scaleEffect(gestureViewModel.scale)
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

                        // Success haptic
                        if rating == 2 || rating == 3 {
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

            withAnimation(.easeInOut(duration: 0.3)) {
                isFlipped.toggle()
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
            print("Rated: \(rating)")
        }
    )
    .padding()
}
