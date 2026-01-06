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
    @State private var isGeneratingSentences = false
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?

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
                        saveTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveTask = Task { await saveCard() }
                    }) {
                        HStack(spacing: 8) {
                            if isSaving {
                                if isGeneratingSentences {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Generating sentences...")
                                } else if isTranslating {
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
                    .disabled(word.isEmpty || definition.isEmpty || isSaving || isTranslating || isGeneratingSentences)
                }
            }
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    do {
                        let data = try await newItem.loadTransferable(type: Data.self)
                        imageData = data
                    } catch {
                        errorMessage = "Failed to load image: \(error.localizedDescription)"
                        logger.error("Image loading failed: \(error.localizedDescription)")
                        Analytics.trackError("image_load_failed", error: error)
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
        guard !Task.isCancelled else { return }

        isSaving = true
        defer {
            Task { @MainActor in
                isSaving = false
                isTranslating = false
                isGeneratingSentences = false
            }
        }

        // 1. Create Flashcard
        let flashcard = Flashcard(
            word: word,
            definition: definition,
            phonetic: phonetic.isEmpty ? nil : phonetic,
            imageData: imageData
        )
        flashcard.deck = selectedDeck

        // 2. Automatic translation
        isTranslating = true

        if AppSettings.isTranslationEnabled && TranslationService.shared.isConfigured {
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
                    flashcard.translationTargetLanguage = AppSettings.translationTargetLanguage

                    logger.info("Translation successful: '\(word)' -> '\(item.targetTranslation)' (CEFR: \(item.cefrLevel))")
                }
            } catch {
                logger.error("Translation failed: \(error.localizedDescription)")
                Analytics.trackError("translation_failed", error: error)
                errorMessage = "Translation failed, but card will be saved without it"
                // Auto-dismiss after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if errorMessage?.contains("Translation failed") == true {
                        errorMessage = nil
                    }
                }
            }
        } else if AppSettings.isTranslationEnabled && !TranslationService.shared.isConfigured {
            logger.warning("Translation enabled but API key not configured, skipping")
        }

        isTranslating = false

        // 2b. Automatic sentence generation (if translation enabled)
        if AppSettings.isTranslationEnabled && TranslationService.shared.isConfigured {
            isGeneratingSentences = true

            do {
                let sentenceVM = SentenceGenerationViewModel(modelContext: modelContext)
                await sentenceVM.generateSentences(for: flashcard)
            } catch {
                logger.error("Sentence generation failed: \(error.localizedDescription)")
                Analytics.trackError("sentence_generation_failed", error: error)
                // Card will still be saved without sentences
            }

            isGeneratingSentences = false
        }

        // 3. Create FSRSState for the card
        let state = FSRSState(
            stability: 0.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.new.rawValue
        )
        flashcard.fsrsState = state

        // 4. Insert and save in one atomic operation
        do {
            modelContext.insert(flashcard)
            modelContext.insert(state)
            try modelContext.save()
            dismiss()
        } catch {
            // Rollback: delete from context if save fails
            modelContext.delete(flashcard)
            modelContext.delete(state)
            Analytics.trackError("save_flashcard", error: error)
            errorMessage = "Failed to save flashcard: \(error.localizedDescription)"
        }
    }
}

#Preview("Add Flashcard") {
    AddFlashcardView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
