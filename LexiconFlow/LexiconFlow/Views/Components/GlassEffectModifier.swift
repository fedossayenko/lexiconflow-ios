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
            .ultraThinMaterial
        case .regular:
            .thinMaterial
        case .thick:
            .regularMaterial
        }
    }

    /// The corner radius for the glass shape.
    var cornerRadius: CGFloat {
        switch self {
        case .thin: 12
        case .regular: 16
        case .thick: 20
        }
    }

    /// The shadow radius for depth effect.
    var shadowRadius: CGFloat {
        switch self {
        case .thin: 5
        case .regular: 10
        case .thick: 15
        }
    }

    /// The opacity of the glass overlay.
    var overlayOpacity: Double {
        switch self {
        case .thin: 0.1
        case .regular: 0.2
        case .thick: 0.3
        }
    }

    /// Blur radius for refraction effect (simulates light bending through glass)
    var refractionBlur: CGFloat {
        switch self {
        case .thin: 2
        case .regular: 5
        case .thick: 8
        }
    }

    /// Specular highlight intensity (creates "shiny" appearance)
    var specularOpacity: Double {
        switch self {
        case .thin: 0.15
        case .regular: 0.25
        case .thick: 0.35
        }
    }
}

/// A view modifier that applies a glass morphism effect to the view.
struct GlassEffectModifier<S: InsettableShape>: ViewModifier {
    let thickness: GlassThickness
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let config = AppSettings.glassConfiguration
        let effectiveOpacity = self.thickness.overlayOpacity * config.opacityMultiplier

        @ViewBuilder var glassContent: some View {
            content
                .clipShape(shape)
                .background {
                    // PERFORMANCE: All layers combined in single ZStack for optimal GPU composition
                    // .drawingGroup() caches the entire ZStack as a GPU bitmap for massive performance boost
                    // This reduces composition passes from 3+ to 1 by caching the composited result
                    ZStack {
                        // Layer 1: Base material
                        shape.fill(thickness.material)

                        // Layer 2: Refraction blur (simulates light bending through glass)
                        shape
                            .fill(.ultraThinMaterial)
                            .blur(radius: thickness.refractionBlur)

                        // Layer 3: Specular highlight (creates "shiny" appearance)
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(thickness.specularOpacity * config.opacityMultiplier),
                                        .clear,
                                        .white.opacity(thickness.specularOpacity * 0.5 * config.opacityMultiplier)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                    .drawingGroup()
                }
                .overlay {
                    // Layer 4: Inner glow for depth (essential for "Liquid Glass" aesthetic)
                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(effectiveOpacity),
                                    .white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.1) // Light shadow for depth in dark mode
                        : Color.black.opacity(0.05), // Subtle shadow in light mode
                    radius: thickness.shadowRadius,
                    x: 0,
                    y: 4
                )
                .modifier(DynamicLightingModifier(thickness: thickness)) // KEEP - essential
        }

        return glassContent
    }
}

extension View {
    /// Applies a glass morphism effect to the view.
    /// - Parameters:
    ///   - thickness: The thickness of the glass effect (thin, regular, thick).
    ///   - shape: The shape to clip the glass effect to.
    /// - Returns: A view with the glass effect applied.
    func glassEffect(_ thickness: GlassThickness, in shape: some InsettableShape) -> some View {
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

#Preview("Glass Effect - Light Mode") {
    VStack(spacing: 32) {
        Text("Thin Glass (Light)")
            .padding()
            .glassEffect(.thin)

        Text("Regular Glass (Light)")
            .padding()
            .glassEffect(.regular)

        Text("Thick Glass (Light)")
            .padding()
            .glassEffect(.thick)
    }
    .padding()
    .background(Color.white.opacity(0.9))
    .preferredColorScheme(.light)
}

#Preview("Glass Effect - Dark Mode") {
    VStack(spacing: 32) {
        Text("Thin Glass (Dark)")
            .padding()
            .glassEffect(.thin)

        Text("Regular Glass (Dark)")
            .padding()
            .glassEffect(.regular)

        Text("Thick Glass (Dark)")
            .padding()
            .glassEffect(.thick)
    }
    .padding()
    .background(Color.black.opacity(0.3))
    .preferredColorScheme(.dark)
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

#Preview("Glass Effect Cards - Light Mode") {
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
    .background(Color.white.opacity(0.9))
    .preferredColorScheme(.light)
}

#Preview("Glass Effect Cards - Dark Mode") {
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
    .background(Color.black.opacity(0.3))
    .preferredColorScheme(.dark)
}
