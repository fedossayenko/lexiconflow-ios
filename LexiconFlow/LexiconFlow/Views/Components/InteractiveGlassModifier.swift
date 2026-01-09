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
    static let edgeGlowBlurRadius: CGFloat = 4

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

    func body(content: Content) -> some View {
        let effect = self.effectBuilder(self.offset)
        let progress = min(abs(offset.width) / InteractiveGlassConstants.maxDragDistance, 1.0)

        return content
            .overlay(
                ZStack {
                    // Layer 1: Directional tint
                    effect.tint.clipShape(RoundedRectangle(cornerRadius: 20))

                    // Layer 2: Specular highlight shift (simulates light refraction)
                    if progress > 0.1 {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(InteractiveGlassConstants.specularHighlightOpacity * progress),
                                        .clear
                                    ],
                                    startPoint: self.offset.width > 0 ? .leading : .trailing,
                                    endPoint: self.offset.width > 0 ? .trailing : .leading
                                )
                            )
                            .blendMode(.screen)
                    }

                    // Layer 3: Edge glow (creates "glowing rim" effect)
                    if progress > 0.2 {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                effect.tint.opacity(progress * InteractiveGlassConstants.edgeGlowOpacityMultiplier),
                                lineWidth: InteractiveGlassConstants.edgeGlowLineWidth
                            )
                            .blur(radius: InteractiveGlassConstants.edgeGlowBlurRadius)
                    }
                }
            )
            .hueRotation(.degrees(progress * InteractiveGlassConstants.hueRotationDegrees))
            .saturation(progress > 0 ? 1.0 + (progress * InteractiveGlassConstants.saturationIncreaseMultiplier) : 1.0)
            .scaleEffect(1.0 + (progress * InteractiveGlassConstants.scaleEffectMultiplier)) // Subtle "swelling"
            .rotation3DEffect(
                .degrees(progress * InteractiveGlassConstants.rotation3DDegrees),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 1.0
            )
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
    struct InteractivePreview: View {
        @State private var offset: CGSize = .zero

        var body: some View {
            VStack(spacing: 40) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(Text("Drag Me"))
                    .interactive($offset) { dragOffset in
                        let progress = min(max(dragOffset.width / 100, -1), 1)

                        if progress > 0 {
                            return .tint(.green.opacity(0.3 * progress))
                        } else {
                            return .tint(.red.opacity(0.3 * abs(progress)))
                        }
                    }
                    .offset(x: offset.width, y: offset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    offset = .zero
                                }
                            }
                    )

                Text("Offset: \(offset.width)")
            }
        }
    }

    return InteractivePreview()
}
