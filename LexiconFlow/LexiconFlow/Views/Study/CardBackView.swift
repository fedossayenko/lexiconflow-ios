//
//  CardBackView.swift
//  LexiconFlow
//
//  Back of flashcard showing definition, translation, and AI-generated sentences
//

import SwiftUI
import SwiftData

struct CardBackView: View {
    @Bindable var card: Flashcard
    @State private var viewModel: SentenceGenerationViewModel?
    @Environment(\.modelContext) private var modelContext
    @State private var showAllSentences = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()

                // Word reminder (smaller)
                Text(card.word)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Word: \(card.word)")

                // CEFR Level badge - NEW
                if let cefr = card.cefrLevel {
                    HStack(spacing: 6) {
                        Text("CEFR")
                            .font(.caption2)
                        Text(cefr)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cefrColor(for: cefr).opacity(0.2))
                    .foregroundStyle(cefrColor(for: cefr))
                    .cornerRadius(12)
                    .accessibilityLabel("CEFR level: \(cefr)")
                }

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

                // Definition
                Text(card.definition)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityLabel("Definition: \(card.definition)")

                // Image (if available)
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData) {
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
                sentenceSection

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card back")
        .task {
            // Initialize view model on appear
            if viewModel == nil {
                viewModel = SentenceGenerationViewModel(modelContext: modelContext)
                viewModel?.loadSentences(for: card)
            }
        }
    }

    // MARK: - Sentence Section

    @ViewBuilder
    private var sentenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with generate button
            HStack {
                Text("AI Sentences")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let vm = viewModel {
                    if vm.isGenerating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button {
                            Task {
                                await vm.generateSentences(for: card)
                            }
                        } label: {
                            Image(systemName: vm.hasSentences ? "arrow.clockwise" : "sparkles")
                                .font(.caption)
                        }
                        .disabled(vm.isGenerating)
                    }
                }
            }
            .padding(.horizontal)

            // Sentences display
            if let vm = viewModel, vm.hasSentences {
                sentencesList(viewModel: vm)
            } else if let vm = viewModel {
                emptyStatePrompt(viewModel: vm)
            }

            // Generation message
            if let vm = viewModel, let message = vm.generationMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            // Error message
            if let vm = viewModel, let error = vm.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    /// Display generated sentences
    private func sentencesList(viewModel: SentenceGenerationViewModel) -> some View {
        let sentencesToShow = showAllSentences ? viewModel.validSentences : Array(viewModel.validSentences.prefix(2))

        return VStack(spacing: 12) {
            ForEach(sentencesToShow, id: \.id) { sentence in
                SentenceRow(
                    sentence: sentence,
                    onFavoriteToggle: {
                        viewModel.toggleFavorite(sentence)
                    },
                    onDelete: {
                        viewModel.deleteSentence(sentence)
                    }
                )
            }

            // Show more button
            if viewModel.validSentences.count > 2 && !showAllSentences {
                Button("Show \(viewModel.validSentences.count - 2) more sentences") {
                    withAnimation {
                        showAllSentences = true
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }

            // Regenerate button
            if viewModel.validSentences.count > 0 {
                Button {
                    Task {
                        await viewModel.regenerateSentences(for: card)
                    }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(viewModel.isGenerating)
            }
        }
    }

    /// Empty state prompt
    private func emptyStatePrompt(viewModel: SentenceGenerationViewModel) -> some View {
        Button {
            Task {
                await viewModel.generateSentences(for: card)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tertiary)

                Text("Generate AI Sentences")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .disabled(viewModel.isGenerating)
    }

    // MARK: - Helper Methods

    private func cefrColor(for level: String) -> Color {
        switch level.uppercased() {
        case "A1", "A2": return .green
        case "B1", "B2": return .blue
        case "C1", "C2": return .purple
        default: return .gray
        }
    }
}

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

// MARK: - Sentence Row Component

struct SentenceRow: View {
    let sentence: GeneratedSentence
    let onFavoriteToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Sentence text
            VStack(alignment: .leading, spacing: 6) {
                Text(sentence.sentenceText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    // CEFR Level badge
                    HStack(spacing: 4) {
                        Text(sentence.cefrLevel)
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text("AI")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cefrColor(for: sentence.cefrLevel).opacity(0.15))
                    .foregroundStyle(cefrColor(for: sentence.cefrLevel))
                    .cornerRadius(6)

                    // Source badge
                    Text(sourceLabel(for: sentence.source))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                // Expiration warning
                if sentence.isExpired {
                    Text("Expired")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if sentence.daysUntilExpiration <= 2 {
                    Text("Expires in \(sentence.daysUntilExpiration)d")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Action buttons
            VStack(spacing: 8) {
                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: sentence.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(sentence.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private func sourceLabel(for source: SentenceSource) -> String {
        switch source {
        case .aiGenerated: return "AI"
        case .staticFallback: return "Offline"
        case .userCreated: return "Custom"
        }
    }

    private func cefrColor(for level: String) -> Color {
        switch level.uppercased() {
        case "A1", "A2": return .green
        case "B1", "B2": return .blue
        case "C1", "C2": return .purple
        default: return .gray
        }
    }
}

#Preview("Sentence Row") {
    let sentence = GeneratedSentence(
        sentenceText: "The ephemeral beauty of sunset colors fades quickly.",
        cefrLevel: "B2",
        generatedAt: Date(),
        ttlDays: 7,
        isFavorite: true,
        source: .aiGenerated
    )

    return SentenceRow(
        sentence: sentence,
        onFavoriteToggle: {},
        onDelete: {}
    )
    .padding()
    .background(Color(.systemBackground))
}
