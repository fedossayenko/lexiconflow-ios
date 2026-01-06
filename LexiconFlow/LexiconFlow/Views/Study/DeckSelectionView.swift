//
//  DeckSelectionView.swift
//  LexiconFlow
//
//  Multi-deck selection screen for study sessions
//

import SwiftUI
import SwiftData

/// Statistics for a single deck in selection UI
struct DeckSelectionStats {
    var newCount: Int = 0
    var dueCount: Int = 0
    var totalCount: Int = 0
}

/// View for selecting multiple decks to study from
struct DeckSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Deck.order) private var decks: [Deck]

    @State private var selectedDeckIDs: Set<UUID>
    @State private var deckStats: [UUID: DeckSelectionStats] = [:]
    @State private var isLoading = true

    init() {
        // Initialize with persisted selection
        _selectedDeckIDs = State(initialValue: AppSettings.selectedDeckIDs)
    }

    private var scheduler: Scheduler {
        Scheduler(modelContext: modelContext)
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
                await loadStats()
            }
            .onAppear {
                // Re-sync local state from AppSettings when sheet is presented
                // This fixes the bug where cached view instance shows stale selection
                selectedDeckIDs = AppSettings.selectedDeckIDs
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
                Text("Deck creation would go here")
            }
        }
    }

    private var deckList: some View {
        List {
            ForEach(decks) { deck in
                DeckSelectionRow(
                    deck: deck,
                    stats: deckStats[deck.id] ?? DeckSelectionStats(),
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
    }

    private func toggleSelection(_ deckID: UUID) {
        if selectedDeckIDs.contains(deckID) {
            selectedDeckIDs.remove(deckID)
        } else {
            selectedDeckIDs.insert(deckID)
        }
    }

    private func selectAll() {
        selectedDeckIDs = Set(decks.map { $0.id })
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

        var stats: [UUID: DeckSelectionStats] = [:]

        for deck in decks {
            let newCount = scheduler.newCardCount(for: deck)
            let dueCount = scheduler.dueCardCount(for: deck)
            let totalCount = scheduler.totalCardCount(for: deck)

            stats[deck.id] = DeckSelectionStats(
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
    let stats: DeckSelectionStats
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
    let container = try! ModelContainer(for: Deck.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)

    // Create sample decks
    let deck1 = Deck(name: "Vocabulary", icon: "book.fill", order: 0)
    let deck2 = Deck(name: "Phrases", icon: "text.bubble", order: 1)
    let deck3 = Deck(name: "Grammar", icon: "text.alignleft", order: 2)

    _ = context.insert(deck1)
    _ = context.insert(deck2)
    _ = context.insert(deck3)

    return DeckSelectionView()
        .modelContainer(container)
}
