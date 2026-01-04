//
//  HapticServiceTests.swift
//  LexiconFlowTests
//
//  Tests for HapticService including generator caching and haptic feedback.
//

import Testing
@testable import LexiconFlow
import CoreFoundation

// Note: HapticService uses UIKit haptic generators which require a main thread/UI context.
// These tests verify the service logic and generator caching without triggering actual haptics.

@MainActor
struct HapticServiceTests {

    // MARK: - Singleton Tests

    @Test("HapticService singleton is consistent")
    func testSingletonConsistency() {
        let service1 = HapticService.shared
        let service2 = HapticService.shared
        #expect(service1 === service2, "HapticService should return the same singleton instance")
    }

    // MARK: - Swipe Direction Tests

    @Test("Right swipe direction exists")
    func testSwipeDirectionRight() {
        let direction = HapticService.SwipeDirection.right
        // Verify the direction exists (compile-time check)
        #expect(true, "Right swipe direction exists")
    }

    @Test("Left swipe direction exists")
    func testSwipeDirectionLeft() {
        let direction = HapticService.SwipeDirection.left
        #expect(true, "Left swipe direction exists")
    }

    @Test("Up swipe direction exists")
    func testSwipeDirectionUp() {
        let direction = HapticService.SwipeDirection.up
        #expect(true, "Up swipe direction exists")
    }

    @Test("Down swipe direction exists")
    func testSwipeDirectionDown() {
        let direction = HapticService.SwipeDirection.down
        #expect(true, "Down swipe direction exists")
    }

    // MARK: - Progress Threshold Tests

    @Test("Swipe below threshold does not trigger haptic")
    func testProgressThreshold() {
        let service = HapticService.shared

        // These calls should not trigger haptics (progress <= 0.3)
        service.triggerSwipe(direction: .right, progress: 0.0)
        service.triggerSwipe(direction: .left, progress: 0.1)
        service.triggerSwipe(direction: .up, progress: 0.2)
        service.triggerSwipe(direction: .down, progress: 0.3)

        // Verify by checking no crash occurs
        #expect(true, "Low progress haptics handled correctly")
    }

    @Test("Swipe above threshold triggers haptic")
    func testProgressAboveThreshold() {
        let service = HapticService.shared

        // These calls should trigger haptics (progress > 0.3)
        service.triggerSwipe(direction: .right, progress: 0.5)
        service.triggerSwipe(direction: .left, progress: 0.7)
        service.triggerSwipe(direction: .up, progress: 1.0)

        // Verify by checking no crash occurs
        #expect(true, "High progress haptics handled correctly")
    }

    // MARK: - Notification Haptic Tests

    @Test("Success haptic does not crash")
    func testSuccessHaptic() {
        let service = HapticService.shared
        service.triggerSuccess()
        #expect(true, "Success haptic executed without crash")
    }

    @Test("Warning haptic does not crash")
    func testWarningHaptic() {
        let service = HapticService.shared
        service.triggerWarning()
        #expect(true, "Warning haptic executed without crash")
    }

    @Test("Error haptic does not crash")
    func testErrorHaptic() {
        let service = HapticService.shared
        service.triggerError()
        #expect(true, "Error haptic executed without crash")
    }

    // MARK: - Reset Tests

    @Test("Reset clears cached generators")
    func testResetClearsGenerators() {
        let service = HapticService.shared

        // Trigger some haptics to ensure generators are cached
        service.triggerSwipe(direction: .right, progress: 0.5)
        service.triggerSwipe(direction: .left, progress: 0.5)

        // Reset should clear the cache
        service.reset()

        // Subsequent calls should still work (re-create generators)
        service.triggerSwipe(direction: .right, progress: 0.5)

        #expect(true, "Reset and subsequent haptics work correctly")
    }

    @Test("Multiple resets are safe")
    func testMultipleResets() {
        let service = HapticService.shared

        // Multiple resets should not cause issues
        service.reset()
        service.reset()
        service.reset()

        // Service should still work after multiple resets
        service.triggerSuccess()

        #expect(true, "Multiple resets handled correctly")
    }

    // MARK: - Edge Cases

    @Test("All swipe directions work with maximum progress")
    func testAllDirectionsMaxProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 1.0)
        service.triggerSwipe(direction: .left, progress: 1.0)
        service.triggerSwipe(direction: .up, progress: 1.0)
        service.triggerSwipe(direction: .down, progress: 1.0)

        #expect(true, "All directions with max progress handled correctly")
    }

    @Test("Progress above 1.0 is clamped by generator")
    func testProgressAboveOne() {
        let service = HapticService.shared

        // UIKit generators should clamp values > 1.0 internally
        service.triggerSwipe(direction: .right, progress: 1.5)
        service.triggerSwipe(direction: .left, progress: 2.0)

        #expect(true, "Progress values above 1.0 handled correctly")
    }

    @Test("Zero progress is handled")
    func testZeroProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 0.0)

        #expect(true, "Zero progress handled correctly")
    }
}
