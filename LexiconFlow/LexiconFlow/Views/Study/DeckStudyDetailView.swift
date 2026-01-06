//
//  DeckStudyDetailView.swift
//  LexiconFlow
//
//  Shows study options for a specific deck
//

import SwiftUI
import SwiftData

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
            if isSessionActive, let mode = selectedMode {
                StudySessionView(mode: mode, deck: deck, onComplete: sessionComplete)
            } else {
                studyOptionsView
            }
        }
        .onAppear {
            refreshStats()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var studyOptionsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Deck header
                deckHeader

                // Learn New (always available)
                learnNewSection

                // Scheduled (only if has due cards)
                if stats.dueCount > 0 {
                    scheduledSection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var deckHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: deck.icon ?? "folder.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(stats.totalCount) cards total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var learnNewSection: some View {
        studyModeCard(
            icon: "plus.circle.fill",
            title: "Learn New",
            description: "\(stats.newCount) new cards to learn",
            color: .green,
            action: { startSession(.learning) }
        )
    }

    private var scheduledSection: some View {
        studyModeCard(
            icon: "calendar.badge.clock",
            title: "Scheduled",
            description: "\(stats.dueCount) cards due for review",
            color: .orange,
            action: { startSession(.scheduled) }
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
    }

    private func refreshStats() {
        let scheduler = Scheduler(modelContext: modelContext)
        stats.newCount = scheduler.newCardCount(for: deck)
        stats.dueCount = scheduler.dueCardCount(for: deck)
        stats.totalCount = scheduler.totalCardCount(for: deck)
    }

    private func startSession(_ mode: StudyMode) {
        // Validate cards available
        let scheduler = Scheduler(modelContext: modelContext)
        let availableCount = scheduler.fetchCards(for: deck, mode: mode, limit: 1).count

        guard availableCount > 0 else {
            errorMessage = "No cards available for this mode"
            return
        }

        selectedMode = mode
        isSessionActive = true
    }

    private func sessionComplete() {
        isSessionActive = false
        selectedMode = nil
        refreshStats()
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
