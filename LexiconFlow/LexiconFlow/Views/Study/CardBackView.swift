//
//  CardBackView.swift
//  LexiconFlow
//
//  Back of flashcard showing definition, translation, and AI-generated sentences
//

import SwiftData
import SwiftUI

struct CardBackView: View {
    @Bindable var card: Flashcard
    @State private var showAllSentences = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()

                // Word reminder (smaller)
                Text(self.card.word)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Word: \(self.card.word)")

                // Translation - NEW
                if let translation = card.translation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(translation)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .accessibilityLabel("Translation: \(translation)")
                }

                // CEFR Level Badge (if available)
                if let cefrLevel = card.cefrLevel {
                    HStack(spacing: 4) {
                        Text("Level")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(cefrLevel)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cefrColor(for: cefrLevel).opacity(0.15))
                    .foregroundStyle(Theme.cefrColor(for: cefrLevel))
                    .cornerRadius(6)
                    .accessibilityLabel("CEFR Level: \(cefrLevel)")
                }

                // Definition
                Text(self.card.definition)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityLabel("Definition: \(self.card.definition)")

                // Image (if available)
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .accessibilityLabel("Card image")
                        .accessibilityAddTraits(.isImage)
                }

                // AI-Generated Sentences Section
                self.sentenceSection

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card back")
    }

    // MARK: - Sentence Section

    @ViewBuilder
    private var sentenceSection: some View {
        // Filter valid (non-expired) sentences
        let validSentences = self.card.generatedSentences.filter { !$0.isExpired }

        // Only show section if there are valid sentences
        if !validSentences.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Header (no button)
                Text("AI Sentences")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Sentences display
                self.sentencesList(sentences: validSentences)
            }
            .padding(.vertical, 8)
        }
    }

    /// Display generated sentences (read-only)
    private func sentencesList(sentences: [GeneratedSentence]) -> some View {
        let sentencesToShow = self.showAllSentences ? sentences : Array(sentences.prefix(2))

        return VStack(spacing: 12) {
            ForEach(sentencesToShow, id: \.id) { sentence in
                ReadOnlySentenceRow(sentence: sentence)
            }

            // Show more button
            if sentences.count > 2, !self.showAllSentences {
                Button("Show \(sentences.count - 2) more sentences") {
                    withAnimation {
                        self.showAllSentences = true
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Helper Methods
}

// MARK: - Helper Methods

#Preview("Card Back") {
    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time; short-lived; transitory",
        phonetic: "/əˈfem(ə)rəl/"
    )
    return CardBackView(card: card)
        .frame(height: 500)
        .background(Color(.systemBackground))
}

// MARK: - Read-Only Sentence Row Component

struct ReadOnlySentenceRow: View {
    let sentence: GeneratedSentence

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Sentence text
            VStack(alignment: .leading, spacing: 6) {
                Text(self.sentence.sentenceText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    // CEFR Level badge
                    HStack(spacing: 4) {
                        Text(self.sentence.cefrLevel)
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text(self.sourceLabel(for: self.sentence.source))
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cefrColor(for: self.sentence.cefrLevel).opacity(0.15))
                    .foregroundStyle(Theme.cefrColor(for: self.sentence.cefrLevel))
                    .cornerRadius(6)

                    // Source badge
                    Text(self.sourceLabel(for: self.sentence.source))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                // Expiration warning
                if self.sentence.isExpired {
                    Text("Expired")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if self.sentence.daysUntilExpiration <= 2 {
                    Text("Expires in \(self.sentence.daysUntilExpiration)d")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                // Favorite indicator (display only)
                if self.sentence.isFavorite {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("Favorite")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private func sourceLabel(for source: SentenceSource) -> String {
        switch source {
        case .aiGenerated: "AI"
        case .staticFallback: "Offline"
        case .userCreated: "Custom"
        }
    }
}

#Preview("Read-Only Sentence Row") {
    let sentence = (try? GeneratedSentence(
        sentenceText: "The ephemeral beauty of sunset colors fades quickly.",
        cefrLevel: "B2",
        generatedAt: Date(),
        ttlDays: 7,
        isFavorite: true,
        source: .aiGenerated
    ))

    return Group {
        if let sentence {
            ReadOnlySentenceRow(sentence: sentence)
        } else {
            Text("Preview error: Invalid sentence data")
                .foregroundStyle(.red)
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
