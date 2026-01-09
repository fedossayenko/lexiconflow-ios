//
//  MainTabView.swift
//  LexiconFlow
//
//  Root navigation container with 4 tabs: Decks, Study, Statistics, Settings
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var dueCardCount = 0

    @Query(sort: \Deck.order) private var decks: [Deck]

    var body: some View {
        TabView(selection: self.$selectedTab) {
            NavigationStack {
                DeckListView()
            }
            .tabItem {
                Label("Decks", systemImage: "book.fill")
            }
            .tag(0)
            .accessibilityIdentifier("decks_tab")

            NavigationStack {
                StudyView()
            }
            .tabItem {
                Label("Study", systemImage: "brain.fill")
            }
            .tag(1)
            .badge(self.dueCardCount)
            .accessibilityIdentifier("study_tab")
            .accessibilityLabel(self.dueCardCount > 0 ? "Study, \(self.dueCardCount) cards due" : "Study")

            NavigationStack {
                StatisticsDashboardView()
            }
            .tabItem {
                Label("Statistics", systemImage: "chart.bar.fill")
            }
            .tag(2)
            .accessibilityIdentifier("statistics_tab")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
            .accessibilityIdentifier("settings_tab")
        }
        .onAppear {
            self.refreshDueCount()
        }
        .onChange(of: self.selectedTab) { _, _ in
            if self.selectedTab == 1 {
                self.refreshDueCount()
            }
        }
        .onChange(of: AppSettings.selectedDeckIDs) { _, _ in
            self.refreshDueCount()
        }
    }

    private var selectedDecks: [Deck] {
        let selectedIDs = AppSettings.selectedDeckIDs
        return self.decks.filter { selectedIDs.contains($0.id) }
    }

    private func refreshDueCount() {
        let scheduler = Scheduler(modelContext: modelContext)
        self.dueCardCount = scheduler.dueCardCount(for: self.selectedDecks)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self, StudySession.self, DailyStats.self], inMemory: true)
}
