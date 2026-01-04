//
//  RatingButtonsView.swift
//  LexiconFlow
//
//  Displays 4 rating buttons for card review
//

import SwiftUI

struct RatingButtonsView: View {
    let onRating: (CardRating) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(CardRating.allCases.reversed(), id: \.self) { rating in
                Button(action: { onRating(rating) }) {
                    VStack(spacing: 6) {
                        Image(systemName: rating.iconName)
                            .font(.title2)

                        Text(rating.label)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(rating.swiftUIColor.opacity(0.15))
                    .foregroundStyle(rating.swiftUIColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rating.label)
                .accessibilityHint("Rate card as \(rating.label.lowercased())")
                .accessibilityIdentifier("rating_\(rating.rawValue)")
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rating options")
    }
}

// MARK: - CardRating Extension

extension CardRating {
    /// SwiftUI Color for this rating
    var swiftUIColor: Color {
        switch self {
        case .again: return .red
        case .hard: return .orange
        case .good: return .blue
        case .easy: return .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("How well did you know this?")
            .font(.headline)

        RatingButtonsView { rating in
            print("Rated: \(rating.label)")
        }
    }
    .padding()
}
