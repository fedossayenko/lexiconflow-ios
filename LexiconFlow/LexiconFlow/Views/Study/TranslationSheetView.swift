//
//  TranslationSheetView.swift
//  LexiconFlow
//
//  Sheet view for displaying quick translation results
//

import OSLog
import SwiftUI

/// Sheet view for displaying flashcard translation results
///
/// **States:**
/// - Loading: Shows spinner while translation is in progress
/// - Result: Displays translation with cache hit/miss indicator
///
/// **Features:**
/// - Cache status badge (checkmark for cache hit, sparkles for fresh)
/// - Language pair display (source → target)
/// - Expiration date for cached translations
/// - Error handling with recovery options
struct TranslationSheetView: View {
    // MARK: - Properties

    /// The flashcard being translated
    let flashcard: Flashcard

    /// Translation result (nil if still loading or error occurred)
    let translationResult: QuickTranslationService.QuickTranslationResult?

    /// Whether translation is currently in progress
    let isTranslating: Bool

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "TranslationSheetView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if self.isTranslating {
                    self.loadingView
                } else if let result = self.translationResult {
                    self.resultView(result)
                } else {
                    self.errorView
                }
            }
            .navigationTitle("Quick Translation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large], selection: .constant(.medium))
        .presentationDragIndicator(.visible)
        // Sheet dismisses automatically via drag indicator
    }

    // MARK: - Loading View

    /// Loading state with spinner and message
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.accentColor)

            Text("Translating...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(self.flashcard.word)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Translating \(self.flashcard.word)")
    }

    // MARK: - Result View

    /// Translation result display
    private func resultView(_ result: QuickTranslationService.QuickTranslationResult) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 20)

                // Source word
                VStack(spacing: 8) {
                    Text("Source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(self.flashcard.word)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Source word: \(self.flashcard.word)")
                }

                // Language badges with arrow
                HStack(spacing: 12) {
                    self.languageBadge(result.sourceLanguage)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    self.languageBadge(result.targetLanguage)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("From \(result.sourceLanguage) to \(result.targetLanguage)")

                // Divider
                Divider()
                    .padding(.horizontal, 40)

                // Translation
                VStack(spacing: 12) {
                    if result.isCacheHit {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.cached)
                            Text("Cached translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Cached translation")
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.Colors.fresh)
                            Text("Fresh translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Fresh translation")
                    }

                    Text(result.translatedText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.primary)
                        .accessibilityLabel("Translation: \(result.translatedText)")
                }

                // Metadata (cache expiration)
                if let expirationDate = result.cacheExpirationDate {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Cache expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Error View

    /// Error state with message
    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.warning)

            Text("Translation Unavailable")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The translation could not be loaded.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Translation unavailable")
    }

    // MARK: - Helper Views

    /// Language badge with rounded corners
    private func languageBadge(_ language: String) -> some View {
        Text(language.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Language: \(language)")
    }
}

// MARK: - Preview

#Preview {
    TranslationSheetView(
        flashcard: {
            let card = Flashcard(
                word: "Hello",
                definition: "A greeting",
                phonetic: "/həˈloʊ/"
            )
            return card
        }(),
        translationResult: QuickTranslationService.QuickTranslationResult(
            translatedText: "Hola",
            sourceLanguage: "en",
            targetLanguage: "es",
            isCacheHit: false,
            cacheExpirationDate: nil
        ),
        isTranslating: false
    )
}
