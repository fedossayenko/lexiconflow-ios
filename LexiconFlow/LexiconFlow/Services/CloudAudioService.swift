//
//  CloudAudioService.swift
//  LexiconFlow
//
//  Cloud TTS service with hardware-aware audio routing
//
//  **Purpose**: Provides text-to-speech via Firebase Cloud Functions proxy,
//  with intelligent routing based on device capabilities.
//
//  **Architecture**:
//  - @MainActor isolation for thread-safe access
//  - Singleton pattern for shared instance
//  - Hardware detection (A14-A19)
//  - Local audio file caching
//
//  **Audio Routing**:
//  - A19/A18: On-device synthesis (AVSpeechSynthesizer .premium)
//  - A14-A17: Cloud TTS via proxy with local caching
//

import AVFoundation
import FirebaseFunctions
import Foundation
import OSLog

/// Cloud audio service using Firebase Cloud Functions
///
/// Provides text-to-speech via secure backend proxy with device-aware routing.
@MainActor
final class CloudAudioService {
    // MARK: - Singleton

    static let shared = CloudAudioService()

    private let logger = Logger(subsystem: "com.lexiconflow.audio", category: "CloudAudioService")
    private let functions = Functions.functions()

    // MARK: - DTOs

    /// TTS request to Cloud Functions
    struct TTSRequest: Codable, Sendable {
        let text: String
        let language: String
        let voiceQuality: String
        let deviceChip: String
        let userId: String
    }

    /// TTS response from Cloud Functions
    struct TTSResponse: Codable, Sendable {
        let audioData: String // Base64-encoded MP3/WAV
        let duration: Double // Seconds
        let format: String // "mp3" or "wav"
        let provider: String // "gemini", "zhipu", or "on-device"
        let cached: Bool
    }

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }

    // MARK: - Public API

    /// Speak text using device-aware routing
    ///
    /// - Parameters:
    ///   - text: Text to speak
    ///   - language: Language code (e.g., "en-US", "ru-RU")
    ///   - quality: Voice quality tier
    ///
    /// - Throws: CloudAudioError if synthesis fails
    ///
    /// **Routing Logic**:
    /// - A19/A18: Uses on-device synthesis (SpeechService)
    /// - A14-A17: Uses cloud TTS with local caching
    func speak(
        _ text: String,
        language: String = AppSettings.ttsVoiceLanguage,
        quality: AppSettings.VoiceQuality = AppSettings.ttsVoiceQuality
    ) async throws {
        self.logger.debug("TTS request", [
            "text": text.prefix(50),
            "language": language,
            "quality": quality.rawValue
        ])

        // Route based on hardware capability
        if HardwareCapability.supportsOnDeviceGenerativeAudio {
            self.logger.info("Using on-device generative audio", [
                "chip": HardwareCapability.Chip.current.name
            ])
            try await self.speakOnDevice(text, language: language, quality: quality)
        } else {
            self.logger.info("Using cloud TTS", [
                "chip": HardwareCapability.Chip.current.name
            ])
            try await self.speakFromCloud(text, language: language, quality: quality)
        }
    }

    // MARK: - On-Device TTS

    /// Use on-device text-to-speech
    private func speakOnDevice(
        _ text: String,
        language: String,
        quality _: AppSettings.VoiceQuality
    ) async throws {
        // Use existing SpeechService
        SpeechService.shared.speak(text, language: language)
    }

    // MARK: - Cloud TTS

    /// Use cloud text-to-speech with caching
    private func speakFromCloud(
        _ text: String,
        language: String,
        quality: AppSettings.VoiceQuality
    ) async throws {
        // 1. Check local cache
        let cacheKey = self.generateCacheKey(text: text, language: language, quality: quality)
        if let cachedAudioData = try? getCachedAudio(key: cacheKey) {
            self.logger.info("Playing cached audio", ["cacheKey": cacheKey])
            try await self.playAudio(base64Audio: cachedAudioData)
            return
        }

        // 2. Request from Cloud Functions
        let userId = try await ensureAuthenticated()

        let request = TTSRequest(
            text: text,
            language: language,
            voiceQuality: quality.rawValue,
            deviceChip: HardwareCapability.Chip.current.rawValue,
            userId: userId
        )

        let response: TTSResponse
        do {
            response = try await self.callCloudFunction("ttsV2", data: request)
        } catch {
            self.logger.error("Cloud TTS request failed", error)

            // Fallback to on-device
            self.logger.info("Falling back to on-device TTS")
            try await self.speakOnDevice(text, language: language, quality: quality)
            return
        }

        self.logger.info("Cloud TTS completed", [
            "provider": response.provider,
            "duration": "\(response.duration)s",
            "cached": response.cached
        ])

        // 3. Cache audio locally
        try self.cacheAudio(key: cacheKey, base64Audio: response.audioData)

        // 4. Play audio
        try await self.playAudio(base64Audio: response.audioData)
    }

    /// Play audio from Base64-encoded data
    private func playAudio(base64Audio: String) async throws {
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw CloudAudioError.invalidAudioData
        }

        // Write to temp file and play
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")

        try audioData.write(to: tempURL)

        self.logger.debug("Playing audio file", ["path": tempURL.lastPathComponent])

        // Play using AVAudioPlayer
        try await withCheckedThrowingContinuation { continuation in
            do {
                let player = try AVAudioPlayer(contentsOf: tempURL)
                player.delegate = AudioPlayerDelegate(continuation: continuation)
                player.play()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Caching

    /// Generate cache key for audio
    private func generateCacheKey(
        text: String,
        language: String,
        quality: AppSettings.VoiceQuality
    ) -> String {
        let input = "\(text)|\(language)|\(quality.rawValue)"
        return input.sha256()
    }

    /// Cache audio locally
    private func cacheAudio(key: String, base64Audio: String) throws {
        let cacheURL = self.getCacheURL(key: key)

        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw CloudAudioError.invalidAudioData
        }

        // Create cache directory if needed
        try? FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try audioData.write(to: cacheURL)

        self.logger.debug("Audio cached", ["key": key.prefix(16)])
    }

    /// Get cached audio
    private func getCachedAudio(key: String) throws -> String {
        let cacheURL = self.getCacheURL(key: key)

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            throw CloudAudioError.cacheMiss
        }

        let data = try Data(contentsOf: cacheURL)
        return data.base64EncodedString()
    }

    /// Get cache file URL
    private func getCacheURL(key: String) -> URL {
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("audio", isDirectory: true)

        return cacheDir.appendingPathComponent("\(key).mp3")
    }

    /// Clear all cached audio
    func clearAudioCache() {
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("audio", isDirectory: true)

        try? FileManager.default.removeItem(at: cacheDir)
        self.logger.info("Audio cache cleared")
    }

    // MARK: - Helpers

    /// Call a Cloud Function
    private func callCloudFunction<U: Codable>(
        _ functionName: String,
        data: some Codable
    ) async throws -> U {
        do {
            let result = try await functions.httpsCallable(functionName).call(data)

            guard let responseData = result.data as? [String: Any] else {
                throw CloudAudioError.invalidResponse
            }

            let responseJSON: Data
            if let response = responseData["response"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: response)
            {
                responseJSON = jsonData
            } else if let jsonData = try? JSONSerialization.data(withJSONObject: responseData) {
                responseJSON = jsonData
            } else {
                throw CloudAudioError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(U.self, from: responseJSON)
            return decoded
        } catch let error as CloudAudioError {
            throw error
        } catch {
            self.logger.error("Cloud Function call failed", error)
            throw CloudAudioError.functionFailed(error)
        }
    }

    /// Ensure user is authenticated
    private func ensureAuthenticated() async throws -> String {
        if let userId = FirebaseService.shared.currentUserId {
            return userId
        }

        self.logger.info("User not authenticated, signing in anonymously")
        return try await FirebaseService.shared.signInAnonymously()
    }
}

// MARK: - AVAudioPlayerDelegate

/// AVAudioPlayer delegate for async audio playback
private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let continuation: CheckedContinuation<Void, Error>

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
        super.init()
    }

    nonisolated func audioPlayerDidFinishPlaying(
        _: AVAudioPlayer,
        successfully flag: Bool
    ) {
        if flag {
            self.continuation.resume()
        } else {
            self.continuation.resume(throwing: CloudAudioError.playbackFailed)
        }
    }
}

// MARK: - Errors

/// Cloud audio service errors
enum CloudAudioError: LocalizedError {
    case notAuthenticated
    case functionFailed(Error)
    case invalidResponse
    case invalidAudioData
    case cacheMiss
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Not authenticated with Firebase"
        case let .functionFailed(error):
            "Cloud Function error: \(error.localizedDescription)"
        case .invalidResponse:
            "Invalid response from server"
        case .invalidAudioData:
            "Invalid audio data from server"
        case .cacheMiss:
            "Audio not found in cache"
        case .playbackFailed:
            "Audio playback failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            "Try signing out and signing back in"
        case .functionFailed:
            "Check your internet connection and try again"
        case .cacheMiss:
            "Audio will be downloaded from server"
        default:
            nil
        }
    }
}

// MARK: - String SHA256 Extension

extension String {
    /// Compute SHA-256 hash of string
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
