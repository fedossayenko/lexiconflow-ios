//
//  DeckSelectionView.swift
//  LexiconFlow
//
//  Multi-deck selection screen for study sessions
//

import OSLog
import SwiftData
import SwiftUI

/// View for selecting multiple decks to study from
struct DeckSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Deck.order) private var decks: [Deck]

    @State private var selectedDeckIDs: Set<UUID>
    @State private var deckStats: [UUID: DeckStudyStats] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scheduler: Scheduler?

    init() {
        // Initialize with persisted selection
        _selectedDeckIDs = State(initialValue: AppSettings.selectedDeckIDs)
    }

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyStateView
                } else {
                    deckList
                }
            }
            .navigationTitle("Select Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSelection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !decks.isEmpty {
                        quickActionsMenu
                    }
                }
            }
            .task {
                if scheduler == nil {
                    scheduler = Scheduler(modelContext: modelContext)
                }
                await loadStats()
            }
            .onAppear {
                // Re-sync local state from AppSettings when sheet is presented
                // This fixes the bug where cached view instance shows stale selection
                selectedDeckIDs = AppSettings.selectedDeckIDs
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Decks", systemImage: "square.stack.3d.up.fill")
        } description: {
            Text("Create decks first to select them for study")
        } actions: {
            NavigationLink("Create Deck") {
                AddDeckView()
            }
        }
    }

    private var deckList: some View {
        List {
            ForEach(decks) { deck in
                DeckSelectionRow(
                    deck: deck,
                    stats: deckStats[deck.id] ?? DeckStudyStats(),
                    isSelected: selectedDeckIDs.contains(deck.id)
                ) {
                    toggleSelection(deck.id)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var quickActionsMenu: some View {
        Menu {
            Button("Select All") {
                selectAll()
            }

            Button("Deselect All") {
                deselectAll()
            }

            Divider()

            Button("Select Decks with Due Cards") {
                selectDueDecks()
            }

            Button("Select Decks with New Cards") {
                selectNewDecks()
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedDeckIDs.count) selected")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Quick actions")
        .accessibilityHint("Select multiple decks at once")
    }

    private func toggleSelection(_ deckID: UUID) {
        if selectedDeckIDs.contains(deckID) {
            selectedDeckIDs.remove(deckID)
        } else {
            selectedDeckIDs.insert(deckID)
        }
    }

    private func selectAll() {
        selectedDeckIDs = Set(decks.map(\.id))
    }

    private func deselectAll() {
        selectedDeckIDs.removeAll()
    }

    private func selectDueDecks() {
        selectedDeckIDs = Set(deckStats.filter { _, stats in
            stats.dueCount > 0
        }.map { deckID, _ in deckID })
    }

    private func selectNewDecks() {
        selectedDeckIDs = Set(deckStats.filter { _, stats in
            stats.newCount > 0
        }.map { deckID, _ in deckID })
    }

    private func saveSelection() {
        AppSettings.selectedDeckIDs = selectedDeckIDs
    }

    private func loadStats() async {
        isLoading = true
        defer { isLoading = false }

        guard let scheduler else {
            errorMessage = "Failed to initialize scheduler"
            return
        }

        var stats: [UUID: DeckStudyStats] = [:]

        for deck in decks {
            let newCount = scheduler.newCardCount(for: deck)
            let dueCount = scheduler.dueCardCount(for: deck)
            let totalCount = scheduler.totalCardCount(for: deck)

            stats[deck.id] = DeckStudyStats(
                newCount: newCount,
                dueCount: dueCount,
                totalCount: totalCount
            )
        }

        deckStats = stats
    }
}

/// Single row in deck selection list
struct DeckSelectionRow: View {
    let deck: Deck
    let stats: DeckStudyStats
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Deck icon
                Image(systemName: deck.icon ?? "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: .circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deck: \(deck.name)")
        .accessibilityHint("Tap to toggle selection")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var statsText: String {
        var parts: [String] = []

        if stats.newCount > 0 {
            parts.append("\(stats.newCount) new")
        }

        if stats.dueCount > 0 {
            parts.append("\(stats.dueCount) due")
        }

        if parts.isEmpty {
            return "\(stats.totalCount) cards"
        }

        return parts.joined(separator: " • ")
    }
}

#Preview("Empty State") {
    DeckSelectionView()
        .modelContainer(for: [Deck.self], inMemory: true)
}

#Preview("With Decks") {
    makeDeckSelectionPreview()
}

private func makeDeckSelectionPreview() -> some View {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(for: Deck.self, configurations: config)
    } catch {
        Logger(subsystem: "com.lexiconflow.preview", category: "DeckSelectionView")
            .error("Failed to create preview container: \(error)")
        return AnyView(Text("Preview Unavailable"))
    }
    let context = ModelContext(container)

    // Create sample decks
    let deck1 = Deck(name: "Vocabulary", icon: "book.fill", order: 0)
    let deck2 = Deck(name: "Phrases", icon: "text.bubble", order: 1)
    let deck3 = Deck(name: "Grammar", icon: "text.alignleft", order: 2)

    context.insert(deck1)
    context.insert(deck2)
    context.insert(deck3)

    return AnyView(DeckSelectionView().modelContainer(container))
}
