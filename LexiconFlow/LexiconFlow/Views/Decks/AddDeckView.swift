//
//  AddDeckView.swift
//  LexiconFlow
//
//  Form for creating a new deck
//

import SwiftUI
import SwiftData

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
                    TextField("Deck Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Deck Name")
                        .accessibilityHint("Enter a name for the new deck")

                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(deckIcons, id: \.self) { icon in
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
                        ForEach(deckIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Icon \(icon)")
                            .accessibilityHint(selectedIcon == icon ? "Currently selected" : "Select this icon")
                            .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Icon grid")
                } header: {
                    Text("Choose Icon")
                }
            }
            .navigationTitle("New Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDeck()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func saveDeck() {
        let newDeck = Deck(
            name: name,
            icon: selectedIcon,
            order: existingDecks.count
        )
        modelContext.insert(newDeck)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            Analytics.trackError("save_deck", error: error)
            errorMessage = "Failed to save deck: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AddDeckView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
