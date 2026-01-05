//
//  AppearanceSettingsView.swift
//  LexiconFlow
//
//  Theme and appearance preferences
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("darkMode") private var darkMode = AppSettings.DarkModePreference.system
    @AppStorage("glassEffectsEnabled") private var glassEffectsEnabled = true

    var body: some View {
        Form {
            // Theme Selection
            Section {
                Picker("Appearance", selection: $darkMode) {
                    ForEach(AppSettings.DarkModePreference.allCases, id: \.rawValue) { mode in
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .foregroundStyle(.secondary)
                            Text(mode.displayName)
                                .tag(mode.rawValue)
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
                Toggle("Glass Effects", isOn: $glassEffectsEnabled)
                    .accessibilityLabel("Enable glass morphism effects")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("About Glass Effects")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("Glass morphism creates translucent, frosted glass UI elements with blur effects. This feature is planned for Phase 2.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Visual Effects")
            } footer: {
                Text("Enable glass morphism effects throughout the app")
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

extension AppSettings.DarkModePreference {
    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
