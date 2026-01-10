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

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            AppSettings.hasCompletedOnboarding = newValue
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
