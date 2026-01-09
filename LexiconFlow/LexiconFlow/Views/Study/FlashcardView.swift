//
//  FlashcardView.swift
//  LexiconFlow
//
//  Displays card with tap-to-flip animation and swipe gestures.
//

import SwiftData
import SwiftUI

struct FlashcardView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    // MARK: - Gesture State

    @StateObject private var gestureViewModel = CardGestureViewModel()
    @State private var isDragging = false
    @State private var lastHapticTime = Date()

    // MARK: - Sheet State

    @State private var showingDetail = false

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
            if self.isFlipped {
                CardBackView(card: self.card)
                    .glassEffectTransition(.scaleFade)
                    .zIndex(1)
            } else {
                CardFrontView(card: self.card)
                    .glassEffectTransition(.scaleFade)
                    .zIndex(0)
            }

            // Info button (top-right corner)
            VStack {
                HStack {
                    Spacer()

                    Button {
                        self.showingDetail = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("View card details")
                    .accessibilityHint("Shows review history and card information")
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .background(Color(.systemBackground))
        .glassEffect(AppSettings.glassEffectsEnabled ? self.glassThickness : .thin)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: self.isFlipped)
        .interactive(self.$gestureViewModel.offset) { dragOffset in
            let progress = min(max(dragOffset.width / 100, -1), 1)

            if progress > 0 {
                return .tint(.green.opacity(0.3 * progress))
            } else {
                return .tint(.red.opacity(0.3 * abs(progress)))
            }
        }
        // Gesture visual feedback
        .offset(x: self.gestureViewModel.offset.width, y: self.gestureViewModel.offset.height)
        .scaleEffect(self.gestureViewModel.scale)
        .rotationEffect(.degrees(self.gestureViewModel.rotation))
        .opacity(self.gestureViewModel.opacity)
        // Gesture handling - use simultaneousGesture to allow tap to work
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    self.isDragging = true

                    guard let result = gestureViewModel.handleGestureChange(value) else { return }

                    let now = Date()
                    if now.timeIntervalSince(self.lastHapticTime) >= AnimationConstants.hapticThrottleInterval {
                        HapticService.shared.triggerSwipe(
                            direction: result.direction.hapticDirection,
                            progress: result.progress
                        )
                        self.lastHapticTime = now
                    }
                }
                .onEnded { value in
                    let direction = self.gestureViewModel.detectDirection(translation: value.translation)
                    _ = max(abs(value.translation.width), abs(value.translation.height))
                    let shouldCommit = self.gestureViewModel.shouldCommitSwipe(translation: value.translation)

                    if shouldCommit {
                        // Commit swipe
                        let rating = self.gestureViewModel.ratingForDirection(direction)

                        // Success haptic
                        if rating == 2 || rating == 3 {
                            HapticService.shared.triggerSuccess()
                        } else {
                            HapticService.shared.triggerWarning()
                        }

                        // Reset with animation
                        self.isDragging = false
                        withAnimation(.spring(response: AnimationConstants.commitSpringResponse, dampingFraction: AnimationConstants.commitSpringDamping)) {
                            self.gestureViewModel.resetGestureState()
                        }

                        // Notify parent
                        self.onSwipe?(rating)
                    } else {
                        // Cancel swipe - snap back
                        self.isDragging = false
                        withAnimation(.spring(response: AnimationConstants.cancelSpringResponse, dampingFraction: AnimationConstants.cancelSpringDamping)) {
                            self.gestureViewModel.resetGestureState()
                        }
                    }
                }
        )
        .accessibilityLabel(self.isFlipped ? "Card back showing definition" : "Card front showing word")
        .accessibilityHint("Double tap to flip card, or swipe in any direction to rate")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("flashcard")
        .onTapGesture {
            // Only allow tap to flip if not currently dragging
            guard !self.isDragging else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                self.isFlipped.toggle()
            }
        }
        .sheet(isPresented: self.$showingDetail) {
            FlashcardDetailView(flashcard: self.card)
        }
        .id("flashcard-base")
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
        onSwipe: { _ in }
    )
    .padding()
}
