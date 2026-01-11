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

    // Orphaned cards onboarding state
    @State private var showingOrphanedCardsAlert = false
    @State private var orphanedCardsCount = 0
    @State private var navigateToOrphanedCards = false

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
            self.checkOrphanedCards()
        }
        .onChange(of: self.selectedTab) { _, newValue in
            if newValue == 1 {
                self.refreshDueCount()
            }
            // Navigate to orphaned cards when flag is set
            if self.navigateToOrphanedCards, newValue == 0 {
                self.navigateToOrphanedCards = false
                // Trigger navigation after a slight delay to ensure tab switch completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // The NavigationLink in DeckListView will handle the actual navigation
                }
            }
        }
        .onChange(of: AppSettings.selectedDeckIDs) { _, _ in
            self.refreshDueCount()
        }
        .alert("Orphaned Cards Found", isPresented: self.$showingOrphanedCardsAlert) {
            Button("View Orphaned Cards") {
                self.showingOrphanedCardsAlert = false
                self.selectedTab = 0
                self.navigateToOrphanedCards = true
            }
            Button("Later", role: .cancel) {
                self.showingOrphanedCardsAlert = false
            }
        } message: {
            Text("You have \(self.orphanedCardsCount) card\(self.orphanedCardsCount == 1 ? "" : "s") without deck assignment. These appear when decks are deleted. You can reassign them to existing decks in the Orphaned Cards section.")
        }
    }

    // MARK: - Orphaned Cards Onboarding

    /// Checks for orphaned cards and shows onboarding notification if needed
    ///
    /// This runs on first launch after the orphaned cards feature is introduced.
    /// Users who already have orphaned cards will be informed about the feature.
    private func checkOrphanedCards() {
        // Only check once per app install
        guard !AppSettings.hasShownOrphanedCardsPrompt else { return }

        let count = OrphanedCardsService.shared.orphanedCardCount(context: self.modelContext)
        guard count > 0 else {
            // Mark as shown even if no orphans (no need to check again)
            AppSettings.hasShownOrphanedCardsPrompt = true
            return
        }

        self.orphanedCardsCount = count
        self.showingOrphanedCardsAlert = true
        AppSettings.hasShownOrphanedCardsPrompt = true
    }

    private var selectedDecks: [Deck] {
        let selectedIDs = AppSettings.selectedDeckIDs
        return self.decks.filter { selectedIDs.contains($0.id) }
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
        if self.scheduler == nil {
            self.scheduler = Scheduler(modelContext: self.modelContext)
        }
        self.dueCardCount = self.scheduler?.dueCardCount(for: self.selectedDecks) ?? 0
        self.lastBadgeUpdate = Date()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self, StudySession.self, DailyStats.self], inMemory: true)
}
