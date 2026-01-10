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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if self.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
