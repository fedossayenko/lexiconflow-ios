//
//  StreakChimeService.swift
//  LexiconFlow
//
//  Harmonic chime audio playback for streak milestones
//

import AVFoundation
import OSLog

/// Service for playing celebratory harmonic chimes at study streak milestones
///
/// **Milestones:** 3, 7, 14, 30, 60, 90, 100, 365 days
/// **Audio Format:** WAV files bundled in app or system sounds as fallback
@MainActor
final class StreakChimeService {
    /// Shared singleton instance
    static let shared = StreakChimeService()

    /// Logger for streak chime operations
    private let logger = Logger(subsystem: "com.lexiconflow.streakchime", category: "StreakChimeService")

    /// Audio player for chime playback
    private var audioPlayer: AVAudioPlayer?

    /// Milestone days that trigger chimes
    private let milestoneDays: Set<Int> = [3, 7, 14, 30, 60, 90, 100, 365]

    private init() {}

    /// Play streak chime if the streak is a milestone
    ///
    /// - Parameter streak: Current study streak in days
    func playStreakChime(for streak: Int) async {
        guard AppSettings.streakChimesEnabled else {
            self.logger.debug("Streak chimes disabled, skipping playback for streak: \(streak)")
            return
        }

        guard self.milestoneDays.contains(streak) else {
            self.logger.debug("Streak \(streak) is not a milestone, skipping chime")
            return
        }

        self.logger.info("Playing streak chime for \(streak)-day milestone")
        await self.playHarmonicChime(streak: streak)
    }

    /// Play harmonic chime for specific milestone
    ///
    /// - Parameter streak: The milestone day number
    private func playHarmonicChime(streak: Int) async {
        // Try to load milestone-specific sound file
        let soundFileName = "streak_chime_\(streak)"
        let soundExtension = "wav"

        guard let soundURL = Bundle.main.url(forResource: soundFileName, withExtension: soundExtension) else {
            self.logger.warning("Sound file not found: \(soundFileName).\(soundExtension), using system sound fallback")
            // Fallback to system sound
            AudioServicesPlaySystemSound(1020) // Sherlock sound (celebratory)
            return
        }

        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.play()
            self.logger.info("Playing chime sound: \(soundFileName).\(soundExtension)")
        } catch {
            self.logger.error("Failed to play streak chime: \(error.localizedDescription)")
            // Fallback to system sound if audio player fails
            AudioServicesPlaySystemSound(1020)
        }
    }
}
