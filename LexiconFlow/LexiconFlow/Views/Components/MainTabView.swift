//
//  MainTabView.swift
//  LexiconFlow
//
//  Root navigation container with 3 tabs: Decks, Study, Settings
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var dueCardCount = 0
    @State private var scheduler: Scheduler?

    var body: some View {
        TabView(selection: $selectedTab) {
            DeckListView()
                .tabItem {
                    Label("Decks", systemImage: "book.fill")
                }
                .tag(0)
                .accessibilityIdentifier("decks_tab")

            StudyView()
                .tabItem {
                    Label("Study", systemImage: "brain.fill")
                }
                .tag(1)
                .badge(dueCardCount)
                .accessibilityIdentifier("study_tab")
                .accessibilityLabel(dueCardCount > 0 ? "Study, \(dueCardCount) cards due" : "Study")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
                .accessibilityIdentifier("settings_tab")
        }
        .task {
            if scheduler == nil {
                scheduler = Scheduler(modelContext: modelContext)
            }
            refreshDueCount()
        }
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == 1 {
                refreshDueCount()
            }
        }
    }

    private func refreshDueCount() {
        guard let scheduler = scheduler else { return }
        dueCardCount = scheduler.dueCardCount()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
