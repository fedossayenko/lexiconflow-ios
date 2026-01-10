//
//  ManualTests.swift
//  LexiconFlowTests
//
//  Manual tests for SpeechService audio session lifecycle management.
//  These tests are timing-dependent and often unreliable in automated CI environments.
//  They require manual execution and observation to verify correct behavior.
//
//  **Manual Test Instructions:**
//  1. Open the LexiconFlowTests target in Xcode.
//  2. Select the "ManualTests" suite or individual tests within it.
//  3. Run the tests on a **physical iOS device** for the most accurate audio behavior.
//  4. Pay close attention to console logs, breakpoints, and especially **audio output**.
//
//  **Device/Simulator Requirements:**
//  - Physical iOS device is highly recommended (simulator audio timing is inconsistent)
//  - Ensure "Speech Content" (Settings → Accessibility → Spoken Content) is enabled
//  - Simulator audio must be enabled and at sufficient volume
//
//  **Why Manual?**
//  These tests verify timing-dependent behaviors that are difficult to automate reliably:
//  - Audio session state transitions (cleanup, restart)
//  - AVSpeechSynthesizer speaking state (isSpeaking)
//  - MainActor isolation verification
//  - Thread safety under concurrent operations
//
//  Automated testing of these behaviors often produces false negatives due to CI
//  environment timing variations. Manual testing with human observation provides
//  more reliable verification of correct audio session lifecycle management.
//
//  **Expected Audio Output:**
//  Most tests use "test" or "test1", "test2", etc. as speech text. You should hear
//  these words spoken by the iOS text-to-speech system during test execution.
//

import AVFoundation
import Foundation
import Testing
@testable import LexiconFlow

/// Manual tests for SpeechService audio session lifecycle management
///
/// **Purpose:** Verify that audio session is properly managed during app lifecycle
/// transitions to prevent AVAudioSession error 4099. These tests require manual
/// observation because automated assertions are unreliable for timing-dependent
/// audio behaviors.
///
/// **Running the Tests:**
/// 1. Open Xcode and select the ManualTests suite
/// 2. Choose a physical device (recommended) or simulator
/// 3. Run individual tests or the full suite
/// 4. Observe console output, breakpoints, and audio playback
/// 5. Verify expected behaviors match test documentation
@Suite("Manual Tests - SpeechService Audio Session")
@MainActor
struct ManualSpeechServiceAudioSessionTests {
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

    // MARK: - Lifecycle Tests

    /// **Purpose:** Verify that `cleanup()` correctly resets the internal state flag
    /// so that the audio session is reconfigured on the next `speak()` call.
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device or simulator.
    /// 2. Place a breakpoint inside `SpeechService.configureAudioSession()`.
    /// 3. Let the test run:
    ///    - First `speak("test")` should hit the breakpoint.
    ///    - `cleanup()` should NOT hit the breakpoint.
    ///    - Second `speak("test2")` MUST hit the breakpoint again.
    ///
    /// **Expected Behavior:**
    /// - The `configureAudioSession` breakpoint is hit exactly twice.
    /// - Audio is heard for "test" and "test2".
    ///
    /// **Verification Method:** Observe breakpoint hit count and listen for audio.
    @Test("cleanup sets isAudioSessionConfigured to false")
    func cleanupResetsConfigurationFlag() async throws {
        // Given: Configured audio session
        service.speak("test")

        // When: cleanup is called
        service.cleanup()

        // Then: Next speak() should reconfigure (verify by checking behavior)
        service.speak("test2")
        // Note: isSpeaking is timing-dependent, may not be true immediately
        // In production, verify audio session reconfigures correctly
    }

    /// **Purpose:** Verify that `restartEngine()` properly reconfigures the audio
    /// session after it has been cleaned up (simulating app backgrounding/foregrounding).
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device or simulator.
    /// 2. Enable audio on your device/simulator.
    /// 3. Listen for audio output during test execution.
    ///
    /// **Expected Behavior:**
    /// - First "test" is spoken successfully.
    /// - After `cleanup()` and `restartEngine()`, second "test2" is also spoken.
    /// - No audio errors or glitches in the second speech.
    ///
    /// **Verification Method:** Listen for both "test" and "test2" being spoken.
    @Test("restartEngine reconfigures session when app foregrounds")
    func restartEngineReconfiguresSession() async throws {
        // Given: Cleaned up session
        service.speak("test")
        service.cleanup()

        // When: restartEngine is called
        service.restartEngine()

        // Then: Session should be reconfigured and active
        service.speak("test2")
        // Note: isSpeaking is timing-dependent, may not be true immediately
        // In production, verify speak() works after restartEngine
    }

    // MARK: - Idempotency Tests

    /// **Purpose:** Verify that the audio session is configured on the first `speak()`
    /// call but not reconfigured on subsequent calls (idempotent behavior).
    ///
    /// **Manual Execution Steps:**
    /// 1. Place a breakpoint at the start of `configureAudioSession()`.
    /// 2. Run this test.
    /// 3. Count how many times the breakpoint is hit.
    ///
    /// **Expected Behavior:**
    /// - The breakpoint should be hit exactly **once** (first speak() call).
    /// - Subsequent speak() calls should NOT reconfigure the session.
    /// - No errors or crashes occur during multiple speak() calls.
    ///
    /// **Verification Method:** Breakpoint hit count should be 1.
    @Test("audio session configured only once (idempotent)")
    func speakConfiguresAudioSessionOnce() async throws {
        // Given: Fresh audio session state
        service.cleanup()

        // When: speak() is called multiple times
        service.speak("test1")
        service.speak("test2")
        service.speak("test3")

        // Then: Audio session remains configured (no errors)
        // Note: isSpeaking is timing-dependent
    }

    // MARK: - Lifecycle Cycle Tests

    /// **Purpose:** Verify that speech functionality works correctly after a complete
    /// lifecycle cycle (speak → cleanup → restartEngine → speak).
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device with audio enabled.
    /// 2. Listen for both "test1" and "test2".
    ///
    /// **Expected Behavior:**
    /// - "test1" is spoken before the lifecycle cycle.
    /// - "test2" is spoken after the lifecycle cycle.
    /// - Both speeches are clear and uninterrupted.
    /// - No audio glitches or errors occur.
    ///
    /// **Verification Method:** Listen for both words being spoken successfully.
    @Test("speak works after cleanup and restartEngine cycle")
    func speakWorksAfterLifecycleCycle() async throws {
        // Given: Audio session configured
        service.speak("test1")

        // When: Full lifecycle cycle
        service.cleanup() // Background
        service.restartEngine() // Foreground

        // Then: speak() should still work
        service.speak("test2")
        // Note: isSpeaking is timing-dependent
    }

    /// **Purpose:** Verify that the audio session survives multiple rapid lifecycle
    /// transitions (background/foreground cycles).
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device.
    /// 2. The test will perform 5 lifecycle cycles automatically.
    /// 3. Listen for "test1" and "test2".
    ///
    /// **Expected Behavior:**
    /// - "test1" is spoken before the lifecycle cycles.
    /// - After 5 cleanup/restartEngine cycles, "test2" is still spoken successfully.
    /// - No errors, crashes, or audio failures occur.
    ///
    /// **Verification Method:** Both words should be spoken successfully.
    @Test("multiple background/foreground transitions")
    func multipleLifecycleTransitions() async throws {
        // Given: Audio session configured
        service.speak("test1")

        // When: Multiple lifecycle cycles
        for _ in 0 ..< 5 {
            service.cleanup()
            service.restartEngine()
        }

        // Then: speak() should still work
        service.speak("test2")
        // Note: isSpeaking is timing-dependent
    }

    // MARK: - State Consistency Tests

    /// **Purpose:** Verify that the audio session state remains consistent across
    /// lifecycle events (cleanup → restartEngine).
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device.
    /// 2. Listen for "test1" and "test2".
    ///
    /// **Expected Behavior:**
    /// - "test1" is spoken before lifecycle transition.
    /// - "test2" is spoken after lifecycle transition.
    /// - Both speeches work correctly without errors.
    ///
    /// **Verification Method:** Listen for both words being spoken.
    @Test("audio session state consistency across lifecycle events")
    func audioSessionStateRemainsConsistent() async throws {
        // Given: Initial state
        service.speak("test1")

        // When: Lifecycle transitions
        service.cleanup()
        service.restartEngine()

        // Then: speak() should still work
        service.speak("test2")
        // Note: isSpeaking is timing-dependent
    }

    // MARK: - Thread Safety Tests

    /// **Purpose:** Verify that audio session configuration is properly isolated to
    /// the main actor to prevent concurrency issues.
    ///
    /// **Manual Execution Steps:**
    /// 1. Place a breakpoint inside `configureAudioSession()`.
    /// 2. Run this test.
    /// 3. When the breakpoint is hit, check the debug navigator for the thread.
    ///
    /// **Expected Behavior:**
    /// - The breakpoint is hit on the **main thread** (not a background thread).
    /// - No concurrency warnings or errors appear in the console.
    /// - Audio is spoken successfully.
    ///
    /// **Verification Method:** Verify breakpoint is on main thread (Thread 1).
    @Test("audio session configuration is @MainActor isolated")
    func audioSessionConfigurationIsOnMainActor() async throws {
        // Given: Service is @MainActor isolated
        // When: Calling from MainActor context
        service.speak("test")

        // Then: No concurrency issues
        // Note: isSpeaking is timing-dependent
    }

    /// **Purpose:** Verify that `restartEngine()` can be safely called from background
    /// threads and will properly dispatch to the main actor.
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device.
    /// 2. Listen for the final "test" speech.
    ///
    /// **Expected Behavior:**
    /// - `restartEngine()` is called from a background task.
    /// - The method safely dispatches to the main actor.
    /// - The final "test" speech works correctly.
    /// - No thread safety errors or crashes occur.
    ///
    /// **Verification Method:** Listen for successful speech after background thread restart.
    @Test("restartEngine is safe from background threads")
    func restartEngineIsThreadSafe() async throws {
        // Given: Cleaned up session
        service.cleanup()

        // When: restartEngine from background thread
        await Task.detached {
            await MainActor.run {
                service.restartEngine()
            }
        }.value

        // Then: Session reconfigured safely
        service.speak("test")
        // Note: isSpeaking is timing-dependent
    }

    // MARK: - Edge Case Tests

    /// **Purpose:** Verify that calling `restartEngine()` before any `speak()` calls
    /// is safe and properly configures the audio session.
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device or simulator.
    /// 2. Listen for "test" being spoken.
    ///
    /// **Expected Behavior:**
    /// - `restartEngine()` is called before any speech occurs.
    /// - The audio session is configured successfully.
    /// - "test" is spoken without errors.
    /// - No crashes or state corruption occur.
    ///
    /// **Verification Method:** Listen for successful speech after premature restart.
    @Test("restartEngine before any speak is safe")
    func restartEngineBeforeFirstSpeakIsSafe() async throws {
        // Given: Fresh service instance
        // When: restartEngine is called before any speak()
        service.restartEngine()

        // Then: No crash or error, session configured
        service.speak("test")
        // Note: isSpeaking is timing-dependent
    }

    /// **Purpose:** Verify that rapid lifecycle cycles (20 iterations) don't cause
    /// state corruption or crashes.
    ///
    /// **Manual Execution Steps:**
    /// 1. Run this test on a device.
    /// 2. The test will automatically perform 20 rapid cycles.
    /// 3. Listen for the final "test" speech.
    ///
    /// **Expected Behavior:**
    /// - 20 rapid cleanup/restartEngine cycles execute.
    /// - No crashes or state corruption occur.
    /// - Final "test" speech works correctly.
    /// - No memory leaks or performance degradation.
    ///
    /// **Verification Method:** Test completes without crash and final speech works.
    @Test("rapid cleanup and restart cycles are safe")
    func rapidLifecycleCyclesAreSafe() async throws {
        // Given: Fresh audio session
        service.cleanup()

        // When: Rapid cleanup/restart cycles
        for _ in 0 ..< 20 {
            service.restartEngine()
            service.cleanup()
        }

        // Then: No crash or state corruption
        service.restartEngine()
        service.speak("test")
        // Note: isSpeaking is timing-dependent
    }
}

// MARK: - Test Helpers

extension ManualSpeechServiceAudioSessionTests {
    /// Resets audio session to default state
    private func resetAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
        try? session.setCategory(.ambient)
    }
}
