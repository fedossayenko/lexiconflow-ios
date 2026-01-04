//
//  FlashcardFormView.swift
//  LexiconFlow
//
//  Reusable flashcard form component
//

import SwiftUI
import SwiftData
import PhotosUI

struct FlashcardFormView: View {
    @Binding var word: String
    @Binding var definition: String
    @Binding var phonetic: String
    @Binding var imageData: Data?
    @Binding var selectedDeck: Deck?
    @Binding var selectedImage: PhotosPickerItem?

    @Query var allDecks: [Deck]

    var body: some View {
        Form {
            Section("Word") {
                TextField("Word", text: $word)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Word")
                    .accessibilityHint("Enter the vocabulary word")
            }

            Section("Definition") {
                TextField("Definition", text: $definition, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel("Definition")
                    .accessibilityHint("Enter the word definition")
            }

            Section("Phonetic (Optional)") {
                TextField("Phonetic", text: $phonetic)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Phonetic")
                    .accessibilityHint("Enter pronunciation guide (optional)")
            }

            Section {
                Picker("Deck", selection: $selectedDeck) {
                    Text("No Deck").tag(nil as Deck?)
                    ForEach(allDecks) { deck in
                        Text(deck.name).tag(deck as Deck?)
                    }
                }
                .accessibilityLabel("Deck picker")
                .accessibilityHint("Select a deck to add this card to")
            } header: {
                Text("Add to Deck")
            }

            Section {
                if let imageData = imageData, let image = UIImage(data: imageData) {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)

                        Button("Remove Image") {
                            self.imageData = nil
                            selectedImage = nil
                        }
                        .foregroundStyle(.red)
                        .accessibilityLabel("Remove Image")
                        .accessibilityHint("Remove the selected image from the flashcard")
                    }
                }

                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Label(imageData == nil ? "Add Image" : "Change Image",
                          systemImage: imageData == nil ? "photo" : "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel(imageData == nil ? "Add Image" : "Change Image")
                .accessibilityHint("Open photo picker to select an image")
            } header: {
                Text("Image (Optional)")
            }
        }
    }
}

#Preview("Flashcard Form") {
    FlashcardFormView(
        word: .constant(""),
        definition: .constant(""),
        phonetic: .constant(""),
        imageData: .constant(nil),
        selectedDeck: .constant(nil),
        selectedImage: .constant(nil)
    )
    .modelContainer(for: [Flashcard.self], inMemory: true)
}
