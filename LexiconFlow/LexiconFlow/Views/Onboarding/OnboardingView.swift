//
//  OnboardingView.swift
//  LexiconFlow
//
//  First-launch welcome screen with app introduction and sample deck creation
//

import OSLog
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    // Use centralized AppSettings instead of direct @AppStorage (CLAUDE.md pattern #4)
    @State private var hasCompletedOnboarding: Bool = AppSettings.hasCompletedOnboarding
    @State private var currentPage = 0
    @State private var isCreatingSampleDeck = false
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "com.lexiconflow.onboarding", category: "Onboarding")

    private let pages = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Welcome to Lexicon Flow",
            description: "Master vocabulary with the power of spaced repetition."
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "FSRS v5 Algorithm",
            description: "Our advanced algorithm schedules reviews at the optimal time for maximum retention."
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Ready to Start",
            description: "IELTS vocabulary has been pre-loaded. Start learning now!"
        )
    ]

    var body: some View {
        TabView(selection: self.$currentPage) {
            ForEach(0 ..< self.pages.count, id: \.self) { index in
                OnboardingPageView(page: self.pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding pages")
        .toolbar {
            if self.currentPage == self.pages.count - 1 {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: self.completeOnboarding) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Get Started")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(self.isCreatingSampleDeck)
                    .accessibilityLabel("Get Started")
                }
            }
        }
        .alert("Error", isPresented: .constant(self.errorMessage != nil)) {
            Button("Retry", role: .cancel) {
                self.errorMessage = nil
                self.completeOnboarding()
            }
            Button("Cancel", role: .destructive) {
                self.errorMessage = nil
                self.isCreatingSampleDeck = false
            }
        } message: {
            Text(self.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Sample Deck

    private func completeOnboarding() {
        self.isCreatingSampleDeck = true

        Task { @MainActor in
            // Create sample deck
            let sampleDeck = Deck(name: "Sample Vocabulary", icon: "star.fill", order: 0)
            self.modelContext.insert(sampleDeck)

            // Create sample flashcards
            let sampleCards = [
                (word: "Ephemeral", definition: "Lasting for a very short time", phonetic: "/əˈfem(ə)rəl/"),
                (word: "Serendipity", definition: "Finding something good without looking for it", phonetic: "/ˌserənˈdipədē/"),
                (word: "Eloquent", definition: "Fluent or persuasive in speaking or writing", phonetic: "/ˈeləkwənt/"),
                (word: "Meticulous", definition: "Showing great attention to detail", phonetic: "/məˈtikyələs/"),
                (word: "Pragmatic", definition: "Dealing with things sensibly and realistically", phonetic: "/praɡˈmadik/")
            ]

            for cardData in sampleCards {
                let card = Flashcard(
                    word: cardData.word,
                    definition: cardData.definition,
                    phonetic: cardData.phonetic
                )
                card.deck = sampleDeck

                // Create FSRSState for the card
                let state = FSRSState(
                    stability: 0.0,
                    difficulty: 5.0,
                    retrievability: 0.9,
                    dueDate: Date(),
                    stateEnum: FlashcardState.new.rawValue
                )
                card.fsrsState = state

                self.modelContext.insert(card)
                self.modelContext.insert(state)
            }

            // Save to persistent store
            do {
                try self.modelContext.save()
                self.hasCompletedOnboarding = true
            } catch {
                Task { Analytics.trackError("onboarding_save", error: error) }
                self.errorMessage = "Failed to create sample deck: \(error.localizedDescription)"
                self.isCreatingSampleDeck = false
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: self.page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 16) {
                Text(self.page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(self.page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self, FlashcardReview.self], inMemory: true)
}
