# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lexicon Flow** is a native iOS vocabulary acquisition app built with **Swift 6**, **SwiftUI**, **SwiftData**, and the **FSRS v5** spaced repetition algorithm. It targets iOS 26.0+ and uses "Liquid Glass" design patterns for a fluid, state-of-flow learning experience.

**Core Differentiators:**
- FSRS v5 algorithm (adaptive, superior to SM-2)
- iOS 26 "Liquid Glass" UI with reactive glass effects
- On-device AI (Foundation Models) for privacy
- Two study modes: Scheduled (respects due dates) and Cram (for practice)

## Build and Test Commands

### Build
```bash
cd LexiconFlow
xcodebuild build \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

### Run Tests
```bash
# Run all tests (serialized execution required for shared container)
cd LexiconFlow
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests \
  -parallel-testing-enabled NO

# Run specific test suite
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests/TranslationServiceTests \
  -parallel-testing-enabled NO
```

### Dependencies
- **SwiftFSRS**: `https://github.com/open-spaced-repetition/swift-fsrs` (v5.0.0)
- Resolve with: `xcodebuild -resolvePackageDependencies` (from `LexiconFlow/` directory)

## Architecture

### MVVM with SwiftData
- **Models**: `@Model` classes in `Models/` (Flashcard, Deck, FSRSState, FlashcardReview)
- **ViewModels**: `@MainActor` classes in `ViewModels/` (Scheduler)
- **Views**: SwiftUI views in `Views/` observing `@Bindable` models

### Actor-Based Concurrency
- **FSRSWrapper**: Actor-isolated wrapper for FSRS algorithm operations (returns DTOs)
- **Scheduler**: `@MainActor` view model that applies DTO updates to SwiftData models
- **DTO Pattern**: Data transfer objects prevent cross-actor concurrency issues

### SwiftData Concurrency Architecture

**Why SwiftData Models Cannot Be Actor-Isolated:**

SwiftData `@Model` classes handle their own concurrency internally via `ModelContext`. Adding `actor` to a SwiftData model would break persistence and cause compile errors. The current architecture is the CORRECT approach for Swift 6 + SwiftData.

**Data Flow:**
```
Actor (FSRSWrapper) → DTO (FSRSReviewResult) → MainActor (Scheduler) → SwiftData Models
```

**Key Principles:**
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

**Example:**
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

### Key Components
- **Flashcard**: Core vocabulary model (word, definition, phonetic, imageData)
- **Deck**: Container/organizer for flashcards
- **FSRSState**: Algorithm state (stability, difficulty, retrievability, dueDate)
- **FlashcardReview**: Historical review log for analytics
- **Scheduler**: Main coordinator for fetching cards and processing reviews

### Study Modes
- **scheduled**: Respects due dates, updates FSRS state after each review
- **cram**: Ignores due dates, logs reviews only (doesn't update FSRS)

## Critical Implementation Patterns

### 1. Naming: Flashcard vs Card
- Use `Flashcard` instead of `Card` to avoid collision with FSRS library's `Card` type

### 2. ModelContainer Fallback Pattern (No fatalError)
**NEVER use `fatalError` for ModelContainer creation** - it causes immediate app crash:
```swift
// ❌ AVOID: Crashes app on any database error
var sharedModelContainer: ModelContainer = {
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")  // CRASH!
    }
}()

// ✅ CORRECT: Graceful degradation with fallback
var sharedModelContainer: ModelContainer = {
    let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        logger.critical("ModelContainer creation failed: \(error)")
        Analytics.trackError("model_container_failed", error: error)

        // Fallback to in-memory for recovery
        let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        } catch {
            // Last resort: minimal app with error UI
            return ModelContainer(for: [])
        }
    }
}()
```
**Rationale**: Database corruption, permissions, or disk full should not crash the app. Use in-memory fallback to allow user to see error and attempt recovery.

### 3. KeychainManager Security Pattern
**Use KeychainManager for sensitive data** (API keys, tokens):
```swift
// Store API key securely
try KeychainManager.setAPIKey("sk-test-...")

// Retrieve API key
if let apiKey = try KeychainManager.getAPIKey() {
    // Use API key
}

// Check if API key exists
if KeychainManager.hasAPIKey() {
    // API key is configured
}

// Delete API key
try KeychainManager.deleteAPIKey()
```
**Key Features**:
- UTF-8 encoding support (emoji, CJK, RTL languages)
- Generic account storage for custom data
- Empty key validation
- Secure storage with kSecClassGenericPassword

### 4. AppSettings Centralization (Not @AppStorage)
**Use `AppSettings` class instead of direct `@AppStorage`** for centralized state management:
```swift
// ✅ CORRECT: Use AppSettings properties
struct MyView: View {
    var body: some View {
        Toggle("Translation", isOn: Binding(
            get: { AppSettings.isTranslationEnabled },
            set: { AppSettings.isTranslationEnabled = $0 }
        ))
    }
}

// ❌ AVOID: Direct @AppStorage
struct MyView: View {
    @AppStorage("translationEnabled") private var translationEnabled = true
    // ^^^ Scattered across views, hard to maintain
}
```
**Rationale**: Single source of truth, easier to test, centralized defaults.

### 5. TranslationService Batch Pattern
**Use actor-isolated TranslationService for concurrent batch translation**:
```swift
// Configure with API key
try KeychainManager.setAPIKey("sk-test-...")

// Batch translate with concurrency control
let service = TranslationService.shared
let result = try await service.translateBatch(
    cards,
    maxConcurrency: 5,
    progressHandler: { progress in
        print("Progress: \(progress.completedCount)/\(progress.totalCount)")
    }
)

// Result contains success/failure counts
print("Success: \(result.successCount)")
print("Failed: \(result.failedCount)")
```
**Key Features**:
- Rate limiting with adaptive concurrency
- Progress handler callbacks
- Individual card failure handling
- Actor-isolated for thread safety

### 6. DTO Pattern for Concurrency
```swift
// FSRSWrapper actor returns DTO (not model mutation)
func processReview(flashcard: Flashcard, rating: Int) throws -> FSRSReviewResult

// Scheduler (@MainActor) applies DTO updates
func processReview(flashcard: Flashcard, rating: Int) async -> FlashcardReview?
```

### 7. Single-Sided Inverse Relationships
Define `@Relationship` inverse on **only ONE side** to avoid SwiftData circular macro expansion errors:
```swift
// Flashcard.swift - inverse NOT defined here
@Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

// FSRSState.swift - inverse defined HERE
@Relationship(inverse: \Flashcard.fsrsState) var card: Flashcard?
```

### 8. Cached lastReviewDate
Cache last review date in `FSRSState.lastReviewDate` for O(1) access vs O(n) scan through reviewLogs

### 9. String Literals in Predicates
Use string literals instead of enum raw values in `#Predicate`:
```swift
// CORRECT: String literal
#Predicate<FSRSState> { state in
    state.stateEnum != "new"
}

// AVOID: Can cause SwiftData key path issues
#Predicate<FSRSState> { state in
    state.stateEnum != FlashcardState.new.rawValue
}
```

### 10. External Storage for Images
```swift
@Attribute(.externalStorage) var imageData: Data?
```

### 11. Timezone-Aware Date Math
Use `DateMath.elapsedDays()` for calendar-aware calculations (handles DST, timezone boundaries)

### 12. Safe View Initialization Pattern
Use `@State` with lazy initialization instead of `@StateObject` with force unwrap:
```swift
// ❌ AVOID: Force unwrap in init
struct MyView: View {
    @StateObject private var viewModel = ViewModel(modelContext: ModelContext(try! container))
}

// ✅ CORRECT: Lazy initialization with @State
struct MyView: View {
    @State private var viewModel: ViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                // content
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ViewModel(modelContext: modelContext)
            }
        }
    }
}
```
**Rationale**: Prevents app crashes if ModelContainer fails, follows iOS 26 best practices.

### 13. Reactive Updates with @Query
Use `@Query` for automatic SwiftData updates instead of manual refresh:
```swift
// ❌ AVOID: Manual refresh with .onAppear
struct MyView: View {
    @State private var items: [Item] = []

    var body: some View {
        List(items) { item in Text(item.name) }
            .onAppear { loadItems() }  // Never updates!
    }
}

// ✅ CORRECT: Automatic updates with @Query
struct MyView: View {
    @Query private var items: [Item]

    var body: some View {
        List(items) { item in Text(item.name) }  // Auto-updates
    }
}
```
**Rationale**: @Query automatically tracks SwiftData changes and updates the view.

### 14. Error Handling with User Alerts
Always show errors to users with Analytics tracking:
```swift
struct MyView: View {
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button("Save") { save() }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            Analytics.trackError("save_failed", error: error)
        }
    }
}
```
**Rationale**: Silent failures create poor UX. Users need to know when operations fail.

## Project Structure

```
LexiconFlow/
├── App/                    # App entry point (@main)
├── Models/                 # SwiftData @Model classes
├── ViewModels/             # @MainActor coordinators (Scheduler)
├── Services/               # TranslationService, Analytics, DataImporter
├── Utils/                  # AppSettings, KeychainManager, FSRSWrapper, DateMath
├── Views/                  # SwiftUI views
│   ├── Cards/              # AddFlashcardView, StudySessionView
│   ├── Decks/              # DeckDetailView
│   └── Settings/           # TranslationSettingsView, AppearanceSettingsView, etc.
├── Assets.xcassets/        # Images, colors
└── LexiconFlowTests/       # Unit tests (14+ suites)
```

## Concurrency Guidelines

- Swift 6 strict concurrency is enforced
- Use `actor` for thread-safe operations (FSRSWrapper)
- Use `@MainActor` for SwiftData model mutations (Scheduler)
- Return `Sendable` DTOs from actors, not models
- Never mutate `@Model` instances across actor boundaries

## Testing

- **Framework**: Swift Testing (`import Testing`)
- **Structure**: 14 test suites in `LexiconFlowTests/`:
  - ModelTests, SchedulerTests, DataImporterTests
  - StudySessionViewModelTests, OnboardingTests, ErrorHandlingTests
  - FSRSWrapperTests, DateMathTests, AnalyticsTests
  - TranslationServiceTests (42 tests with concurrency stress tests)
  - AddFlashcardViewTests (23 tests for saveCard() flow)
  - KeychainManagerPersistenceTests (30 tests for UTF-8, persistence)
  - SettingsViewsTests (42 smoke tests for settings views)
  - EdgeCaseTests (40 tests for security, Unicode, input validation)
- **Pattern**: In-memory SwiftData container for isolation
- **Coverage Target**: >80% for new code
- **Test Execution**: Use `-parallel-testing-enabled NO` for shared container tests

## Development Workflow

### Branch Strategy
```
main (protected)
  └── develop (integration)
    ├── feature/phase1-foundation
    ├── feature/phase2-liquid-ui
    ├── feature/phase3-intelligence
    └── feature/phase4-polish
```

### Commit Conventions
```
<type>(<scope>): <subject>

Types: feat, fix, refactor, test, docs, chore, perf

Example:
feat(models): add Flashcard model with SwiftData
```

## Documentation

Comprehensive documentation in `/docs/`:
- `ARCHITECTURE.md` - Technical architecture with code examples
- `ALGORITHM_SPECS.md` - FSRS v5 implementation details
- `WORKFLOW.md` - Git workflow and commit conventions
- `ROADMAP.md` - 16-week phased development plan

## Known Limitations

- No linting tools configured (consider adding SwiftLint)
- "Liquid Glass" UI not yet implemented (planned for Phase 2)
- AI integration not yet implemented (planned for Phase 3)
- SwiftData migration strategy not yet defined (translation fields added as optional)

## Common Pitfalls

1. **Circular relationships**: Define inverse on only ONE side
2. **Enum in predicates**: Use string literals instead of enum raw values
3. **Cross-actor mutations**: Return DTOs from actors, not models
4. **Date math**: Use `DateMath.elapsedDays()` for timezone-aware calculations
5. **Force unwraps**: Avoid `!` without proper validation
6. **fatalError in app init**: Use ModelContainer fallback pattern instead
7. **Direct @AppStorage**: Use AppSettings class for centralized state
8. **Silent error swallowing**: Always show errors to users with Analytics tracking
9. **Force view refresh**: Avoid UUID hacks, use proper @Observable state
10. **API key validation side effects**: Validate before storing to Keychain
