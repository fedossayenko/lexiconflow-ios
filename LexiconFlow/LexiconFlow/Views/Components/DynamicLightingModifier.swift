//
//  DynamicLightingModifier.swift
//  LexiconFlow
//
//  Dynamic lighting effects for glass morphism.
//  Adds subtle radial gradient overlays that simulate ambient light.
//

import SwiftUI

/// View modifier that applies dynamic lighting effects to glass surfaces.
///
/// Creates a subtle radial gradient overlay that simulates ambient light
/// hitting the glass surface from the top-left corner, enhancing the
/// three-dimensional appearance of glass elements.
struct DynamicLightingModifier: ViewModifier {
    let thickness: GlassThickness
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: self.thickness.cornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(self.isPressed ? 0.1 : 0.05),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
            }
            .animation(.easeOut(duration: 0.2), value: self.isPressed)
    }
}

#Preview("Dynamic Lighting") {
    VStack(spacing: 32) {
        Text("Thin Glass")
            .padding()
            .glassEffect(.thin)

        Text("Regular Glass")
            .padding()
            .glassEffect(.regular)

        Text("Thick Glass")
            .padding()
            .glassEffect(.thick)
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
