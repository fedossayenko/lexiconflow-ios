//
//  HapticSettingsView.swift
//  LexiconFlow
//
//  Haptic feedback settings screen
//

import SwiftUI

struct HapticSettingsView: View {
    @AppStorage("hapticEnabled") private var isEnabled = true
    @State private var isTesting = false

    private let hapticService = HapticService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Haptic Feedback", isOn: $isEnabled)
                    .accessibilityLabel("Enable haptic feedback")
            } header: {
                Text("Feedback")
            } footer: {
                Text("Haptic feedback during card swipes and ratings.")
            }

            if isEnabled {
                Button {
                    testHaptic()
                } label: {
                    if isTesting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Text("Test Haptic")
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Test haptic feedback")
                .disabled(isTesting)
            }
        }
        .navigationTitle("Haptic Feedback")
    }

    private func testHaptic() {
        isTesting = true
        hapticService.triggerSuccess()

        // Reset after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                isTesting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        HapticSettingsView()
    }
}
