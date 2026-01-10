//
//  GlassEffectUnion.swift
//  LexiconFlow
//
//  Merges deck icon with circular progress ring using glass morphism effects.
//
//  This modifier creates a visual union of the deck icon and a progress indicator,
//  showing the due/total ratio as a "liquid glass" arc around the icon.
//
//  **Usage:**
//  ```swift
//  Image(systemName: "folder.fill")
//      .glassEffectUnion(
//          progress: 0.5,  // 50% complete
//          thickness: .thin,
//          iconSize: 50
//      )
//  ```
//

import SwiftUI

/// Modifier that merges a view with a circular progress ring using glass morphism effects
///
/// **Color Coding:**
/// - Green (0-0.3): Low due count
/// - Orange (0.3-0.7): Medium due count
/// - Red (0.7-1.0): High due count
///
/// **Animation:** Smooth spring animation (response: 0.6, damping: 0.7)
struct GlassEffectUnion: ViewModifier {
    /// Progress value from 0.0 to 1.0 (due/total ratio)
    let progress: Double

    /// Glass thickness for the effect
    let thickness: GlassThickness

    /// Size of the icon
    let iconSize: CGFloat

    /// Animation state for smooth progress updates
    @State private var animatedProgress: Double = 0

    // MARK: - Body

    func body(content: Content) -> some View {
        let config = AppSettings.glassConfiguration
        let effectiveThickness = config.effectiveThickness(base: thickness)
        let opacityMultiplier = config.opacityMultiplier

        ZStack {
            // Background circle (glass base)
            Circle()
                .fill(effectiveThickness.material)
                .frame(width: iconSize + 16, height: iconSize + 16)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(effectiveThickness.overlayOpacity * opacityMultiplier),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }

            // Progress arc (liquid glass ring)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: progressColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: iconSize + 16, height: iconSize + 16)
                .blur(radius: 2)
                .overlay {
                    // Specular highlight on progress arc
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.5 * opacityMultiplier),
                                    .white.opacity(0.1 * opacityMultiplier)
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .blendMode(.overlay)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedProgress)

            // Icon (centered, with glass background)
            content
                .frame(width: iconSize, height: iconSize)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1 * opacityMultiplier), radius: 4, x: 0, y: 2)
                }
        }
        .onAppear {
            // Animate progress on appear
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newProgress in
            // Animate when progress changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newProgress
            }
        }
    }

    // MARK: - Computed Properties

    /// Progress color gradient based on ratio
    private var progressColors: [Color] {
        let baseHue: Double
        let saturation: Double

        switch progress {
        case 0.0 ..< 0.3:
            // Green (low due count)
            baseHue = 120 // Green
            saturation = 0.8
        case 0.3 ..< 0.7:
            // Orange (medium due count)
            baseHue = 30 // Orange
            saturation = 0.9
        default:
            // Red (high due count)
            baseHue = 0 // Red
            saturation = 0.9
        }

        return [
            Color(hue: baseHue, saturation: saturation, brightness: 0.8).opacity(0.8),
            Color(hue: baseHue, saturation: saturation, brightness: 0.6).opacity(0.6),
            Color(hue: baseHue, saturation: saturation, brightness: 0.4).opacity(0.4)
        ]
    }
}

// MARK: - View Extension

extension View {
    /// Merges the view with a circular progress ring using glass morphism effects.
    ///
    /// This modifier creates a visual union of the view (typically an icon) with a
    /// circular progress indicator, showing the due/total ratio as a "liquid glass" arc.
    ///
    /// **Parameters:**
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - thickness: Glass thickness for the effect (default: .regular)
    ///   - iconSize: Size of the icon (default: 50)
    ///
    /// **Returns:** A view with the glass progress union applied
    ///
    /// **Example:**
    /// ```swift
    /// Image(systemName: "folder.fill")
    ///     .font(.system(size: 24))
    ///     .foregroundStyle(.blue)
    ///     .glassEffectUnion(
    ///         progress: 0.5,  // 50% complete
    ///         thickness: .thin,
    ///         iconSize: 50
    ///     )
    /// ```
    func glassEffectUnion(
        progress: Double,
        thickness: GlassThickness = .regular,
        iconSize: CGFloat = 50
    ) -> some View {
        modifier(GlassEffectUnion(progress: progress, thickness: thickness, iconSize: iconSize))
    }
}

// MARK: - Previews

#Preview("GlassEffectUnion - 0% Progress") {
    Image(systemName: "folder.fill")
        .font(.system(size: 24))
        .foregroundStyle(.blue)
        .glassEffectUnion(progress: 0.0, thickness: .thin, iconSize: 60)
        .padding()
        .background(LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        ))
}

#Preview("GlassEffectUnion - 25% Progress (Green)") {
    Image(systemName: "folder.fill")
        .font(.system(size: 24))
        .foregroundStyle(.blue)
        .glassEffectUnion(progress: 0.25, thickness: .thin, iconSize: 60)
        .padding()
        .background(LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        ))
}

#Preview("GlassEffectUnion - 50% Progress (Orange)") {
    Image(systemName: "folder.fill")
        .font(.system(size: 24))
        .foregroundStyle(.blue)
        .glassEffectUnion(progress: 0.5, thickness: .regular, iconSize: 60)
        .padding()
        .background(LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        ))
}

#Preview("GlassEffectUnion - 75% Progress (Red)") {
    Image(systemName: "folder.fill")
        .font(.system(size: 24))
        .foregroundStyle(.blue)
        .glassEffectUnion(progress: 0.75, thickness: .thick, iconSize: 60)
        .padding()
        .background(LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        ))
}

#Preview("GlassEffectUnion - Animation") {
    struct AnimationPreview: View {
        @State private var progress: Double = 0.0

        var body: some View {
            VStack(spacing: 40) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .glassEffectUnion(progress: progress, thickness: .regular, iconSize: 60)

                Slider(value: $progress, in: 0 ... 1)
                    .frame(width: 200)

                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }

    return AnimationPreview()
}
