# Lexicon Flow iOS - Technical Architecture

## Overview

This document outlines the technical architecture for Lexicon Flow, a native iOS flashcard application built with **Swift 6**, **SwiftUI**, **SwiftData**, and **iOS 26** frameworks.

---

## Technology Stack

### Core Frameworks

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| **Language** | Swift | 6.0 | Strict concurrency, Sendable protocols, Actors |
| **UI Framework** | SwiftUI | iOS 26 | Native "Liquid Glass" APIs, morphing transitions |
| **Data Persistence** | SwiftData | iOS 26 | @Model macro, CloudKit sync, @Query integration |
| **Concurrency** | Swift Concurrency | Swift 6 | async/await, Actor isolation, MainActor |
| **Algorithm** | FSRS | v5 | Three-component model (S, D, R), superior to SM-2 |
| **AI/ML** | Foundation Models | iOS 26 | On-device LLM for sentence generation |
| **Translation** | Translation API | iOS 26 | On-device, zero-latency translation |
| **Audio** | AVSpeechSynthesizer | iOS 26 | Neural TTS voices, accent selection |
| **Haptics** | CoreHaptics | iOS 26 | Custom vibration patterns |
| **Navigation** | NavigationStack + Custom | iOS 26 | Hybrid for optimal fluidity |
| **Widgets** | WidgetKit | iOS 26 | Lock Screen, Live Activities |
| **Testing** | Swift Testing | Xcode 26 | Unit + integration testing |
| **Minimum Target** | iOS | 26.0 | No legacy fallbacks needed |

---

## Concurrency Architecture

### Swift 6 Strict Concurrency

Lexicon Flow adopts Swift 6's strict concurrency checking to ensure thread safety for heavy background operations.

```swift
// Scheduler Actor - isolated to prevent data races
actor SRSScheduler {
    private var fsrs: FSRS

    func schedule(card: Card, rating: Rating) async -> SchedulingResult {
        // FSRS calculations run on actor's executor
        return fsrs.review(card: card.fsrsState, rating: rating)
    }
}
```

### ModelActor for Background Operations

For heavy database operations (e.g., importing 10,000 words), SwiftData's `ModelActor` ensures the main thread never blocks.

```swift
@ModelActor
actor DataImporter {
    func importCards(from jsonData: Data, into deck: Deck) async throws -> Int {
        let decoder = JSONDecoder()
        let cards = try decoder.decode([CardDTO].self, from: jsonData)

        var count = 0
        for dto in cards {
            let card = Card(
                word: dto.word,
                definition: dto.definition,
                phonetic: dto.phonetic
            )
            card.deck = deck
            count += 1

            // Batch save every 500 cards
            if count % 500 == 0 {
                try modelContext.save()
            }
        }

        try modelContext.save()
        return count
    }
}
```

---

## Data Model

### Entity Relationship Diagram

```
Deck (1) ────< (N) Card (1) ────< (N) ReviewLog
     │                │
     │                └─── (1) FSRSState
     │
     └─── iconData (@Attribute(.externalStorage))
```

### SwiftData Schema

```swift
import SwiftData
import Foundation

@Model
final class Deck {
    var id: UUID
    var name: String
    var icon: String?
    var createdAt: Date
    var order: Int

    @Relationship(deleteRule: .nullify, inverse: \Card.deck)
    var cards: [Card] = []

    init(name: String, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.order = 0
    }
}

@Model
final class Card {
    var id: UUID
    var word: String
    var definition: String
    var phonetic: String?
    var createdAt: Date

    @Attribute(.externalStorage)
    var imageData: Data?

    @Relationship(inverse: \Deck.cards)
    var deck: Deck?

    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var reviewLogs: [ReviewLog] = []

    var fsrsState: FSRSState

    init(
        word: String,
        definition: String,
        phonetic: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.word = word
        self.definition = definition
        self.phonetic = phonetic
        self.imageData = imageData
        self.createdAt = Date()
        self.fsrsState = FSRSState()
    }
}

@Model
final class FSRSState {
    var stability: Double
    var difficulty: Double
    var dueDate: Date
    var retrievability: Double
    var state: CardState

    init() {
        self.stability = 0.0
        self.difficulty = 5.0
        self.dueDate = Date()
        self.retrievability = 0.9
        self.state = .new
    }
}

@Model
final class ReviewLog {
    var id: UUID
    var rating: Rating
    var reviewDate: Date
    var scheduledDays: Int
    var elapsedDays: Int
    var state: CardState

    @Relationship(inverse: \Card.reviewLogs)
    var card: Card?

    init(
        rating: Rating,
        scheduledDays: Int,
        elapsedDays: Int,
        state: CardState
    ) {
        self.id = UUID()
        self.rating = rating
        self.reviewDate = Date()
        self.scheduledDays = scheduledDays
        self.elapsedDays = elapsedDays
        self.state = state
    }
}

enum CardState: String, Codable {
    case new
    case learning
    case review
    case relearning
}

enum Rating: Int, Codable {
    case again = 0    // Forgot completely
    case hard = 1     // Remembered with difficulty
    case good = 2     // Remembered correctly
    case easy = 3     // Remembered instantly
}
```

---

## Algorithm Architecture

### FSRS Integration

Lexicon Flow uses the **SwiftFSRS** package for Spaced Repetition scheduling.

```swift
import SwiftFSRS

// Wrapper for FSRS algorithm
@Observable
class Scheduler {
    private let fsrs = FSRS()
    private let actor: SRSScheduler

    func review(card: Card, rating: Rating) async -> SchedulingResult {
        // Convert our Card to FSRS Card
        var fsrsCard = Card(
            stability: card.fsrsState.stability,
            difficulty: card.fsrsState.difficulty
        )

        // Run FSRS review
        let result = await actor.schedule(card: fsrsCard, rating: rating)

        // Update our card state
        card.fsrsState.stability = result.stability
        card.fsrsState.difficulty = result.difficulty
        card.fsrsState.dueDate = result.dueDate
        card.fsrsState.retrievability = result.retrievability
        card.fsrsState.state = CardState(from: result.state)

        // Log the review
        let log = ReviewLog(
            rating: rating,
            scheduledDays: result.scheduledDays,
            elapsedDays: result.elapsedDays,
            state: card.fsrsState.state
        )
        card.reviewLogs.append(log)

        return result
    }

    // Query for due cards
    func fetchDueCards(in context: ModelContext) -> [Card] {
        let now = Date()
        let predicate = #Predicate<Card> { card in
            card.fsrsState.dueDate <= now
        }

        let descriptor = FetchDescriptor<Card>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fsrsState.dueDate)]
        )

        return try? context.fetch(descriptor) ?? []
    }
}
```

---

## UI Architecture

### "Liquid Glass" Implementation

#### Flashcard View

```swift
struct FlashcardView: View {
    @Bindable var card: Card
    @State private var offset: CGSize = .zero
    @State private var isFlipped = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                if isFlipped {
                    BackFace(card: card)
                        .glassEffectTransition(.materialize, namespace: namespace)
                } else {
                    FrontFace(card: card)
                        .glassEffectTransition(.materialize, namespace: namespace)
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            .interactive($offset) { dragOffset in
                // Visual feedback based on drag
                let progress = dragOffset.width / 100

                if progress > 0 {
                    // Swiping right (Good) - green tint
                    return .tint(.green.opacity(0.3 * progress))
                } else {
                    // Swiping left (Again) - red tint
                    return .tint(.red.opacity(0.3 * abs(progress)))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            handleSwipe(value.translation)
                            offset = .zero
                        }
                    }
            )
        }
    }

    private func handleSwipe(_ translation: CGSize) {
        let threshold: CGFloat = 50

        switch (translation.width, translation.height) {
        case (let x, _) where x > threshold:
            // Swipe right - Good
            Task { await handleRating(.good) }
        case (let x, _) where x < -threshold:
            // Swipe left - Again
            Task { await handleRating(.again) }
        case (_, let y) where y < -threshold:
            // Swipe up - Easy
            Task { await handleRating(.easy) }
        case (_, let y) where y > threshold:
            // Swipe down - Hard
            Task { await handleRating(.hard) }
        default:
            break
        }
    }
}
```

#### Glass Effect Container

For optimal performance with multiple glass elements:

```swift
struct DeckGridView: View {
    @Query private var decks: [Deck]

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            ForEach(decks) { deck in
                DeckCard(deck: deck)
                    .glassEffect(.thin, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
```

---

## AI Integration

### Foundation Models Framework

#### Sentence Generation

```swift
import FoundationModels

@Actor
class SentenceGenerator {
    private var session: LanguageModelSession?

    func generateSentence(for word: String) async throws -> String {
        if session == nil {
            session = try LanguageModelSession()
        }

        let prompt = """
        Generate a simple, clear sentence using the word "\(word)" in a casual,
        American English context. Use simple vocabulary. Return only the sentence.
        """

        let response = try await session?.generate(prompt)
        return response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
```

#### Caching Strategy

```swift
@Model
final class Card {
    // ... existing properties

    var generatedSentence: String?
    var sentenceGeneratedAt: Date?

    func sentence(using generator: SentenceGenerator) async throws -> String {
        // Return cached if less than 7 days old
        if let cached = generatedSentence,
           let generated = sentenceGeneratedAt,
           Date().timeIntervalSince(generated) < 7 * 24 * 3600 {
            return cached
        }

        // Generate new sentence
        let new = try await generator.generateSentence(for: word)
        generatedSentence = new
        sentenceGeneratedAt = Date()
        return new
    }
}
```

---

## Translation Integration

### Translation API

```swift
import Translation

@Actor
class TranslationService {
    private var session: TranslationSession?

    func translate(_ text: String, to language: Language) async throws -> String {
        if session == nil {
            session = try TranslationSession()
        }

        let response = try await session?.translate(text, from: .english, to: language)
        return response?.targetText ?? text
    }

    func batchTranslate(_ texts: [String], to language: Language) async throws -> [String] {
        if session == nil {
            session = try TranslationSession()
        }

        var results: [String] = []

        for text in texts {
            let response = try await session?.translate(text, from: .english, to: language)
            results.append(response?.targetText ?? text)
        }

        return results
    }
}
```

---

## Audio System

### AVSpeechSynthesizer

```swift
import AVFoundation

@Observable
class AudioService {
    private let synthesizer = AVSpeechSynthesizer()
    var selectedAccent: VoiceAccent = .american

    enum VoiceAccent: String, CaseIterable {
        case american = "en-US"
        case british = "en-GB"
        case australian = "en-AU"
        case irish = "en-IE"

        var displayName: String {
            rawValue
        }
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)

        // Select premium voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == selectedAccent.rawValue }
            .sorted { voice1, voice2 in
                // Prefer premium > enhanced > default
                let quality1 = voiceQuality(voice1)
                let quality2 = voiceQuality(voice2)
                return quality1 > quality2
            }

        utterance.voice = voices.first
        utterance.rate = 0.5  // Normal speech rate

        synthesizer.speak(utterance)
    }

    private func voiceQuality(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }
}
```

---

## Haptic Feedback

### CoreHaptics Patterns

```swift
import CoreHaptics

@Actor
class HapticService {
    private var engine: CHHapticEngine?

    func setup() async throws {
        engine = try CHHapticEngine()
        try engine?.start()
    }

    func playRatingFeedback(_ rating: Rating) async {
        guard let engine = engine else { return }

        let pattern: CHHapticPattern

        switch rating {
        case .again:
            pattern = try! hapticPattern(
                intensity: 1.0, sharpness: 0.8, duration: 0.1
            )
        case .hard:
            pattern = try! hapticPattern(
                intensity: 0.7, sharpness: 0.6, duration: 0.08
            )
        case .good:
            pattern = try! hapticPattern(
                intensity: 0.5, sharpness: 0.3, duration: 0.05
            )
        case .easy:
            pattern = try! hapticPattern(
                intensity: 0.3, sharpness: 0.1, duration: 0.03
            )
        }

        try? engine.execute(pattern)
    }

    private func hapticPattern(
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval
    ) throws -> CHHapticPattern {
        try CHHapticPattern(
            events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    time: 0,
                    intensity: intensity,
                    sharpness: sharpness
                )
            ],
            parameters: []
        )
    }
}
```

---

## Widget Architecture

### Lock Screen Widget

```swift
struct LexiconFlowWidget: Widget {
    let kind: String = "LexiconFlowLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .containerBackground(.glassEffect, for: .widget)
        }
        .configurationDisplayName("Words Due")
        .description("See your daily review count")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct Provider: TimelineProvider {
    func timeline(for context: Context, in entry: WidgetEntry) async -> Timeline<Entry> {
        let dueCount = await fetchDueCount()

        let entries = [
            Entry(date: Date(), dueCount: dueCount)
        ]

        return Timeline(entries: entries, policy: .atEnd)
    }
}
```

### Live Activity

```swift
struct StudySessionActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudySessionAttributes.self) { context in
            // Lock Screen / Dynamic Island UI
            VStack {
                Text("\(context.state.cardsReviewed)/\(context.state.totalCards)")
                Text("Cards Reviewed")
                    .font(.caption)
            }
            .activityBackground(.glassEffect)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded state
            } compactLeading: {
                Text("\(context.state.cardsReviewed)")
            } compactTrailing: {
                Image(systemName: "checkmark.circle.fill")
            } minimal: {
                Text("\(context.state.cardsReviewed)")
            }
        }
    }
}
```

---

## Performance Optimizations

### 1. External Storage for Media

```swift
@Attribute(.externalStorage) var imageData: Data?
```

- Prevents database bloat
- Queries remain fast without loading images

### 2. Lazy Loading

```swift
LazyVGrid(columns: columns, spacing: 16) {
    ForEach(decks) { deck in
        DeckCard(deck: deck)
    }
}
```

- `LazyVGrid` renders only visible items
- Prevents memory spikes

### 3. Batch Operations

```swift
// Save every 500 items during import
if count % 500 == 0 {
    try modelContext.save()
}
```

- Reduces I/O operations
- Background thread via ModelActor

### 4. Predicate Queries

```swift
let predicate = #Predicate<Card> { card in
    card.fsrsState.dueDate <= now && card.fsrsState.state == .review
}
```

- Type-safe queries
- Compiler-validated
- Better than NSPredicate strings

---

## Security & Privacy

### Data Protection

- All data stored locally using SwiftData
- On-device AI (Foundation Models) - no data sent to servers
- Optional iCloud sync using CloudKit (user-controlled)

### Translation Privacy

- On-device translation using iOS 26 Translation framework
- No external API calls
- Works offline after language pack download

---

## Project Structure

```
LexiconFlow/
├── App/
│   ├── LexiconFlowApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Card.swift
│   ├── Deck.swift
│   ├── ReviewLog.swift
│   └── FSRSState.swift
├── Views/
│   ├── FlashcardView.swift
│   ├── DeckGridView.swift
│   ├── StudySessionView.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── Scheduler.swift
│   ├── StudySessionViewModel.swift
│   └── AudioService.swift
├── Services/
│   ├── SentenceGenerator.swift
│   ├── TranslationService.swift
│   ├── HapticService.swift
│   └── DataImporter.swift
├── Widgets/
│   ├── LexiconFlowWidget.swift
│   └── StudySessionActivity.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── dictionary.json
│   └── Localizable.strings
└── Tests/
    ├── ModelTests/
    └── UITests/
```

---

## Dependencies

### Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/open-spaced-repetition/swift-fsrs",
        from: "1.0.0"
    )
]
```

---

**Document Version**: 1.0
**Last Updated**: January 2026
**iOS Target**: 26.0
**Swift Version**: 6.0
