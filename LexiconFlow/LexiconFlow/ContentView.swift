//
//  ContentView.swift
//  LexiconFlow
//
//  Root view for the LexiconFlow app
//  Placeholder until Phase 1, Task 1.6 (Core Views)
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Lexicon Flow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Phase 1: Foundation - Models Complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Core Views coming in Task 1.6")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .navigationTitle("Lexicon Flow")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
