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

    @StateObject private var gestureViewModel = CardGestureViewModel()
    @State private var dragOffset = CGSize.zero

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
        // Gesture handling
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let direction = gestureViewModel.detectDirection(translation: value.translation)
                    let distance = max(abs(value.translation.width), abs(value.translation.height))
                    let progress = min(distance / 100, 1.0)

                    // Update visual state
                    gestureViewModel.updateGestureState(translation: value.translation)

                    // Haptic feedback during drag
                    if direction != .none {
                        let hapticDirection: HapticService.SwipeDirection
                        switch direction {
                        case .right: hapticDirection = .right
                        case .left: hapticDirection = .left
                        case .up: hapticDirection = .up
                        case .down: hapticDirection = .down
                        case .none: hapticDirection = .right
                        }
                        HapticService.shared.triggerSwipe(
                            direction: hapticDirection,
                            progress: progress
                        )
                    }
                }
                .onEnded { value in
                    let direction = gestureViewModel.detectDirection(translation: value.translation)

                    if gestureViewModel.shouldCommitSwipe(translation: value.translation) {
                        // Commit swipe
                        let rating = gestureViewModel.ratingForDirection(direction)

                        // Success haptic
                        if rating == 2 || rating == 3 {
                            HapticService.shared.triggerSuccess()
                        } else {
                            HapticService.shared.triggerWarning()
                        }

                        // Reset with animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            gestureViewModel.resetGestureState()
                        }

                        // Notify parent
                        onSwipe?(rating)
                    } else {
                        // Cancel swipe - snap back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            gestureViewModel.resetGestureState()
                        }
                    }
                }
        )
        .onTapGesture {
            // Only allow tap to flip if not currently dragging
            guard gestureViewModel.offset == .zero else { return }

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
