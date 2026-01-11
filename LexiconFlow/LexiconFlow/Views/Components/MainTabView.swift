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
    @State private var scheduler: Scheduler? // Memoized scheduler for performance
    @State private var lastBadgeUpdate: Date? // Debouncing for badge updates

    @Query(sort: \Deck.order) private var decks: [Deck]

    var body: some View {
        TabView(selection: $selectedTab) {
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
            .badge(dueCardCount)
            .accessibilityIdentifier("study_tab")
            .accessibilityLabel(dueCardCount > 0 ? "Study, \(dueCardCount) cards due" : "Study")

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
            refreshDueCount()
        }
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == 1 {
                refreshDueCount()
            }
        }
        .onChange(of: AppSettings.selectedDeckIDs) { _, _ in
            refreshDueCount()
        }
    }

    private var selectedDecks: [Deck] {
        let selectedIDs = AppSettings.selectedDeckIDs
        return decks.filter { selectedIDs.contains($0.id) }
    }

    private func refreshDueCount() {
        // Debounce: only update badge if 5 seconds have passed (or on first load)
        // This prevents excessive queries during rapid tab switching
        if let lastUpdate = lastBadgeUpdate,
           Date().timeIntervalSince(lastUpdate) < 5.0
        {
            return
        }

        // Memoize scheduler to avoid creating new instance on every tab switch
        if scheduler == nil {
            scheduler = Scheduler(modelContext: modelContext)
        }
        dueCardCount = scheduler?.dueCardCount(for: selectedDecks) ?? 0
        lastBadgeUpdate = Date()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self, StudySession.self, DailyStats.self], inMemory: true)
}
