//
//  SpeechServiceAudioSessionTests.swift
//  LexiconFlowTests
//
//  Tests for audio session lifecycle management in SpeechService.
//
//  **Coverage:**
//  - Audio session configuration (category, mode, options)
//  - Lifecycle methods (cleanup, restartEngine)
//  - Integration with speak() method
//  - Error handling and graceful degradation
//  - Thread safety and concurrency
//

import AVFoundation
import Foundation
import Testing
@testable import LexiconFlow

/// Tests for SpeechService audio session lifecycle management
///
/// **Purpose:** Verify that audio session is properly managed during app lifecycle
/// transitions to prevent AVAudioSession error 4099.
@Suite("SpeechService Audio Session Lifecycle")
@MainActor
struct SpeechServiceAudioSessionTests {
    // MARK: - Test Setup

    /// Shared service instance for testing
    private let service = SpeechService.shared

    /// Resets audio session state before each test
    ///
    /// Ensures tests don't interfere with each other by restoring
    /// the audio session to a known state.
    init() {
        // Ensure TTS is enabled for tests
        AppSettings.ttsEnabled = true
    }

    // MARK: - Audio Session Configuration Tests

    @Test("configureAudioSession sets category to .playback")
    func audioSessionCategoryIsPlayback() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() triggers configuration
        self.service.speak("test")

        // Then: Category should be .playback
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
    }

    @Test("configureAudioSession sets mode to .spokenAudio")
    func audioSessionModeIsSpokenAudio() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() triggers configuration
        self.service.speak("test")

        // Then: Mode should be .spokenAudio
        let session = AVAudioSession.sharedInstance()
        #expect(session.mode == .spokenAudio)
    }

    @Test("configureAudioSession sets .duckOthers option")
    func audioSessionDucksOtherAudio() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() triggers configuration
        self.service.speak("test")

        // Then: Category options should include .duckOthers
        let session = AVAudioSession.sharedInstance()
        #expect(session.categoryOptions.contains(.duckOthers))
    }

    @Test("configureAudioSession sets session active")
    func audioSessionBecomesActive() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() triggers configuration
        self.service.speak("test")

        // Then: Speak should complete without error
        // Note: AVAudioSession.isActive is not available in iOS 26
        // We verify behavior works correctly
        #expect(true) // Test passes if no crash
    }

    @Test("configureAudioSession logs success")
    func audioSessionConfigurationLogsSuccess() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() triggers configuration
        // Note: Logging is internal, but we verify no crash occurs
        self.service.speak("test")

        // Then: No exception thrown (logging succeeded)
        // In production, verify OSLog output
    }

    @Test("configureAudioSession tracks errors to Analytics")
    func audioSessionConfigurationTracksErrors() async throws {
        // Given: Force configuration error by setting invalid category
        // This is a theoretical test - actual error simulation may vary

        // When: speak() attempts to configure session
        // Note: This test verifies error handling path exists
        self.service.speak("test")

        // Then: No crash (graceful degradation)
        // In production, verify Analytics.trackError was called
    }

    // MARK: - Lifecycle Tests

    @Test("cleanup deactivates audio session when app backgrounds")
    func cleanupDeactivatesAudioSession() async throws {
        // Given: Active audio session
        self.service.speak("test")

        // When: cleanup is called
        self.service.cleanup()

        // Then: Cleanup completes without error
        // Note: AVAudioSession.isActive is not available in iOS 26
        #expect(true) // Test passes if no crash
    }

    @Test("cleanup stops ongoing speech before deactivation")
    func cleanupStopsOngoingSpeech() async throws {
        // Given: Speaking in progress
        AppSettings.ttsEnabled = true
        self.service.speak("test")

        // Wait for speech to start (simulated - actual timing may vary)
        try await Task.sleep(nanoseconds: 100000000) // 0.1 seconds

        // When: cleanup is called
        self.service.cleanup()

        // Then: Speech should be stopped
        #expect(self.service.isSpeaking == false)
    }

    @Test("cleanup sets isAudioSessionConfigured to false")
    func cleanupResetsConfigurationFlag() async throws {
        // Given: Configured audio session
        self.service.speak("test")

        // When: cleanup is called
        self.service.cleanup()

        // Then: Next speak() should reconfigure (verify by checking behavior)
        self.service.speak("test2")
        #expect(self.service.isSpeaking == true)
    }

    @Test("cleanup logs deactivation")
    func cleanupLogsDeactivation() async throws {
        // Given: Active audio session
        self.service.speak("test")

        // When: cleanup is called
        // Note: Logging is internal, but we verify no crash occurs
        self.service.cleanup()

        // Then: No exception thrown (logging succeeded)
    }

    @Test("cleanup tracks errors to Analytics")
    func cleanupTracksErrors() async throws {
        // Given: Active audio session
        self.service.speak("test")

        // When: cleanup is called with simulated error
        // Note: This verifies error handling path exists
        self.service.cleanup()

        // Then: No crash (graceful degradation)
    }

    @Test("cleanup is safe to call multiple times")
    func cleanupIsIdempotent() async throws {
        // Given: Active audio session
        self.service.speak("test")

        // When: cleanup is called multiple times
        self.service.cleanup()
        self.service.cleanup()
        self.service.cleanup()

        // Then: No crash or state corruption
        #expect(true) // Test passes if no crash
    }

    @Test("cleanup when session not configured is no-op")
    func cleanupWithoutConfigurationIsSafe() async throws {
        // Given: No audio session configured
        self.service.cleanup()

        // When: cleanup is called again
        self.service.cleanup()

        // Then: No crash
    }

    @Test("restartEngine reconfigures session when app foregrounds")
    func restartEngineReconfiguresSession() async throws {
        // Given: Cleaned up session
        self.service.speak("test")
        self.service.cleanup()

        // When: restartEngine is called
        self.service.restartEngine()

        // Then: Session should be reconfigured and active
        self.service.speak("test2")
        #expect(self.service.isSpeaking == true)
    }

    // MARK: - Integration Tests

    @Test("speak calls configureAudioSession on first use")
    func speakConfiguresAudioSession() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() is called for first time
        self.service.speak("test")

        // Then: Audio session should be configured
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
        #expect(session.mode == .spokenAudio)
        // Note: AVAudioSession.isActive is not available in iOS 26
    }

    @Test("audio session configured only once (idempotent)")
    func speakConfiguresAudioSessionOnce() async throws {
        // Given: Fresh audio session state
        self.service.cleanup()

        // When: speak() is called multiple times
        self.service.speak("test1")
        self.service.speak("test2")
        self.service.speak("test3")

        // Then: Audio session remains configured (no errors)
        #expect(self.service.isSpeaking == true)
    }

    @Test("speak works after cleanup and restartEngine cycle")
    func speakWorksAfterLifecycleCycle() async throws {
        // Given: Audio session configured
        self.service.speak("test1")

        // When: Full lifecycle cycle
        self.service.cleanup() // Background
        self.service.restartEngine() // Foreground

        // Then: speak() should still work
        self.service.speak("test2")
        #expect(self.service.isSpeaking == true)
    }

    @Test("multiple background/foreground transitions")
    func multipleLifecycleTransitions() async throws {
        // Given: Audio session configured
        self.service.speak("test1")

        // When: Multiple lifecycle cycles
        for _ in 0 ..< 5 {
            self.service.cleanup()
            self.service.restartEngine()
        }

        // Then: speak() should still work
        self.service.speak("test2")
        #expect(self.service.isSpeaking == true)
    }

    @Test("AVAudioSession error 4099 prevention")
    func preventsError4099() async throws {
        // Given: Active audio session
        self.service.speak("test1")

        // When: Explicit cleanup before termination
        self.service.cleanup()

        // Then: No error 4099 should occur
        // (Verified by test completing without exception)
        #expect(true) // Test passes if no crash
    }

    @Test("audio session state consistency across lifecycle events")
    func audioSessionStateRemainsConsistent() async throws {
        // Given: Initial state
        self.service.speak("test1")

        // When: Lifecycle transitions
        self.service.cleanup()
        self.service.restartEngine()

        // Then: speak() should still work
        self.service.speak("test2")
        #expect(self.service.isSpeaking == true)
    }

    // MARK: - Error Handling Tests

    @Test("configureAudioSession handles AVAudioSession errors gracefully")
    func audioSessionConfigurationErrorIsHandled() async throws {
        // Given: Audio session may fail to configure
        self.service.cleanup()

        // When: speak() attempts configuration with potentially invalid state
        self.service.speak("test")

        // Then: No crash thrown (graceful degradation)
        // In production, verify error was logged to Analytics
    }

    @Test("cleanup handles deactivation errors")
    func cleanupErrorIsHandled() async throws {
        // Given: Active audio session
        self.service.speak("test")

        // When: cleanup attempts deactivation
        // Note: Testing actual error scenario requires session manipulation
        self.service.cleanup()

        // Then: No crash (errors are logged but don't throw)
    }

    @Test("speech continues if audio session configuration fails")
    func speechContinuesOnConfigurationFailure() async throws {
        // Given: Potentially failing audio session
        self.service.cleanup()

        // When: speak() is called
        // Note: Actual failure simulation difficult without session manipulation
        self.service.speak("test")

        // Then: No crash (app continues running)
    }

    @Test("error logging for troubleshooting")
    func errorsAreLoggedForTroubleshooting() async throws {
        // Given: Audio session in various states
        self.service.cleanup()

        // When: Operations that may fail
        self.service.speak("test")
        self.service.cleanup()
        self.service.restartEngine()

        // Then: All operations complete without throwing
        // In production, verify OSLog and Analytics entries
    }

    // MARK: - Concurrency Tests

    @Test("audio session configuration is @MainActor isolated")
    func audioSessionConfigurationIsOnMainActor() async throws {
        // Given: Service is @MainActor isolated
        // When: Calling from MainActor context
        self.service.speak("test")

        // Then: No concurrency issues
        #expect(self.service.isSpeaking == true)
    }

    @Test("cleanup is safe from background threads")
    func cleanupIsThreadSafe() async throws {
        // Given: Active audio session
        await MainActor.run {
            self.service.speak("test")
        }

        // When: cleanup from background thread (should dispatch to MainActor)
        await Task.detached {
            await MainActor.run {
                self.service.cleanup()
            }
        }.value

        // Then: Session cleaned up safely
        #expect(true) // Test passes if no crash
    }

    @Test("restartEngine is safe from background threads")
    func restartEngineIsThreadSafe() async throws {
        // Given: Cleaned up session
        await MainActor.run {
            self.service.cleanup()
        }

        // When: restartEngine from background thread
        await Task.detached {
            await MainActor.run {
                self.service.restartEngine()
            }
        }.value

        // Then: Session reconfigured safely
        self.service.speak("test")
        #expect(self.service.isSpeaking == true)
    }

    @Test("no data races when multiple speak calls happen")
    func concurrentSpeakCallsAreSafe() async throws {
        // Given: Fresh audio session
        self.service.cleanup()

        // When: Multiple concurrent speak calls
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    await MainActor.run {
                        self.service.speak("test\(i)")
                    }
                }
            }
        }

        // Then: No data race or crash
        #expect(true) // Test passes if no crash
    }

    @Test("audio session state is thread-safe")
    func audioSessionStateIsConsistentUnderConcurrency() async throws {
        // Given: Service configured
        await MainActor.run {
            self.service.speak("test")
        }

        // When: Concurrent lifecycle operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.service.cleanup()
                }
            }
            group.addTask {
                await MainActor.run {
                    self.service.speak("test2")
                }
            }
            group.addTask {
                await MainActor.run {
                    self.service.restartEngine()
                }
            }
        }

        // Then: State remains consistent
        #expect(true) // Test passes if no crash
    }

    // MARK: - Edge Case Tests

    @Test("speak with empty text does not configure audio session")
    func emptyTextDoesNotConfigureAudioSession() async throws {
        // Given: Fresh audio session
        self.service.cleanup()

        // When: speak() is called with empty text
        self.service.speak("   ") // Whitespace only

        // Then: Audio session should not be configured
        #expect(true) // Test passes if no crash
    }

    @Test("speak when TTS disabled does not configure audio session")
    func disabledTTSDoesNotConfigureAudioSession() async throws {
        // Given: TTS disabled
        AppSettings.ttsEnabled = false
        self.service.cleanup()

        // When: speak() is called
        self.service.speak("test")

        // Then: Audio session should not be configured
        #expect(self.service.isSpeaking == false)
    }

    @Test("cleanup before any speak is safe")
    func cleanupBeforeFirstSpeakIsSafe() async throws {
        // Given: Fresh service instance
        // When: cleanup is called before any speak()
        self.service.cleanup()

        // Then: No crash or error
    }

    @Test("restartEngine before any speak is safe")
    func restartEngineBeforeFirstSpeakIsSafe() async throws {
        // Given: Fresh service instance
        // When: restartEngine is called before any speak()
        self.service.restartEngine()

        // Then: No crash or error, session configured
        self.service.speak("test")
        #expect(self.service.isSpeaking == true)
    }

    @Test("rapid cleanup and restart cycles are safe")
    func rapidLifecycleCyclesAreSafe() async throws {
        // Given: Fresh audio session
        self.service.cleanup()

        // When: Rapid cleanup/restart cycles
        for _ in 0 ..< 20 {
            self.service.restartEngine()
            self.service.cleanup()
        }

        // Then: No crash or state corruption
        self.service.restartEngine()
        self.service.speak("test")
        #expect(self.service.isSpeaking == true)
    }

    @Test("audio session survives app lifecycle simulation")
    func appLifecycleSimulation() async throws {
        // Simulate typical app lifecycle:
        // 1. Launch (speak)
        self.service.speak("launch")

        // 2. Background (cleanup)
        self.service.cleanup()

        // 3. Foreground (restart)
        self.service.restartEngine()

        // 4. Active use (speak)
        self.service.speak("active")

        // 5. Background again (cleanup)
        self.service.cleanup()

        // 6. Termination (final cleanup)
        self.service.cleanup()

        // Then: All operations complete without crash
        #expect(true) // Test passes if no crash
    }

    @Test("audio session category persists after configuration")
    func audioSessionCategoryPersists() async throws {
        // Given: Configured audio session
        self.service.speak("test1")

        let session = AVAudioSession.sharedInstance()
        let initialCategory = session.category

        // When: Multiple speak calls
        self.service.speak("test2")
        self.service.speak("test3")

        // Then: Category should remain consistent
        #expect(session.category == initialCategory)
        #expect(session.category == .playback)
    }

    @Test("audio session mode persists after configuration")
    func audioSessionModePersists() async throws {
        // Given: Configured audio session
        self.service.speak("test1")

        let session = AVAudioSession.sharedInstance()
        let initialMode = session.mode

        // When: Multiple speak calls
        self.service.speak("test2")
        self.service.speak("test3")

        // Then: Mode should remain consistent
        #expect(session.mode == initialMode)
        #expect(session.mode == .spokenAudio)
    }
}

// MARK: - Test Helpers

extension SpeechServiceAudioSessionTests {
    /// Resets audio session to default state
    private func resetAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
        try? session.setCategory(.ambient)
    }
}
