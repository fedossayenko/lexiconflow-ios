//
//  OrphanedCardsView.swift
//  LexiconFlow
//
//  View for managing orphaned flashcards (cards without deck assignment)
//

import OSLog
import SwiftData
import SwiftUI

/// View for managing orphaned flashcards
///
/// Displays all cards with `deck == nil` and provides operations for:
/// - Viewing card details (word and definition)
/// - Multi-select for bulk operations
/// - Reassigning selected cards to an existing deck
/// - Bulk deleting selected cards with confirmation
struct OrphanedCardsView: View {
    @Environment(\.modelContext) private var modelContext

    /// Query for orphaned cards (cards with nil deck)
    @Query(filter: #Predicate<Flashcard> { $0.deck == nil }, sort: \Flashcard.createdAt)
    private var orphanedCards: [Flashcard]

    /// Set of selected card IDs for multi-select operations
    @State private var selectedCards = Set<UUID>()

    /// Sheet state for deck reassignment
    @State private var showingReassignSheet = false

    /// Alert state for delete confirmation
    @State private var showingDeleteConfirmation = false

    /// Target deck for reassignment
    @State private var targetDeck: Deck?

    /// Error message state
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "com.lexiconflow.orphans", category: "OrphanedCardsView")
    private let service = OrphanedCardsService.shared

    var body: some View {
        List {
            if self.orphanedCards.isEmpty {
                // Empty state when no orphaned cards
                ContentUnavailableView {
                    Label("No Orphaned Cards", systemImage: "folder.badge.checkmark")
                } description: {
                    Text("All cards are properly assigned to decks")
                }
            } else {
                // List of orphaned cards with multi-select
                Section {
                    ForEach(self.orphanedCards) { card in
                        OrphanedCardRow(
                            card: card,
                            isSelected: self.selectedCards.contains(card.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.toggleSelection(card.id)
                        }
                    }
                } header: {
                    Text("\(self.orphanedCards.count) Orphaned Card\(self.orphanedCards.count == 1 ? "" : "s")")
                } footer: {
                    if !self.selectedCards.isEmpty {
                        // Bulk action toolbar when cards are selected
                        HStack(spacing: 16) {
                            Text("\(self.selectedCards.count) selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Reassign button
                            Button {
                                self.showingReassignSheet = true
                            } label: {
                                Label("Reassign", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)

                            // Delete button
                            Button {
                                self.showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Orphaned Cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Clear selection button (only visible when cards are selected)
                if !self.selectedCards.isEmpty {
                    Button("Deselect All") {
                        self.selectedCards.removeAll()
                    }
                }
            }
        }
        .sheet(isPresented: self.$showingReassignSheet) {
            OrphanedCardDeckReassignmentView(
                targetDeck: self.$targetDeck,
                onConfirm: { deck in
                    self.targetDeck = deck
                    self.reassignSelectedCards(to: deck)
                }
            )
        }
        .alert("Confirm Deletion", isPresented: self.$showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                // Clear selection on cancel
                self.selectedCards.removeAll()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await self.deleteSelectedCards()
                }
            }
        } message: {
            if self.selectedCards.count == 1 {
                Text("Permanently delete 1 orphaned card? This action cannot be undone.")
            } else {
                Text("Permanently delete \(self.selectedCards.count) orphaned cards? This action cannot be undone.")
            }
        }
        .alert("Error", isPresented: .constant(self.errorMessage != nil)) {
            Button("OK") {
                self.errorMessage = nil
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    /// Toggle selection state for a card
    private func toggleSelection(_ id: UUID) {
        if self.selectedCards.contains(id) {
            self.selectedCards.remove(id)
        } else {
            self.selectedCards.insert(id)
        }
    }

    /// Reassign selected cards to the specified deck
    private func reassignSelectedCards(to deck: Deck) {
        let cardsToReassign = self.orphanedCards.filter { self.selectedCards.contains($0.id) }

        Task { @MainActor in
            do {
                let reassigned = try await service.reassignCards(
                    cardsToReassign,
                    to: deck,
                    context: self.modelContext
                )

                // Clear selection after successful reassignment
                self.selectedCards.removeAll()
                self.logger.info("Successfully reassigned \(reassigned) cards to deck \(deck.name)")

            } catch {
                self.logger.error("Failed to reassign cards: \(error)")
                self.errorMessage = "Failed to reassign cards: \(error.localizedDescription)"
                Analytics.trackError("reassign_orphaned_cards", error: error)
            }
        }
    }

    /// Delete selected cards
    private func deleteSelectedCards() async {
        let cardsToDelete = self.orphanedCards.filter { self.selectedCards.contains($0.id) }

        do {
            let deleted = try await service.deleteOrphanedCards(
                cardsToDelete,
                context: self.modelContext
            )

            // Clear selection after successful deletion
            self.selectedCards.removeAll()
            self.logger.info("Successfully deleted \(deleted) orphaned cards")

        } catch {
            self.logger.error("Failed to delete orphaned cards: \(error)")
            self.errorMessage = "Failed to delete cards: \(error.localizedDescription)"
            Analytics.trackError("delete_orphaned_cards", error: error)
        }
    }
}

// MARK: - Orphaned Card Row

/// Single row in the orphaned cards list
///
/// Displays the card's word and definition with a visual indicator
/// for selection state.
struct OrphanedCardRow: View {
    let card: Flashcard
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if self.isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .font(.title3)
            }

            // Card content
            VStack(alignment: .leading, spacing: 4) {
                // Word
                Text(self.card.word)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Definition (truncated if too long)
                Text(self.card.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Orphan indicator badge
                Text("No Deck")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Deck Selection View

/// Sheet view for selecting a target deck for card reassignment
struct OrphanedCardDeckReassignmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Deck.order) private var decks: [Deck]

    @Binding var targetDeck: Deck?
    let onConfirm: (Deck) -> Void

    var body: some View {
        NavigationStack {
            List {
                if self.decks.isEmpty {
                    ContentUnavailableView {
                        Label("No Decks", systemImage: "book.fill")
                    } description: {
                        Text("Create a deck first before reassigning cards")
                    }
                } else {
                    ForEach(self.decks) { deck in
                        Button {
                            self.targetDeck = deck
                            self.onConfirm(deck)
                            self.dismiss()
                        } label: {
                            HStack {
                                Image(systemName: deck.icon ?? "folder.fill")
                                    .foregroundStyle(.blue)
                                Text(deck.name)
                                Spacer()
                                if self.targetDeck?.id == deck.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reassign to Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

private func makeEmptyPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    do {
        return try ModelContainer(
            for: Flashcard.self, Deck.self, FSRSState.self,
            configurations: config
        )
    } catch {
        assertionFailure("Failed to create preview container: \(error.localizedDescription)")
        // Return empty schema container as absolute fallback
        let emptySchema = Schema([])
        return try! ModelContainer(for: emptySchema, configurations: config)
    }
}

#Preview("Empty State") {
    OrphanedCardsView()
        .modelContainer(makeEmptyPreviewContainer())
}

private func makeOrphanedCardsPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: Flashcard.self, Deck.self, FSRSState.self,
            configurations: config
        )
    } catch {
        assertionFailure("Failed to create preview container: \(error.localizedDescription)")
        // Return empty schema container as absolute fallback
        let emptySchema = Schema([])
        return try! ModelContainer(for: emptySchema, configurations: config)
    }

    // Create some orphaned cards
    let context = ModelContext(container)
    let card1 = Flashcard(word: "orphan1", definition: "First orphaned card")
    let card2 = Flashcard(word: "orphan2", definition: "Second orphaned card")
    let card3 = Flashcard(word: "orphan3", definition: "Third orphaned card")

    context.insert(card1)
    context.insert(card2)
    context.insert(card3)

    // Create a deck for reassignment testing
    let deck = Deck(name: "Test Deck")
    context.insert(deck)

    do {
        try context.save()
    } catch {
        assertionFailure("Failed to save preview context: \(error.localizedDescription)")
    }

    return container
}

#Preview("With Orphaned Cards") {
    OrphanedCardsView()
        .modelContainer(makeOrphanedCardsPreviewContainer())
}
