//
//  GlassEffectTransition.swift
//  LexiconFlow
//
//  Custom transition for glass morphism effects.
//

import SwiftUI

/// Defines the transition style for glass morphism effects.
enum GlassTransitionStyle {
    /// Scale + fade in/out (card flip)
    case scaleFade
    /// Fade with distortion (navigation)
    case dissolve
    /// Stretch/snap morph (state changes)
    case liquid
    /// Glass materialization effect (blur + opacity morphing)
    case materialize
}

extension View {
    /// Applies glass morphism transition effect.
    ///
    /// - Parameters:
    ///   - style: The transition style (scaleFade, dissolve, liquid, or materialize)
    /// - Returns: A view with the glass transition applied
    ///
    /// Note: AnyView is used here because SwiftUI's transition modifiers
    /// return different concrete types that cannot be unified in a switch
    /// statement. For transitions, the performance impact is negligible
    /// since they are only applied during animation.
    func glassEffectTransition(_ style: GlassTransitionStyle) -> some View {
        switch style {
        case .scaleFade:
            // Scale in/out with opacity for "scaleFade" effect
            // Creates the illusion of content emerging from liquid glass
            return AnyView(self.transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 1.05).combined(with: .opacity)
            )))
        case .dissolve:
            return AnyView(self.transition(.opacity))
        case .liquid:
            return AnyView(self.transition(.move(edge: .trailing).combined(with: .opacity)))
        case .materialize:
            // Glass materialization effect with subtle opacity morphing
            // Creates the illusion of content materializing from glass
            //
            // TECHNICAL NOTE: AnyView type erasure causes SwiftUI accessibilityHint ambiguity.
            // The .materialize transition creates issues where accessibility hints are not
            // properly propagated to VoiceOver when applied via AnyView.
            //
            // WORKAROUND: FlashcardView currently uses .scaleFade transition instead.
            // This provides smooth animations without the accessibility issues.
            //
            // FUTURE: Revisit when SwiftUI provides better type-erased transition modifiers
            // or when a non-AnyView approach for dynamic transitions is available.
            // Tracking: https://forums.swift.org/t/swiftui-type-erasure-and-accessibility (if applicable)
            return AnyView(self.transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                removal: .opacity.combined(with: .scale(scale: 1.02))
            )))
        }
    }
}

#Preview("ScaleFade Transition") {
    struct TransitionPreview: View {
        @State private var isFlipped = false

        var body: some View {
            VStack(spacing: 40) {
                ZStack {
                    if isFlipped {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.blue.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(Text("Back"))
                            .glassEffectTransition(.scaleFade)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.green.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(Text("Front"))
                            .glassEffectTransition(.scaleFade)
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isFlipped.toggle()
                    }
                }

                Button("Toggle Flip") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isFlipped.toggle()
                    }
                }
            }
        }
    }

    return TransitionPreview()
}
