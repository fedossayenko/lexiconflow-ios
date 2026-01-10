//
//  ViewModelHolder.swift
//  LexiconFlow
//
//  A wrapper that holds an optional ObservableObject and properly publishes changes
//  Use this when you need @StateObject semantics with optional values
//

import Combine
import SwiftUI

/// A wrapper that holds an optional ObservableObject and properly publishes changes
///
/// **Why This Exists**:
/// SwiftUI's `@State` doesn't observe `@Published` properties inside an ObservableObject.
/// When you need to lazily initialize an ObservableObject but still want proper
/// SwiftUI observation, use this wrapper with `@StateObject`.
///
/// **Critical**: This wrapper forwards `objectWillChange` from the inner ObservableObject
/// to ensure all `@Published` property changes trigger view updates.
///
/// **Usage**:
/// ```swift
/// @StateObject private var viewModelHolder = ViewModelHolder<StatisticsViewModel>()
///
/// var body: some View {
///     if let viewModel = viewModelHolder.value {
///         // Use viewModel - SwiftUI will observe its @Published properties
///     }
/// }
///
/// .task {
///     viewModelHolder.value = StatisticsViewModel(modelContext: modelContext)
/// }
/// ```
@MainActor
final class ViewModelHolder<T: ObservableObject>: ObservableObject {
    /// The wrapped ObservableObject value
    @Published var value: T? {
        didSet {
            // When value changes, observe its objectWillChange
            if let value {
                setupObservation(for: value)
            }
        }
    }

    /// Combine cancellables for observation
    private var cancellables = Set<AnyCancellable>()

    /// Initialize with an optional value
    /// - Parameter value: Optional ObservableObject to wrap
    init(_ value: T? = nil) {
        self.value = value
        if let value {
            setupObservation(for: value)
        }
    }

    /// Set up observation of the inner ObservableObject
    /// - Parameter object: The ObservableObject to observe
    private func setupObservation(for object: T) {
        // Observe the inner object's objectWillChange
        // When ANY @Published property changes, forward the change
        object.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
