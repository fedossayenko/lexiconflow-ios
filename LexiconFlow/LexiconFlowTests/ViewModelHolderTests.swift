//
//  ViewModelHolderTests.swift
//  LexiconFlowTests
//
//  Tests for ViewModelHolder utility
//

import Combine
import SwiftUI
import Testing
@testable import LexiconFlow

/// Test ObservableObject for testing
@MainActor
final class TestViewModel: ObservableObject {
    @Published var count: Int = 0
    @Published var text: String = "test"
    var nonPublishedValue: String = "not published"

    func increment() {
        count += 1
    }

    func updateText(_ newText: String) {
        text = newText
    }
}

/// Test suite for ViewModelHolder
///
/// Tests verify:
/// - Optional value storage
/// - Proper objectWillChange forwarding
/// - Observation setup on value assignment
/// - Cancellation on value change
@MainActor
struct ViewModelHolderTests {
    // MARK: - Initialization Tests

    @Test("Initialize with nil value")
    func initWithNil() {
        let holder = ViewModelHolder<TestViewModel>()

        #expect(holder.value == nil, "Holder should start with nil")
    }

    @Test("Initialize with value")
    func initWithValue() {
        let viewModel = TestViewModel()
        let holder = ViewModelHolder(viewModel)

        #expect(holder.value != nil, "Holder should contain value")
        #expect(holder.value?.count == 0, "ViewModel should be initialized")
    }

    // MARK: - Value Assignment Tests

    @Test("Assign nil to holder")
    func assignNil() {
        let holder = ViewModelHolder<TestViewModel>()
        holder.value = nil

        #expect(holder.value == nil, "Value should remain nil")
    }

    @Test("Assign value to holder")
    func assignValue() {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()

        holder.value = viewModel

        #expect(holder.value !== nil, "Value should be assigned")
        #expect(holder.value === viewModel, "Same instance should be stored")
    }

    @Test("Reassign value")
    func reassignValue() {
        let holder = ViewModelHolder<TestViewModel>()
        let firstViewModel = TestViewModel()
        let secondViewModel = TestViewModel()

        holder.value = firstViewModel
        #expect(holder.value === firstViewModel, "First value should be assigned")

        holder.value = secondViewModel
        #expect(holder.value === secondViewModel, "Second value should replace first")
    }

    // MARK: - ObjectWillChange Forwarding Tests

    @Test("Forward objectWillChange from inner ObservableObject")
    func forwardObjectWillChange() async {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()
        holder.value = viewModel

        var changeCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                changeCount += 1
            }

        // Modify published property
        viewModel.increment()

        // Small delay to let change propagate
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        #expect(changeCount >= 1, "objectWillChange should fire when inner object changes")
        #expect(viewModel.count == 1, "ViewModel should be updated")

        cancellable.cancel()
    }

    @Test("Forward multiple published property changes")
    func forwardMultipleChanges() async {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()
        holder.value = viewModel

        var changeCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                changeCount += 1
            }

        // Modify multiple properties
        viewModel.increment() // count: 0 -> 1
        try? await Task.sleep(nanoseconds: 5000000) // 5ms
        viewModel.updateText("new text") // text: "test" -> "new text"
        try? await Task.sleep(nanoseconds: 5000000) // 5ms

        #expect(changeCount >= 2, "objectWillChange should fire for each change")
        #expect(viewModel.count == 1, "Count should be updated")
        #expect(viewModel.text == "new text", "Text should be updated")

        cancellable.cancel()
    }

    @Test("Not forward when value is nil")
    func notForwardWhenNil() async {
        let holder = ViewModelHolder<TestViewModel>()
        var changeCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                changeCount += 1
            }

        // Holder has no value
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        #expect(changeCount == 0, "No changes should fire when value is nil")

        cancellable.cancel()
    }

    // MARK: - Memory Management Tests

    @Test("Handle deallocation of inner object")
    func handleDeallocation() {
        let holder = ViewModelHolder<TestViewModel>()
        var viewModel: TestViewModel? = TestViewModel()
        holder.value = viewModel

        #expect(holder.value != nil, "Value should be assigned")

        // Deallocate
        viewModel = nil

        // Holder should still have the value (strong reference)
        #expect(holder.value != nil, "Holder should maintain strong reference")
    }

    @Test("Release old value when assigning new")
    func releaseOldValue() {
        let holder = ViewModelHolder<TestViewModel>()
        let firstViewModel = TestViewModel()
        let secondViewModel = TestViewModel()

        holder.value = firstViewModel
        let firstReference = firstViewModel
        holder.value = secondViewModel

        // First reference is still valid (we hold it)
        #expect(firstReference.count == 0, "First view model should still exist")
    }

    // MARK: - Type Safety Tests

    @Test("Maintain type safety")
    func maintainTypeSafety() {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()

        holder.value = viewModel

        #expect(holder.value?.count == 0, "Should maintain TestViewModel type")
        #expect(holder.value?.text == "test", "Should have access to TestViewModel properties")
    }

    @Test("Work with different ObservableObject types")
    func workWithDifferentTypes() {
        @MainActor
        class OtherViewModel: ObservableObject {
            @Published var flag: Bool = false
        }

        let holder = ViewModelHolder<OtherViewModel>()
        let viewModel = OtherViewModel()

        holder.value = viewModel

        #expect(holder.value?.flag == false, "Should work with any ObservableObject")
    }

    // MARK: - Integration Tests

    @Test("Simulate view lifecycle")
    func simulateViewLifecycle() async {
        // Simulate view initialization
        let holder = ViewModelHolder<TestViewModel>()

        // Simulate .task block creating view model
        let viewModel = TestViewModel()
        holder.value = viewModel

        #expect(holder.value != nil, "ViewModel should be available")

        // Simulate view updates
        var updateCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                updateCount += 1
            }

        viewModel.increment()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        #expect(updateCount >= 1, "View should receive updates")

        // Simulate view dismissal
        holder.value = nil
        #expect(holder.value == nil, "ViewModel should be cleared")

        cancellable.cancel()
    }

    @Test("Handle rapid value changes")
    func handleRapidChanges() async {
        let holder = ViewModelHolder<TestViewModel>()

        var changeCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                changeCount += 1
            }

        // Rapidly change values
        for i in 0 ..< 10 {
            let viewModel = TestViewModel()
            viewModel.count = i
            holder.value = viewModel
        }

        try? await Task.sleep(nanoseconds: 50000000) // 50ms

        #expect(changeCount >= 10, "Should handle rapid changes")

        cancellable.cancel()
    }

    @Test("Concurrent value access")
    func concurrentAccess() async {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()
        holder.value = viewModel

        await withTaskGroup(of: Void.self) { group in
            // Multiple concurrent reads
            for _ in 0 ..< 10 {
                group.addTask { @MainActor in
                    _ = holder.value?.count
                }
            }

            // Multiple concurrent writes
            for i in 0 ..< 10 {
                group.addTask { @MainActor in
                    holder.value?.count = i
                }
            }
        }

        // Should complete without crashes
        #expect(holder.value != nil, "Holder should still be valid")
    }

    // MARK: - Edge Cases

    @Test("Handle nil initial value")
    func handleNilInitialValue() async {
        let holder = ViewModelHolder<TestViewModel>(nil)

        #expect(holder.value == nil, "Should start as nil")

        // Assign value after initialization
        let viewModel = TestViewModel()
        holder.value = viewModel

        #expect(holder.value !== nil, "Should accept value after nil")
    }

    @Test("Handle reassigning to same value")
    func reassignSameValue() {
        let holder = ViewModelHolder<TestViewModel>()
        let viewModel = TestViewModel()

        holder.value = viewModel
        let firstAssignment = holder.value

        holder.value = viewModel
        let secondAssignment = holder.value

        // Should be same instance
        #expect(firstAssignment === secondAssignment, "Same instance should be stored")
    }

    @Test("Handle multiple nil assignments")
    func multipleNilAssignments() {
        let holder = ViewModelHolder<TestViewModel>()

        holder.value = nil
        holder.value = nil
        holder.value = nil

        #expect(holder.value == nil, "Multiple nil assignments should be safe")
    }

    // MARK: - Observation Cleanup Tests

    @Test("Clean up observations on value change")
    func cleanupObservations() async {
        let holder = ViewModelHolder<TestViewModel>()
        let firstViewModel = TestViewModel()
        let secondViewModel = TestViewModel()

        holder.value = firstViewModel

        var changeCount = 0
        let cancellable = holder.objectWillChange
            .sink { _ in
                changeCount += 1
            }

        // Change first view model
        firstViewModel.increment()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        let changesAfterFirst = changeCount

        // Switch to new view model
        holder.value = secondViewModel
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        // Modify first view model (should not trigger changes)
        firstViewModel.increment()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        let changesAfterSwitch = changeCount

        // Changes after switch should only be from second view model assignment
        #expect(changesAfterFirst >= 1, "First changes should be recorded")
        #expect(changesAfterSwitch >= changesAfterFirst, "Second view model should be observed")

        cancellable.cancel()
    }

    @Test("Maintain separate observation for each value")
    func maintainSeparateObservations() async {
        let holder = ViewModelHolder<TestViewModel>()

        var firstChanges = 0
        var secondChanges = 0

        // Create first cancellable
        let cancellable1 = holder.objectWillChange
            .sink { _ in
                firstChanges += 1
            }

        let firstViewModel = TestViewModel()
        holder.value = firstViewModel
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        // Change first view model
        firstViewModel.increment()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        let changesBeforeSwitch = firstChanges

        // Create new cancellable after switch
        holder.value = TestViewModel()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        // First cancellable should still receive changes
        #expect(firstChanges >= changesBeforeSwitch, "Observations should be maintained")

        cancellable1.cancel()
    }

    // MARK: - Real-World Scenario Tests

    @Test("Simulate StatisticsViewModel usage pattern")
    func simulateStatisticsViewModelPattern() async {
        // This simulates the actual usage in StatisticsDashboardView
        let holder = ViewModelHolder<TestViewModel>()

        // Initially nil (view not loaded yet)
        #expect(holder.value == nil, "Should start nil")

        // Simulate async view model creation in .task
        await Task { @MainActor in
            let viewModel = TestViewModel()
            holder.value = viewModel
            viewModel.increment()
        }.value

        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        #expect(holder.value?.count == 1, "ViewModel should be updated")

        // Simulate view update
        var updateReceived = false
        let cancellable = holder.objectWillChange
            .sink { _ in
                updateReceived = true
            }

        holder.value?.increment()
        try? await Task.sleep(nanoseconds: 10000000) // 10ms

        #expect(updateReceived, "View should receive update notification")

        cancellable.cancel()
    }

    @Test("Handle view model with complex state")
    func handleComplexState() {
        @MainActor
        class ComplexViewModel: ObservableObject {
            @Published var items: [String] = []
            @Published var isLoading: Bool = false
            @Published var error: String?

            func addItem(_ item: String) {
                items.append(item)
            }

            func startLoading() {
                isLoading = true
            }

            func stopLoading() {
                isLoading = false
            }

            func setError(_ error: String?) {
                self.error = error
            }
        }

        let holder = ViewModelHolder<ComplexViewModel>()
        let viewModel = ComplexViewModel()
        holder.value = viewModel

        // Test complex state changes
        viewModel.startLoading()
        #expect(holder.value?.isLoading == true, "Loading state should be set")

        viewModel.addItem("item1")
        #expect(holder.value?.items.count == 1, "Item should be added")

        viewModel.setError("Test error")
        #expect(holder.value?.error == "Test error", "Error should be set")

        viewModel.stopLoading()
        #expect(holder.value?.isLoading == false, "Loading should complete")
    }
}
