# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working with LexiconFlow.

## Project Overview

**LexiconFlow** - Native iOS vocabulary app with Swift 6, SwiftUI, SwiftData, FSRS v5.

**Core Features:**
- FSRS v5 spaced repetition algorithm
- iOS 26 "Liquid Glass" UI
- On-device translation (100% offline via iOS 26 Translation framework)
- Two study modes: Scheduled (respects due dates) and Cram (practice mode)

## Build & Test

```bash
# Build (from LexiconFlow/ directory)
cd LexiconFlow
xcodebuild build -project LexiconFlow.xcodeproj -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'

# Test all (serialized for shared container)
xcodebuild test -project LexiconFlow.xcodeproj -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' \
  -only-testing:LexiconFlowTests -parallel-testing-enabled NO \
  -resultBundlePath /tmp/lexiconflow-test-results.xcresult

# Resolve dependencies
xcodebuild -resolvePackageDependencies
```

## Dependencies

- **SwiftFSRS**: https://github.com/open-spaced-repetition/swift-fsrs (v5.0.0)
- **Translation**: iOS 26 Translation framework (on-device, no package dependency)

## Critical Implementation Patterns

### 1. ModelContainer Fallback Pattern

**NEVER use `fatalError` for ModelContainer** - it causes immediate app crash:

```swift
// ✅ CORRECT: Graceful degradation
var sharedModelContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: false)
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        logger.critical("ModelContainer failed: \(error)")
        // Fallback to in-memory
        let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [fallbackConfig])
    }
}()

// ❌ WRONG: Crashes app on any database error
fatalError("Could not create ModelContainer: \(error)")
```

### 2. DTO Pattern for Concurrency

Return `Sendable` DTOs from actors, not models (prevents cross-actor mutations):

```swift
// Actor returns DTO
actor FSRSWrapper {
    func processReview(flashcard: Flashcard, rating: Int) throws -> FSRSReviewResult
}

// MainActor applies updates
@MainActor func processReview(flashcard: Flashcard, rating: Int) async throws {
    let dto = try await FSRSWrapper.shared.processReview(flashcard: flashcard, rating: rating)
    flashcard.fsrsState?.stability = dto.stability
    try modelContext.save()
}
```

### 3. Single-Sided Inverse Relationships

Define `@Relationship` inverse on **only ONE side** to avoid SwiftData circular expansion errors:

```swift
// Flashcard.swift - no inverse here
@Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

// FSRSState.swift - inverse defined here
@Relationship(inverse: \Flashcard.fsrsState) var card: Flashcard?
```

### 4. String Literals in Predicates

Use string literals instead of enum raw values in `#Predicate`:

```swift
// ✅ CORRECT: String literal
#Predicate<FSRSState> { state in state.stateEnum != "new" }

// ❌ AVOID: Can cause SwiftData key path issues
#Predicate<FSRSState> { state in state.stateEnum != FlashcardState.new.rawValue }
```

### 5. Reactive Updates with @Query

Use `@Query` for automatic SwiftData updates (avoid manual refresh):

```swift
// ✅ CORRECT: Auto-updates
struct CardListView: View {
    @Query private var cards: [Flashcard]
    var body: some View { List(cards) { ... } }  // Auto-refreshes
}

// ❌ AVOID: Manual refresh
@State private var items: [Item] = []
var body: some View {
    List(items) { ... }.onAppear { loadItems() }  // Never updates!
}
```

### 6. Error Handling with User Alerts

Always show errors to users with Analytics tracking:

```swift
do {
    try modelContext.save()
} catch {
    errorMessage = error.localizedDescription
    Analytics.trackError("save_failed", error: error)
}
```

### 7. DeckStatisticsCache Pattern

O(1) cache service with 30-second TTL to eliminate expensive database queries.

**Performance Impact:**
- Eliminates O(n) database queries for deck statistics
- Fixes tab-switching lag and "gesture timeout" errors
- Reduces deck list rendering from N*3 queries to 1 query with caching

**Cache Implementation:**
```swift
@MainActor
final class DeckStatisticsCache: Sendable {
    static let shared = DeckStatisticsCache()

    private var cache: [Deck.ID: CacheEntry] = [:]
    private let ttl: TimeInterval = 30.0 // 30 seconds
    private var globalTimestamp: Date = Date()

    struct CacheEntry {
        let statistics: DeckStatistics
        let timestamp: Date
    }

    func fetchDeckStatistics(for deck: Deck) -> DeckStatistics {
        // O(1) cache lookup
        if let entry = cache[deck.id],
           Date().timeIntervalSince(entry.timestamp) < ttl
        {
            return entry.statistics
        }

        // Cache miss: compute and cache
        let stats = computeStatistics(for: deck)
        cache[deck.id] = CacheEntry(statistics: stats, timestamp: Date())
        return stats
    }

    func invalidate(deckID: Deck.ID? = nil) {
        if let deckID {
            cache.removeValue(forKey: deckID)
        } else {
            cache.removeAll()
        }
    }
}
```

**Cache-Aside Pattern:**

1. **Check cache** - O(1) dictionary lookup
2. **If miss** - Compute statistics (O(n) database query)
3. **Store result** - Save to cache with timestamp
4. **Return value** - Always return valid statistics

**Invalidation Triggers** (MANDATORY after data changes):

| Operation | Invalidation Scope | Reason |
|-----------|-------------------|--------|
| Card review | Specific deck | Due count changes |
| Card import | Specific deck | Total count changes |
| Deck deletion | Global | Deck removed |
| Card deletion | Specific deck | Total count changes |
| Orphan reassignment | Both decks | Card count changes in both |
| Orphan deletion | Global | May affect any deck |

**Usage Example:**
```swift
// Fetch statistics (uses cache if available)
let stats = DeckStatisticsCache.shared.fetchDeckStatistics(for: deck)

// After modifying data, invalidate cache
func processReview(flashcard: Flashcard, rating: Int) async throws {
    // ... update FSRS state ...
    try modelContext.save()

    // Critical: invalidate cache
    DeckStatisticsCache.shared.invalidate(deckID: flashcard.deck?.id)
}
```

**Thread Safety:**

- `@MainActor` isolation ensures thread-safe access
- No locks required (all operations on main actor)
- Safe for concurrent SwiftUI view updates

**Testing Support** (DEBUG only):
```swift
// Mock time for deterministic TTL testing
var mockDate = Date()
DeckStatisticsCache.setTimeProviderForTesting { mockDate }
mockDate = mockDate.addingTimeInterval(31) // Advance time

// Custom TTL for faster tests
DeckStatisticsCache.shared.setTTLForTesting(0.1)

// Cache inspection
DeckStatisticsCache.shared.clearForTesting()
DeckStatisticsCache.shared.size // Current entry count
```

**Public API:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `fetchDeckStatistics(for:)` | `Deck` | `DeckStatistics` | Get stats (uses cache if valid) |
| `get(deckID:)` | `UUID` | `DeckStatistics?` | Direct cache lookup (no TTL check) |
| `set(_:for:)` | `DeckStatistics`, `UUID` | `Void` | Store stats in cache |
| `setBatch(_:)` | `[UUID: DeckStatistics]` | `Void` | Bulk update for initial load |
| `invalidate(deckID:)` | `UUID?` (optional) | `Void` | Remove specific or clear all |
| `isValid(deckID:)` | `UUID` | `Bool` | Check existence + validity |
| `age()` | None | `TimeInterval?` | Get current cache age in seconds |

**Analytics Events Tracked:**
- `deck_statistics_cache_hit` - Successful cache lookup
- `deck_statistics_cache_miss` - Cache miss with reason metadata
- `deck_statistics_cache_set` - New entry stored
- `deck_statistics_cache_invalidate` - Cache invalidated

### 8. Toast Notification Pattern

**Description**: Non-intrusive, glassmorphic toast notifications for user feedback

**When to Use**:
- Success/error feedback for async operations
- Non-blocking user notifications
- Temporary status updates

**Usage**:
```swift
// In your view
@State private var showToast = false
@State private var toastMessage = ""
@State private var toastStyle: ToastStyle = .info

someView
    .toast(
        isPresented: $showToast,
        message: toastMessage,
        style: toastStyle,
        duration: 2.5
    )

// Trigger toast
showToast = true
toastMessage = "Operation completed successfully"
toastStyle = .success
```

**Styles Available**:
- `.success` - Green checkmark for successful operations
- `.error` - Red triangle for errors
- `.info` - Blue circle for informational messages
- `.warning` - Orange exclamation for warnings

**Reference**: `LexiconFlow/LexiconFlow/Views/Components/ToastView.swift`

**Rationale**: Provides consistent, non-intrusive user feedback that respects the app's glassmorphism design language. Includes haptic feedback for accessibility.

---

### 9. Multi-Modal Learning Integration Pattern

**Description**: Integrate all four learning modalities (Visual, Auditory, Kinesthetic, Contextual) into flashcard views for enhanced memory consolidation through multi-sensory encoding.

**When to Use**:
- All flashcard review interactions
- Card presentation views
- Study session workflows

**Usage**:
```swift
struct FlashcardView: View {
    @Bindable var card: Flashcard
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: 24) {
                // 1. Visual: Text display with typographic hierarchy
                Text(card.word)
                    .font(.system(size: 42, weight: .bold, design: .rounded))

                // 2. Visual: Phonetic notation
                if let phonetic = card.phonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // 3. Auditory: TTS integration
                if AppSettings.ttsEnabled {
                    Button {
                        SpeechService.shared.speak(card.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                }

                // 4. Contextual: AI-generated sentence
                if let sentence = card.generatedSentences.first {
                    Text(sentence.sentence)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // 5. Kinesthetic: Gesture-based grading
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    HapticService.shared.triggerFeedback(for: detectRating(from: value.translation))
                    updateGlassTint(for: value.translation)
                }
                .onEnded { value in
                    processRating(from: value.translation)
                }
        )
    }
}
```

**Pedagogical Benefits**:
- **Visual**: Orthographic processing → Occipital lobe
- **Auditory**: Phonological loop → Temporal lobe (Wernicke's area)
- **Kinesthetic**: Motor memory → Cerebellum + Motor cortex
- **Contextual**: Episodic binding → Hippocampus

**Expected Improvement**: 40-60% better retention vs. single-modality approaches (Dual Coding Theory + Embodied Cognition research).

**Reference**: `docs/MULTI_MODAL_LEARNING_ARCHITECTURE.md`

---

### 10. Bidirectional Learning Pattern

**Description**: Support Recognition (L2→L1) and Production (L1→L2) learning modes through CardType enumeration.

**Card Types Implemented**:
- `.forward` - Recognition mode (English→Russian)
- `.reverse` - Production mode (Russian→English)
- `.audio` - Audio-only listening comprehension (✅ Implemented)

**Data Model**:
```swift
enum CardType: String, Codable, Sendable {
    case forward    // Recognition mode (L2→L1)
    case reverse    // Production mode (L1→L2)
    case audio      // Audio-only listening comprehension (✅ Implemented)
    case cloze      // Cloze deletion (planned)
}
```

**Direction-Aware Rendering**:
```swift
struct CardFrontView: View {
    let card: Flashcard
    var isAudioOnly: Bool {
        card.cardType == .audio
    }

    var body: some View {
        if isAudioOnly {
            AudioOnlyCardContent(card: card)
        } else {
            // Standard content for forward/reverse
            standardCardContent
        }
    }
}
```

**Scheduler Filtering**:
```swift
func matchesStudyDirection(_ cardType: CardType, _ direction: StudyDirection) -> Bool {
    switch (cardType, direction) {
    case (.forward, .recognitionOnly), (.audio, .recognitionOnly):
        true  // Audio cards are recognition mode
    case (.reverse, .productionOnly):
        true
    case (_, .both):
        true
    default:
        false
    }
}
```

**Reference**: `docs/BIDIRECTIONAL_LEARNING_STRATEGY.md`

---

### 11. Audio-Only Learning Pattern

**Description**: Audio-only flashcards that train listening comprehension without visual support, using delayed text reveal to prevent visual crutch during audio playback.

**When to Use**:
- Listening comprehension practice
- Auditory processing training
- Phonetic discrimination exercises
- Advanced learners seeking auditory immersion

**Usage**:
```swift
struct AudioOnlyCardContent: View {
    let card: Flashcard
    @State private var revealText = false
    @State private var isSpeaking = false

    var body: some View {
        VStack(spacing: 30) {
            // Card type badge (purple for audio)
            HStack(spacing: 6) {
                Image(systemName: card.cardType.iconName)
                Text(card.cardType.displayName)
            }
            .foregroundStyle(.purple)

            // Animated speaker icon
            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .symbolEffect(.pulse, options: .repeating, isActive: isSpeaking)

            // Text reveals after audio completes
            if revealText {
                Text(wordToSpeak)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            playAudio() // Auto-play on appear
        }
    }

    private func playAudio() {
        guard AppSettings.ttsEnabled else {
            revealText = true
            return
        }

        isSpeaking = true
        SpeechService.shared.speak(wordToSpeak, language: speechLanguage)

        // Calculate duration and reveal text
        let duration = Double(wordToSpeak.count) * 0.12 + 0.5
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation {
                    revealText = true
                    isSpeaking = false
                }
            }
        }
    }
}
```

**Pedagogical Benefits**:
- **Auditory Cortex**: Heschl's gyrus activation for phonological processing
- **Wernicke's Area**: Comprehension of spoken language
- **Phonological Loop**: Baddeley's working memory model for auditory rehearsal
- **Prevents Visual Crutch**: No text during playback forces auditory focus

**Reference**: `docs/AUDIO_ONLY_CARDS.md`

**Rationale**: Audio-only cards provide pure listening comprehension training by hiding text during TTS playback. The delayed reveal prevents learners from relying on visual processing, strengthening auditory pathways in the brain.

---

### 12. Streak Milestone Celebration Pattern

**Description**: Celebratory audio feedback at study streak milestones to reinforce positive learning habits through gamification.

**When to Use**:
- Reinforcing daily study habits
- Celebrating user milestones
- Providing audio feedback for achievements

**Usage**:
```swift
@MainActor
final class StreakChimeService: Sendable {
    static let shared = StreakChimeService()

    private let milestoneDays: Set<Int> = [3, 7, 14, 30, 60, 90, 100, 365]

    func playStreakChime(for streak: Int) async {
        guard AppSettings.streakChimesEnabled else { return }
        guard milestoneDays.contains(streak) else { return }

        await playHarmonicChime(streak: streak)
    }

    private func playHarmonicChime(streak: Int) async {
        // Try milestone-specific sound file
        let soundFileName = "streak_chime_\(streak)"
        guard let soundURL = Bundle.main.url(forResource: soundFileName, withExtension: "wav") else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1020) // Sherlock sound
            return
        }

        // Play custom sound
        audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.play()
    }
}
```

**Milestones**: 3, 7, 14, 30, 60, 90, 100, 365 days

**Behavioral Psychology**:
- **Dopamine Release**: Audio rewards trigger positive reinforcement
- **Habit Formation**: Variable interval reinforcement schedule
- **Achievement Recognition**: Celebrates progress, boosts motivation

**Reference**: `LexiconFlow/LexiconFlow/Services/StreakChimeService.swift`

**Rationale**: Audio celebration at milestone streaks leverages operant conditioning to reinforce daily study habits. The variable interval schedule (unpredictable milestone timing) creates stronger habit formation than fixed rewards.

---

## Project Structure

```
LexiconFlow/
├── Models/         # SwiftData @Model classes
├── ViewModels/     # @MainActor coordinators (Scheduler)
├── Services/       # Translation, Analytics, DataImporter
├── Utils/          # AppSettings, KeychainManager, FSRSWrapper
├── Views/          # SwiftUI views
└── LexiconFlowTests/  # Unit tests (Swift Testing framework)
```

## Concurrency Guidelines

Swift 6 strict concurrency enforced:
- Use `@MainActor` for all ViewModels
- Use `actor` for services with mutable state
- Return DTOs from actors, not SwiftData models
- Never mutate `@Model` instances across actor boundaries

## Code Quality Standards

**Force Unwrap Policy:**
- **NEVER** use force unwrap (`!`) in production code
- Use optional binding (`if let`, `guard let`) or nil coalescing (`??`)
- Exception: Static constants validated at init with `assert()`

**FatalError Policy:**
- Development stage: `fatalError` acceptable in DEBUG for setup/critical errors
- Use graceful degradation in RELEASE builds

**Magic Numbers:**
- Always document with constants
- Add references for thresholds (e.g., Cambridge English for CEFR)

**Error Handling:**
- Always show errors to users with Analytics tracking
- Use typed errors with `isRetryable` property
- Implement exponential backoff for transient failures

## Naming Conventions

- Use `Flashcard` instead of `Card` (avoids collision with FSRS library's `Card` type)

## Translation Services

**On-Device Translation** (`OnDeviceTranslationService`): 100% offline, iOS 26 Translation framework, no API key needed.

**Limitations:** Text-only translation (no CEFR levels or context sentences like cloud service).

## Known Limitations

- On-device translation: Text-only (no CEFR/context sentences)
- Language packs require 50-200MB per language (one-time download)
- SwiftData migration: See docs/ARCHITECTURE.md for guidelines
