//
//  DeckRowView.swift
//  LexiconFlow
//
//  Single deck display in list
//

import SwiftData
import SwiftUI

struct DeckRowView: View {
    @Bindable var deck: Deck
    let dueCount: Int

    // MARK: - Computed Properties

    /// Calculate progress ratio (due/total), clamped to 0-1
    private var progressRatio: Double {
        guard deck.cards.count > 0 else { return 0 }
        return min(max(Double(dueCount) / Double(deck.cards.count), 0), 1)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Deck icon with progress ring (UNIFIED)
            Image(systemName: deck.icon ?? "folder.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.Colors.primary)
                .glassEffectUnion(
                    progress: progressRatio,
                    thickness: .thin,
                    iconSize: 50
                )
                .accessibilityLabel("Deck icon")
                .accessibilityValue("\(dueCount) of \(deck.cards.count) cards due")
                .accessibilityHint("Circular progress showing \(Int(progressRatio * 100))% complete")

            // Deck info
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(deck.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if dueCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)

                        Text("\(dueCount) due")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.error)
                            .fontWeight(.semibold)
                    }
                }
            }

            Spacer()
        }
    }
}

#Preview {
    let deck = Deck(name: "Sample Deck", icon: "star.fill")
    DeckRowView(deck: deck, dueCount: 5)
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
