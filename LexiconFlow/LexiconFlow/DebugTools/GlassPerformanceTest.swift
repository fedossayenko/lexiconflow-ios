//
//  GlassPerformanceTest.swift
//  LexiconFlow
//
//  Debug view for Instruments profiling of GlassEffectModifier performance
//  Used with Core Animation profiler to validate .drawingGroup() optimization
//
//  USAGE:
//  1. Build app in Release configuration
//  2. Open Xcode → Product → Profile (Cmd+I)
//  3. Choose "Core Animation" template
//  4. Navigate to this view in the app
//  5. Scroll through all 50 cards while recording
//  6. Analyze FPS and frame time in Instruments
//
//  TARGET METRICS:
//  - Frame time: <16.6ms (60fps)
//  - GPU utilization: 40-60% lower than without .drawingGroup()
//  - No frame drops during smooth scrolling
//

import SwiftUI

struct GlassPerformanceTest: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0 ..< 50) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.blue.opacity(0.3))
                        .frame(width: 300, height: 200)
                        .glassEffect(.regular)
                        .overlay(
                            VStack {
                                Text("Glass Card \(i + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Test GPU caching with .drawingGroup()")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        )
                }
            }
            .padding()
        }
        .navigationTitle("Glass Performance Test")
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("50 Glass Cards")
                        .font(.headline)
                    Text("Scroll to test GPU performance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GlassPerformanceTest()
    }
}
