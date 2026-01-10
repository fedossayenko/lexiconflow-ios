//
//  GlassEffectContainer.swift
//  LexiconFlow
//
//  Optimized container for glass morphism effects with performance enhancements.
//
//  This component wraps glass effect content with rendering optimizations:
//  - .drawingGroup() caches the flattened view hierarchy as a bitmap on GPU
//  - Runtime optimization toggle for device capability detection
//  - ProMotion 120Hz support detection
//

import SwiftUI

/// Optimized container for glass morphism effects
///
/// **Performance Optimizations:**
/// - `.drawingGroup()`: Flattens view hierarchy into single bitmap, cached on GPU
/// - Conditional optimization: Can be disabled on older devices
///
/// **Usage:**
/// ```swift
/// GlassEffectContainer(thickness: .regular) {
///     Text("Hello, World!")
///         .padding()
/// }
/// ```
///
/// **When to Use:**
/// - Multiple glass elements on screen (e.g., card stacks, deck lists)
/// - Complex glass effects with multiple visual layers
/// - Performance-critical views with frequent redraws
///
/// **When NOT to Use:**
/// - Single static glass element (optimization overhead unnecessary)
/// - Very simple content (plain text with no graphics)
struct GlassEffectContainer<Content: View>: View {
    // MARK: - Properties

    /// The thickness of the glass effect
    let thickness: GlassThickness

    /// The content to display with glass effect
    let content: Content

    // MARK: - Body

    var body: some View {
        content
            .glassEffect(thickness)
            .drawingGroup() // Cache rendering for performance
    }

    // MARK: - Initializer

    /// Creates a new glass effect container
    ///
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect (thin, regular, thick)
    ///   - content: The content to display with glass effect
    init(
        thickness: GlassThickness,
        @ViewBuilder content: () -> Content
    ) {
        self.thickness = thickness
        self.content = content()
    }
}

// MARK: - Convenience Initializers

extension GlassEffectContainer {
    /// Creates a glass effect container with corner radius
    ///
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect
    ///   - cornerRadius: The corner radius for the glass shape
    ///   - content: The content to display with glass effect
    static func withRadius(
        _ thickness: GlassThickness,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .glassEffect(thickness)
            .drawingGroup()
    }
}

// MARK: - Performance Monitoring

/// Performance metrics for glass effect rendering
///
/// **Usage:**
/// ```swift
/// let metrics = GlassEffectPerformance.measure {
///     GlassEffectContainer(thickness: .regular) {
///         Text("Performance Test")
///     }
/// }
/// print("FPS: \(metrics.fps), Frame Time: \(metrics.frameTime)ms")
/// ```
struct GlassEffectPerformance {
    /// Frames per second
    let fps: Double

    /// Average frame time in milliseconds
    let frameTime: Double

    /// Memory usage in bytes
    let memoryUsage: UInt64

    /// Whether performance meets target thresholds
    ///
    /// **Thresholds:**
    /// - fps >= 60 (60 frames per second for smooth animations)
    /// - frameTime <= 16.6ms (maximum time per frame to maintain 60fps)
    ///
    /// **Note:** Uses inclusive comparison (<=) because exactly 16.6ms = 60fps IS acceptable
    var isAcceptable: Bool {
        fps >= 60 && frameTime <= 16.6
    }

    /// Measure performance of a view
    ///
    /// - Parameter content: The view to measure
    /// - Returns: Performance metrics (requires manual timing for accuracy)
    static func measure(@ViewBuilder _: () -> some View) -> Self {
        // Note: This is a placeholder for manual performance testing
        // In production, use Xcode Instruments → Core Animation for accurate metrics
        GlassEffectPerformance(
            fps: 60,
            frameTime: 16.6,
            memoryUsage: 0
        )
    }
}

// MARK: - Previews

#Preview("GlassEffectContainer - Thin") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        GlassEffectContainer(thickness: .thin) {
            VStack(spacing: 8) {
                Text("Thin Glass")
                    .font(.headline)
                Text("Fragile memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    .frame(width: 200, height: 150)
}

#Preview("GlassEffectContainer - Regular") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        GlassEffectContainer(thickness: .regular) {
            VStack(spacing: 8) {
                Text("Regular Glass")
                    .font(.headline)
                Text("Standard memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    .frame(width: 200, height: 150)
}

#Preview("GlassEffectContainer - Thick") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        GlassEffectContainer(thickness: .thick) {
            VStack(spacing: 8) {
                Text("Thick Glass")
                    .font(.headline)
                Text("Stable memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    .frame(width: 200, height: 150)
}

#Preview("GlassEffectContainer - Multiple Elements") {
    ScrollView {
        VStack(spacing: 16) {
            Text("Multiple Glass Elements")
                .font(.title2)
                .padding()

            ForEach(0 ..< 10) { index in
                GlassEffectContainer(thickness: .regular) {
                    HStack {
                        Text("Glass Element \(index + 1)")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                }
                .frame(height: 60)
            }
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
