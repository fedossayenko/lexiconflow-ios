//
//  TTSSettingsView.swift
//  LexiconFlow
//
//  Text-to-Speech settings screen
//

import AVFoundation
import SwiftUI

struct TTSSettingsView: View {
    @State private var isTesting = false
    @State private var availableVoices: [String] = []

    private let speechService = SpeechService.shared

    /// Binding to AppSettings.ttsEnabled following centralized pattern
    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.ttsEnabled },
            set: { AppSettings.ttsEnabled = $0 }
        )
    }

    /// Binding to AppSettings.ttsTiming following centralized pattern
    private var timingBinding: Binding<AppSettings.TTSTiming> {
        Binding(
            get: { AppSettings.ttsTiming },
            set: { AppSettings.ttsTiming = $0 }
        )
    }

    /// Binding to AppSettings.ttsSpeechRate following centralized pattern
    private var speechRateBinding: Binding<Double> {
        Binding(
            get: { AppSettings.ttsSpeechRate },
            set: { AppSettings.ttsSpeechRate = $0 }
        )
    }

    /// Binding to AppSettings.ttsPitchMultiplier following centralized pattern
    private var pitchMultiplierBinding: Binding<Double> {
        Binding(
            get: { AppSettings.ttsPitchMultiplier },
            set: { AppSettings.ttsPitchMultiplier = $0 }
        )
    }

    /// Binding to AppSettings.ttsVoiceLanguage following centralized pattern
    private var voiceLanguageBinding: Binding<String> {
        Binding(
            get: { AppSettings.ttsVoiceLanguage },
            set: { AppSettings.ttsVoiceLanguage = $0 }
        )
    }

    /// Binding to AppSettings.ttsVoiceQuality following centralized pattern
    private var voiceQualityBinding: Binding<AppSettings.VoiceQuality> {
        Binding(
            get: { AppSettings.ttsVoiceQuality },
            set: { AppSettings.ttsVoiceQuality = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Text-to-Speech", isOn: self.isEnabledBinding)
                    .accessibilityLabel("Enable text-to-speech")

                Picker("Pronunciation Timing", selection: self.timingBinding) {
                    ForEach(AppSettings.TTSTiming.allCases, id: \.self) { timing in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timing.displayName)
                                .font(.body)
                            Text(timing.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(timing)
                    }
                }
                .accessibilityLabel("Pronunciation timing")
                .disabled(!AppSettings.ttsEnabled)
            } header: {
                Text("General")
            } footer: {
                Text("Text-to-Speech pronounces words during study sessions. Choose when to play pronunciation automatically.")
            }

            if AppSettings.ttsEnabled {
                Section {
                    Picker("Voice Accent", selection: self.voiceLanguageBinding) {
                        ForEach(AppSettings.supportedTTSAccents, id: \.code) { accent in
                            if self.availableVoices.contains(accent.code) {
                                Text(accent.name)
                                    .tag(accent.code)
                            }
                        }
                    }
                    .accessibilityLabel("Select voice accent")

                    Picker("Voice Quality", selection: self.voiceQualityBinding) {
                        ForEach(AppSettings.VoiceQuality.allCases, id: \.self) { quality in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(quality.displayName)
                                    Text(quality.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: quality.icon)
                            }
                            .tag(quality)
                        }
                    }
                    .accessibilityLabel("Select voice quality")

                    if let currentAccent = AppSettings.supportedTTSAccents.first(where: { $0.code == AppSettings.ttsVoiceLanguage }) {
                        Text("Selected: \(currentAccent.name) (\(AppSettings.ttsVoiceQuality.displayName))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !self.availableVoices.contains(AppSettings.ttsVoiceLanguage) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Selected voice not available on this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Premium and Enhanced voices require download in Settings → Accessibility → Spoken Content → Voices.")

                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                                .accessibilityLabel("Speech rate")
                            Spacer()
                            Text("\(Int(AppSettings.ttsSpeechRate * 100))%")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }

                        Slider(
                            value: self.speechRateBinding,
                            in: 0.0 ... 1.0,
                            step: 0.1
                        )
                        .accessibilityLabel("Speech rate")
                        .accessibilityValue("\(Int(AppSettings.ttsSpeechRate * 100)) percent")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                                .accessibilityLabel("Pitch")
                            Spacer()
                            Text("\(AppSettings.ttsPitchMultiplier, specifier: "%.1f")x")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }

                        Slider(
                            value: self.pitchMultiplierBinding,
                            in: 0.5 ... 2.0,
                            step: 0.1
                        )
                        .accessibilityLabel("Pitch multiplier")
                        .accessibilityValue("\(AppSettings.ttsPitchMultiplier, specifier: "%.1f") times normal")
                    }
                } header: {
                    Text("Speech Settings")
                } footer: {
                    Text("Adjust speech rate and pitch to your preference.")
                }

                Section {
                    Button {
                        self.testSpeech()
                    } label: {
                        if self.isTesting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Speaking...")
                            }
                        } else {
                            Text("Test Pronunciation")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Test pronunciation")
                    .disabled(self.isTesting)
                } header: {
                    Text("Test")
                }
            }
        }
        .navigationTitle("Text-to-Speech")
        .task {
            self.loadAvailableVoices()
            AppSettings.migrateTTSTimingIfNeeded()
        }
    }

    /// Load available voices for device capability detection
    private func loadAvailableVoices() {
        let allVoices = SpeechService.shared.availableVoices()
        self.availableVoices = Array(Set(allVoices.map(\.language))).sorted()

        // Auto-select first available accent if selected is not available
        if !self.availableVoices.contains(AppSettings.ttsVoiceLanguage) {
            if let firstAvailable = availableVoices.first {
                AppSettings.ttsVoiceLanguage = firstAvailable
            }
        }
    }

    /// Test speech with sample word
    func testSpeech() {
        self.isTesting = true
        SpeechService.shared.speak("Ephemeral")

        // Reset after estimated duration (roughly 0.1s per character)
        let estimatedDuration = 10 * 0.1 // "Ephemeral" is 10 characters
        Task {
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1000000000))
            await MainActor.run {
                self.isTesting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        TTSSettingsView()
    }
}
