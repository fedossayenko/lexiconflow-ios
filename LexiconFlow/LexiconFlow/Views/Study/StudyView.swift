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
    @State private var isSessionActive = false

    var body: some View {
        NavigationStack {
            Group {
                if isSessionActive {
                    StudySessionView(mode: studyMode) {
                        sessionComplete()
                    }
                } else if dueCount > 0 {
                    VStack(spacing: 24) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("You have \(dueCount) cards due")
                            .font(.title2)
                            .multilineTextAlignment(.center)

                        Text(modeDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Picker("Study Mode", selection: $studyMode) {
                            Text("Scheduled").tag(StudyMode.scheduled)
                            Text("Cram").tag(StudyMode.cram)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .accessibilityLabel("Study mode selector")
                        .accessibilityHint("Choose between scheduled review or cram all cards")

                        Button(action: startSession) {
                            Text("Start Studying")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .accessibilityLabel("Start studying")
                        .accessibilityHint("Begin study session with \(dueCount) cards")
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
        case .scheduled:
            return "Review cards scheduled for today using the FSRS algorithm."
        case .cram:
            return "Practice all cards regardless of due date, ordered by difficulty."
        }
    }

    private func refreshDueCount() {
        let scheduler = Scheduler(modelContext: modelContext)
        if studyMode == .scheduled {
            dueCount = scheduler.dueCardCount()
        } else {
            // For cram mode, show total cards with FSRS state (including "new" cards)
            let stateDescriptor = FetchDescriptor<FSRSState>(
                predicate: #Predicate<FSRSState> { _ in
                    true
                }
            )
            do {
                dueCount = try modelContext.fetchCount(stateDescriptor)
            } catch {
                dueCount = 0
            }
        }
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
