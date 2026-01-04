//
//  CardBackView.swift
//  LexiconFlow
//
//  Back of flashcard showing definition and optional image
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

                // Definition
                Text(card.definition)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Image (if available)
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
