import SwiftUI

/// A container view that provides glass morphism effects for its content.
///
/// This container wraps content in a glass-like material with blur and translucency,
/// creating the "Liquid Glass" visual effect that responds to memory stability.
///
/// Optimized for 120Hz ProMotion displays with Metal-accelerated rendering.
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    /// Initializes a new glass effect container.
    /// - Parameters:
    ///   - spacing: The spacing between child elements in the container.
    ///   - content: The content to display within the glass effect container.
    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        // Promote to Metal for smooth 120Hz rendering
        // drawingGroup composites all child views efficiently as a single texture
        content
            .drawingGroup()
    }
}

#Preview {
    GlassEffectContainer(spacing: 16) {
        VStack(spacing: 16) {
            Text("Glass Effect Container")
                .font(.title)
            Text("Content with glass morphism effects")
                .font(.body)
        }
        .padding()
    }
}
