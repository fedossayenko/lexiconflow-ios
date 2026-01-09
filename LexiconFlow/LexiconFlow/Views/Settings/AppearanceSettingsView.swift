//
//  AppearanceSettingsView.swift
//  LexiconFlow
//
//  Theme and appearance preferences
//

import SwiftUI

struct AppearanceSettingsView: View {
    var body: some View {
        Form {
            // Theme Selection
            Section {
                Picker("Appearance", selection: Binding(
                    get: { AppSettings.darkMode },
                    set: { AppSettings.darkMode = $0 }
                )) {
                    ForEach(AppSettings.DarkModePreference.allCases, id: \.rawValue) { mode in
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .foregroundStyle(.secondary)
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                }
                .pickerStyle(.inline)
                .accessibilityLabel("App appearance theme")
            } header: {
                Text("Theme")
            } footer: {
                Text("Choose how the app appearance is determined")
            }

            // Visual Effects
            Section {
                Toggle("Glass Effects", isOn: Binding(
                    get: { AppSettings.glassEffectsEnabled },
                    set: { AppSettings.glassEffectsEnabled = $0 }
                ))
                .accessibilityLabel("Enable glass morphism effects")

                if AppSettings.glassEffectsEnabled {
                    // Glass Effect Intensity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intensity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(AppSettings.glassEffectIntensity * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { AppSettings.glassEffectIntensity },
                                set: { AppSettings.glassEffectIntensity = $0 }
                            ),
                            in: 0 ... 1,
                            step: 0.1
                        )
                        .accessibilityLabel("Glass effect intensity")
                        .accessibilityValue("\(Int(AppSettings.glassEffectIntensity * 100)) percent")
                    }
                    .padding(.vertical, 4)

                    // Gesture Sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gesture Sensitivity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1fx", AppSettings.gestureSensitivity))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { AppSettings.gestureSensitivity },
                                set: { AppSettings.gestureSensitivity = $0 }
                            ),
                            in: 0.5 ... 2.0,
                            step: 0.1
                        )
                        .accessibilityLabel("Gesture sensitivity")
                        .accessibilityValue("\(String(format: "%.1f", AppSettings.gestureSensitivity))x")
                        Text("Controls how responsive swipe gestures are")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Visual Effects")
            } footer: {
                Text("Glass morphism creates translucent, frosted glass UI elements with blur effects. Adjust intensity and gesture sensitivity to your preference.")
            }

            // Preview
            Section {
                VStack(spacing: 16) {
                    // Card Preview
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 80)
                        .overlay {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sample Card")
                                    .font(.headline)
                                Text("This is how cards appear in your current theme")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Text("Preview updates based on your theme selection")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
