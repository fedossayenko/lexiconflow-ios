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

                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(deckIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                    .frame(width: 30)
                            }
                            .tag(icon)
                        }
                    }
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
                        }
                    }
                    .padding(.vertical, 8)
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
            print("Failed to save deck: \(error)")
        }
    }
}

#Preview {
    AddDeckView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
