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

    private let logger = Logger(subsystem: "com.lexiconflow.deckdetail", category: "BatchTranslation")
    private let translationService = TranslationService.shared

    // MARK: - Computed Properties

    /// Cards that don't have a translation yet (cached for efficiency)
    private var untranslatedCards: [Flashcard] {
        deck.cards.filter { $0.translation == nil }
    }

    var body: some View {
        List {
            if deck.cards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle")
                } description: {
                    Text("Add flashcards to this deck to get started")
                } actions: {
                    Button("Add Card") {
                        showingAddCard = true
                    }
                }
            } else {
                // Inline progress banner
                if isTranslating, let progress = translationProgress {
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
                                cancelTranslation()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    ForEach(deck.cards) { card in
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
                    .onDelete(perform: deleteCards)
                } header: {
                    Text("Flashcards (\(deck.cards.count))")
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddCard = true }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button("Translate All") {
                    showingTranslateConfirmation = true
                }
                .disabled(deck.cards.isEmpty || !AppSettings.isTranslationEnabled || !translationService.isConfigured || isTranslating)
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddFlashcardView(deck: deck)
        }
        .confirmationDialog(
            "Translate All Cards",
            isPresented: $showingTranslateConfirmation,
            titleVisibility: .visible
        ) {
            let count = untranslatedCards.count

            Button("Translate \(count) Cards") {
                translateAllCards()
            }
            .disabled(count == 0)

            Button("Cancel", role: .cancel) {}
        } message: {
            let count = untranslatedCards.count
            if count > 0 {
                Text("Translate \(count) cards without translation using Z.ai API.")
            } else {
                Text("All cards already have translations.")
            }
        }
        .alert("Translation Complete", isPresented: $showingTranslationResult) {
            Button("OK") {}
        } message: {
            if let result = translationResult {
                Text(result.summary)
            }
        }
        .onDisappear {
            // Cancel any ongoing translation when view disappears
            translationTask?.cancel()
            translationService.cancelBatchTranslation()
        }
    }

    // MARK: - Batch Translation

    private func translateAllCards() {
        // Cancel existing task if running
        translationTask?.cancel()

        isTranslating = true
        translationResult = nil

        let cardsToTranslate = untranslatedCards // Use computed property
        let total = cardsToTranslate.count

        logger.info("Starting batch translation of \(total) cards")

        // Background task - non-blocking but still can update @State
        translationTask = Task(priority: .userInitiated) { @MainActor in
            let startTime = Date()

            do {
                // Branch based on device capability
                // Use on-device translation (iOS 26+)
                logger.info("Using on-device translation (iOS 26 Translation framework)")
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
                            translationProgress = currentProgress
                        }
                    }
                )
                // Apply on-device translation results
                applyOnDeviceTranslationResults(result, cards: cardsToTranslate, startTime: startTime)

            } catch let error as TranslationService.TranslationError {
                handleTranslationError(error)
            } catch let error as OnDeviceTranslationError {
                handleOnDeviceTranslationError(error)
            } catch {
                handleTranslationError(.apiFailed)
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
            try modelContext.save()
            logger.info("Successfully saved on-device translations: \(result.successCount) cards")

            // Create result for UI
            translationResult = TranslationResult(
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

            logger.info("On-device batch translation complete: \(result.successCount) success, \(result.failedCount) failed, \(String(format: "%.2f", result.totalDuration))s")

        } catch {
            logger.error("Failed to save on-device translations: \(error.localizedDescription)")

            // Update result to reflect failure
            translationResult = TranslationResult(
                translatedCount: 0,
                skippedCount: 0,
                failedCount: cards.count,
                failedWords: cards.map(\.word)
            )

            Analytics.trackError("translation_save_failed", error: error)
        }

        // Clear state
        isTranslating = false
        translationProgress = nil
        showingTranslationResult = true
    }

    private func handleTranslationError(_ error: TranslationService.TranslationError) {
        logger.error("Batch translation failed: \(error.localizedDescription)")

        translationResult = TranslationResult(
            translatedCount: 0,
            skippedCount: 0,
            failedCount: deck.cards.count(where: { $0.translation == nil }),
            failedWords: []
        )

        // Clear state
        isTranslating = false
        translationProgress = nil
        showingTranslationResult = true
    }

    private func handleOnDeviceTranslationError(_ error: OnDeviceTranslationError) {
        logger.error("On-device translation failed: \(error.localizedDescription)")

        translationResult = TranslationResult(
            translatedCount: 0,
            skippedCount: 0,
            failedCount: deck.cards.count(where: { $0.translation == nil }),
            failedWords: []
        )

        // Clear state
        isTranslating = false
        translationProgress = nil
        showingTranslationResult = true
    }

    private func cancelTranslation() {
        translationTask?.cancel()
        TranslationService.shared.cancelBatchTranslation()
        isTranslating = false
        translationProgress = nil
        logger.info("Translation cancelled by user")
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            guard index >= 0, index < deck.cards.count else { continue }
            modelContext.delete(deck.cards[index])
        }
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
        if failedCount == 0 {
            return "Successfully translated \(translatedCount) card\(translatedCount == 1 ? "" : "s")."
        } else {
            let failedList = failedWords.prefix(3).joined(separator: ", ")
            let more = failedWords.count > 3 ? " and \(failedWords.count - 3) more" : ""
            return "Translated \(translatedCount) card\(translatedCount == 1 ? "" : "s").\n\nFailed: \(failedList)\(more)"
        }
    }
}

#Preview("Deck Detail") {
    NavigationStack {
        DeckDetailView(deck: Deck(name: "Sample Deck", icon: "star.fill"))
    }
    .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
