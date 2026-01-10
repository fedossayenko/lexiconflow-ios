//
//  CardBackViewMatched.swift
//  LexiconFlow
//
//  Back of flashcard with matched geometry effect IDs.
//
//  This view uses matchedGeometryEffect to allow word and phonetic
//  to smoothly animate from their positions on the front.
//

import SwiftData
import SwiftUI

/// Back of flashcard with matched geometry effect transitions
///
/// **Matched Elements:**
/// - word: Smaller text at top (animates from center on front)
/// - phonetic: Below word (animates from below word on front)
struct CardBackViewMatched: View {
    @Bindable var card: Flashcard
    var namespace: Namespace.ID
    @State private var showAllSentences = false

    // MARK: - Matched Geometry IDs

    /// Matched geometry effect identifiers for element transitions
    private enum MatchedID: String {
        case word
        case phonetic
    }

    // MARK: - Body

    var body: some View {
        // VStack instead of ScrollView for performance with matchedGeometryEffect
        // ScrollView causes layout thrashing during flip animations
        VStack(spacing: 24) {
            Spacer()

            // Word reminder (matched - from front, now smaller and at top)
            Text(self.card.word)
                .font(.title3)
                .foregroundStyle(.secondary)
                .matchedGeometryEffect(id: MatchedID.word.rawValue, in: self.namespace)
                .accessibilityLabel("Word: \(self.card.word)")

            // Translation - NEW (no match - fades in)
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

            // CEFR Level Badge (if available) (no match - fades in)
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

            // Phonetic (matched - from front, same position)
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: MatchedID.phonetic.rawValue, in: self.namespace)
                    .accessibilityLabel("Pronunciation: \(phonetic)")
            }

            // Definition (no match - fades in)
            Text(self.card.definition)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Definition: \(self.card.definition)")

            // Image (if available) (no match - fades in)
            // PERFORMANCE: Uses ImageCache to avoid repeated JPEG/PNG decoding
            if let imageData = card.imageData,
               let cachedImage = ImageCache.shared.image(for: imageData)
            {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .accessibilityLabel("Card image")
                    .accessibilityAddTraits(.isImage)
            }

            // AI-Generated Sentences Section (no match - fades in)
            self.sentenceSection

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped() // Clip overflow content for performance
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
                // Header
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
}

// MARK: - Previews

#Preview("CardBackViewMatched") {
    struct PreviewWrapper: View {
        @Namespace private var namespace

        let card = Flashcard(
            word: "Ephemeral",
            definition: "Lasting for a very short time; short-lived; transitory",
            phonetic: "/əˈfem(ə)rəl/"
        )

        var body: some View {
            CardBackViewMatched(card: card, namespace: namespace)
                .frame(height: 500)
                .background(Color(.systemBackground))
        }
    }

    return PreviewWrapper()
}
