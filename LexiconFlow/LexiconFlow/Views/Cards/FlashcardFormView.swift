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
            }

            Section("Definition") {
                TextField("Definition", text: $definition, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Phonetic (Optional)") {
                TextField("Phonetic", text: $phonetic)
                    .textInputAutocapitalization(.never)
            }

            Section {
                Picker("Deck", selection: $selectedDeck) {
                    Text("No Deck").tag(nil as Deck?)
                    ForEach(allDecks) { deck in
                        Text(deck.name).tag(deck as Deck?)
                    }
                }
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

                        Button("Remove Image") {
                            self.imageData = nil
                            selectedImage = nil
                        }
                        .foregroundStyle(.red)
                    }
                }

                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Label(imageData == nil ? "Add Image" : "Change Image",
                          systemImage: imageData == nil ? "photo" : "arrow.triangle.2.circlepath")
                }
            } header: {
                Text("Image (Optional)")
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Flashcard.self, configurations: config)

    FlashcardFormView(
        word: .constant(""),
        definition: .constant(""),
        phonetic: .constant(""),
        imageData: .constant(nil),
        selectedDeck: .constant(nil),
        selectedImage: .constant(nil)
    )
    .modelContainer(container)
}
