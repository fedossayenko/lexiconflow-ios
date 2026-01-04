//
//  AddFlashcardView.swift
//  LexiconFlow
//
//  Form for creating a new flashcard
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddFlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var deck: Deck
    @Query(sort: \Deck.order) private var allDecks: [Deck]

    @State private var word = ""
    @State private var definition = ""
    @State private var phonetic = ""
    @State private var selectedDeck: Deck?
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("Word", text: $word)
                        .textInputAutocapitalization(.words)
                }

                Section("Definition") {
                    TextField("Definition", text: $definition, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Phonetic (Optional)") {
                    TextField("Phonetic", text: $phonetic)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Picker("Deck", selection: $selectedDeck) {
                        Text("No Deck").tag(nil as Deck?)
                        ForEach(allDecks) { deck in
                            Text(deck.name).tag(deck as Deck?)
                        }
                    }
                } header: {
                    Text("Add to Deck")
                }

                Section {
                    if let imageData = imageData, let image = UIImage(data: imageData) {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button("Remove Image") {
                                self.imageData = nil
                                selectedImage = nil
                            }
                            .foregroundStyle(.red)
                        }
                    }

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        Label(imageData == nil ? "Add Image" : "Change Image",
                              systemImage: imageData == nil ? "photo" : "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Image (Optional)")
                }
            }
            .navigationTitle("New Flashcard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveCard) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(word.isEmpty || definition.isEmpty || isSaving)
                }
            }
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .onAppear {
                selectedDeck = deck
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

    private func saveCard() {
        isSaving = true

        let flashcard = Flashcard(
            word: word,
            definition: definition,
            phonetic: phonetic.isEmpty ? nil : phonetic,
            imageData: imageData
        )
        flashcard.deck = selectedDeck

        // Create FSRSState for the card
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state

        modelContext.insert(flashcard)
        modelContext.insert(state)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            Analytics.trackError("save_flashcard", error: error)
            errorMessage = "Failed to save flashcard: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Flashcard.self, configurations: config)
    let deck = Deck(name: "Sample Deck", icon: "star.fill")
    container.mainContext.insert(deck)

    return AddFlashcardView(deck: deck)
        .modelContainer(container)
}
