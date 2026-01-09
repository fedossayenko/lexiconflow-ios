# Testing Guide

## Testing Framework

LexiconFlow uses **Swift Testing** (NOT XCTest):
- Import with `import Testing`
- Use `@Test("description")` attribute
- Use `#expect()` for assertions
- No `XCTestCase` subclasses needed
- Native async/await support

## Test Structure

### Test File Organization

```
LexiconFlowTests/
├── ModelTests.swift                    # SwiftData model tests
├── SchedulerTests.swift                # Business logic tests
├── StudySessionViewModelTests.swift    # ViewModel tests
├── OnboardingTests.swift               # Feature integration tests
├── ErrorHandlingTests.swift            # Error scenario tests
├── DataImporterTests.swift             # Service layer tests
├── FSRSWrapperTests.swift              # Algorithm integration tests
├── DateMathTests.swift                 # Utility tests
└── AnalyticsTests.swift                # Analytics & benchmarking
```

**Current Coverage** (as of January 2026):
- Total tests: **370+**
- Test suites: **24**
- Target: >80% for new code

### Test Suites (24 total)

| Test Suite | Focus | Test Count |
|------------|-------|------------|
| FSRSWrapperTests | Algorithm DTO integration | ~20 |
| SchedulerTests | Business logic, concurrency | ~30 |
| ModelTests | SwiftData models | ~18 |
| StudySessionViewModelTests | View model behavior | ~12 |
| StudySessionViewTests | Study view integration | ~8 |
| DateMathTests | Timezone-aware date math | ~26 |
| EdgeCaseTests | Unicode, security, validation | ~40 |
| FlashcardMigrationTests | Schema migration, backward compatibility | ~24 |
| TranslationServiceTests | Batch translation API | ~42 |
| KeychainManagerPersistenceTests | Keychain UTF-8 support | ~30 |
| AddFlashcardViewTests | Add flashcard flow | ~23 |
| AnalyticsTests | Event tracking | ~17 |
| HapticServiceTests | Haptic feedback | ~15 |
| CardGestureViewModelTests | Swipe gesture handling | ~12 |
| DataImporterTests | CSV import | ~18 |
| ErrorHandlingTests | Error scenarios | ~7 |
| SettingsViewsTests | Settings views smoke tests | ~42 |
| DeckListViewTests | Deck list view | ~8 |
| DeckDetailViewTests | Deck detail view | ~10 |
| FlashcardViewTests | Flashcard view | ~8 |
| GlassEffectModifierTests | Glass effect modifier | ~5 |
| MainTabViewTests | Main tab view | ~5 |
| OnboardingTests | First-run flow | ~8 |
| StudyViewTests | Study view | ~5 |

## Test Patterns

### 1. SwiftData Model Testing

Always use in-memory containers for isolation:

```swift
@MainActor
struct ModelTests {
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Flashcard creation with required fields")
    func flashcardCreation() {
        let container = createTestContainer()
        let context = container.mainContext

        let flashcard = Flashcard(word: "test", definition: "definition")
        context.insert(flashcard)
        try! context.save()

        #expect(flashcard.word == "test")
    }
}
```

**Key Points**:
- Always mark test suites with `@MainActor` (SwiftData requires main thread)
- Use `isStoredInMemoryOnly: true` for test isolation
- Include all 4 models in schema (relationships require them)

### 2. ViewModel Testing

Test business logic in isolation:

```swift
@MainActor
struct StudySessionViewModelTests {
    @Test("Submit rating advances to next card")
    func submitRatingAdvancesToNextCard() async throws {
        let container = createTestContainer()
        let context = container.mainContext
        let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

        // Create test cards
        // ...

        let initialIndex = viewModel.currentIndex
        await viewModel.submitRating(2)

        #expect(viewModel.currentIndex == initialIndex + 1)
    }
}
```

### 3. Error Handling Testing

Test both success and failure paths:

```swift
@Test("Submit rating without card does nothing")
func submitRatingWithoutCardDoesNothing() async throws {
    let viewModel = StudySessionViewModel(modelContext: context, mode: .scheduled)

    // Don't load any cards
    let initialIndex = viewModel.currentIndex

    await viewModel.submitRating(2)

    #expect(viewModel.currentIndex == initialIndex)  // Guard clause worked
    #expect(viewModel.lastError == nil)  // No error, just guarded
}
```

### 4. Async Testing

Use async/await naturally:

```swift
@Test("Process review updates FSRS state")
func scheduledModeUpdatesState() async throws {
    let flashcard = createTestFlashcard(context: context)

    _ = await scheduler.processReview(
        flashcard: flashcard,
        rating: 3,
        mode: .scheduled
    )

    #expect(flashcard.fsrsState!.dueDate > Date())
}
```

### 5. Concurrency Testing

Test thread safety with TaskGroup:

```swift
@Test("Concurrent review processing is serialized")
func concurrentReviews() async throws {
    await withTaskGroup(of: Void.self) { group in
        for card in cards {
            group.addTask {
                _ = await scheduler.processReview(flashcard: card, rating: 2, mode: .scheduled)
            }
        }
    }
    // Should not crash due to actor isolation
}
```

## Critical Testing Patterns

### DTO Pattern for Actor Isolation

When testing actor-isolated code (FSRSWrapper):

```swift
// ✅ CORRECT: Test DTO accuracy, not model mutation
@Test("DTO accuracy for new cards")
func dtoAccuracyForNewCards() {
    let dto = FSRSWrapper.shared.processReview(
        flashcard: newCard,
        rating: 2,
        mode: .scheduled
    )

    #expect(dto.state == .learning)
    #expect(dto.stability > 0)
}

// ❌ AVOID: Direct model mutation across actors
// This causes Swift 6 concurrency violations
```

**Rationale**: Actors return Sendable DTOs, not models. Testing DTO accuracy validates the algorithm without violating concurrency.

### Predicate String Literals

Always use string literals in SwiftData predicates:

```swift
// ✅ CORRECT: String literal
#Predicate<FSRSState> { state in
    state.stateEnum != "new"
}

// ❌ AVOID: Enum raw values
#Predicate<FSRSState> { state in
    state.stateEnum != FlashcardState.new.rawValue  // Can cause key path issues
}
```

**Rationale**: Enum raw values in predicates can cause SwiftData key path issues. String literals are reliable.

## Running Tests

### All Tests

```bash
cd LexiconFlow
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests
```

### Specific Test Suite

```bash
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests/ModelTests
```

### Specific Test

```bash
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests/ModelTests/testFlashcardCreation
```

## Test Coverage

### Coverage Areas

- ✅ SwiftData models (relationships, cascades, validation, migration)
- ✅ ViewModels (business logic, state management)
- ✅ Services (import, analytics, utilities, haptics)
- ✅ Error scenarios (save failures, validation errors)
- ✅ Concurrency (actor isolation, concurrent reviews)
- ✅ Retrievability calculation accuracy
- ✅ Clock skew and DST boundary handling
- ✅ Database backward compatibility (v1.0 → v1.1)
- ⚠️ UI components (smoke tests only, no SwiftUI view tests)
- ⚠️ Integration tests (no end-to-end flows yet)

### Recent Test Additions (January 2026)

#### FSRSWrapperTests
- Retrievability formula accuracy tests
- Retrievability clamping for extreme values
- Clock skew with future lastReviewDate
- DST boundary handling

#### SchedulerTests
- Concurrent reviews on same card
- lastReviewDate consistency verification
- FSRSState orphan prevention
- Stress test with >10 concurrent operations

#### FlashcardMigrationTests
- Database backward compatibility tests
- v1.0 to v1.1 migration defaults
- Empty string vs nil handling

## Common Pitfalls

### 1. Not Marking Test Suites as @MainActor

**Problem**: SwiftData requires main thread access

```swift
// ❌ AVOID
struct ModelTests {
    // Tests will fail with "context must be on main thread"
}

// ✅ CORRECT
@MainActor
struct ModelTests {
    // Tests run on main actor
}
```

### 2. Using Persistent Storage in Tests

**Problem**: Disk I/O is slow and tests can pollute each other

```swift
// ❌ AVOID
let configuration = ModelConfiguration()  // Persistent storage

// ✅ CORRECT
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
```

### 3. Testing Private Internals

**Problem**: Implementation details change, behavior stays

```swift
// ❌ AVOID
@Test("Internal _cache property works")
func testInternalCache() {
    #expect(viewModel._cache.count == 5)  // Brittle!
}

// ✅ CORRECT
@Test("Fetch returns cached results")
func testCachingBehavior() {
    let results = viewModel.fetch()
    #expect(results.count == 5)  // Tests behavior, not implementation
}
```

### 4. Flaky Timing Tests

**Problem**: `Task.sleep` is not precise

```swift
// ❌ AVOID
@Test("Operation completes in 50ms")
func testTiming() async {
    let start = Date()
    await performOperation()
    let duration = Date().timeIntervalSince(start)
    #expect(duration < 0.050)  // Flaky!
}

// ✅ CORRECT
@Test("Operation completes without error")
func testSuccess() async {
    await performOperation()
    // Don't assert exact timing
}
```

## Test Fixture Helpers

### createTestContainer()

Standard in-memory container:

```swift
private func createTestContainer() -> ModelContainer {
    let schema = Schema([
        FSRSState.self,
        Flashcard.self,
        Deck.self,
        FlashcardReview.self,
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [configuration])
}
```

### createTestDeck()

Create reusable deck instances:

```swift
private func createTestDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
    let deck = Deck(name: name, icon: "📚")
    context.insert(deck)
    try! context.save()
    return deck
}
```

### createTestFlashcard()

Create flashcards with custom FSRS state:

```swift
private func createTestFlashcard(
    context: ModelContext,
    word: String = UUID().uuidString,
    state: FlashcardState = .new,
    dueOffset: TimeInterval = 0
) -> Flashcard {
    let flashcard = Flashcard(word: word, definition: "Test definition")
    let fsrsState = FSRSState(
        stability: 0.0,
        difficulty: 5.0,
        retrievability: 0.9,
        dueDate: Date().addingTimeInterval(dueOffset),
        stateEnum: state.rawValue
    )
    flashcard.fsrsState = fsrsState
    context.insert(flashcard)
    context.insert(fsrsState)
    try! context.save()
    return flashcard
}
```

## CI/CD

Tests run automatically on:
- Pull requests to `main` or `develop`
- Workflow: `.github/workflows/ci.yml`
- Platform: macOS latest, iPhone 17 simulator, iOS 26.2

## Writing New Tests

1. **Choose test file**: Add to existing suite or create new one
2. **Mark as @MainActor**: Required for SwiftData tests
3. **Use in-memory container**: Call `createTestContainer()`
4. **Write descriptive test name**: Use `@Test("Description")`
5. **Arrange-Act-Assert**: Setup, execute, verify
6. **Run locally**: Verify before committing

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/swift-testing)
- [SwiftData Testing Guide](https://developer.apple.com/documentation/swiftdata/testing)
- [CLAUDE.md](../CLAUDE.md) - Project patterns and conventions
