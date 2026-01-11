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
  -only-testing:LexiconFlowTests -parallel-testing-enabled NO

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

O(1) cache service with 30-second TTL to eliminate expensive database queries:

```swift
// Cache-aside pattern
@MainActor func fetchDeckStatistics(for deck: Deck) -> DeckStatistics {
    // O(1) cache lookup
    if let cached = DeckStatisticsCache.shared.get(deckID: deck.id) {
        return cached
    }
    // Fallback to O(n) database query
    let stats = /* expensive aggregation */
    DeckStatisticsCache.shared.set(stats, for: deck.id)
    return stats
}

// Invalidate after data changes
func processReview(flashcard: Flashcard, rating: Int) async throws {
    // ... update FSRS state ...
    DeckStatisticsCache.shared.invalidate(deckID: flashcard.deck?.id)
}
```

**Invalidate Triggers:**
- After processing card review (due count changes)
- After importing cards (total count changes)
- After deleting deck or resetting card

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
