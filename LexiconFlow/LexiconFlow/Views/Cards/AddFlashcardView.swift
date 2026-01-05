//
//  AddFlashcardView.swift
//  LexiconFlow
//
//  Form for creating a new flashcard
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

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
    @State private var isTranslating = false
    @State private var errorMessage: String?

    @AppStorage("translationEnabled") private var translationEnabled = true
    @AppStorage("translationTargetLanguage") private var targetLanguage = "ru"

    private let logger = Logger(subsystem: "com.lexiconflow.flashcard", category: "AddFlashcardView")

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("Word", text: $word)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Word")
                        .accessibilityHint("Enter the vocabulary word")
                }

                Section("Definition") {
                    TextField("Definition", text: $definition, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Definition")
                        .accessibilityHint("Enter the word definition")
                }

                Section("Phonetic (Optional)") {
                    TextField("Phonetic", text: $phonetic)
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Phonetic")
                        .accessibilityHint("Enter pronunciation guide (optional)")
                }

                Section {
                    Picker("Deck", selection: $selectedDeck) {
                        Text("No Deck").tag(nil as Deck?)
                        ForEach(allDecks) { deck in
                            Text(deck.name).tag(deck as Deck?)
                        }
                    }
                    .accessibilityLabel("Deck picker")
                    .accessibilityHint("Select a deck to add this card to")
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
                                .accessibilityHidden(true)

                            Button("Remove Image") {
                                self.imageData = nil
                                selectedImage = nil
                            }
                            .foregroundStyle(.red)
                            .accessibilityLabel("Remove Image")
                            .accessibilityHint("Remove the selected image from the flashcard")
                        }
                    }

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        Label(imageData == nil ? "Add Image" : "Change Image",
                              systemImage: imageData == nil ? "photo" : "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel(imageData == nil ? "Add Image" : "Change Image")
                    .accessibilityHint("Open photo picker to select an image")
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
                    Button(action: { Task { await saveCard() } }) {
                        HStack(spacing: 8) {
                            if isSaving {
                                if isTranslating {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Translating...")
                                } else {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Saving...")
                                }
                            } else {
                                Text("Save")
                            }
                        }
                    }
                    .disabled(word.isEmpty || definition.isEmpty || isSaving || isTranslating)
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

    private func saveCard() async {
        isSaving = true

        // 1. Create Flashcard
        let flashcard = Flashcard(
            word: word,
            definition: definition,
            phonetic: phonetic.isEmpty ? nil : phonetic,
            imageData: imageData
        )
        flashcard.deck = selectedDeck

        // 2. Automatic translation - NEW
        isTranslating = true

        if translationEnabled && TranslationService.shared.isConfigured {
            do {
                let result = try await TranslationService.shared.translate(
                    word: word,
                    definition: definition,
                    context: nil
                )

                if let item = result.items.first {
                    flashcard.translation = item.targetTranslation
                    flashcard.cefrLevel = item.cefrLevel
                    flashcard.contextSentence = item.contextSentence
                    flashcard.translationSourceLanguage = "en"
                    flashcard.translationTargetLanguage = targetLanguage

                    logger.info("Translation successful: '\(word)' -> '\(item.targetTranslation)' (CEFR: \(item.cefrLevel))")
                }
            } catch {
                logger.error("Translation failed: \(error.localizedDescription)")
                // Card is still saved without translation
            }
        } else if translationEnabled && !TranslationService.shared.isConfigured {
            logger.warning("Translation enabled but API key not configured, skipping")
        }

        isTranslating = false

        // 3. Create FSRSState for the card
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

#Preview("Add Flashcard") {
    AddFlashcardView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
