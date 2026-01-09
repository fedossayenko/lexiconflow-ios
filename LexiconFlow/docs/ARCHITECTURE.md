# LexiconFlow iOS - Architecture Documentation

## Table of Contents

1. [Overview](#overview)
2. [MVVM with SwiftData](#mvvm-with-swiftdata)
3. [Actor-Based Concurrency](#actor-based-concurrency)
4. [SwiftData Concurrency Architecture](#swiftdata-concurrency-architecture)
5. [SwiftData Migration Strategy](#swiftdata-migration-strategy)
6. [Glass Morphism Performance](#glass-morphism-performance)
7. [Key Components](#key-components)
8. [Testing Strategy](#testing-strategy)

---

## Overview

LexiconFlow is a native iOS vocabulary acquisition app built with **Swift 6**, **SwiftUI**, **SwiftData**, and the **FSRS v5** spaced repetition algorithm. It targets iOS 26.0+ and uses "Liquid Glass" design patterns for a fluid, state-of-flow learning experience.

**Core Differentiators:**
- FSRS v5 algorithm (adaptive, superior to SM-2)
- iOS 26 "Liquid Glass" UI with reactive glass effects
- On-device AI (Foundation Models) for privacy
- On-device translation (iOS 26 Translation framework) - 100% offline, no API costs
- Two study modes: Scheduled (respects due dates) and Cram (for practice)

---

## MVVM with SwiftData

### Model Layer
- **Models**: `@Model` classes in `Models/` (Flashcard, Deck, FSRSState, FlashcardReview)
- SwiftData handles persistence automatically
- Relationships defined with `@Relationship` macro
- External storage for large data (images)

### ViewModel Layer
- **ViewModels**: `@MainActor` classes in `ViewModels/` (Scheduler, StudySessionViewModel)
- Business logic and state management
- Safe SwiftData mutations through `ModelContext`

### View Layer
- **Views**: SwiftUI views in `Views/` observing `@Bindable` models
- Automatic updates when data changes
- Gesture-driven interactions
- Reactive glass effects

---

## Actor-Based Concurrency

### Why Actors?
Swift 6 strict concurrency requires thread-safe access to shared mutable state. Actors provide serialization of access, preventing data races.

### Actor Isolation Pattern
```swift
// Business Logic: @MainActor isolated for safe SwiftData access
@MainActor
func processReview(flashcard: Flashcard, rating: Int) async throws {
    // Safe to access SwiftData models on MainActor
    flashcard.fsrsState?.stability = dto.stability
    try modelContext.save()
}
```

### Key Principles
1. **Models**: Standard `@Model` classes (no actor isolation)
   - SwiftData handles model concurrency internally
   - All model mutations must happen through a `ModelContext`

2. **Business Logic**: `@MainActor` isolated for safe SwiftData access
   - FSRSWrapper: `@MainActor` - thread-safe algorithm wrapper
   - Scheduler: `@MainActor` - safe SwiftData mutations
   - StudySessionViewModel: `@MainActor` - session state management

3. **DTO Pattern**: Return `Sendable` structs from actors, not models
   - `FSRSReviewResult`: `Sendable` struct with updated values
   - Prevents cross-actor model mutations
   - Caller (Scheduler) applies DTO updates on `@MainActor`

4. **Pure Functions**: No actor isolation needed
   - DateMath: Pure functions using `Calendar.autoupdatingCurrent`
   - Safe to call from any context

---

## SwiftData Concurrency Architecture

### Why SwiftData Models Cannot Be Actor-Isolated

SwiftData `@Model` classes handle their own concurrency internally via `ModelContext`. Adding `actor` to a SwiftData model would break persistence and cause compile errors. The current architecture is the **CORRECT** approach for Swift 6 + SwiftData.

### Data Flow

```
Actor (FSRSWrapper) → DTO (FSRSReviewResult) → MainActor (Scheduler) → SwiftData Models
```

### Example: Correct Pattern

```swift
// ✅ CORRECT: Actor returns DTO, MainActor applies updates
@MainActor
func processReview(flashcard: Flashcard, rating: Int) async -> FlashcardReview? {
    // 1. Call actor (returns DTO)
    let dto = try FSRSWrapper.shared.processReview(
        flashcard: flashcard,
        rating: rating
    )

    // 2. Apply DTO updates to model (safe on @MainActor)
    flashcard.fsrsState?.stability = dto.stability
    flashcard.fsrsState?.difficulty = dto.difficulty
    flashcard.fsrsState?.dueDate = dto.dueDate
    flashcard.fsrsState?.stateEnum = dto.stateEnum

    // 3. Save to SwiftData
    try modelContext.save()

    return review
}

// ❌ AVOID: Returning models from actors
actor MyActor {
    func getFlashcard() -> Flashcard { ... }  // DON'T DO THIS
}
```

---

## SwiftData Migration Strategy

LexiconFlow uses SwiftData's **automatic lightweight migration**. No explicit migration code is required for schema changes that meet the lightweight criteria.

### Migration History

| Version | Change | Type | Impact |
|---------|--------|------|--------|
| V1 → V2 | Added `translation: String?` to Flashcard | Lightweight | Existing cards have `nil` |
| V2 → V3 | Added `cefrLevel: String?` to Flashcard | Lightweight | Existing cards have `nil` |
| V3 → V4 | Added `lastReviewDate: Date?` to FSRSState | Lightweight | Existing cards have `nil` |
| V3 → V4 | Added `GeneratedSentence` and `DailyStats` models | Lightweight | No existing data affected |

### Lightweight Migration Criteria

SwiftData automatically handles migrations that:
- Add new properties (optional or with default values)
- Remove properties
- Add new models
- Remove empty models

All LexiconFlow schema changes meet these criteria, so no explicit migration plan is needed.

### Migration Implementation

```swift
// LexiconFlowApp.swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        FSRSState.self,
        Flashcard.self,
        Deck.self,
        FlashcardReview.self,
        StudySession.self,
        DailyStats.self,
        GeneratedSentence.self
    ])

    let persistentConfig = ModelConfiguration(isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [persistentConfig])
    } catch {
        // Fallback to in-memory storage
        let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [inMemoryConfig])
    }
}()
```

---

## Glass Morphism Performance

### Overview

LexiconFlow uses "Liquid Glass" design language with reactive glass effects that respond to FSRS memory stability. Glass effects are applied using a 3-tier thickness system that visualizes memory strength.

### Glass Thickness Levels

| Stability | Thickness | Visual Effect | Memory Metaphor |
|-----------|-----------|---------------|-----------------|
| < 10 | Thin | Fragile, translucent | New/weak memory |
| 10-50 | Regular | Standard opacity | Established memory |
| > 50 | Thick | High opacity, strong blur | Stable/strong memory |

### Performance Optimization Strategy

#### 1. GlassEffectContainer Component

**Location**: `Views/Components/GlassEffectContainer.swift`

**Purpose**: Optimized container for glass morphism effects with GPU caching

**Key Optimization**:
```swift
struct GlassEffectContainer<Content: View>: View {
    var body: some View {
        content
            .glassEffect(thickness)
            .drawingGroup() // Cache rendering for performance
    }
}
```

**How `.drawingGroup()` Works**:
- Flattens view hierarchy into single bitmap
- Caches result on GPU for subsequent frames
- Reduces CPU overhead for complex effects
- Significant performance gain with multiple glass elements

#### 2. When to Use GlassEffectContainer

**Use When**:
- Multiple glass elements on screen (e.g., card stacks, deck lists)
- Complex glass effects with multiple visual layers
- Performance-critical views with frequent redraws

**Don't Use When**:
- Single static glass element (optimization overhead unnecessary)
- Very simple content (plain text with no graphics)

#### 3. Performance Benchmarks

| Scenario | Target | Acceptable |
|----------|--------|------------|
| 10 glass elements | 120fps (ProMotion) | 60fps |
| 50 glass elements | 60fps | 45fps |
| Scroll performance | Smooth | No jank |
| Battery impact (50 elements, 1 hour) | <3% | <5% |

#### 4. ProMotion 120Hz Support

**Detection**: Use `UIScreen.maximumFramesPerSecond` to detect ProMotion devices

**Note**: `UIScreen.main` is deprecated in iOS 26.0. Use environment values instead:
```swift
@Environment(\.displayScale) var displayScale
```

**Performance Target**:
- Standard devices (60fps): Frame time < 16.6ms
- ProMotion devices (120fps): Frame time < 8.3ms

#### 5. Performance Testing

**Manual Testing**:
1. Create test deck with 50 flashcards
2. Scroll through deck list
3. Monitor frame rate with Xcode Instruments → Core Animation
4. Measure battery impact over 1 hour

**Automated Testing**:
- Use `GlassEffectPerformanceTestView` for stress testing
- 50+ glass elements with real-time FPS monitoring
- Battery level tracking
- Frame time measurement

**Performance Test View**:
```swift
GlassEffectPerformanceTestView()
    // Displays 50 glass cards with FPS counter
    // Real-time performance metrics
    // Battery monitoring
```

#### 6. Performance Best Practices

**DO**:
- ✅ Use `.drawingGroup()` for multiple glass elements
- ✅ Optimize glass effects based on device capability
- ✅ Test with Instruments (Core Animation, Time Profiler)
- ✅ Monitor battery impact during extended sessions
- ✅ Use `GlassEffectContainer` for reusable glass components

**DON'T**:
- ❌ Apply `.drawingGroup()` to single static elements
- ❌ Nest multiple `.drawingGroup()` modifiers (no additional benefit)
- ❌ Ignore ProMotion device optimization
- ❌ Skip performance testing with 50+ elements
- ❌ Use glass effects for simple text without optimization

#### 7. Memory Management

**External Storage for Images**:
```swift
@Attribute(.externalStorage) var imageData: Data?
```
- Stores large data outside main database file
- Reduces memory footprint during queries
- Essential for image-heavy flashcards

**DrawingGroup Memory Impact**:
- Caches rendered bitmap on GPU
- Memory cost: ~1-5MB per glass element
- Automatically released when view disappears
- Acceptable tradeoff for performance gain

#### 8. Debugging Performance Issues

**Instruments to Use**:
1. **Core Animation**: FPS and frame time
2. **Time Profiler**: CPU usage per function
3. **Allocations**: Memory growth over time
4. **Energy Log**: Battery impact

**Common Issues**:
- **Stuttering scrolling**: Add `.drawingGroup()` to glass containers
- **High battery usage**: Reduce glass element count, simplify effects
- **Memory growth**: Check for retain cycles, external storage for images

---

## Key Components

### Flashcard
Core vocabulary model with word, definition, phonetic, and optional image data.

### Deck
Container/organizer for flashcards with study statistics tracking.

### FSRSState
Algorithm state (stability, difficulty, retrievability, dueDate) implementing FSRS v5.

### FlashcardReview
Historical review log for analytics and export functionality.

### Scheduler
Main coordinator for fetching cards and processing reviews with FSRS algorithm.

### TranslationService
Cloud-based translation with API key (requires internet).

### OnDeviceTranslationService
Offline translation using iOS 26 Translation framework (no API key, 100% local).

---

## Testing Strategy

### Framework
- **Swift Testing** (`import Testing`)
- In-memory SwiftData container for isolation
- Serialized execution for shared container tests

### Test Coverage
- **16 test suites** in `LexiconFlowTests/`
- **370+ tests** covering models, ViewModels, services
- **Target**: >80% coverage for new code

### Key Test Suites
- `ModelTests`: SwiftData model validation
- `SchedulerTests`: FSRS algorithm integration
- `StudySessionViewModelTests`: Session state management
- `TranslationServiceTests`: 42 tests with concurrency stress
- `OnDeviceTranslationServiceTests`: 44 tests for offline translation
- `OnDeviceTranslationValidationTests`: 26 tests for quality validation
- `EdgeCaseTests`: 40 tests for security, Unicode, input validation

### Performance Testing
- `GlassEffectPerformanceTestView`: 50+ glass elements stress test
- Real-time FPS monitoring
- Battery impact measurement
- Scroll performance validation

---

## Development Workflow

### Build Commands

```bash
# Build
cd LexiconFlow
xcodebuild build -project LexiconFlow.xcodeproj -scheme LexiconFlow

# Run tests (serialized for SwiftData)
xcodebuild test -project LexiconFlow.xcodeproj -scheme LexiconFlow \
  -parallel-testing-enabled NO
```

### Dependencies
- **SwiftFSRS**: `https://github.com/open-spaced-repetition/swift-fsrs` (v5.0.0)
- **Translation**: iOS 26 Translation framework (on-device, no package)

---

## Code Quality Standards

### Force Unwrap Policy
- **NEVER** use force unwrap (`!`) in production code
- Use optional binding (`if let`, `guard let`) or nil coalescing (`??`)
- Exception: Static constants validated at init with `assert()`

### FatalError Policy
- **NEVER** use `fatalError` in app initialization
- Use 3-tier graceful degradation: persistent → in-memory → minimal
- Always allow error UI to be shown to user

### Error Handling
- Always show errors to users with Analytics tracking
- Use typed errors with `isRetryable` property
- Implement exponential backoff for transient failures

### Concurrency Best Practices
- Use `@MainActor` for all ViewModels
- Use `actor` for services with mutable state
- Return DTOs from actors, not SwiftData models
- Add rollback logic when state changes fail to persist

---

## Known Limitations

- On-device translation provides text-only translation (no CEFR levels or context sentences)
- Language packs require 50-200MB per language (one-time download)
- SwiftData migration strategy uses automatic lightweight migration (suitable for current schema changes)

---

## Common Pitfalls

1. **Circular relationships**: Define inverse on only ONE side
2. **Enum in predicates**: Use string literals instead of enum raw values
3. **Cross-actor mutations**: Return DTOs from actors, not models
4. **Date math**: Use `DateMath.elapsedDays()` for timezone-aware calculations
5. **Force unwraps**: Avoid `!` without proper validation
6. **fatalError in app init**: Use ModelContainer fallback pattern instead
7. **Silent error swallowing**: Always show errors to users with Analytics tracking
