//
//  EmptyStateView.swift
//  LexiconFlow
//
//  Reusable empty state view with helpful message and call-to-action button
//

import SwiftUI

struct EmptyStateView: View {
    // MARK: - Properties

    /// Icon to display (SF Symbol name)
    let icon: String

    /// Title text
    let title: String

    /// Message text (secondary, provides context)
    let message: String

    /// Button title text
    let buttonTitle: String

    /// Action to perform when button is tapped
    let action: () -> Void

    /// Optional accessibility label for the entire view
    let accessibilityLabel: String

    /// Optional accessibility hint for additional context
    let accessibilityHint: String

    // MARK: - Initializer

    init(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: self.icon)
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            // Text Content
            VStack(spacing: 8) {
                Text(self.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(self.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Action Button
            Button(action: self.action) {
                Text(self.buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityHint(self.accessibilityHint)
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    /// Creates an empty state view for statistics dashboard
    static func statisticsDashboard(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "chart.bar.xaxis",
            title: "No Study Data",
            message: "Start a study session to see your progress",
            buttonTitle: "Start Studying",
            accessibilityLabel: "No study data available",
            accessibilityHint: "Start a study session to see your statistics",
            action: action
        )
    }

    /// Creates an empty state view for no flashcards
    static func noFlashcards(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "square.stack.badge.plus",
            title: "No Flashcards",
            message: "Add flashcards to start learning vocabulary",
            buttonTitle: "Add Flashcards",
            accessibilityLabel: "No flashcards available",
            accessibilityHint: "Add flashcards to begin studying",
            action: action
        )
    }

    /// Creates an empty state view for no decks
    static func noDecks(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "folder.badge.plus",
            title: "No Decks",
            message: "Create a deck to organize your flashcards",
            buttonTitle: "Create Deck",
            accessibilityLabel: "No decks available",
            accessibilityHint: "Create a deck to organize your flashcards",
            action: action
        )
    }
}

// MARK: - Preview

#Preview("EmptyStateView - Statistics Dashboard") {
    NavigationStack {
        EmptyStateView.statisticsDashboard {
            print("Start studying tapped")
        }
    }
}

#Preview("EmptyStateView - No Flashcards") {
    NavigationStack {
        EmptyStateView.noFlashcards {
            print("Add flashcards tapped")
        }
    }
}

#Preview("EmptyStateView - No Decks") {
    NavigationStack {
        EmptyStateView.noDecks {
            print("Create deck tapped")
        }
    }
}

#Preview("EmptyStateView - Dark Mode") {
    NavigationStack {
        VStack(spacing: 32) {
            EmptyStateView.statisticsDashboard {
                print("Action 1")
            }

            Divider()

            EmptyStateView.noFlashcards {
                print("Action 2")
            }

            Divider()

            EmptyStateView.noDecks {
                print("Action 3")
            }
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("EmptyStateView - Custom") {
    EmptyStateView(
        icon: "tray",
        title: "Custom Empty State",
        message: "This is a custom message for a specific use case",
        buttonTitle: "Custom Action",
        accessibilityLabel: "Custom empty state",
        accessibilityHint: "Perform custom action",
        action: {
            print("Custom action tapped")
        }
    )
}
