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

    var body: some View {
        Form {
            Section {
                Toggle("Haptic Feedback", isOn: Binding(
                    get: { AppSettings.hapticEnabled },
                    set: { AppSettings.hapticEnabled = $0 }
                ))
                    .accessibilityLabel("Enable haptic feedback")

                if AppSettings.hapticEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(value: Binding(
                            get: { AppSettings.hapticIntensity },
                            set: { AppSettings.hapticIntensity = $0 }
                        ), in: 0.1...1.0, step: 0.1)
                            .accessibilityLabel("Haptic intensity")
                            .accessibilityValue("\(Int(AppSettings.hapticIntensity * 100))%")

                        HStack(spacing: 12) {
                            Button("Light") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    AppSettings.hapticIntensity = 0.3
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Light intensity")

                            Button("Medium") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    AppSettings.hapticIntensity = 0.6
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Medium intensity")

                            Button("Heavy") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    AppSettings.hapticIntensity = 1.0
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Heavy intensity")
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Haptic feedback during card swipes and ratings. Test the intensity below:")
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
