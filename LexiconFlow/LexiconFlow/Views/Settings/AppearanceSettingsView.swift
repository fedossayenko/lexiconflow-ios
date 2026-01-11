//
//  AppearanceSettingsView.swift
//  LexiconFlow
//
//  Theme and appearance preferences
//

import SwiftUI

struct AppearanceSettingsView: View {
    // MARK: - UI Constants

    /// Percentage display constants
    private enum PercentageDisplay {
        /// Multiplier to convert decimal (0.0-1.0) to percentage (0-100)
        static let multiplier: Int = 100
    }

    // MARK: - Computed Properties

    /// Dynamic glass thickness based on current settings
    private var previewGlassThickness: GlassThickness {
        let config = AppSettings.glassConfiguration
        guard config.isEnabled else { return .thin }

        switch config.intensity {
        case 0.0 ..< 0.3:
            return .thin
        case 0.3 ..< 0.7:
            return .regular
        default:
            return .thick
        }
    }

    /// Dynamic background for theme demonstration
    private var previewBackground: some View {
        // Creates a gradient that shows theme difference clearly
        LinearGradient(
            colors: self.themeAwareGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Theme-aware gradient colors for preview background
    private var themeAwareGradientColors: [Color] {
        switch AppSettings.darkMode {
        case .light:
            [Color.blue.opacity(0.2), Color.purple.opacity(0.15)]
        case .dark:
            [Color.blue.opacity(0.4), Color.purple.opacity(0.3)]
        case .system:
            // Uses adaptive colors that respond to system theme
            [.blue.opacity(0.3), .purple.opacity(0.2)]
        }
    }

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
                            Text("\(Int(AppSettings.glassEffectIntensity * Double(PercentageDisplay.multiplier)))%")
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
                        .accessibilityValue("\(Int(AppSettings.glassEffectIntensity * Double(PercentageDisplay.multiplier))) percent")
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
                    // Dynamic background to demonstrate theme
                    self.previewBackground
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            // Glass card that responds to intensity settings
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.clear)
                                .frame(height: 80)
                                .glassEffect(self.previewGlassThickness)
                                .overlay {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Sample Card")
                                                .font(.headline)
                                            Spacer()
                                            // Theme indicator
                                            Image(systemName: AppSettings.darkMode.icon)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("Glass: \(AppSettings.glassEffectsEnabled ? "On" : "Off") • \(Int(AppSettings.glassEffectIntensity * 100))% intensity")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                }
                        }

                    Text("Preview updates in real-time based on your settings")
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
