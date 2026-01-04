//
//  OnboardingView.swift
//  LexiconFlow
//
//  First-launch welcome screen with app introduction and sample deck creation
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var isCreatingSampleDeck = false

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
            description: "Let's create your first deck and add some sample cards to get you started."
        )
    ]

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pages.count, id: \.self) { index in
                OnboardingPageView(page: pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .toolbar {
            if currentPage == pages.count - 1 {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: completeOnboarding) {
                        if isCreatingSampleDeck {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Get Started")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isCreatingSampleDeck)
                }
            }
        }
    }

    private func completeOnboarding() {
        isCreatingSampleDeck = true

        Task { @MainActor in
            // Create sample deck
            let sampleDeck = Deck(name: "Sample Vocabulary", icon: "star.fill", order: 0)
            modelContext.insert(sampleDeck)

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

                modelContext.insert(card)
                modelContext.insert(state)
            }

            // Save to persistent store
            do {
                try modelContext.save()
                hasCompletedOnboarding = true
            } catch {
                print("Failed to save sample deck: \(error)")
                isCreatingSampleDeck = false
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

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
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
