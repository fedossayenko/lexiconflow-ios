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
import CoreHaptics
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

    // MARK: - Rating Feedback Tests

    @Test("Again rating feedback does not crash")
    func testAgainRatingFeedback() {
        let service = HapticService.shared
        service.playRatingFeedback(rating: .again)
        #expect(true, "Again rating feedback executed without crash")
    }

    @Test("Hard rating feedback does not crash")
    func testHardRatingFeedback() {
        let service = HapticService.shared
        service.playRatingFeedback(rating: .hard)
        #expect(true, "Hard rating feedback executed without crash")
    }

    @Test("Good rating feedback does not crash")
    func testGoodRatingFeedback() {
        let service = HapticService.shared
        service.playRatingFeedback(rating: .good)
        #expect(true, "Good rating feedback executed without crash")
    }

    @Test("Easy rating feedback does not crash")
    func testEasyRatingFeedback() {
        let service = HapticService.shared
        service.playRatingFeedback(rating: .easy)
        #expect(true, "Easy rating feedback executed without crash")
    }

    @Test("All rating feedbacks can be played in sequence")
    func testAllRatingFeedbacksSequentially() {
        let service = HapticService.shared

        // Play all four ratings in sequence
        service.playRatingFeedback(rating: .again)
        service.playRatingFeedback(rating: .hard)
        service.playRatingFeedback(rating: .good)
        service.playRatingFeedback(rating: .easy)

        #expect(true, "All rating feedbacks handled sequentially without crash")
    }

    // MARK: - Streak Milestone Chime Tests

    @Test("Streak milestone chime for small streak does not crash")
    func testStreakMilestoneChimeSmallStreak() {
        let service = HapticService.shared
        service.playStreakMilestoneChime(streakCount: 7)
        #expect(true, "Small streak chime executed without crash")
    }

    @Test("Streak milestone chime for medium streak does not crash")
    func testStreakMilestoneChimeMediumStreak() {
        let service = HapticService.shared
        service.playStreakMilestoneChime(streakCount: 30)
        #expect(true, "Medium streak chime executed without crash")
    }

    @Test("Streak milestone chime for large streak does not crash")
    func testStreakMilestoneChimeLargeStreak() {
        let service = HapticService.shared
        service.playStreakMilestoneChime(streakCount: 100)
        #expect(true, "Large streak chime executed without crash")
    }

    @Test("Streak milestone chime for very large streak does not crash")
    func testStreakMilestoneChimeVeryLargeStreak() {
        let service = HapticService.shared
        service.playStreakMilestoneChime(streakCount: 365)
        #expect(true, "Very large streak chime executed without crash")
    }

    @Test("Streak milestone chime handles edge case of zero streak")
    func testStreakMilestoneChimeZeroStreak() {
        let service = HapticService.shared
        service.playStreakMilestoneChime(streakCount: 0)
        #expect(true, "Zero streak chime handled without crash")
    }

    // MARK: - Custom Haptic Pattern Tests

    @Test("Custom haptic pattern with single event does not crash")
    func testCustomHapticPatternSingleEvent() {
        let service = HapticService.shared
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        )
        service.playCustomPattern(events: [event])
        #expect(true, "Single event custom pattern executed without crash")
    }

    @Test("Custom haptic pattern with multiple events does not crash")
    func testCustomHapticPatternMultipleEvents() {
        let service = HapticService.shared
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.1,
                duration: 0.3
            )
        ]
        service.playCustomPattern(events: events)
        #expect(true, "Multiple events custom pattern executed without crash")
    }

    @Test("Custom haptic pattern with empty events array does not crash")
    func testCustomHapticPatternEmptyEvents() {
        let service = HapticService.shared
        service.playCustomPattern(events: [])
        #expect(true, "Empty events custom pattern handled without crash")
    }

    @Test("Custom haptic pattern with custom intensity does not crash")
    func testCustomHapticPatternWithCustomIntensity() {
        let service = HapticService.shared
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        )
        service.playCustomPattern(events: [event], intensity: 0.5)
        #expect(true, "Custom intensity pattern executed without crash")
    }

    @Test("Custom haptic pattern with zero intensity does not crash")
    func testCustomHapticPatternWithZeroIntensity() {
        let service = HapticService.shared
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0
        )
        service.playCustomPattern(events: [event], intensity: 0.0)
        #expect(true, "Zero intensity pattern handled without crash")
    }

    @Test("Custom haptic pattern with intensity above 1.0 does not crash")
    func testCustomHapticPatternWithIntensityAboveOne() {
        let service = HapticService.shared
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0
        )
        service.playCustomPattern(events: [event], intensity: 1.5)
        #expect(true, "Intensity above 1.0 handled without crash")
    }
}
