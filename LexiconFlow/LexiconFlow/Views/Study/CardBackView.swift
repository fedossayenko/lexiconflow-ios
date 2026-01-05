//
//  CardBackView.swift
//  LexiconFlow
//
//  Back of flashcard showing definition, translation, and optional image
//

import SwiftUI

struct CardBackView: View {
    @Bindable var card: Flashcard

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

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card back")
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

#Preview {
    let card = Flashcard(
        word: "Ephemeral",
        definition: "Lasting for a very short time; short-lived; transitory",
        phonetic: "/əˈfem(ə)rəl/"
    )
    return CardBackView(card: card)
        .frame(height: 400)
        .background(Color(.systemBackground))
}
