//
//  InteractiveGlassModifier.swift
//  LexiconFlow
//
//  Reactive glass refraction based on drag gestures.
//

import SwiftUI

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
        let effect = effectBuilder(offset)
        let progress = min(abs(offset.width) / 200, 1.0)

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
                                        .white.opacity(0.3 * progress),
                                        .clear
                                    ],
                                    startPoint: offset.width > 0 ? .leading : .trailing,
                                    endPoint: offset.width > 0 ? .trailing : .leading
                                )
                            )
                            .blendMode(.screen)
                    }

                    // Layer 3: Edge glow (creates "glowing rim" effect)
                    if progress > 0.2 {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                effect.tint.opacity(progress * 0.5),
                                lineWidth: 2
                            )
                            .blur(radius: 4)
                    }
                }
            )
            .hueRotation(.degrees(progress * 5))
            .saturation(progress > 0 ? 1.0 + (progress * 0.2) : 1.0)
            .scaleEffect(1.0 + (progress * 0.05))  // Subtle "swelling"
            .rotation3DEffect(
                .degrees(progress * 5),
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
