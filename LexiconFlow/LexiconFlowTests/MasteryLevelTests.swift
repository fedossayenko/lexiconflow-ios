//
//  MasteryLevelTests.swift
//  LexiconFlowTests
//
//  Tests for mastery level classification based on FSRS stability
//

import Foundation
import Testing
@testable import LexiconFlow

@Suite("Mastery Level Tests")
struct MasteryLevelTests {
    // MARK: - Threshold Tests

    @Test("Beginner threshold: 0 to 3 days")
    func beginnerThreshold() {
        #expect(MasteryLevel(stability: 0) == .beginner)
        #expect(MasteryLevel(stability: 1.5) == .beginner)
        #expect(MasteryLevel(stability: 2.999) == .beginner)
    }

    @Test("Intermediate threshold: 3 to 14 days")
    func intermediateThreshold() {
        #expect(MasteryLevel(stability: 3.0) == .intermediate)
        #expect(MasteryLevel(stability: 8.5) == .intermediate)
        #expect(MasteryLevel(stability: 13.999) == .intermediate)
    }

    @Test("Advanced threshold: 14 to 30 days")
    func advancedThreshold() {
        #expect(MasteryLevel(stability: 14.0) == .advanced)
        #expect(MasteryLevel(stability: 22.0) == .advanced)
        #expect(MasteryLevel(stability: 29.999) == .advanced)
    }

    @Test("Mastered threshold: 30+ days")
    func masteredThreshold() {
        #expect(MasteryLevel(stability: 30.0) == .mastered)
        #expect(MasteryLevel(stability: 60.0) == .mastered)
        #expect(MasteryLevel(stability: 365.0) == .mastered)
    }

    @Test("Boundary conditions")
    func boundaryConditions() {
        // Test exact boundaries
        #expect(MasteryLevel(stability: 2.9999) == .beginner)
        #expect(MasteryLevel(stability: 3.0) == .intermediate)
        #expect(MasteryLevel(stability: 13.9999) == .intermediate)
        #expect(MasteryLevel(stability: 14.0) == .advanced)
        #expect(MasteryLevel(stability: 29.9999) == .advanced)
        #expect(MasteryLevel(stability: 30.0) == .mastered)
    }

    @Test("Negative stability defaults to beginner")
    func negativeStability() {
        // Edge case: negative stability should not happen but should default to beginner
        #expect(MasteryLevel(stability: -1.0) == .beginner)
    }

    // MARK: - Display Properties

    @Test("Display names are user-friendly")
    func displayNames() {
        #expect(MasteryLevel.beginner.displayName == "Beginner")
        #expect(MasteryLevel.intermediate.displayName == "Intermediate")
        #expect(MasteryLevel.advanced.displayName == "Advanced")
        #expect(MasteryLevel.mastered.displayName == "Mastered")
    }

    @Test("Icons match mastery levels")
    func icons() {
        #expect(MasteryLevel.beginner.icon == "seedling.fill")
        #expect(MasteryLevel.intermediate.icon == "flame.fill")
        #expect(MasteryLevel.advanced.icon == "bolt.fill")
        #expect(MasteryLevel.mastered.icon == "star.circle.fill")
    }

    // MARK: - Enum Conformance

    @Test("Raw values match enum cases")
    func rawValues() {
        #expect(MasteryLevel.beginner.rawValue == "beginner")
        #expect(MasteryLevel.intermediate.rawValue == "intermediate")
        #expect(MasteryLevel.advanced.rawValue == "advanced")
        #expect(MasteryLevel.mastered.rawValue == "mastered")
    }

    @Test("Case iterable includes all cases")
    func caseIterable() {
        let allCases = MasteryLevel.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.beginner))
        #expect(allCases.contains(.intermediate))
        #expect(allCases.contains(.advanced))
        #expect(allCases.contains(.mastered))
    }

    @Test("Identifiable uses rawValue as id")
    func identifiable() {
        #expect(MasteryLevel.beginner.id == "beginner")
        #expect(MasteryLevel.intermediate.id == "intermediate")
        #expect(MasteryLevel.advanced.id == "advanced")
        #expect(MasteryLevel.mastered.id == "mastered")
    }

    // MARK: - Sendable Conformance

    @Test("MasteryLevel is Sendable")
    @MainActor
    func sendableConformance() {
        // Verify that MasteryLevel can be passed across actor boundaries
        let level: MasteryLevel = .advanced
        Task { @MainActor in
            #expect(level == .advanced)
        }
    }

    // MARK: - FSRSState Integration Tests

    @Test("FSRSState.masteryLevel returns correct level")
    func fsrsStateMasteryLevel() {
        let state1 = FSRSState(stability: 1.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state1.masteryLevel == .beginner)

        let state2 = FSRSState(stability: 10.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state2.masteryLevel == .intermediate)

        let state3 = FSRSState(stability: 25.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state3.masteryLevel == .advanced)

        let state4 = FSRSState(stability: 50.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state4.masteryLevel == .mastered)
    }

    @Test("FSRSState.isMastered returns true only when stability >= 30 and state is review")
    func fsrsStateIsMastered() {
        let mastered = FSRSState(stability: 30.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(mastered.isMastered == true)

        let notMasteredLowStability = FSRSState(stability: 29.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(notMasteredLowStability.isMastered == false)

        let notMasteredNewState = FSRSState(stability: 30.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "new")
        #expect(notMasteredNewState.isMastered == false)

        let notMasteredLearningState = FSRSState(stability: 30.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "learning")
        #expect(notMasteredLearningState.isMastered == false)

        let notMasteredRelearningState = FSRSState(stability: 30.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "relearning")
        #expect(notMasteredRelearningState.isMastered == false)
    }

    @Test("FSRSState.masteryLevel boundary at 30 days with review state")
    func fsrsStateMasteryBoundaryAt30() {
        // Exactly 30 days with review state = mastered
        let state1 = FSRSState(stability: 30.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state1.masteryLevel == .mastered)
        #expect(state1.isMastered == true)

        // Just below 30 days with review state = advanced
        let state2 = FSRSState(stability: 29.999, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: "review")
        #expect(state2.masteryLevel == .advanced)
        #expect(state2.isMastered == false)
    }

    @Test("FSRSState.isMastered false for non-review states regardless of stability")
    func isMasteredFalseForNonReviewStates() {
        let states: [FlashcardState] = [.new, .learning, .relearning]

        for state in states {
            let fsrsState = FSRSState(stability: 100.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: state.rawValue)
            #expect(fsrsState.isMastered == false, "isMastered should be false for \(state) state")
        }
    }

    // MARK: - Additional Edge Cases

    @Test("Zero stability returns beginner")
    func zeroStabilityReturnsBeginner() {
        #expect(MasteryLevel(stability: 0.0) == .beginner)
    }

    @Test("Extreme high stability values return mastered")
    func extremeHighStabilityReturnsMastered() {
        #expect(MasteryLevel(stability: 1000.0) == .mastered)
        #expect(MasteryLevel(stability: 10000.0) == .mastered)
        #expect(MasteryLevel(stability: Double.greatestFiniteMagnitude) == .mastered)
    }

    @Test("Adjacent values test range inclusivity")
    func adjacentValuesTestRangeInclusivity() {
        // Test just below and above each threshold
        #expect(MasteryLevel(stability: 2.999) == .beginner)
        #expect(MasteryLevel(stability: 3.001) == .intermediate)

        #expect(MasteryLevel(stability: 13.999) == .intermediate)
        #expect(MasteryLevel(stability: 14.001) == .advanced)

        #expect(MasteryLevel(stability: 29.999) == .advanced)
        #expect(MasteryLevel(stability: 30.001) == .mastered)
    }

    @Test("Fractional stability values are handled correctly")
    func fractionalStabilityValues() {
        #expect(MasteryLevel(stability: 0.5) == .beginner)
        #expect(MasteryLevel(stability: 3.5) == .intermediate)
        #expect(MasteryLevel(stability: 14.5) == .advanced)
        #expect(MasteryLevel(stability: 30.5) == .mastered)
    }
}
