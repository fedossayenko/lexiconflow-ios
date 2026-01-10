//
//  InteractiveGlassModifier.swift
//  LexiconFlow
//
//  Reactive glass refraction based on drag gestures.
//

import SwiftUI

// MARK: - Interactive Glass Constants

/// Visual constants for interactive glass effects.
///
/// These values are tuned for the "Liquid Glass" feel where glass responds
/// fluidly to drag gestures with appropriate visual feedback.
private enum InteractiveGlassConstants {
    /// Maximum drag distance for full effect (points)
    /// - Drag distance beyond this value saturates at 1.0 progress
    static let maxDragDistance: CGFloat = 200

    /// Specular highlight opacity at full progress
    /// - Controls brightness of the light refraction effect
    static let specularHighlightOpacity: Double = 0.3

    /// Edge glow opacity multiplier at full progress
    /// - Controls intensity of the glowing rim effect
    static let edgeGlowOpacityMultiplier: Double = 0.5

    /// Edge glow line width (points)
    /// - Thickness of the glowing border around the card
    static let edgeGlowLineWidth: CGFloat = 2

    /// Edge glow blur radius (points)
    /// - Softness of the glowing edge
    /// PERFORMANCE: Reduced from 4 to 2 for better gesture performance
    static let edgeGlowBlurRadius: CGFloat = 2

    /// Hue rotation degrees at max drag
    /// - Creates subtle color shift during drag
    static let hueRotationDegrees: Double = 5

    /// Saturation increase multiplier at full progress
    /// - Enhances color vividness during interaction
    static let saturationIncreaseMultiplier: Double = 0.2

    /// Scale effect multiplier at full progress (5% swelling)
    /// - Creates subtle "swelling" effect when dragged
    static let scaleEffectMultiplier: Double = 0.05

    /// 3D rotation degrees at max drag
    /// - Creates subtle perspective tilt effect
    static let rotation3DDegrees: Double = 5
}

// MARK: - Interactive Effect

/// Configuration for interactive glass effects.
///
/// Defines the visual feedback applied during drag gestures,
/// including tint color for direction-based feedback.
struct InteractiveEffect {
    /// The tint color overlay for direction-based feedback.
    let tint: Color

    /// Creates a clear effect with no visual changes.
    static func clear() -> InteractiveEffect {
        InteractiveEffect(tint: .clear)
    }

    /// Creates a tinted effect.
    ///
    /// - Parameter color: The tint color to apply
    /// - Returns: An interactive effect with the specified tint
    static func tint(_ color: Color) -> InteractiveEffect {
        InteractiveEffect(tint: color)
    }
}

/// View modifier that applies reactive glass effects based on drag offset.
///
/// Creates the "Liquid Glass" refraction effect where glass appears to
/// bend light and shift colors as the card is dragged in different directions.
struct InteractiveGlassModifier: ViewModifier {
    @Binding var offset: CGSize
    let effectBuilder: (CGSize) -> InteractiveEffect

    /// Pre-compute progress ONCE per frame (critical performance optimization)
    private func progress(for offset: CGSize, config: AppSettings.GlassEffectConfiguration) -> Double {
        let baseProgress = min(abs(offset.width) / InteractiveGlassConstants.maxDragDistance, 1.0)
        return baseProgress * config.opacityMultiplier
    }

    func body(content: Content) -> some View {
        let effect = self.effectBuilder(self.offset)
        let config = AppSettings.glassConfiguration
        let currentProgress = self.progress(for: self.offset, config: config)

        // PRE-COMPUTE all conditional states (reduces branch evaluation during animation)
        let showHighlight = currentProgress > 0.1
        let showGlow = currentProgress > 0.2
        let hasInteraction = currentProgress > 0

        @ViewBuilder var modifiedContent: some View {
            content
                .overlay(
                    ZStack {
                        // Layer 1: Directional tint (always rendered for base feedback)
                        effect.tint.clipShape(RoundedRectangle(cornerRadius: 20))

                        // Layer 2: Specular highlight shift (essential for "Liquid" feel)
                        if showHighlight {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(InteractiveGlassConstants.specularHighlightOpacity * currentProgress * config.opacityMultiplier),
                                            .clear
                                        ],
                                        startPoint: self.offset.width > 0 ? .leading : .trailing,
                                        endPoint: self.offset.width > 0 ? .trailing : .leading
                                    )
                                )
                                .blendMode(.screen)
                        }

                        // Layer 3: Edge glow (essential for "Liquid" feel)
                        if showGlow {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    effect.tint.opacity(currentProgress * InteractiveGlassConstants.edgeGlowOpacityMultiplier * config.opacityMultiplier),
                                    lineWidth: InteractiveGlassConstants.edgeGlowLineWidth
                                )
                                .blur(radius: InteractiveGlassConstants.edgeGlowBlurRadius)
                        }
                    }
                    .drawingGroup() // PERFORMANCE: Cache gesture effects as GPU bitmap
                )
                // KEEP all effects (essential for full "Liquid Glass" aesthetic)
                .hueRotation(.degrees(currentProgress * InteractiveGlassConstants.hueRotationDegrees))
                .saturation(hasInteraction ? 1.0 + (currentProgress * InteractiveGlassConstants.saturationIncreaseMultiplier) : 1.0)
                .scaleEffect(1.0 + (currentProgress * InteractiveGlassConstants.scaleEffectMultiplier))
                .rotation3DEffect(
                    .degrees(currentProgress * InteractiveGlassConstants.rotation3DDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 1.0
                )
        }

        return modifiedContent
    }
}

extension View {
    /// Applies reactive glass refraction based on drag offset.
    ///
    /// - Parameters:
    ///   - offset: Binding to the gesture offset
    ///   - effect: Closure that returns an InteractiveEffect based on current offset
    /// - Returns: A view with interactive glass effects applied
    ///
    /// Example:
    /// ```swift
    /// .interactive($offset) { dragOffset in
    ///     let progress = dragOffset.width / 100
    ///     if progress > 0 {
    ///         return .tint(.green.opacity(0.3 * progress))
    ///     } else {
    ///         return .tint(.red.opacity(0.3 * abs(progress)))
    ///     }
    /// }
    /// ```
    func interactive(_ offset: Binding<CGSize>, effect: @escaping (CGSize) -> InteractiveEffect) -> some View {
        modifier(InteractiveGlassModifier(offset: offset, effectBuilder: effect))
    }
}

#Preview("Interactive Effect") {
    InteractivePreview()
}

struct InteractivePreview: View {
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 40) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.blue.opacity(0.3))
                .frame(width: 200, height: 200)
                .overlay(Text("Drag Me"))
                .interactive(self.$offset) { dragOffset in
                    let progress = min(max(dragOffset.width / 100, -1), 1)

                    if progress > 0 {
                        return .tint(.green.opacity(0.3 * progress))
                    } else {
                        return .tint(.red.opacity(0.3 * abs(progress)))
                    }
                }
                .offset(x: self.offset.width, y: self.offset.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.offset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                self.offset = .zero
                            }
                        }
                )

            Text("Offset: \(self.offset.width)")
        }
    }
}
