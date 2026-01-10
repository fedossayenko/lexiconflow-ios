//
//  InteractiveGlassModifier.swift
//  LexiconFlow
//
//  Created by Claude on 2025-01-08.
//  Copyright © 2025 LexiconFlow. All rights reserved.
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

        // PRE-COMPUTE all visual effect values (expensive calculations done once)
        let hueRotation = InteractiveGlassConstants.hueRotationDegrees * currentProgress
        let saturationIncrease = 1.0 + (InteractiveGlassConstants.saturationIncreaseMultiplier * currentProgress)
        let scaleIncrease = 1.0 + (InteractiveGlassConstants.scaleEffectMultiplier * currentProgress)
        let rotationAngle = InteractiveGlassConstants.rotation3DDegrees * currentProgress
        let rotationYAxis: CGFloat = self.offset.width > 0 ? 1 : -1

        // BUILD view hierarchy with pre-computed values
        @ViewBuilder var modifiedContent: some View {
            content
                .overlay(effect.tint.opacity(0.3 * currentProgress))
                .overlay {
                    if showHighlight {
                        self.specularHighlight(for: self.offset)
                            .opacity(InteractiveGlassConstants.specularHighlightOpacity * currentProgress)
                    }
                }
                .overlay {
                    if showGlow {
                        self.edgeGlow(for: self.offset)
                            .opacity(InteractiveGlassConstants.edgeGlowOpacityMultiplier * currentProgress)
                    }
                }
                .hueRotation(.degrees(hueRotation))
                .saturation(saturationIncrease)
                .scaleEffect(scaleIncrease)
                .rotation3DEffect(
                    .degrees(rotationAngle),
                    axis: (x: 0, y: rotationYAxis, z: 0)
                )
        }

        return modifiedContent
    }

    // MARK: - Effect Helpers

    /// Generates specular highlight based on drag direction.
    ///
    /// - Parameter offset: Current drag offset
    /// - Returns: Linear gradient simulating light refraction
    private func specularHighlight(for offset: CGSize) -> some View {
        let isDraggingRight = offset.width > 0

        return LinearGradient(
            colors: [
                .white.opacity(isDraggingRight ? 0.5 : 0),
                .white.opacity(isDraggingRight ? 0 : 0.5)
            ],
            startPoint: isDraggingRight ? .topLeading : .topTrailing,
            endPoint: isDraggingRight ? .bottomTrailing : .bottomLeading
        )
    }

    /// Generates edge glow based on drag direction.
    ///
    /// - Parameter offset: Current drag offset
    /// - Returns: Glowing border with blur effect
    private func edgeGlow(for offset: CGSize) -> some View {
        let isDraggingRight = offset.width > 0
        let glowColor: Color = isDraggingRight ? .green : .red

        return RoundedRectangle(cornerRadius: 16)
            .stroke(glowColor, lineWidth: InteractiveGlassConstants.edgeGlowLineWidth)
            .blur(radius: InteractiveGlassConstants.edgeGlowBlurRadius)
    }
}

// MARK: - View Extension

extension View {
    /// Applies interactive glass effects based on drag offset.
    ///
    /// **Parameters**:
    ///   - offset: Binding to drag offset from gesture
    ///   - effect: Closure returning `InteractiveEffect` for given offset
    ///
    /// **Performance**: Pre-computes all values once per frame for smooth 60fps animations.
    /// Avoids repeated calculations during gesture updates.
    ///
    /// **Example**:
    /// ```swift
    /// struct CardView: View {
    ///     @State private var offset: CGSize = .zero
    ///
    ///     var body: some View {
    ///         RoundedRectangle(cornerRadius: 20)
    ///             .fill(.ultraThinMaterial)
    ///             .interactive($offset) { dragOffset in
    ///                 let progress = min(max(dragOffset.width / 100, -1), 1)
    ///                 if progress > 0 {
    ///                     return .tint(.green.opacity(0.3 * progress))
    ///                 } else {
    ///                     return .tint(.red.opacity(0.3 * abs(progress)))
    ///                 }
    ///             }
    ///             .gesture(
    ///                 DragGesture()
    ///                     .onChanged { value in
    ///                         offset = value.translation
    ///                     }
    ///                     .onEnded { _ in
    ///                         withAnimation(.spring()) {
    ///                             offset = .zero
    ///                         }
    ///                     }
    ///             )
    ///     }
    /// }
    /// ```
    func interactive(_ offset: Binding<CGSize>, effect: @escaping (CGSize) -> InteractiveEffect) -> some View {
        modifier(InteractiveGlassModifier(offset: offset, effectBuilder: effect))
    }
}

// MARK: - Preview

struct InteractiveGlassModifierPreview: View {
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

#Preview("Interactive Effect") {
    InteractiveGlassModifierPreview()
}
