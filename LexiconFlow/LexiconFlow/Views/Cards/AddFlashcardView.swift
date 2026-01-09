//
//  AddFlashcardView.swift
//  LexiconFlow
//
//  Form for creating a new flashcard
//

import OSLog
import PhotosUI
import SwiftData
import SwiftUI
import Translation

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

    // MARK: - Language Pack Download Configuration

    /// Configuration for triggering language pack downloads via .translationTask()
    ///
    /// **Important**: Language pack downloads must use SwiftUI's .translationTask() modifier
    /// because the TranslationSession API only works within SwiftUI views.
    @State private var downloadConfiguration: TranslationSession.Configuration?

    private let logger = Logger(subsystem: "com.lexiconflow.flashcard", category: "AddFlashcardView")

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("Word", text: self.$word)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Word")
                        .accessibilityHint("Enter the vocabulary word")
                }

                Section("Definition") {
                    TextField("Definition", text: self.$definition, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityLabel("Definition")
                        .accessibilityHint("Enter the word definition")
                }

                Section("Phonetic (Optional)") {
                    TextField("Phonetic", text: self.$phonetic)
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Phonetic")
                        .accessibilityHint("Enter pronunciation guide (optional)")
                }

                Section {
                    Picker("Deck", selection: self.$selectedDeck) {
                        Text("No Deck").tag(nil as Deck?)
                        ForEach(self.allDecks) { deck in
                            Text(deck.name).tag(deck as Deck?)
                        }
                    }
                    .accessibilityLabel("Deck picker")
                    .accessibilityHint("Select a deck to add this card to")
                } header: {
                    Text("Add to Deck")
                }

                Section {
                    if let imageData, let image = UIImage(data: imageData) {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityHidden(true)

                            Button("Remove Image") {
                                self.imageData = nil
                                self.selectedImage = nil
                            }
                            .foregroundStyle(Theme.Colors.destructive)
                            .accessibilityLabel("Remove Image")
                            .accessibilityHint("Remove the selected image from the flashcard")
                        }
                    }

                    PhotosPicker(selection: self.$selectedImage, matching: .images) {
                        Label(
                            imageData == nil ? "Add Image" : "Change Image",
                            systemImage: imageData == nil ? "photo" : "arrow.triangle.2.circlepath"
                        )
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
                        self.saveTask?.cancel()
                        self.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        self.saveTask = Task { await self.saveCard() }
                    }) {
                        HStack(spacing: 8) {
                            if self.isSaving {
                                if self.isGeneratingSentences {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Generating sentences...")
                                } else if self.isTranslating {
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
                    .disabled(self.word.isEmpty || self.definition.isEmpty || self.isSaving || self.isTranslating || self.isGeneratingSentences || self.isCheckingLanguageAvailability)
                }
            }
            .onChange(of: self.selectedImage) { _, newItem in
                Task {
                    guard let newItem else { return }
                    do {
                        let data = try await newItem.loadTransferable(type: Data.self)
                        self.imageData = data
                    } catch {
                        self.errorMessage = "Failed to load image: \(error.localizedDescription)"
                        self.logger.error("Image loading failed: \(error.localizedDescription)")
                        Analytics.trackError("image_load_failed", error: error)
                    }
                }
            }
            .onAppear {
                self.selectedDeck = self.deck
            }
            .alert("Error", isPresented: .constant(self.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    self.errorMessage = nil
                }
            } message: {
                Text(self.errorMessage ?? "An unknown error occurred")
            }
            .alert("Download Language Pack", isPresented: self.$showLanguageDownloadPrompt) {
                Button("Cancel", role: .cancel) {
                    self.missingLanguage = nil
                }
                Button("Download") {
                    if let language = missingLanguage {
                        Task {
                            await self.downloadLanguagePack(language)
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
        .translationTask(self.downloadConfiguration) { session in
            // This closure is called when downloadConfiguration changes
            // prepareTranslation() triggers the system download prompt for language packs
            do {
                try await session.prepareTranslation()
                self.logger.info("Language pack download completed successfully")

                // Show success message and clear error
                self.errorMessage = "Language pack downloaded. You can now save the card."
                try? await Task.sleep(nanoseconds: 2000000000)
                self.errorMessage = nil

            } catch {
                self.logger.error("Language pack download failed: \(error.localizedDescription)")
                Analytics.trackError("language_pack_download_failed", error: error)
                self.errorMessage = "Failed to download language pack: \(error.localizedDescription)"

                // Auto-dismiss after 3 seconds
                try? await Task.sleep(nanoseconds: 3000000000)
                self.errorMessage = nil
            }

            // Reset state
            self.missingLanguage = nil
            self.downloadConfiguration = nil
        }
    }

    private func saveCard() async {
        guard !Task.isCancelled else { return }

        self.isSaving = true
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
            phonetic: phonetic.isEmpty ? nil : self.phonetic,
            imageData: self.imageData
        )
        flashcard.deck = self.selectedDeck

        // 2. Automatic translation (on-device only)
        self.isTranslating = true

        if AppSettings.isTranslationEnabled {
            await self.performOnDeviceTranslation(flashcard: flashcard)
        }

        self.isTranslating = false

        // 2b. Automatic sentence generation (if translation and sentence generation enabled)
        // Note: Sentence generation uses cloud TranslationService separately
        // This is an optional premium feature that requires both translation AND sentence generation to be enabled
        if AppSettings.isTranslationEnabled,
           AppSettings.isSentenceGenerationEnabled,
           TranslationService.shared.isConfigured
        {
            self.isGeneratingSentences = true

            let sentenceVM = SentenceGenerationViewModel(modelContext: modelContext)
            await sentenceVM.generateSentences(for: flashcard)

            self.isGeneratingSentences = false
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
            self.modelContext.insert(flashcard)
            self.modelContext.insert(state)
            try self.modelContext.save()
            self.dismiss()
        } catch {
            // Rollback: delete from context if save fails
            self.modelContext.delete(flashcard)
            self.modelContext.delete(state)
            Analytics.trackError("save_flashcard", error: error)
            self.errorMessage = "Failed to save flashcard: \(error.localizedDescription)"
        }
    }

    // MARK: - Translation

    /// Perform on-device translation for a flashcard
    @MainActor
    private func performOnDeviceTranslation(flashcard: Flashcard) async {
        let sourceLanguage = AppSettings.translationSourceLanguage
        let targetLanguage = AppSettings.translationTargetLanguage

        self.logger.info("Attempting on-device translation: \(sourceLanguage) -> \(targetLanguage)")

        // Check language pack availability
        self.isCheckingLanguageAvailability = true

        let sourceAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(sourceLanguage)
        let targetAvailable = await OnDeviceTranslationService.shared.isLanguageAvailable(targetLanguage)

        self.isCheckingLanguageAvailability = false

        // Prompt for language pack download if needed
        if !sourceAvailable {
            self.missingLanguage = AppSettings.supportedLanguages.first { $0.code == sourceLanguage }?.name ?? sourceLanguage
            self.showLanguageDownloadPrompt = true
            self.logger.warning("Source language pack not available: \(sourceLanguage)")
            return
        }

        if !targetAvailable {
            self.missingLanguage = AppSettings.supportedLanguages.first { $0.code == targetLanguage }?.name ?? targetLanguage
            self.showLanguageDownloadPrompt = true
            self.logger.warning("Target language pack not available: \(targetLanguage)")
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
                text: self.word,
                from: sourceLanguage,
                to: targetLanguage
            )

            // Note: On-device translation only provides translated text
            // We don't get CEFR level or context sentence from iOS Translation framework
            flashcard.translation = translatedWord

            self.logger.info("On-device translation successful: '\(self.word)' -> '\(translatedWord)'")

        } catch let error as OnDeviceTranslationError {
            logger.error("On-device translation failed: \(error.localizedDescription)")

            // Handle specific error types
            switch error {
            case .languagePackNotAvailable:
                errorMessage = "Language pack not available. Please download it in Settings."
                Analytics.trackError("on_device_translation_no_language_pack", error: error)

            case .unsupportedLanguagePair:
                errorMessage = "Language pair not supported on this device"
                Analytics.trackError("on_device_translation_unsupported_pair", error: error)

            default:
                errorMessage = "Translation failed: \(error.localizedDescription)"
                Analytics.trackError("on_device_translation_failed", error: error)
            }

            // Auto-dismiss after 3 seconds
            try? await Task.sleep(nanoseconds: 3000000000)
            if errorMessage?.contains("Translation failed") == true || errorMessage?.contains("Language pack") == true {
                errorMessage = nil
            }

        } catch {
            self.logger.error("Unexpected on-device translation error: \(error.localizedDescription)")
            Analytics.trackError("on_device_translation_unexpected", error: error)
            self.errorMessage = "Translation failed, but card will be saved without it"
        }
    }

    /// Download a missing language pack
    ///
    /// **Important**: This creates a TranslationSession.Configuration to trigger download
    /// via the .translationTask() modifier. The prepareTranslation() method is the only
    /// API that properly triggers the system download prompt for language packs.
    @MainActor
    private func downloadLanguagePack(_ languageCode: String) async {
        self.logger.info("Requesting language pack download for: \(languageCode)")

        let language = Locale.Language(identifier: languageCode)
        let target = Locale.Language(identifier: AppSettings.translationSourceLanguage)

        // Create configuration to trigger download via .translationTask()
        // This is the Apple-documented pattern for language pack downloads
        self.downloadConfiguration = TranslationSession.Configuration(
            source: language,
            target: target
        )
    }
}

#Preview("Add Flashcard") {
    AddFlashcardView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
