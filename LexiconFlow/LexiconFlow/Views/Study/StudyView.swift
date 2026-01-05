//
//  StudyView.swift
//  LexiconFlow
//
//  Entry point for study sessions
//

import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var studyMode: StudyMode = .scheduled
    @State private var dueCount = 0
    @State private var newCardCount = 0
    @State private var isSessionActive = false

    var body: some View {
        NavigationStack {
            Group {
                if isSessionActive {
                    StudySessionView(mode: studyMode) {
                        sessionComplete()
                    }
                } else if hasCardsToStudy {
                    VStack(spacing: 24) {
                        Image(systemName: modeIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text(modeTitle)
                            .font(.title2)
                            .multilineTextAlignment(.center)

                        Text(modeDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Picker("Study Mode", selection: $studyMode) {
                            Text("Learn New").tag(StudyMode.learning)
                            Text("Scheduled").tag(StudyMode.scheduled)
                            Text("Cram").tag(StudyMode.cram)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .accessibilityLabel("Study mode selector")
                        .accessibilityHint("Choose between learning new cards, scheduled review, or cram all cards")

                        Button(action: startSession) {
                            Text("Start Studying")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .accessibilityLabel("Start studying")
                        .accessibilityHint("Begin study session with \(studyMode == .learning ? newCardCount : dueCount) cards")
                    }
                    .padding()
                    .navigationTitle("Study")
                } else {
                    StudyEmptyView(mode: studyMode, onSwitchMode: { newMode in
                        studyMode = newMode
                        refreshDueCount()
                    })
                }
            }
            .onAppear {
                refreshDueCount()
            }
            .onChange(of: studyMode) { _, _ in
                refreshDueCount()
            }
        }
    }

    private var modeDescription: String {
        switch studyMode {
        case .learning:
            return "Learn new vocabulary for the first time. Cards will go through initial learning steps."
        case .scheduled:
            return "Review cards scheduled for today using the FSRS algorithm."
        case .cram:
            return "Practice all cards regardless of due date, ordered by difficulty."
        }
    }

    private var hasCardsToStudy: Bool {
        switch studyMode {
        case .learning:
            return newCardCount > 0
        case .scheduled:
            return dueCount > 0
        case .cram:
            return dueCount > 0 || newCardCount > 0
        }
    }

    private var modeTitle: String {
        switch studyMode {
        case .learning:
            return "\(newCardCount) new cards to learn"
        case .scheduled:
            return "\(dueCount) cards due"
        case .cram:
            let total = dueCount + newCardCount
            return "\(total) cards to practice"
        }
    }

    private var modeIcon: String {
        switch studyMode {
        case .learning:
            return "plus.circle.fill"
        case .scheduled:
            return "brain.head.profile"
        case .cram:
            return "arrow.triangle.2.circlepath"
        }
    }

    private func refreshDueCount() {
        let scheduler = Scheduler(modelContext: modelContext)
        dueCount = scheduler.dueCardCount()
        newCardCount = scheduler.newCardCount()
    }

    private func startSession() {
        isSessionActive = true
    }

    private func sessionComplete() {
        isSessionActive = false
        refreshDueCount()
    }
}

#Preview {
    StudyView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
