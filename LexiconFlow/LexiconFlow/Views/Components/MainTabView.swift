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

    private let scheduler: Scheduler

    init() {
        // Temporary storage for modelContext, will be set in body
        // Use a default that gets replaced immediately
        self.scheduler = Scheduler(modelContext: ModelContext(try! ModelContainer(for: Flashcard.self)))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DeckListView()
                .tabItem {
                    Label("Decks", systemImage: "book.fill")
                }
                .tag(0)

            StudyView()
                .tabItem {
                    Label("Study", systemImage: "brain.fill")
                }
                .tag(1)
                .badge(dueCardCount)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onAppear {
            refreshDueCount()
        }
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == 1 {
                refreshDueCount()
            }
        }
    }

    private func refreshDueCount() {
        let context = ModelContext(modelContext.container)
        let tempScheduler = Scheduler(modelContext: context)
        dueCardCount = tempScheduler.dueCardCount()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
