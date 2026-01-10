//
//  FlashcardView.swift
//  LexiconFlow
//
//  Displays card with tap-to-flip animation and swipe gestures.
//

import SwiftData
import SwiftUI
import Translation

struct FlashcardView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    // MARK: - Gesture State

    @StateObject private var gestureViewModel = CardGestureViewModel()
    @State private var isDragging = false
    @State private var lastHapticTime = Date()

    // MARK: - Sheet State

    @State private var showingDetail = false
    @State private var showingTranslation = false
    @State private var translationResult: QuickTranslationService.QuickTranslationResult?
    @State private var translationError: QuickTranslationService.QuickTranslationError?
    @State private var isTranslating = false
    @State private var translationTask: Task<Void, Never>?

    // MARK: - Language Pack Download Configuration

    /// Configuration for triggering language pack downloads via .translationTask()
    @State private var downloadConfiguration: TranslationSession.Configuration?

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

    // MARK: - Computed View Properties

    /// Main card content based on geometry effect setting
    @ViewBuilder
    private var cardContent: some View {
        if AppSettings.matchedGeometryEffectEnabled {
            FlashcardMatchedView(card: card, isFlipped: $isFlipped)
        } else {
            traditionalCardView
        }
    }

    /// Traditional ZStack-based card view
    @ViewBuilder
    private var traditionalCardView: some View {
        ZStack {
            if isFlipped {
                CardBackView(card: card)
                    .glassEffectTransition(.scaleFade)
                    .zIndex(1)
            } else {
                CardFrontView(card: card)
                    .glassEffectTransition(.scaleFade)
                    .zIndex(0)
            }
        }
        .ttsTiming(for: card, isFlipped: $isFlipped)
    }

    /// Info button overlay (top-right corner)
    @ViewBuilder
    private var infoButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    showingDetail = true
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

    var body: some View {
        cardContent
            .overlay(infoButtonOverlay)
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .background(Color(.systemBackground))
            .glassEffect(AppSettings.glassConfiguration.effectiveThickness(base: glassThickness))
            // Animation removed - nested in FlashcardMatchedView to avoid double animations
            .interactive(gestureViewModel.offsetBinding) { dragOffset in
                let horizontalProgress = min(max(dragOffset.width / 100, -1), 1)
                let verticalProgress = min(max(dragOffset.height / 100, -1), 1)
                let isHorizontal = abs(dragOffset.width) > abs(dragOffset.height)

                if isHorizontal {
                    if horizontalProgress > 0 {
                        return .tint(.green.opacity(0.3 * horizontalProgress))
                    } else {
                        return .tint(.red.opacity(0.3 * abs(horizontalProgress)))
                    }
                } else {
                    if verticalProgress < 0 {
                        return .tint(.blue.opacity(0.3 * abs(verticalProgress)))
                    } else {
                        return .tint(.orange.opacity(0.4 * verticalProgress))
                    }
                }
            }
            // Gesture visual feedback
            .offset(x: gestureViewModel.offset.width, y: gestureViewModel.offset.height)
            .scaleEffect(gestureViewModel.scale)
            .rotationEffect(.degrees(gestureViewModel.rotation))
            .opacity(gestureViewModel.opacity)
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
                        _ = max(abs(value.translation.width), abs(value.translation.height))
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
                            isDragging = false
                            withAnimation(.spring(response: AnimationConstants.commitSpringResponse, dampingFraction: AnimationConstants.commitSpringDamping)) {
                                gestureViewModel.resetGestureState()
                            }

                            // Notify parent
                            onSwipe?(rating)
                        } else {
                            // Cancel swipe - snap back
                            isDragging = false
                            withAnimation(.spring(response: AnimationConstants.cancelSpringResponse, dampingFraction: AnimationConstants.cancelSpringDamping)) {
                                gestureViewModel.resetGestureState()
                            }
                        }
                    }
            )
            .accessibilityLabel(isFlipped ? "Card back showing definition" : "Card front showing word")
            .accessibilityHint("Double tap to flip card, or swipe in any direction to rate")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("flashcard")
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        guard !isDragging else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFlipped.toggle()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        guard !isDragging else { return }
                        translationTask?.cancel()
                        translationTask = Task {
                            await handleDoubleTapTranslation()
                        }
                    }
            )
            .sheet(isPresented: $showingDetail) {
                FlashcardDetailView(flashcard: card)
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingTranslation) {
                TranslationSheetView(
                    flashcard: card,
                    translationResult: translationResult,
                    isTranslating: isTranslating
                )
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
            }
            .alert("Translation Error", isPresented: .constant(translationError != nil)) {
                Button("OK", role: .cancel) {
                    translationError = nil
                }
                if case .languagePackMissing = translationError {
                    Button("Download") {
                        // Create configuration to trigger download via .translationTask()
                        let target = Locale.Language(identifier: AppSettings.translationTargetLanguage)
                        let source = Locale.Language(identifier: AppSettings.translationSourceLanguage)
                        downloadConfiguration = TranslationSession.Configuration(source: source, target: target)
                    }
                }
            } message: {
                Text(translationError?.localizedDescription ?? "")
            }
            .translationTask(downloadConfiguration) { session in
                // prepareTranslation() triggers the system download prompt
                do {
                    try await session.prepareTranslation()
                    translationError = nil
                } catch {
                    translationError = .languagePackMissing(
                        source: AppSettings.translationSourceLanguage,
                        target: AppSettings.translationTargetLanguage
                    )
                }
                downloadConfiguration = nil
            }
            .id("flashcard-base")
    }

    // MARK: - Translation Handlers

    /// Handle double-tap gesture for translation
    @MainActor
    private func handleDoubleTapTranslation() async {
        guard let container = card.modelContext?.container else { return }

        isTranslating = true
        showingTranslation = true

        do {
            // Create DTO with word to translate
            let request = QuickTranslationService.FlashcardTranslationRequest(
                word: card.word,
                flashcardID: card.persistentModelID
            )

            let result = try await QuickTranslationService.shared.translate(
                request: request,
                container: container
            )

            translationResult = result
            isTranslating = false

            // Haptic feedback: subtle for cache hit, strong for fresh translation
            if result.isCacheHit {
                HapticService.shared.triggerWarning()
            } else {
                HapticService.shared.triggerSuccess()
            }
        } catch {
            translationError = error as? QuickTranslationService.QuickTranslationError
            isTranslating = false
            showingTranslation = false
        }
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
