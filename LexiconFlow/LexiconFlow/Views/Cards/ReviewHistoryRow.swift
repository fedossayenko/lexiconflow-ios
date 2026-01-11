//
//  ReviewHistoryRow.swift
//  LexiconFlow
//
//  Individual review row component for review history list
//  Displays rating badge, date, state change indicator, and scheduling info
//

import SwiftUI

struct ReviewHistoryRow: View {
    /// The review data to display
    let review: FlashcardReviewDTO

    var body: some View {
        HStack(spacing: 16) {
            // Rating badge (left)
            self.ratingBadge

            // Review details (center)
            VStack(alignment: .leading, spacing: 6) {
                // Primary info: rating label + state change
                HStack(spacing: 8) {
                    Text(self.review.ratingLabel)
                        .font(.headline)
                        .foregroundStyle(self.ratingColor)

                    // State change badge (if applicable)
                    if let stateBadge = review.stateChangeBadge {
                        self.stateChangeBadge(stateBadge)
                    }
                }

                // Secondary info: relative date + timing details
                HStack(spacing: 6) {
                    Text(self.review.relativeDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(self.review.elapsedTimeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Tertiary info: scheduled interval
                Text(self.review.scheduledIntervalDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityHint("Review from \(self.review.fullDateString)")
    }

    // MARK: - Rating Badge

    /// Color-coded rating badge with icon
    private var ratingBadge: some View {
        ZStack {
            Circle()
                .fill(self.ratingColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: self.review.ratingIcon)
                .font(.title3)
                .foregroundStyle(self.ratingColor)
        }
        .accessibilityHidden(true) // Part of combined label
    }

    /// SwiftUI Color for rating
    private var ratingColor: Color {
        switch self.review.rating {
        case 0: .red
        case 1: .orange
        case 2: .blue
        case 3: .green
        default: .blue
        }
    }

    // MARK: - State Change Badge

    /// Badge highlighting state transition
    @ViewBuilder
    private func stateChangeBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(self.stateChangeColor(for: text).opacity(0.15))
            .foregroundStyle(self.stateChangeColor(for: text))
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }

    /// Color for state change badge
    private func stateChangeColor(for text: String) -> Color {
        switch text {
        case "First Review":
            .purple
        case "Graduated":
            .green
        case "Relearning":
            .orange
        default:
            .gray
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for VoiceOver
    private var accessibilityLabel: String {
        var parts: [String] = []

        // Rating
        parts.append("Rated \(self.review.ratingLabel.lowercased())")

        // State change (if any)
        if let stateBadge = review.stateChangeBadge {
            parts.append(stateBadge)
        }

        // Timing
        parts.append(self.review.relativeDateString)
        parts.append(self.review.elapsedTimeDescription)

        // Scheduled info
        parts.append("Next review \(self.review.scheduledIntervalDescription)")

        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // First review
        ReviewHistoryRow(
            review: FlashcardReviewDTO(
                id: UUID(),
                rating: 2, // Good
                reviewDate: Date().addingTimeInterval(-2 * 24 * 60 * 60), // 2 days ago
                scheduledDays: 3.0,
                elapsedDays: 2.0,
                stateChange: .firstReview
            )
        )

        // Graduated review
        ReviewHistoryRow(
            review: FlashcardReviewDTO(
                id: UUID(),
                rating: 3, // Easy
                reviewDate: Date().addingTimeInterval(-5 * 24 * 60 * 60), // 5 days ago
                scheduledDays: 7.0,
                elapsedDays: 5.0,
                stateChange: .graduated
            )
        )

        // Failed review (relearning)
        ReviewHistoryRow(
            review: FlashcardReviewDTO(
                id: UUID(),
                rating: 0, // Again
                reviewDate: Date().addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
                scheduledDays: 1.0,
                elapsedDays: 3.0,
                stateChange: .relearning
            )
        )

        // Normal review (no state change)
        ReviewHistoryRow(
            review: FlashcardReviewDTO(
                id: UUID(),
                rating: 2, // Good
                reviewDate: Date().addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
                scheduledDays: 14.0,
                elapsedDays: 10.0,
                stateChange: .none
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
