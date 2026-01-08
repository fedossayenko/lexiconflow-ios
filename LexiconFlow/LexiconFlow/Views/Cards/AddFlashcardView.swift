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
    @State private var isCheckingLanguageAvailability = false
    @State private var showLanguageDownloadPrompt = false
    @State private var missingLanguage: String?
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
                    .disabled(word.isEmpty || definition.isEmpty || isSaving || isTranslating || isGeneratingSentences || isCheckingLanguageAvailability)
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
                        await Analytics.trackError("image_load_failed", error: error)
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
            .alert("Download Language Pack", isPresented: $showLanguageDownloadPrompt) {
                Button("Cancel", role: .cancel) {
                    missingLanguage = nil
                }
                Button("Download") {
                    if let language = missingLanguage {
                        Task {
                            await downloadLanguagePack(language)
                        }
                    }
                }
            } message: {
                if let language = missingLanguage {
                    Text("Language pack for \(language) is required for on-device translation. Download it now?")
                } else {
                    Text("Language pack download required")
                }
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

        // 2. Automatic translation (on-device only)
        isTranslating = true

        if AppSettings.isTranslationEnabled {
            await performOnDeviceTranslation(flashcard: flashcard)
        }

        isTranslating = false

        // 2b. Automatic sentence generation (if translation and sentence generation enabled)
        // Note: Sentence generation uses cloud TranslationService separately
        // This is an optional premium feature that requires both translation AND sentence generation to be enabled
        if AppSettings.isTranslationEnabled &&
           AppSettings.isSentenceGenerationEnabled &&
           TranslationService.shared.isConfigured {
            isGeneratingSentences = true

            do {
                let sentenceVM = SentenceGenerationViewModel(modelContext: modelContext)
                await sentenceVM.generateSentences(for: flashcard)
            } catch {
                logger.error("Sentence generation failed: \(error.localizedDescription)")
                await Analytics.trackError("sentence_generation_failed", error: error)
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
            await Analytics.trackError("save_flashcard", error: error)
            errorMessage = "Failed to save flashcard: \(error.localizedDescription)"
        }
    }

    // MARK: - Translation

    /// Perform on-device translation for a flashcard
    @MainActor
    private func performOnDeviceTranslation(flashcard: Flashcard) async {
        let sourceLanguage = AppSettings.translationSourceLanguage
        let targetLanguage = AppSettings.translationTargetLanguage

        logger.info("Attempting on-device translation: \(sourceLanguage) -> \(targetLanguage)")

        // Check language pack availability
        isCheckingLanguageAvailability = true

        let sourceAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(sourceLanguage)
        let targetAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(targetLanguage)

        isCheckingLanguageAvailability = false

        // Prompt for language pack download if needed
        if !sourceAvailable {
            missingLanguage = AppSettings.supportedLanguages.first { $0.code == sourceLanguage }?.name ?? sourceLanguage
            showLanguageDownloadPrompt = true
            logger.warning("Source language pack not available: \(sourceLanguage)")
            return
        }

        if !targetAvailable {
            missingLanguage = AppSettings.supportedLanguages.first { $0.code == targetLanguage }?.name ?? targetLanguage
            showLanguageDownloadPrompt = true
            logger.warning("Target language pack not available: \(targetLanguage)")
            return
        }

        // Perform on-device translation
        do {
            // Configure languages
            await OnDeviceTranslationService.shared.setLanguages(
                source: sourceLanguage,
                target: targetLanguage
            )

            // Translate the word
            let translatedWord = try await OnDeviceTranslationService.shared.translate(
                text: word,
                from: sourceLanguage,
                to: targetLanguage
            )

            // Note: On-device translation only provides translated text
            // We don't get CEFR level or context sentence from iOS Translation framework
            flashcard.translation = translatedWord

            logger.info("On-device translation successful: '\(word)' -> '\(translatedWord)'")

        } catch let error as OnDeviceTranslationError {
            logger.error("On-device translation failed: \(error.localizedDescription)")

            // Handle specific error types
            switch error {
            case .languagePackNotAvailable:
                errorMessage = "Language pack not available. Please download it in Settings."
                Task { await Analytics.trackError("on_device_translation_no_language_pack", error: error) }

            case .unsupportedLanguagePair:
                errorMessage = "Language pair not supported on this device"
                Task { await Analytics.trackError("on_device_translation_unsupported_pair", error: error) }

            default:
                errorMessage = "Translation failed: \(error.localizedDescription)"
                Task { await Analytics.trackError("on_device_translation_failed", error: error) }
            }

            // Auto-dismiss after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if errorMessage?.contains("Translation failed") == true || errorMessage?.contains("Language pack") == true {
                errorMessage = nil
            }

        } catch {
            logger.error("Unexpected on-device translation error: \(error.localizedDescription)")
            Task { await Analytics.trackError("on_device_translation_unexpected", error: error) }
            errorMessage = "Translation failed, but card will be saved without it"
        }
    }

    /// Download a missing language pack
    @MainActor
    private func downloadLanguagePack(_ languageCode: String) async {
        logger.info("Requesting language pack download for: \(languageCode)")

        do {
            try await OnDeviceTranslationService.shared.requestLanguageDownload(languageCode)

            // Success - retry translation
            logger.info("Language pack download initiated successfully")

            // Show success message
            errorMessage = "Language pack downloaded. You can now save the card."
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            errorMessage = nil

        } catch {
            logger.error("Language pack download failed: \(error.localizedDescription)")
            Task { await Analytics.trackError("language_pack_download_failed", error: error) }
            errorMessage = "Failed to download language pack: \(error.localizedDescription)"

            // Auto-dismiss after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            errorMessage = nil
        }

        missingLanguage = nil
    }
}

#Preview("Add Flashcard") {
    AddFlashcardView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
