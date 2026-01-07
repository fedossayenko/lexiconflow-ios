//
//  StudySessionView.swift
//  LexiconFlow
//
//  Displays current card and handles rating input
//

import SwiftUI
import SwiftData

struct StudySessionView: View {
    @State private var viewModel: StudySessionViewModel?
    @Environment(\.modelContext) private var modelContext
    @State private var isFlipped = false
    @State private var showError = false
    let mode: StudyMode
    let decks: [Deck]
    let onComplete: () -> Void

    init(mode: StudyMode, decks: [Deck] = [], onComplete: @escaping () -> Void) {
        self.mode = mode
        self.decks = decks
        self.onComplete = onComplete
    }

    var body: some View {
        @ViewBuilder var content: some View {
            if let viewModel = viewModel {
                if viewModel.isComplete {
                    sessionCompleteView(vm: viewModel)
                } else if let currentCard = viewModel.currentCard {
                    VStack(spacing: 30) {
                        // Progress indicator
                        Text(viewModel.progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top)

                        // Flashcard
                        FlashcardView(card: currentCard, isFlipped: $isFlipped) { rating in
                            // IMPORTANT: Capture card reference NOW before async Task
                            // Don't rely on viewModel.currentCard which might change
                            let cardToRate = currentCard

                            // Handle swipe-to-rate
                            Task {
                                await viewModel.submitRating(rating, card: cardToRate)
                                withAnimation {
                                    isFlipped = false
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .id(currentCard.persistentModelID)  // View identity tied to card
                        .opacity(viewModel.isComplete ? 0 : 1)  // Hide when complete

                        // Rating buttons (show after flip)
                        if isFlipped {
                            RatingButtonsView { rating in
                                // Capture card reference before async
                                let cardToRate = currentCard
                                Task {
                                    await viewModel.submitRating(rating.rawValue, card: cardToRate)
                                    withAnimation {
                                        isFlipped = false
                                    }
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Text("Tap card to flip")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .navigationTitle(mode == .learning ? "Learn New" : "Study")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Exit") {
                                onComplete()
                            }
                        }
                    }
                } else {
                    ProgressView("Loading cards...")
                }
            } else {
                ProgressView("Loading session...")
            }
        }

        return content
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel?.lastError?.localizedDescription ?? "An unknown error occurred")
            }
            .task {
                if viewModel == nil {
                    viewModel = StudySessionViewModel(modelContext: modelContext, decks: decks, mode: mode)
                }
                if let viewModel = viewModel, viewModel.cards.isEmpty {
                    viewModel.loadCards()
                }
            }
            .onChange(of: viewModel?.lastError != nil) { _, hasError in
                if hasError {
                    showError = true
                }
            }
    }

    private func sessionCompleteView(vm: StudySessionViewModel) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)

            Text("You reviewed \(vm.cards.count) cards")
                .foregroundStyle(.secondary)

            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview("Study Session") {
    StudySessionView(mode: .scheduled) {}
        .modelContainer(for: [Flashcard.self], inMemory: true)
}
