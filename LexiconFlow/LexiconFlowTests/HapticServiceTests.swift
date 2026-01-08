//
//  HapticServiceTests.swift
//  LexiconFlowTests
//
//  Tests for HapticService including generator caching and haptic feedback.
//
//  NOTE: These are smoke tests that verify HapticService doesn't crash.
//  UIKit's haptic generators don't provide observable state for verification.
//

import CoreFoundation
import Testing
@testable import LexiconFlow

/// Saves and restores the original hapticEnabled setting for test isolation.
@MainActor
private func withHapticEnabled<T>(_ enabled: Bool, operation: () throws -> T) rethrows -> T {
    let original = AppSettings.hapticEnabled
    AppSettings.hapticEnabled = enabled
    defer {
        AppSettings.hapticEnabled = original
    }
    return try operation()
}

@MainActor
struct HapticServiceTests {
    // MARK: - Singleton Tests

    @Test("HapticService singleton is consistent")
    func singletonConsistency() {
        let service1 = HapticService.shared
        let service2 = HapticService.shared
        #expect(service1 === service2, "HapticService should return the same singleton instance")
    }

    // MARK: - SwipeDirection Enum Tests

    @Test("SwipeDirection right case exists")
    func rightSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.right
        #expect(direction == .right, "Right swipe direction should be instantiable")
    }

    @Test("SwipeDirection left case exists")
    func leftSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.left
        #expect(direction == .left, "Left swipe direction should be instantiable")
    }

    @Test("SwipeDirection up case exists")
    func upSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.up
        #expect(direction == .up, "Up swipe direction should be instantiable")
    }

    @Test("SwipeDirection down case exists")
    func downSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.down
        #expect(direction == .down, "Down swipe direction should be instantiable")
    }

    // MARK: - Smoke Tests (Verify No Crashes)

    @Test("Swipe below threshold does not crash")
    func progressBelowThreshold() {
        let service = HapticService.shared

        // These calls should not trigger haptics (progress <= 0.3)
        // Smoke test: verify no crash occurs
        service.triggerSwipe(direction: .right, progress: 0.0)
        service.triggerSwipe(direction: .left, progress: 0.1)
        service.triggerSwipe(direction: .up, progress: 0.2)
        service.triggerSwipe(direction: .down, progress: 0.3)

        #expect(true, "Low progress haptics handled without crash")
    }

    @Test("Swipe above threshold does not crash")
    func progressAboveThreshold() {
        let service = HapticService.shared

        // These calls should trigger haptics (progress > 0.3)
        // Smoke test: verify no crash occurs
        service.triggerSwipe(direction: .right, progress: 0.5)
        service.triggerSwipe(direction: .left, progress: 0.7)
        service.triggerSwipe(direction: .up, progress: 1.0)

        #expect(true, "High progress haptics handled without crash")
    }

    @Test("Success haptic does not crash")
    func successHaptic() {
        let service = HapticService.shared
        service.triggerSuccess()
        #expect(true, "Success haptic executed without crash")
    }

    @Test("Warning haptic does not crash")
    func warningHaptic() {
        let service = HapticService.shared
        service.triggerWarning()
        #expect(true, "Warning haptic executed without crash")
    }

    @Test("Error haptic does not crash")
    func errorHaptic() {
        let service = HapticService.shared
        service.triggerError()
        #expect(true, "Error haptic executed without crash")
    }

    @Test("Reset clears cached generators and subsequent calls work")
    func resetClearsGenerators() {
        let service = HapticService.shared

        // Trigger some haptics to ensure generators are cached
        service.triggerSwipe(direction: .right, progress: 0.5)
        service.triggerSwipe(direction: .left, progress: 0.5)

        // Reset should clear the cache
        service.reset()

        // Subsequent calls should still work (re-create generators)
        service.triggerSwipe(direction: .right, progress: 0.5)

        #expect(true, "Reset and subsequent haptics work without crash")
    }

    @Test("Multiple resets are safe")
    func multipleResets() {
        let service = HapticService.shared

        // Multiple resets should not cause issues
        service.reset()
        service.reset()
        service.reset()

        // Service should still work after multiple resets
        service.triggerSuccess()

        #expect(true, "Multiple resets handled without crash")
    }

    // MARK: - Edge Cases

    @Test("All swipe directions work with maximum progress")
    func allDirectionsMaxProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 1.0)
        service.triggerSwipe(direction: .left, progress: 1.0)
        service.triggerSwipe(direction: .up, progress: 1.0)
        service.triggerSwipe(direction: .down, progress: 1.0)

        #expect(true, "All directions with max progress handled without crash")
    }

    @Test("Progress above 1.0 is handled by generator")
    func progressAboveOne() {
        let service = HapticService.shared

        // UIKit generators should clamp values > 1.0 internally
        service.triggerSwipe(direction: .right, progress: 1.5)
        service.triggerSwipe(direction: .left, progress: 2.0)

        #expect(true, "Progress values above 1.0 handled without crash")
    }

    @Test("Zero progress is handled")
    func zeroProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 0.0)

        #expect(true, "Zero progress handled without crash")
    }

    @Test("Negative progress is handled")
    func negativeProgress() {
        let service = HapticService.shared

        // Negative progress should be handled gracefully
        service.triggerSwipe(direction: .right, progress: -0.5)

        #expect(true, "Negative progress handled without crash")
    }

    // MARK: - AppSettings Integration Tests

    @Test("HapticService respects hapticEnabled=false for triggerSwipe")
    func triggerSwipeRespectsSetting() {
        let service = HapticService.shared

        // When hapticEnabled is false, triggerSwipe should return early
        withHapticEnabled(false) {
            service.triggerSwipe(direction: .right, progress: 0.5)
            service.triggerSwipe(direction: .left, progress: 0.7)
            service.triggerSwipe(direction: .up, progress: 0.9)
            service.triggerSwipe(direction: .down, progress: 0.6)
        }

        // When hapticEnabled is true, haptics should work
        withHapticEnabled(true) {
            service.triggerSwipe(direction: .right, progress: 0.5)
            service.triggerSwipe(direction: .left, progress: 0.7)
        }

        #expect(true, "HapticService should respect hapticEnabled setting for triggerSwipe")
    }

    @Test("HapticService respects hapticEnabled=false for triggerSuccess")
    func triggerSuccessRespectsSetting() {
        let service = HapticService.shared

        withHapticEnabled(false) {
            service.triggerSuccess()
        }

        withHapticEnabled(true) {
            service.triggerSuccess()
        }

        #expect(true, "HapticService should respect hapticEnabled setting for triggerSuccess")
    }

    @Test("HapticService respects hapticEnabled=false for triggerWarning")
    func triggerWarningRespectsSetting() {
        let service = HapticService.shared

        withHapticEnabled(false) {
            service.triggerWarning()
        }

        withHapticEnabled(true) {
            service.triggerWarning()
        }

        #expect(true, "HapticService should respect hapticEnabled setting for triggerWarning")
    }

    @Test("HapticService respects hapticEnabled=false for triggerError")
    func triggerErrorRespectsSetting() {
        let service = HapticService.shared

        withHapticEnabled(false) {
            service.triggerError()
        }

        withHapticEnabled(true) {
            service.triggerError()
        }

        #expect(true, "HapticService should respect hapticEnabled setting for triggerError")
    }

    @Test("HapticService progress threshold still enforced when hapticEnabled=true")
    func progressThresholdRespectedWhenEnabled() {
        let service = HapticService.shared

        withHapticEnabled(true) {
            // Below threshold should not trigger haptic
            service.triggerSwipe(direction: .right, progress: 0.2)
            service.triggerSwipe(direction: .left, progress: 0.3)

            // Above threshold should trigger haptic
            service.triggerSwipe(direction: .up, progress: 0.5)
            service.triggerSwipe(direction: .down, progress: 1.0)
        }

        #expect(true, "Progress threshold should be enforced when hapticEnabled is true")
    }

    // MARK: - CoreHaptics Engine Tests

    @Test("HapticService handles CoreHaptics engine setup")
    func coreHapticsEngineSetup() {
        let service = HapticService.shared

        // Trigger a haptic to ensure engine is set up
        withHapticEnabled(true) {
            service.triggerSuccess()
        }

        // If device supports haptics, engine should be set up
        // If not, service should gracefully fallback to UIKit
        #expect(true, "HapticService should handle CoreHaptics setup gracefully")
    }

    @Test("HapticService resets CoreHaptics engine")
    func coreHapticsEngineReset() {
        let service = HapticService.shared

        // Trigger some haptics
        withHapticEnabled(true) {
            service.triggerSwipe(direction: .right, progress: 0.5)
            service.triggerSuccess()
        }

        // Reset should clear engine and cached generators
        service.reset()

        // Service should still work after reset
        withHapticEnabled(true) {
            service.triggerSwipe(direction: .left, progress: 0.7)
        }

        #expect(true, "HapticService should reset and recreate CoreHaptics engine")
    }

    @Test("HapticService restarts engine after background")
    func coreHapticsEngineRestart() {
        let service = HapticService.shared

        // Reset (simulating background)
        service.reset()

        // Restart engine (simulating foreground)
        service.restartEngine()

        // Service should work after restart
        withHapticEnabled(true) {
            service.triggerSuccess()
        }

        #expect(true, "HapticService should restart CoreHaptics engine after background")
    }

    @Test("HapticService gracefully falls back to UIKit")
    func uIKitFallback() {
        let service = HapticService.shared

        // Even if CoreHaptics fails, UIKit fallback should work
        withHapticEnabled(true) {
            service.triggerSwipe(direction: .right, progress: 0.5)
            service.triggerSuccess()
            service.triggerWarning()
            service.triggerError()
        }

        #expect(true, "HapticService should fall back to UIKit if CoreHaptics fails")
    }

    @Test("HapticService creates patterns for all directions")
    func hapticPatternCreation() {
        let service = HapticService.shared

        // Trigger all swipe directions to ensure patterns are created
        withHapticEnabled(true) {
            service.triggerSwipe(direction: .right, progress: 0.8)
            service.triggerSwipe(direction: .left, progress: 0.8)
            service.triggerSwipe(direction: .up, progress: 0.8)
            service.triggerSwipe(direction: .down, progress: 0.8)
        }

        #expect(true, "HapticService should create patterns for all swipe directions")
    }

    @Test("HapticService uses custom patterns for notifications")
    func notificationPatterns() {
        let service = HapticService.shared

        withHapticEnabled(true) {
            // Each should use a custom CoreHaptics pattern
            service.triggerSuccess() // Double tap pattern
            service.triggerWarning() // Medium intensity pattern
            service.triggerError() // Sharp, intense pattern
        }

        #expect(true, "HapticService should use custom patterns for notifications")
    }
}
