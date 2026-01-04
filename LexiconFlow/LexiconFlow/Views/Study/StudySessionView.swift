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
    let onComplete: () -> Void

    init(mode: StudyMode, onComplete: @escaping () -> Void) {
        self.mode = mode
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                if viewModel.isComplete {
                    sessionCompleteView(viewModel: viewModel)
                } else if let currentCard = viewModel.currentCard {
                    VStack(spacing: 30) {
                        // Progress indicator
                        Text(viewModel.progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top)

                        // Flashcard
                        FlashcardView(card: currentCard, isFlipped: $isFlipped)
                            .frame(maxHeight: .infinity)

                        // Rating buttons (show after flip)
                        if isFlipped {
                            RatingButtonsView { rating in
                                Task {
                                    await viewModel.submitRating(rating.rawValue)
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
                    .navigationTitle(mode == .scheduled ? "Study" : "Cram")
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.lastError?.localizedDescription ?? "An unknown error occurred")
        }
        .task {
            if viewModel == nil {
                viewModel = StudySessionViewModel(modelContext: modelContext, mode: mode)
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

    private func sessionCompleteView(viewModel: StudySessionViewModel) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)

            Text("You reviewed \(viewModel.cards.count) cards")
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Flashcard.self, configurations: config)
    let card = Flashcard(word: "Ephemeral", definition: "Lasting for a very short time")
    let state = FSRSState(stability: 0.0, difficulty: 5.0, retrievability: 0.9, dueDate: Date(), stateEnum: FlashcardState.new.rawValue)
    card.fsrsState = state
    container.mainContext.insert(card)
    container.mainContext.insert(state)

    return StudySessionView(mode: .scheduled) {}
        .modelContainer(container)
}
