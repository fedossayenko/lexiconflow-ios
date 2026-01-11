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
            checkOrphanedCards()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 {
                refreshDueCount()
            }
            // Navigate to orphaned cards when flag is set
            if navigateToOrphanedCards, newValue == 0 {
                navigateToOrphanedCards = false
                // Trigger navigation after a slight delay to ensure tab switch completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // The NavigationLink in DeckListView will handle the actual navigation
                }
            }
        }
        .onChange(of: AppSettings.selectedDeckIDs) { _, _ in
            refreshDueCount()
        }
        .alert("Orphaned Cards Found", isPresented: $showingOrphanedCardsAlert) {
            Button("View Orphaned Cards") {
                showingOrphanedCardsAlert = false
                selectedTab = 0
                navigateToOrphanedCards = true
            }
            Button("Later", role: .cancel) {
                showingOrphanedCardsAlert = false
            }
        } message: {
            Text("You have \(orphanedCardsCount) card\(orphanedCardsCount == 1 ? "" : "s") without deck assignment. These appear when decks are deleted. You can reassign them to existing decks in the Orphaned Cards section.")
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

        let count = OrphanedCardsService.shared.orphanedCardCount(context: modelContext)
        guard count > 0 else {
            // Mark as shown even if no orphans (no need to check again)
            AppSettings.hasShownOrphanedCardsPrompt = true
            return
        }

        orphanedCardsCount = count
        showingOrphanedCardsAlert = true
        AppSettings.hasShownOrphanedCardsPrompt = true
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
