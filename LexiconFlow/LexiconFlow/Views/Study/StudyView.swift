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

    // MARK: - UI Constants

    /// Card count display constants
    private enum CardCountDisplay {
        /// Large icon font size for card count display
        /// Balances prominence without overwhelming the screen
        static let iconFontSize: CGFloat = 50
    }

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
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if self.isSessionActive {
                    StudySessionView(mode: self.studyMode, decks: self.selectedDecks) {
                        self.sessionComplete()
                    }
                } else if AppSettings.hasSelectedDecks {
                    self.studyReadyView
                } else {
                    self.noDecksSelectedView
                }
            }
            .navigationTitle("Study")
            .sheet(isPresented: self.$showDeckSelection, onDismiss: {
                // Force refresh when deck selection sheet closes
                // This ensures card counts update to reflect new selection
                self.refreshState()
            }) {
                DeckSelectionView()
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                self.refreshState()
            }
            .onChange(of: self.studyMode) { _, _ in
                // When switching modes, refresh the entire state including sessionCards
                // This ensures the new mode fetches its own cards
                self.refreshState()
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
                self.showDeckSelection = true
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
                self.deckSelectionSummary

                // Study mode picker
                VStack(spacing: 12) {
                    Text("Study Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Study Mode", selection: self.$studyMode) {
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
                    Image(systemName: self.countIcon)
                        .font(.system(size: CardCountDisplay.iconFontSize))
                        .foregroundStyle(self.countColor)

                    Text(self.countTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(self.countSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)

                // Start button
                Button(action: self.startSession) {
                    Text(self.startButtonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(self.sessionCards.isEmpty)
                .accessibilityLabel(self.startButtonTitle)
                .accessibilityHint(self.sessionCards.isEmpty ? "No cards available" : "Begin study session")

                Spacer()
            }
            .padding()
        }
        .refreshable {
            await self.performRefresh()
        }
    }

    // MARK: - Deck Selection Summary

    private var deckSelectionSummary: some View {
        Button(action: { self.showDeckSelection = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Selected Decks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(self.selectedDecks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(self.selectedDecks.prefix(4), id: \.id) { deck in
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

                    if self.selectedDecks.count > 4 {
                        Text("+\(self.selectedDecks.count - 4) more")
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
        .accessibilityLabel("Selected decks: \(self.selectedDecks.count). Tap to change selection")
    }

    // MARK: - Computed Properties

    private var countTitle: String {
        switch self.studyMode {
        case .learning:
            "\(self.newCount) new"
        case .scheduled:
            "\(self.dueCount) due"
        case .cram:
            "\(self.totalCount) total"
        }
    }

    private var countSubtitle: String {
        switch self.studyMode {
        case .learning:
            "cards to learn"
        case .scheduled:
            "cards for review"
        case .cram:
            "cards to practice"
        }
    }

    private var countIcon: String {
        switch self.studyMode {
        case .learning:
            "plus.circle.fill"
        case .scheduled:
            "calendar.badge.clock"
        case .cram:
            "repeat"
        }
    }

    private var countColor: Color {
        switch self.studyMode {
        case .learning:
            .green
        case .scheduled:
            self.dueCount > 0 ? .orange : .gray
        case .cram:
            .purple
        }
    }

    private var startButtonTitle: String {
        if self.sessionCards.isEmpty {
            return "No Cards Available"
        }
        return "Start Studying"
    }

    // MARK: - Actions

    private func refreshState() {
        // Filter selected decks
        let selectedIDs = AppSettings.selectedDeckIDs
        self.selectedDecks = self.decks.filter { selectedIDs.contains($0.id) }

        // Validate that selected decks still exist
        let validDeckIDs = Set(selectedDecks.map(\.id))
        if validDeckIDs != selectedIDs {
            Self.logger.warning("Some selected decks no longer exist, updating selection")
            AppSettings.selectedDeckIDs = validDeckIDs
        }

        // Refresh counts
        self.refreshCounts()

        // Pre-fetch session cards
        let scheduler = Scheduler(modelContext: modelContext)
        self.sessionCards = scheduler.fetchCards(for: self.selectedDecks, mode: self.studyMode, limit: AppSettings.studyLimit)
    }

    /// Performs pull-to-refresh with haptic feedback
    @MainActor
    private func performRefresh() async {
        self.isRefreshing = true

        // Perform refresh on background thread
        await Task.detached {
            await MainActor.run {
                self.refreshState()
            }
        }.value

        // Provide haptic feedback on completion
        if AppSettings.hapticEnabled {
            HapticService.shared.triggerSuccess()
        }

        self.isRefreshing = false
        Self.logger.info("Pull-to-refresh completed")
    }

    private func refreshCounts() {
        let scheduler = Scheduler(modelContext: modelContext)
        self.dueCount = scheduler.dueCardCount(for: self.selectedDecks)
        self.newCount = scheduler.newCardCount(for: self.selectedDecks)
        self.totalCount = scheduler.totalCardCount(for: self.selectedDecks)
    }

    private func startSession() {
        guard !self.sessionCards.isEmpty else { return }
        self.isSessionActive = true
    }

    private func sessionComplete() {
        self.isSessionActive = false
        self.refreshState()
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
