//
//  StudyView.swift
//  LexiconFlow
//
//  Deck-centric study entry point with multi-deck selection
//

import OSLog
import SwiftData
import SwiftUI

struct StudyView: View {
    private static let logger = Logger(subsystem: "com.lexiconflow.study", category: "StudyView")
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Deck.order) private var decks: [Deck]

    @State private var studyMode: StudyMode = .scheduled
    @State private var selectedDecks: [Deck] = []
    @State private var dueCount = 0
    @State private var newCount = 0
    @State private var totalCount = 0
    @State private var isSessionActive = false
    @State private var showDeckSelection = false
    @State private var sessionCards: [Flashcard] = []

    var body: some View {
        NavigationStack {
            Group {
                if isSessionActive {
                    StudySessionView(mode: studyMode, decks: selectedDecks) {
                        sessionComplete()
                    }
                } else if AppSettings.hasSelectedDecks {
                    studyReadyView
                } else {
                    noDecksSelectedView
                }
            }
            .navigationTitle("Study")
            .sheet(isPresented: $showDeckSelection, onDismiss: {
                // Force refresh when deck selection sheet closes
                // This ensures card counts update to reflect new selection
                refreshState()
            }) {
                DeckSelectionView()
            }
            .onAppear {
                refreshState()
            }
            .onChange(of: studyMode) { _, _ in
                // When switching modes, refresh the entire state including sessionCards
                // This ensures the new mode fetches its own cards
                refreshState()
            }
        }
    }

    // MARK: - No Decks Selected State

    private var noDecksSelectedView: some View {
        ContentUnavailableView {
            Label("No Decks Selected", systemImage: "square.stack.3d.up.fill")
        } description: {
            Text("Select the decks you want to study from")
        } actions: {
            Button("Select Decks") {
                showDeckSelection = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Select decks to study from")
        }
    }

    // MARK: - Study Ready View

    private var studyReadyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Deck selection summary
                deckSelectionSummary

                // Study mode picker
                VStack(spacing: 12) {
                    Text("Study Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Study Mode", selection: $studyMode) {
                        Text("Learn New").tag(StudyMode.learning)
                        Text("Scheduled").tag(StudyMode.scheduled)
                        Text("Cram").tag(StudyMode.cram)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Study mode selector")
                }
                .padding(.horizontal)

                // Cards count display
                VStack(spacing: 8) {
                    Image(systemName: countIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(countColor)

                    Text(countTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(countSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)

                // Start button
                Button(action: startSession) {
                    Text(startButtonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(sessionCards.isEmpty)
                .accessibilityLabel(startButtonTitle)
                .accessibilityHint(sessionCards.isEmpty ? "No cards available" : "Begin study session")

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Deck Selection Summary

    private var deckSelectionSummary: some View {
        Button(action: { showDeckSelection = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Selected Decks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(selectedDecks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(selectedDecks.prefix(4), id: \.id) { deck in
                        HStack(spacing: 6) {
                            Image(systemName: deck.icon ?? "folder.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(deck.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
                    }

                    if selectedDecks.count > 4 {
                        Text("+\(selectedDecks.count - 4) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected decks: \(selectedDecks.count). Tap to change selection")
    }

    // MARK: - Computed Properties

    private var countTitle: String {
        switch studyMode {
        case .learning:
            "\(newCount) new"
        case .scheduled:
            "\(dueCount) due"
        case .cram:
            "\(totalCount) total"
        }
    }

    private var countSubtitle: String {
        switch studyMode {
        case .learning:
            "cards to learn"
        case .scheduled:
            "cards for review"
        case .cram:
            "cards to practice"
        }
    }

    private var countIcon: String {
        switch studyMode {
        case .learning:
            "plus.circle.fill"
        case .scheduled:
            "calendar.badge.clock"
        case .cram:
            "repeat"
        }
    }

    private var countColor: Color {
        switch studyMode {
        case .learning:
            .green
        case .scheduled:
            dueCount > 0 ? .orange : .gray
        case .cram:
            .purple
        }
    }

    private var startButtonTitle: String {
        if sessionCards.isEmpty {
            return "No Cards Available"
        }
        return "Start Studying"
    }

    // MARK: - Actions

    private func refreshState() {
        // Filter selected decks
        let selectedIDs = AppSettings.selectedDeckIDs
        selectedDecks = decks.filter { selectedIDs.contains($0.id) }

        // Validate that selected decks still exist
        let validDeckIDs = Set(selectedDecks.map(\.id))
        if validDeckIDs != selectedIDs {
            Self.logger.warning("Some selected decks no longer exist, updating selection")
            AppSettings.selectedDeckIDs = validDeckIDs
        }

        // Refresh counts
        refreshCounts()

        // Pre-fetch session cards
        let scheduler = Scheduler(modelContext: modelContext)
        sessionCards = scheduler.fetchCards(for: selectedDecks, mode: studyMode, limit: AppSettings.studyLimit)
    }

    private func refreshCounts() {
        let scheduler = Scheduler(modelContext: modelContext)
        dueCount = scheduler.dueCardCount(for: selectedDecks)
        newCount = scheduler.newCardCount(for: selectedDecks)
        totalCount = scheduler.totalCardCount(for: selectedDecks)
    }

    private func startSession() {
        guard !sessionCards.isEmpty else { return }
        isSessionActive = true
    }

    private func sessionComplete() {
        isSessionActive = false
        refreshState()
    }
}

#Preview("No Decks Selected") {
    StudyView()
        .modelContainer(for: [Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}

#Preview("With Selected Decks") {
    makeStudyViewWithDecksPreview()
}

private func makeStudyViewWithDecksPreview() -> some View {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(for: Deck.self, Flashcard.self, FSRSState.self, FlashcardReview.self, configurations: config)
    } catch {
        Logger(subsystem: "com.lexiconflow.preview", category: "StudyView")
            .error("Failed to create preview container: \(error)")
        return AnyView(Text("Preview Unavailable"))
    }
    let context = ModelContext(container)

    // Create decks
    let deck1 = Deck(name: "Vocabulary", icon: "book.fill", order: 0)
    let deck2 = Deck(name: "Phrases", icon: "text.bubble", order: 1)
    context.insert(deck1)
    context.insert(deck2)

    // Set selected deck IDs
    AppSettings.selectedDeckIDs = [deck1.id, deck2.id]

    return AnyView(StudyView().modelContainer(container))
}
