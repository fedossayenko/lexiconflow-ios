//
//  StudySessionView.swift
//  LexiconFlow
//
//  Displays current card and handles rating input
//

import SwiftUI
import SwiftData

struct StudySessionView: View {
    @StateObject private var viewModel: StudySessionViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isFlipped = false
    let mode: StudyMode
    let onComplete: () -> Void

    init(mode: StudyMode, onComplete: @escaping () -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        // Temporarily initialize with nil modelContext, will be set in body
        self._viewModel = StateObject(wrappedValue: StudySessionViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Flashcard.self)),
            mode: mode
        ))
    }

    var body: some View {
        Group {
            if viewModel.isComplete {
                sessionCompleteView
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
                    .onAppear {
                        let context = ModelContext(modelContext.container)
                        let tempViewModel = StudySessionViewModel(modelContext: context, mode: mode)
                        tempViewModel.loadCards()
                    }
            }
        }
        .onAppear {
            if viewModel.cards.isEmpty {
                let context = ModelContext(modelContext.container)
                viewModel.loadCards()
            }
        }
    }

    private var sessionCompleteView: some View {
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
