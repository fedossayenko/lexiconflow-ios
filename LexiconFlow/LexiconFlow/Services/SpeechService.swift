//
//  SpeechService.swift
//  LexiconFlow
//
//  Text-to-speech service for word pronunciation
//

import AVFoundation
import Foundation
import OSLog

/// Text-to-speech service for word and sentence pronunciation
///
/// **Design Philosophy:**
/// - Simplicity: On-demand speech synthesis with AVSpeechSynthesizer
/// - Flexibility: Real-time voice, rate, and pitch adjustments
/// - Performance: No audio file storage needed (dynamic synthesis)
/// - Privacy: 100% on-device, no network required
///
/// **Usage:**
/// ```swift
/// // Speak a word
/// SpeechService.shared.speak("Ephemeral")
///
/// // Stop speaking
/// SpeechService.shared.stop()
///
/// // Get available voices for a language
/// let voices = SpeechService.shared.availableVoices(for: "en-US")
/// ```
@MainActor
class SpeechService {
    // MARK: - Singleton

    static let shared = SpeechService()

    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.lexiconflow.speech", category: "SpeechService")

    /// Speech synthesizer for text-to-speech
    private let synthesizer = AVSpeechSynthesizer()

    /// Audio session for playback configuration
    private let audioSession = AVAudioSession.sharedInstance()

    /// Whether audio session is configured
    private var isAudioSessionConfigured = false

    /// Detects if running in CI environment by checking for marker file
    private var isRunningInCI: Bool {
        FileManager.default.fileExists(atPath: "/tmp/lexiconflow-ci-running")
    }

    // MARK: - Initialization

    private init() {
        self.logger.info("SpeechService initialized")
    }

    // MARK: - Public API

    /// Speak text with current settings
    ///
    /// **Parameters:**
    ///   - text: The text to speak
    ///
    /// **Behavior:**
    ///   - Checks `AppSettings.ttsEnabled` before speaking
    ///   - Uses configured voice, rate, and pitch from AppSettings
    ///   - Stops any ongoing speech before starting new speech
    ///   - Configures audio session on first call
    func speak(_ text: String) {
        // Check if TTS is enabled
        guard AppSettings.ttsEnabled else {
            self.logger.debug("TTS disabled, skipping speech")
            return
        }

        // Validate input
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            self.logger.warning("Attempted to speak empty text")
            return
        }

        // Configure audio session if needed
        if !self.isAudioSessionConfigured {
            self.configureAudioSession()
        }

        // Stop any ongoing speech
        if self.synthesizer.isSpeaking {
            self.synthesizer.stopSpeaking(at: .immediate)
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: trimmedText)

        // Configure voice
        if let voice = voiceForLanguage(AppSettings.ttsVoiceLanguage) {
            utterance.voice = voice
        } else {
            // Fallback to default voice
            self.logger.warning("Voice not found for '\(AppSettings.ttsVoiceLanguage)', using default")
            utterance.voice = AVSpeechSynthesisVoice(language: AppSettings.ttsVoiceLanguage)
        }

        // Configure rate (0.0 to 1.0, where 0.5 is default)
        utterance.rate = Float(AppSettings.ttsSpeechRate * 0.5) // Map 0.0-1.0 to AVSpeechUtteranceDefaultSpeechRate

        // Configure pitch multiplier (0.5 to 2.0, where 1.0 is normal)
        utterance.pitchMultiplier = Float(AppSettings.ttsPitchMultiplier)

        // Speak
        self.synthesizer.speak(utterance)
        self.logger.info("Speaking: '\(trimmedText)'")
    }

    /// Stop speaking immediately
    func stop() {
        guard self.synthesizer.isSpeaking else { return }
        self.synthesizer.stopSpeaking(at: .immediate)
        self.logger.debug("Stopped speaking")
    }

    /// Pause speech (can be resumed with `continueSpeaking`)
    func pause() {
        guard self.synthesizer.isSpeaking, !self.synthesizer.isPaused else { return }
        self.synthesizer.pauseSpeaking(at: .immediate)
        self.logger.debug("Paused speaking")
    }

    /// Continue paused speech
    func continueSpeaking() {
        guard self.synthesizer.isPaused else { return }
        self.synthesizer.continueSpeaking()
        self.logger.debug("Continued speaking")
    }

    /// Get available voices for a specific language
    ///
    /// **Parameters:**
    ///   - languageCode: Optional BCP 47 language code (e.g., "en-US", "en-GB")
    ///                  If nil, returns all available voices
    ///
    /// **Returns:** Array of available voices matching the language code
    func availableVoices(for languageCode: String? = nil) -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        if let languageCode {
            return allVoices.filter { $0.language == languageCode }
        } else {
            return allVoices
        }
    }

    /// Check if speech is currently in progress
    var isSpeaking: Bool {
        self.synthesizer.isSpeaking
    }

    /// Check if speech is currently paused
    var isPaused: Bool {
        self.synthesizer.isPaused
    }

    // MARK: - Lifecycle Management

    /// Deactivates the audio session when app backgrounds
    ///
    /// Call this method when the app enters the background to release audio resources.
    /// This prevents AVAudioSession error 4099 during iOS shutdown sequences.
    func cleanup() {
        guard self.isAudioSessionConfigured else { return }

        // Stop any ongoing speech before deactivating
        if self.synthesizer.isSpeaking {
            self.synthesizer.stopSpeaking(at: .immediate)
        }

        do {
            try self.audioSession.setActive(false)
            self.isAudioSessionConfigured = false
            self.logger.info("Audio session deactivated")
        } catch {
            self.logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
            Analytics.trackError("speech_audio_session_deactivate_failed", error: error)
        }
    }

    /// Reactivates the audio session when app returns to foreground
    ///
    /// Call this method when the app returns from background to restore audio functionality.
    func restartEngine() {
        if !self.isAudioSessionConfigured {
            self.configureAudioSession()
        }
    }

    // MARK: - Private Helpers

    /// Get voice for specific language code based on user's quality preference
    ///
    /// **Parameters:**
    ///   - languageCode: BCP 47 language code (e.g., "en-US", "en-GB")
    ///
    /// **Returns:** Voice matching the language code and quality preference, with fallback
    ///
    /// **Quality Fallback Chain:**
    /// - If preferred quality not available, falls back to next lower quality
    /// - Premium → Enhanced → Default
    private func voiceForLanguage(_ languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = self.availableVoices(for: languageCode)
        let preferredQuality = AppSettings.ttsVoiceQuality

        // Filter by quality based on user preference
        switch preferredQuality {
        case .premium:
            // Try premium first, then enhanced, then default
            if let premiumVoice = voices.first(where: { $0.quality == .premium }) {
                return premiumVoice
            }
            if let enhancedVoice = voices.first(where: { $0.quality == .enhanced }) {
                self.logger.info("Premium voice not available, using enhanced")
                return enhancedVoice
            }
        case .enhanced:
            // Try enhanced first, then default
            if let enhancedVoice = voices.first(where: { $0.quality == .enhanced }) {
                return enhancedVoice
            }
        case .default:
            // Use default quality only
            if let defaultVoice = voices.first(where: { $0.quality == .default }) {
                return defaultVoice
            }
        }

        // Fallback to any available voice
        return voices.first
    }

    /// Configure audio session for speech playback
    ///
    /// **Configuration:**
    ///   - Category: `.playback`
    ///   - Mode: `.spokenAudio`
    ///   - Options: `.duckOthers` (lower other audio volume)
    ///
    /// **Error Handling:**
    ///   - Logs errors to Analytics
    ///   - Does not throw (graceful degradation)
    private func configureAudioSession() {
        // Skip AVAudioSession configuration in CI (no audio hardware available)
        guard !self.isRunningInCI else {
            self.logger.info("Skipping AVAudioSession configuration in CI environment")
            self.isAudioSessionConfigured = true // Mark as configured to prevent retries
            return
        }

        do {
            try self.audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: .duckOthers
            )
            try self.audioSession.setActive(true)
            self.isAudioSessionConfigured = true
            self.logger.info("Audio session configured successfully")
        } catch {
            self.logger.error("Failed to configure audio session: \(error.localizedDescription)")
            Analytics.trackError("speech_audio_session_failed", error: error)
        }
    }
}
