//
//  DeckDetailView.swift
//  LexiconFlow
//
//  Shows deck details and lists all cards in the deck
//

import OSLog
import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddCard = false

    // MARK: - Batch Translation State

    @State private var showingTranslateConfirmation = false
    @State private var isTranslating = false
    @State private var translationProgress: TranslationProgress?
    @State private var translationResult: TranslationResult?
    @State private var showingTranslationResult = false
    @State private var translationTask: Task<Void, Never>?

    // MARK: - Cached State

    /// Cached list of untranslated cards to avoid O(n) scans during animations
    /// Performance: Eliminates redundant filter operations during view redraws
    @State private var untranslatedCards: [Flashcard] = []
    @State private var lastCardCount: Int = 0

    private let logger = Logger(subsystem: "com.lexiconflow.deckdetail", category: "BatchTranslation")
    private let translationService = TranslationService.shared

    var body: some View {
        List {
            if self.deck.cards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle")
                } description: {
                    Text("Add flashcards to this deck to get started")
                } actions: {
                    Button("Add Card") {
                        self.showingAddCard = true
                    }
                }
            } else {
                // Inline progress banner
                if self.isTranslating, let progress = translationProgress {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Translating \(progress.current)/\(progress.total)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let word = progress.currentWord {
                                    Text("Current: \(word)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button("Cancel") {
                                self.cancelTranslation()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    ForEach(self.deck.cards) { card in
                        NavigationLink(destination: FlashcardDetailView(flashcard: card)) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Word
                                Text(card.word)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                // Definition
                                Text(card.definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                // Translation indicator (if available)
                                if card.translation != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)

                                        Text("Translation available")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Card: \(card.word)")
                        .accessibilityHint("Double tap to view card details and review history")
                    }
                    .onDelete(perform: self.deleteCards)
                } header: {
                    Text("Flashcards (\(self.deck.cards.count))")
                }
            }
        }
        .navigationTitle(self.deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { self.showingAddCard = true }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button("Translate All") {
                    self.showingTranslateConfirmation = true
                }
                .disabled(self.deck.cards.isEmpty || !AppSettings.isTranslationEnabled || !self.translationService.isConfigured || self.isTranslating)
            }
        }
        .sheet(isPresented: self.$showingAddCard) {
            AddFlashcardView(deck: self.deck)
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Translate All Cards",
            isPresented: self.$showingTranslateConfirmation,
            titleVisibility: .visible
        ) {
            let count = self.untranslatedCards.count

            Button("Translate \(count) Cards") {
                self.translateAllCards()
            }
            .disabled(count == 0)

            Button("Cancel", role: .cancel) {}
        } message: {
            let count = self.untranslatedCards.count
            if count > 0 {
                Text("Translate \(count) cards without translation using Z.ai API.")
            } else {
                Text("All cards already have translations.")
            }
        }
        .alert("Translation Complete", isPresented: self.$showingTranslationResult) {
            Button("OK") {}
        } message: {
            if let result = translationResult {
                Text(result.summary)
            }
        }
        .onAppear {
            // Initialize cached untranslated cards on view appear
            self.updateUntranslatedCards()
        }
        .onChange(of: self.deck.cards.count) { _, _ in
            // Update cache when cards are added or deleted
            self.updateUntranslatedCards()
        }
        .onChange(of: self.deck.cards.compactMap(\.translation).count) { _, _ in
            // Update cache when translations change
            self.updateUntranslatedCards()
        }
        .onDisappear {
            // Cancel any ongoing translation when view disappears
            self.translationTask?.cancel()
            self.translationService.cancelBatchTranslation()
        }
    }

    // MARK: - Batch Translation

    private func translateAllCards() {
        // Cancel existing task if running
        self.translationTask?.cancel()

        self.isTranslating = true
        self.translationResult = nil

        // Use cached untranslated cards (updated via onChange modifiers)
        let cardsToTranslate = self.untranslatedCards
        let total = cardsToTranslate.count

        self.logger.info("Starting batch translation of \(total) cards")

        // Background task - non-blocking but still can update @State
        self.translationTask = Task(priority: .userInitiated) { @MainActor in
            let startTime = Date()

            do {
                // Branch based on device capability
                // Use on-device translation (iOS 26+)
                self.logger.info("Using on-device translation (iOS 26 Translation framework)")
                let result = try await OnDeviceTranslationService.shared.translateBatch(
                    cardsToTranslate.map(\.word),
                    maxConcurrency: 5,
                    progressHandler: { progress in
                        // Create local value to avoid capturing @State in Sendable closure
                        let currentProgress = TranslationProgress(
                            current: progress.current,
                            total: progress.total,
                            currentWord: progress.currentWord
                        )
                        // Explicit main actor dispatch for @State mutation
                        Task { @MainActor in
                            self.translationProgress = currentProgress
                        }
                    }
                )
                // Apply on-device translation results
                self.applyOnDeviceTranslationResults(result, cards: cardsToTranslate, startTime: startTime)

            } catch let error as TranslationService.TranslationError {
                handleTranslationError(error)
            } catch let error as OnDeviceTranslationError {
                handleOnDeviceTranslationError(error)
            } catch {
                self.handleTranslationError(.apiFailed)
            }
        }
    }

    private func applyOnDeviceTranslationResults(
        _ result: OnDeviceTranslationService.BatchTranslationResult,
        cards: [Flashcard],
        startTime _: Date
    ) {
        // Apply each successful translation to its card
        // Note: On-device translation only provides translation text (no CEFR/context sentences)
        for translation in result.successfulTranslations {
            // Match word to card
            if let card = cards.first(where: { $0.word == translation.sourceText }) {
                card.translation = translation.translatedText
            }
        }

        // Save all changes with proper error handling
        do {
            try self.modelContext.save()
            self.logger.info("Successfully saved on-device translations: \(result.successCount) cards")

            // Update cache after translations are saved
            self.updateUntranslatedCards()

            // Create result for UI
            self.translationResult = TranslationResult(
                translatedCount: result.successCount,
                skippedCount: 0,
                failedCount: result.failedCount,
                failedWords: result.errors.map { error in
                    switch error {
                    case let .unsupportedLanguagePair(source, _):
                        source
                    case let .languagePackNotAvailable(source, _):
                        source
                    case let .languagePackDownloadFailed(language):
                        language
                    case let .translationFailed(reason):
                        reason
                    case .emptyInput:
                        "empty input"
                    }
                }
            )

            self.logger.info("On-device batch translation complete: \(result.successCount) success, \(result.failedCount) failed, \(String(format: "%.2f", result.totalDuration))s")

        } catch {
            self.logger.error("Failed to save on-device translations: \(error.localizedDescription)")

            // Update result to reflect failure
            self.translationResult = TranslationResult(
                translatedCount: 0,
                skippedCount: 0,
                failedCount: cards.count,
                failedWords: cards.map(\.word)
            )

            Analytics.trackError("translation_save_failed", error: error)
        }

        // Clear state
        self.isTranslating = false
        self.translationProgress = nil
        self.showingTranslationResult = true
    }

    private func handleTranslationError(_ error: TranslationService.TranslationError) {
        self.logger.error("Batch translation failed: \(error.localizedDescription)")

        self.translationResult = TranslationResult(
            translatedCount: 0,
            skippedCount: 0,
            failedCount: self.deck.cards.count(where: { $0.translation == nil }),
            failedWords: []
        )

        // Clear state
        self.isTranslating = false
        self.translationProgress = nil
        self.showingTranslationResult = true
    }

    private func handleOnDeviceTranslationError(_ error: OnDeviceTranslationError) {
        self.logger.error("On-device translation failed: \(error.localizedDescription)")

        self.translationResult = TranslationResult(
            translatedCount: 0,
            skippedCount: 0,
            failedCount: self.deck.cards.count(where: { $0.translation == nil }),
            failedWords: []
        )

        // Clear state
        self.isTranslating = false
        self.translationProgress = nil
        self.showingTranslationResult = true
    }

    private func cancelTranslation() {
        self.translationTask?.cancel()
        TranslationService.shared.cancelBatchTranslation()
        self.isTranslating = false
        self.translationProgress = nil
        self.logger.info("Translation cancelled by user")
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < self.deck.cards.count else { continue }
            self.modelContext.delete(self.deck.cards[index])
        }
    }

    // MARK: - Cache Management

    /// Updates the cached untranslated cards list
    ///
    /// Called on view appear and when card translations change.
    /// Performance: O(n) scan only when necessary, not during every redraw
    private func updateUntranslatedCards() {
        self.lastCardCount = self.deck.cards.count
        self.untranslatedCards = self.deck.cards.filter { $0.translation == nil }
    }
}

// MARK: - Progress & Result Types

struct TranslationProgress {
    let current: Int
    let total: Int
    let currentWord: String?
}

struct TranslationResult {
    let translatedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let failedWords: [String]

    var summary: String {
        if self.failedCount == 0 {
            return "Successfully translated \(self.translatedCount) card\(self.translatedCount == 1 ? "" : "s")."
        } else {
            let failedList = self.failedWords.prefix(3).joined(separator: ", ")
            let more = self.failedWords.count > 3 ? " and \(self.failedWords.count - 3) more" : ""
            return "Translated \(self.translatedCount) card\(self.translatedCount == 1 ? "" : "s").\n\nFailed: \(failedList)\(more)"
        }
    }
}

#Preview("Deck Detail") {
    NavigationStack {
        DeckDetailView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
    }
    .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
