//
//  LoadingView.swift
//  LexiconFlow
//
//  Unified loading view with progress indicator and message
//

import SwiftUI

/// Unified loading view component for consistent loading states
///
/// **Design Philosophy:**
/// - Consistency: Same loading UI across all async operations
/// - Clarity: Clear messaging about what's happening
/// - Accessibility: Proper labels for screen readers
///
/// **Usage:**
/// ```swift
/// if isLoading {
///     LoadingView(message: "Importing dictionary...")
/// }
/// ```
struct LoadingView: View {
    /// The message to display below the progress indicator
    let message: String

    /// Optional progress value (0.0 - 1.0) for determinate progress
    /// If nil, shows indeterminate progress indicator
    var progress: Double?

    /// Creates a loading view with a message
    /// - Parameters:
    ///   - message: The message to display
    ///   - progress: Optional progress value (0.0 - 1.0)
    init(message: String, progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            Group {
                if let progress {
                    // Determinate progress
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else {
                    // Indeterminate progress
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .accessibilityLabel("Loading")

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)

            // Progress percentage (if determinate)
            if let progress {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .accessibilityLabel("\(Int(progress * 100)) percent complete")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(.systemBackground))
    }
}

#Preview("Indeterminate") {
    LoadingView(message: "Loading cards...")
}

#Preview("Determinate") {
    LoadingView(message: "Importing dictionary...", progress: 0.65)
}

#Preview("Complete") {
    LoadingView(message: "Almost done...", progress: 0.95)
}
