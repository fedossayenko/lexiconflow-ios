//
//  ContentView.swift
//  LexiconFlow
//
//  Root view for the LexiconFlow app
//  Routes between Onboarding and MainTabView based on first launch
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // Use centralized AppSettings instead of direct @AppStorage (CLAUDE.md pattern #4)
    @State private var hasCompletedOnboarding: Bool = AppSettings.hasCompletedOnboarding
    @State private var selectedTab: Int = 0

    var body: some View {
        Group {
            if self.hasCompletedOnboarding {
                MainTabView(selectedTab: self.$selectedTab)
            } else {
                OnboardingView()
            }
        }
        .onChange(of: self.hasCompletedOnboarding) { _, newValue in
            AppSettings.hasCompletedOnboarding = newValue
        }
        .onOpenURL { url in
            self.handleOpenURL(url)
        }
    }

    private func handleOpenURL(_ url: URL) {
        // Handle deep links from Widgets and App Intents
        if url.scheme == "lexiconflow" {
            switch url.host {
            case "study":
                self.selectedTab = 1 // Switch to Study tab
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
