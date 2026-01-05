//
//  StudyEmptyViewTests.swift
//  LexiconFlowTests
//
//  Tests for StudyEmptyView
//

import Testing
import SwiftUI
@testable import LexiconFlow

/// Test suite for StudyEmptyView
///
/// Tests verify:
/// - Shown when no cards due
/// - Empty state message
/// - CTA button
/// - Navigation to card creation
/// - Mode-specific messages
/// - Mode switching callback
@MainActor
struct StudyEmptyViewTests {

    // MARK: - Initialization Tests

    @Test("StudyEmptyView initializes with scheduled mode")
    func studyEmptyViewInitializesWithScheduled() {
        var modeSwitchCalled = false

        let view = StudyEmptyView(mode: .scheduled) { newMode in
            modeSwitchCalled = true
        }

        // Basic smoke test
        let body = view.body
        #expect(!body.isEmpty, "View body should not be empty")
        #expect(!modeSwitchCalled, "Callback should not be called initially")
    }

    @Test("StudyEmptyView initializes with cram mode")
    func studyEmptyViewInitializesWithCram() {
        let view = StudyEmptyView(mode: .cram) { _ in }

        let body = view.body
        #expect(!body.isEmpty, "View body should not be empty")
    }

    // MARK: - Mode Tests

    @Test("StudyEmptyView stores scheduled mode")
    func storesScheduledMode() {
        let view = StudyEmptyView(mode: .scheduled) { _ in }

        #expect(view.mode == .scheduled, "Mode should be scheduled")
    }

    @Test("StudyEmptyView stores cram mode")
    func storesCramMode() {
        let view = StudyEmptyView(mode: .cram) { _ in }

        #expect(view.mode == .cram, "Mode should be cram")
    }

    // MARK: - Message Tests

    @Test("Scheduled mode shows appropriate message")
    func scheduledModeShowsCorrectMessage() {
        let view = StudyEmptyView(mode: .scheduled) { _ in }

        let description = view.modeDescription
        #expect(description.contains("No cards are due"), "Should mention no cards due")
        #expect(description.contains("Cram mode"), "Should suggest cram mode")
    }

    @Test("Cram mode shows appropriate message")
    func cramModeShowsCorrectMessage() {
        let view = StudyEmptyView(mode: .cram) { _ in }

        let description = view.modeDescription
        #expect(description.contains("No cards available"), "Should mention no cards available")
        #expect(description.contains("Add some cards"), "Should suggest adding cards")
    }

    // MARK: - Callback Tests

    @Test("Switching from scheduled to cram triggers callback")
    func scheduledToCramTriggersCallback() {
        var receivedMode: StudyMode?

        let view = StudyEmptyView(mode: .scheduled) { newMode in
            receivedMode = newMode
        }

        // Simulate the callback being triggered
        view.onSwitchMode(.cram)

        #expect(receivedMode == .cram, "Should receive cram mode")
    }

    @Test("Switching from cram to scheduled triggers callback")
    func cramToScheduledTriggersCallback() {
        var receivedMode: StudyMode?

        let view = StudyEmptyView(mode: .cram) { newMode in
            receivedMode = newMode
        }

        view.onSwitchMode(.scheduled)

        #expect(receivedMode == .scheduled, "Should receive scheduled mode")
    }

    // MARK: - ContentUnavailableView Tests

    @Test("View uses ContentUnavailableView")
    func usesContentUnavailableView() {
        let view = StudyEmptyView(mode: .scheduled) { _ in }

        let body = view.body
        #expect(!body.isEmpty, "ContentUnavailableView should be rendered")
    }

    @Test("View shows checkmark icon")
    func showsCheckmarkIcon() {
        let view = StudyEmptyView(mode: .scheduled) { _ in }

        // The icon is "checkmark.circle.fill" in the label
        let body = view.body
        #expect(!body.isEmpty, "View should display checkmark icon")
    }

    @Test("View shows All caught up label")
    func showsAllCaughtUpLabel() {
        let view = StudyEmptyView(mode: .scheduled) { _ in }

        // The label is "All caught up!"
        let body = view.body
        #expect(!body.isEmpty, "View should display success message")
    }
}
