//
//  HapticServiceTests.swift
//  LexiconFlowTests
//
//  Tests for HapticService including generator caching and haptic feedback.
//
//  NOTE: These are smoke tests that verify HapticService doesn't crash.
//  UIKit's haptic generators don't provide observable state for verification.
//

import Testing
import CoreFoundation
@testable import LexiconFlow

@MainActor
struct HapticServiceTests {

    // MARK: - Singleton Tests

    @Test("HapticService singleton is consistent")
    func testSingletonConsistency() {
        let service1 = HapticService.shared
        let service2 = HapticService.shared
        #expect(service1 === service2, "HapticService should return the same singleton instance")
    }

    // MARK: - SwipeDirection Enum Tests

    @Test("SwipeDirection right case exists")
    func testRightSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.right
        #expect(direction == .right, "Right swipe direction should be instantiable")
    }

    @Test("SwipeDirection left case exists")
    func testLeftSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.left
        #expect(direction == .left, "Left swipe direction should be instantiable")
    }

    @Test("SwipeDirection up case exists")
    func testUpSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.up
        #expect(direction == .up, "Up swipe direction should be instantiable")
    }

    @Test("SwipeDirection down case exists")
    func testDownSwipeDirectionExists() {
        let direction = HapticService.SwipeDirection.down
        #expect(direction == .down, "Down swipe direction should be instantiable")
    }

    // MARK: - Smoke Tests (Verify No Crashes)

    @Test("Swipe below threshold does not crash")
    func testProgressBelowThreshold() {
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
    func testProgressAboveThreshold() {
        let service = HapticService.shared

        // These calls should trigger haptics (progress > 0.3)
        // Smoke test: verify no crash occurs
        service.triggerSwipe(direction: .right, progress: 0.5)
        service.triggerSwipe(direction: .left, progress: 0.7)
        service.triggerSwipe(direction: .up, progress: 1.0)

        #expect(true, "High progress haptics handled without crash")
    }

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

    @Test("Reset clears cached generators and subsequent calls work")
    func testResetClearsGenerators() {
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
    func testMultipleResets() {
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
    func testAllDirectionsMaxProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 1.0)
        service.triggerSwipe(direction: .left, progress: 1.0)
        service.triggerSwipe(direction: .up, progress: 1.0)
        service.triggerSwipe(direction: .down, progress: 1.0)

        #expect(true, "All directions with max progress handled without crash")
    }

    @Test("Progress above 1.0 is handled by generator")
    func testProgressAboveOne() {
        let service = HapticService.shared

        // UIKit generators should clamp values > 1.0 internally
        service.triggerSwipe(direction: .right, progress: 1.5)
        service.triggerSwipe(direction: .left, progress: 2.0)

        #expect(true, "Progress values above 1.0 handled without crash")
    }

    @Test("Zero progress is handled")
    func testZeroProgress() {
        let service = HapticService.shared

        service.triggerSwipe(direction: .right, progress: 0.0)

        #expect(true, "Zero progress handled without crash")
    }

    @Test("Negative progress is handled")
    func testNegativeProgress() {
        let service = HapticService.shared

        // Negative progress should be handled gracefully
        service.triggerSwipe(direction: .right, progress: -0.5)

        #expect(true, "Negative progress handled without crash")
    }
}
