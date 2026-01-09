//
//  SkeletonLoader.swift
//  LexiconFlow
//
//  Skeleton loading placeholders for smooth content transitions
//

import SwiftUI

/// Skeleton loading placeholder component
///
/// **Design Philosophy:**
/// - Visual continuity: Mimics actual content layout
/// - Performance: Lightweight shimmer animations
/// - Accessibility: Hidden from screen readers when loading
///
/// **Usage:**
/// ```swift
/// if isLoading {
///     SkeletonLoader(width: 100, height: 20)
/// }
/// ```
struct SkeletonLoader: View {
    // MARK: - Animation Constants

    /// Shimmer animation timing constants
    private enum ShimmerAnimation {
        /// Duration of one complete shimmer animation cycle (seconds)
        /// Longer duration = more subtle effect, shorter = more noticeable
        static let duration: TimeInterval = 1.5

        /// Maximum opacity of shimmer gradient (0.0 to 1.0)
        static let maxOpacity: Double = 0.3
    }

    // MARK: - Properties

    /// Width of the skeleton
    var width: CGFloat = 100

    /// Height of the skeleton
    var height: CGFloat = 20

    /// Shape of the skeleton
    var shape: SkeletonShape = .roundedRectangle

    /// Corner radius (for rounded rectangle)
    var cornerRadius: CGFloat = 4

    /// Whether to show shimmer animation
    var shimmer: Bool = true

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Base color
                self.shapeViewFilled

                // Shimmer gradient overlay
                if self.shimmer {
                    self.shimmerOverlay
                        .mask(self.shapeViewFilled)
                }
            }
        }
        .frame(width: self.width, height: self.height)
        .accessibilityHidden(true) // Hide from screen readers
    }

    /// Shimmer gradient animation
    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground).opacity(ShimmerAnimation.maxOpacity),
                    Color(.systemBackground).opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width)
            .offset(x: self.shimmerOffset)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: ShimmerAnimation.duration)
                        .repeatForever(autoreverses: false)
                ) {
                    self.shimmerOffset = geometry.size.width
                }
            }
        }
    }

    /// Shape view with fill applied
    @ViewBuilder
    private var shapeViewFilled: some View {
        switch self.shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: self.cornerRadius)
                .fill(Color(.systemGray5))
        case .circle:
            Circle()
                .fill(Color(.systemGray5))
        case .rectangle:
            Rectangle()
                .fill(Color(.systemGray5))
        }
    }

    /// Shape view based on shape type (for masking)
    @ViewBuilder
    private var shapeView: some View {
        switch self.shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: self.cornerRadius)
        case .circle:
            Circle()
        case .rectangle:
            Rectangle()
        }
    }

    /// Shimmer animation offset
    @State private var shimmerOffset: CGFloat = -200

    /// Skeleton shape types
    enum SkeletonShape {
        case roundedRectangle
        case circle
        case rectangle
    }
}

// MARK: - Convenience Views

extension SkeletonLoader {
    /// Creates a skeleton for text lines
    static func textLine(width: CGFloat = 200, height: CGFloat = 16) -> some View {
        SkeletonLoader(width: width, height: height, cornerRadius: 4)
    }

    /// Creates a skeleton for titles
    static func title(width: CGFloat = 150, height: CGFloat = 24) -> some View {
        SkeletonLoader(width: width, height: height, cornerRadius: 6)
    }

    /// Creates a skeleton for circular images (avatars, icons)
    static func circle(size: CGFloat) -> some View {
        SkeletonLoader(width: size, height: size, shape: .circle)
    }

    /// Creates a skeleton for cards
    static func card(height: CGFloat = 80) -> some View {
        SkeletonLoader(width: .infinity, height: height, cornerRadius: 12)
    }
}

// MARK: - Compound Skeletons

/// Skeleton view for deck row placeholder
struct DeckRowSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Icon placeholder
            SkeletonLoader.circle(size: 44)

            VStack(alignment: .leading, spacing: 4) {
                // Title placeholder
                SkeletonLoader.title(width: 120)

                // Subtitle placeholder
                SkeletonLoader.textLine(width: 150, height: 14)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// Skeleton view for flashcard placeholder
struct FlashcardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Word placeholder
            SkeletonLoader.title(width: 100)

            // Definition placeholder
            SkeletonLoader.textLine(width: 200, height: 14)

            // Definition placeholder (second line)
            SkeletonLoader.textLine(width: 150, height: 14)
        }
        .padding(.vertical, 8)
    }
}

#Preview("Basic Skeletons") {
    VStack(spacing: 20) {
        SkeletonLoader.textLine()
        SkeletonLoader.title()
        SkeletonLoader.circle(size: 50)
        SkeletonLoader.card(height: 80)
    }
    .padding()
}

#Preview("Deck Row Skeleton") {
    List {
        DeckRowSkeleton()
        DeckRowSkeleton()
        DeckRowSkeleton()
    }
}

#Preview("Flashcard Skeleton") {
    List {
        FlashcardSkeleton()
        FlashcardSkeleton()
        FlashcardSkeleton()
    }
}
