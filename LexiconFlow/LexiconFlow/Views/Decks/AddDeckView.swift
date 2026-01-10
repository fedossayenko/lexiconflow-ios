//
//  AddDeckView.swift
//  LexiconFlow
//
//  Form for creating a new deck
//

import SwiftData
import SwiftUI

struct AddDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Deck.order) private var existingDecks: [Deck]

    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var errorMessage: String?

    private let deckIcons = [
        "folder.fill", "star.fill", "heart.fill", "book.fill",
        "graduationcap.fill", "lightbulb.fill", "brain.fill",
        "globe", "terminal.fill", "hammer.fill", "paintbrush.fill",
        "music.note", "camera.fill", "gamecontroller.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck Info") {
                    TextField("Deck Name", text: self.$name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Deck Name")
                        .accessibilityHint("Enter a name for the new deck")

                    Picker("Icon", selection: self.$selectedIcon) {
                        ForEach(self.deckIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                    .frame(width: 30)
                            }
                            .tag(icon)
                        }
                    }
                    .accessibilityLabel("Icon picker")
                    .accessibilityHint("Select an icon for the deck")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(self.deckIcons, id: \.self) { icon in
                            Button(action: { self.selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(self.selectedIcon == icon ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(self.selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Icon \(icon)")
                            .accessibilityHint(self.selectedIcon == icon ? "Currently selected" : "Select this icon")
                            .accessibilityAddTraits(self.selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Icon grid")
                } header: {
                    Text("Choose Icon")
                }

                // Inline buttons to avoid UIKitToolbar warning in sheet presentations
                Section {
                    Button(action: {
                        self.dismiss()
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Discard changes and close")

                    Button("Save") {
                        self.saveDeck()
                    }
                    .disabled(self.name.isEmpty)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Save")
                    .accessibilityHint("Save the new deck")
                }
            }
            .navigationTitle("New Deck")
            .alert("Error", isPresented: .constant(self.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    self.errorMessage = nil
                }
            } message: {
                Text(self.errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func saveDeck() {
        let newDeck = Deck(
            name: name,
            icon: selectedIcon,
            order: existingDecks.count
        )
        self.modelContext.insert(newDeck)

        do {
            try self.modelContext.save()
            self.dismiss()
        } catch {
            Task { Analytics.trackError("save_deck", error: error) }
            self.errorMessage = "Failed to save deck: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AddDeckView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
