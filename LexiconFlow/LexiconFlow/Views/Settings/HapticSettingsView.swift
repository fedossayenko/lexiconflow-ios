//
//  HapticSettingsView.swift
//  LexiconFlow
//
//  Haptic feedback settings screen
//

import SwiftUI

struct HapticSettingsView: View {
    @State private var isTesting = false

    private let hapticService = HapticService.shared

    /// Binding to AppSettings.hapticEnabled following centralized pattern
    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.hapticEnabled },
            set: { AppSettings.hapticEnabled = $0 }
        )
    }

    /// Binding to AppSettings.audioEnabled following centralized pattern
    private var audioEnabledBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.audioEnabled },
            set: { AppSettings.audioEnabled = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Audio Feedback", isOn: audioEnabledBinding)
                    .accessibilityLabel("Enable audio feedback")
                Toggle("Haptic Feedback", isOn: isEnabledBinding)
                    .accessibilityLabel("Enable haptic feedback")
            } header: {
                Text("Feedback")
            } footer: {
                Text("Audio and haptic feedback during study sessions.")
            }

            if AppSettings.hapticEnabled {
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

    func testHaptic() {
        isTesting = true
        hapticService.triggerSuccess()

        // Reset after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500000000) // 0.5 seconds
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
