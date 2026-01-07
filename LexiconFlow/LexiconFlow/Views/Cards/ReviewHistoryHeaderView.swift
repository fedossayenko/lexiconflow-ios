//
//  ReviewHistoryHeaderView.swift
//  LexiconFlow
//
//  Header component displaying review history statistics
//  Shows total reviews, average rating, and current FSRS state with stability
//

import SwiftUI

struct ReviewHistoryHeaderView: View {
    /// Total number of reviews for this card
    let totalReviews: Int

    /// Average rating across all reviews (nil if no reviews)
    let averageRating: Double?

    /// Current FSRS state (nil if card has no FSRS state)
    let currentState: FlashcardState?

    /// Current stability value in days (nil if card has no FSRS state)
    let stability: Double?

    var body: some View {
        HStack(spacing: 20) {
            // Total reviews stat
            reviewCountStat

            // Average rating stat
            averageRatingStat

            // FSRS state stat
            fsrsStateStat

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Stats

    /// Total reviews count display
    private var reviewCountStat: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.blue)

            Text("\(totalReviews)")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(totalReviews == 1 ? "Review" : "Reviews")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(totalReviews) \(totalReviews == 1 ? "review" : "reviews")")
    }

    /// Average rating display with emoji
    private var averageRatingStat: some View {
        VStack(spacing: 6) {
            Text(ratingEmoji)
                .font(.title3)

            Text(averageRating.map { String(format: "%.1f", $0) } ?? "--")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Avg Rating")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(averageRatingAccessibilityLabel)
    }

    /// FSRS state and stability display
    private var fsrsStateStat: some View {
        VStack(spacing: 6) {
            Image(systemName: currentStateIcon)
                .font(.title3)
                .foregroundStyle(stateColor)

            Text(stabilityText)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(stateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stateAccessibilityLabel)
    }

    // MARK: - Computed Properties

    /// Emoji representing average rating quality
    private var ratingEmoji: String {
        guard let rating = averageRating else { return "–" }

        switch rating {
        case 0..<0.5: return "😵"
        case 0.5..<1.5: return "😔"
        case 1.5..<2.5: return "🙂"
        case 2.5..<3.5: return "😊"
        default: return "🌟"
        }
    }

    /// SF Symbol icon for current FSRS state
    private var currentStateIcon: String {
        switch currentState {
        case .new: return "sparkles"
        case .learning: return "graduationcap.fill"
        case .review: return "checkmark.circle.fill"
        case .relearning: return "arrow.clockwise.circle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }

    /// Color for FSRS state
    private var stateColor: Color {
        switch currentState {
        case .new: return .purple
        case .learning: return .blue
        case .review: return .green
        case .relearning: return .orange
        case .none: return .gray
        }
    }

    /// Stability text in days
    private var stabilityText: String {
        guard let stability = stability else { return "--" }

        if stability < 1.0 {
            let hours = Int(stability * 24)
            return hours == 1 ? "1h" : "\(hours)h"
        } else if stability < 7.0 {
            let days = Int(stability)
            return days == 1 ? "1d" : "\(days)d"
        } else if stability < 30.0 {
            let weeks = Int(stability / 7.0)
            return weeks == 1 ? "1w" : "\(weeks)w"
        } else {
            let months = Int(stability / 30.0)
            return months == 1 ? "1mo" : "\(months)mo"
        }
    }

    /// Human-readable state label
    private var stateLabel: String {
        switch currentState {
        case .new: return "New"
        case .learning: return "Learning"
        case .review: return "Review"
        case .relearning: return "Relearning"
        case .none: return "No State"
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for entire header
    private var accessibilityLabel: String {
        var parts: [String] = []

        // Review count
        parts.append("\(totalReviews) \(totalReviews == 1 ? "review" : "reviews")")

        // Average rating
        parts.append(averageRatingAccessibilityLabel)

        // State and stability
        parts.append(stateAccessibilityLabel)

        return parts.joined(separator: ", ")
    }

    /// Accessibility label for average rating
    private var averageRatingAccessibilityLabel: String {
        guard let rating = averageRating else {
            return "No average rating"
        }
        return "Average rating \(String(format: "%.1f", rating)) out of 3"
    }

    /// Accessibility label for state and stability
    private var stateAccessibilityLabel: String {
        guard let state = currentState else {
            return "No FSRS state"
        }

        guard let stability = stability else {
            return stateLabel
        }

        // Format stability for accessibility
        let stabilityText: String
        if stability < 1.0 {
            let hours = Int(stability * 24)
            stabilityText = hours == 1 ? "1 hour" : "\(hours) hours"
        } else if stability < 7.0 {
            let days = Int(stability)
            stabilityText = days == 1 ? "1 day" : "\(days) days"
        } else if stability < 30.0 {
            let weeks = Int(stability / 7.0)
            stabilityText = weeks == 1 ? "1 week" : "\(weeks) weeks"
        } else {
            let months = Int(stability / 30.0)
            stabilityText = months == 1 ? "1 month" : "\(months) months"
        }

        return "\(stateLabel) state, \(stabilityText) stability"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // New card with no reviews
        ReviewHistoryHeaderView(
            totalReviews: 0,
            averageRating: nil,
            currentState: .new,
            stability: 0.0
        )
        .padding()

        // Learning card with few reviews
        ReviewHistoryHeaderView(
            totalReviews: 3,
            averageRating: 2.3,
            currentState: .learning,
            stability: 2.5
        )
        .padding()

        // Review card with good performance
        ReviewHistoryHeaderView(
            totalReviews: 24,
            averageRating: 2.7,
            currentState: .review,
            stability: 14.3
        )
        .padding()

        // Relearning card with poor performance
        ReviewHistoryHeaderView(
            totalReviews: 12,
            averageRating: 1.4,
            currentState: .relearning,
            stability: 3.2
        )
        .padding()

        // Long-term review card with excellent performance
        ReviewHistoryHeaderView(
            totalReviews: 50,
            averageRating: 2.9,
            currentState: .review,
            stability: 45.0
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
