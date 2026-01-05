import SwiftUI

/// The thickness of the glass effect, determining blur intensity and opacity.
enum GlassThickness {
    /// Thin glass with minimal blur and low opacity (for fragile memories)
    case thin
    /// Regular glass with medium blur and opacity (default)
    case regular
    /// Thick glass with heavy blur and high opacity (for stable memories)
    case thick

    /// The material to use for this thickness level.
    var material: Material {
        switch self {
        case .thin:
            return .ultraThinMaterial
        case .regular:
            return .thinMaterial
        case .thick:
            return .regularMaterial
        }
    }

    /// The corner radius for the glass shape.
    var cornerRadius: CGFloat {
        switch self {
        case .thin: return 12
        case .regular: return 16
        case .thick: return 20
        }
    }

    /// The shadow radius for depth effect.
    var shadowRadius: CGFloat {
        switch self {
        case .thin: return 5
        case .regular: return 10
        case .thick: return 15
        }
    }

    /// The opacity of the glass overlay.
    var overlayOpacity: Double {
        switch self {
        case .thin: return 0.1
        case .regular: return 0.2
        case .thick: return 0.3
        }
    }
}

/// A view modifier that applies a glass morphism effect to the view.
///
/// Optimized for 120Hz ProMotion displays with Metal-accelerated rendering.
struct GlassEffectModifier<S: InsettableShape & Sendable>: ViewModifier {
    let thickness: GlassThickness
    let shape: S

    // Pre-computed shadow color for performance
    private var shadowColor: Color {
        .black.opacity(0.1)
    }

    // Pre-computed border color for performance
    private var borderColor: Color {
        .white.opacity(thickness.overlayOpacity)
    }

    func body(content: Content) -> some View {
        content
            .clipShape(shape)
            .background {
                // Glass material background
                shape
                    .fill(thickness.material)
            }
            .overlay {
                // Subtle border for depth
                shape
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: thickness.shadowRadius, x: 0, y: 2)
            // Promote to Metal for smooth 120Hz rendering
            // drawingGroup caches the blurred background as a texture
            .drawingGroup()
    }
}

extension View {
    /// Applies a glass morphism effect to the view.
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect (thin, regular, thick).
    ///   - shape: The shape to clip the glass effect to.
    /// - Returns: A view with the glass effect applied.
    func glassEffect<S: InsettableShape>(_ thickness: GlassThickness, in shape: S) -> some View where S: Sendable {
        modifier(GlassEffectModifier(thickness: thickness, shape: shape))
    }

    /// Applies a glass morphism effect with a rounded rectangle shape.
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect.
    ///   - cornerRadius: The corner radius of the rounded rectangle.
    /// - Returns: A view with the glass effect applied.
    func glassEffect(_ thickness: GlassThickness, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassEffectModifier(thickness: thickness, shape: RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

/// View modifier that conditionally applies glass effect based on AppSettings
struct ConditionalGlassEffectModifier<S: InsettableShape & Sendable>: ViewModifier {
    let thickness: GlassThickness
    let shape: S

    func body(content: Content) -> some View {
        if AppSettings.glassEffectsEnabled {
            content.modifier(GlassEffectModifier(thickness: thickness, shape: shape))
        } else {
            content
        }
    }
}

extension View {
    /// Conditionally applies a glass morphism effect based on AppSettings.glassEffectsEnabled.
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect (thin, regular, thick).
    ///   - shape: The shape to clip the glass effect to.
    /// - Returns: A view with the glass effect applied only if enabled in settings.
    func conditionalGlassEffect<S: InsettableShape>(_ thickness: GlassThickness, in shape: S) -> some View where S: Sendable {
        modifier(ConditionalGlassEffectModifier(thickness: thickness, shape: shape))
    }

    /// Conditionally applies a glass morphism effect with a rounded rectangle shape.
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect.
    ///   - cornerRadius: The corner radius of the rounded rectangle.
    /// - Returns: A view with the glass effect applied only if enabled in settings.
    func conditionalGlassEffect(_ thickness: GlassThickness, cornerRadius: CGFloat = 16) -> some View {
        modifier(ConditionalGlassEffectModifier(thickness: thickness, shape: RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

#Preview("Glass Effect Thickness Variants") {
    VStack(spacing: 32) {
        Group {
            Text("Thin Glass")
                .padding()
                .glassEffect(.thin)
        }

        Group {
            Text("Regular Glass")
                .padding()
                .glassEffect(.regular)
        }

        Group {
            Text("Thick Glass")
                .padding()
                .glassEffect(.thick)
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Glass Effect on Cards") {
    HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fragile Memory")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Stability: 5")
                .font(.headline)
        }
        .padding()
        .glassEffect(.thin)

        VStack(alignment: .leading, spacing: 8) {
            Text("Medium Memory")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Stability: 25")
                .font(.headline)
        }
        .padding()
        .glassEffect(.regular)

        VStack(alignment: .leading, spacing: 8) {
            Text("Stable Memory")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Stability: 75")
                .font(.headline)
        }
        .padding()
        .glassEffect(.thick)
    }
    .padding()
    .background(.gray.opacity(0.1))
}
