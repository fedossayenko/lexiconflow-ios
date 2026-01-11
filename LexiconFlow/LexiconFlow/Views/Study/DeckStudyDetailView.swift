//
//  DeckStudyDetailView.swift
//  LexiconFlow
//
//  Shows study options for a specific deck
//

import SwiftData
import SwiftUI

struct DeckStudyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let deck: Deck

    @State private var stats = DeckStudyStats()
    @State private var selectedMode: StudyMode?
    @State private var isSessionActive = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if self.isSessionActive, let mode = selectedMode {
                StudySessionView(mode: mode, decks: [self.deck], onComplete: self.sessionComplete)
            } else {
                self.studyOptionsView
            }
        }
        .onAppear {
            self.refreshStats()
        }
        .alert("Error", isPresented: .constant(self.errorMessage != nil)) {
            Button("OK") { self.errorMessage = nil }
        } message: {
            Text(self.errorMessage ?? "")
        }
    }

    private var studyOptionsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Deck header
                self.deckHeader

                // Learn New (always available)
                self.learnNewSection

                // Scheduled (only if has due cards)
                if self.stats.dueCount > 0 {
                    self.scheduledSection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(self.deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var deckHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: self.deck.icon ?? "folder.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.deck.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(self.stats.totalCount) cards total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var learnNewSection: some View {
        self.studyModeCard(
            icon: "plus.circle.fill",
            title: "Learn New",
            description: "\(self.stats.newCount) new cards to learn",
            color: .green,
            action: { self.startSession(.learning) }
        )
    }

    private var scheduledSection: some View {
        self.studyModeCard(
            icon: "calendar.badge.clock",
            title: "Scheduled",
            description: "\(self.stats.dueCount) cards due for review",
            color: .orange,
            action: { self.startSession(.scheduled) }
        )
    }

    private func studyModeCard(
        icon: String,
        title: String,
        description: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                    Spacer()
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
        .accessibilityHint("Tap to start study session")
    }

    private func refreshStats() {
        let scheduler = Scheduler(modelContext: modelContext)
        self.stats.newCount = scheduler.newCardCount(for: self.deck)
        self.stats.dueCount = scheduler.dueCardCount(for: self.deck)
        self.stats.totalCount = scheduler.totalCardCount(for: self.deck)
    }

    private func startSession(_ mode: StudyMode) {
        // Validate cards available
        let scheduler = Scheduler(modelContext: modelContext)
        let availableCount = scheduler.fetchCards(for: self.deck, mode: mode, limit: 1).count

        guard availableCount > 0 else {
            self.errorMessage = "No cards available for this mode"
            return
        }

        self.selectedMode = mode
        self.isSessionActive = true
    }

    private func sessionComplete() {
        self.isSessionActive = false
        self.selectedMode = nil
        self.refreshStats()
    }
}

#Preview {
    NavigationStack {
        DeckStudyDetailView(deck: Deck(
            name: "My Vocabulary",
            icon: "book.fill",
            order: 0
        ))
    }
    .modelContainer(for: [Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
