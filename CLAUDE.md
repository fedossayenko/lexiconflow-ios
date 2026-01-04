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
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1'
```

### Run Tests
```bash
# Run all tests (serialized execution required for shared container)
cd LexiconFlow
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1' \
  -only-testing:LexiconFlowTests \
  -parallel-testing-enabled NO

# Run specific test suite
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1' \
  -only-testing:LexiconFlowTests/ModelTests \
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

### 2. DTO Pattern for Concurrency
```swift
// FSRSWrapper actor returns DTO (not model mutation)
func processReview(flashcard: Flashcard, rating: Int) throws -> FSRSReviewResult

// Scheduler (@MainActor) applies DTO updates
func processReview(flashcard: Flashcard, rating: Int) async -> FlashcardReview?
```

### 3. Single-Sided Inverse Relationships
Define `@Relationship` inverse on **only ONE side** to avoid SwiftData circular macro expansion errors:
```swift
// Flashcard.swift - inverse NOT defined here
@Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

// FSRSState.swift - inverse defined HERE
@Relationship(inverse: \Flashcard.fsrsState) var card: Flashcard?
```

### 4. Cached lastReviewDate
Cache last review date in `FSRSState.lastReviewDate` for O(1) access vs O(n) scan through reviewLogs

### 5. String Literals in Predicates
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

### 6. External Storage for Images
```swift
@Attribute(.externalStorage) var imageData: Data?
```

### 7. Timezone-Aware Date Math
Use `DateMath.elapsedDays()` for calendar-aware calculations (handles DST, timezone boundaries)

### 8. Safe View Initialization Pattern
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

### 9. Reactive Updates with @Query
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

### 10. Error Handling with User Alerts
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
├── Services/               # Analytics, DataImporter
├── Utils/                  # FSRSWrapper, DateMath, FSRSConstants
├── Views/                  # SwiftUI views
├── Assets.xcassets/        # Images, colors
└── LexiconFlowTests/       # Unit tests
```

## Concurrency Guidelines

- Swift 6 strict concurrency is enforced
- Use `actor` for thread-safe operations (FSRSWrapper)
- Use `@MainActor` for SwiftData model mutations (Scheduler)
- Return `Sendable` DTOs from actors, not models
- Never mutate `@Model` instances across actor boundaries

## Testing

- **Framework**: Swift Testing (`import Testing`)
- **Structure**: 9 test suites in `LexiconFlowTests/` (ModelTests, SchedulerTests, DataImporterTests, StudySessionViewModelTests, OnboardingTests, ErrorHandlingTests, FSRSWrapperTests, DateMathTests, AnalyticsTests)
- **Pattern**: In-memory SwiftData container for isolation
- **Coverage Target**: >80% for new code

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

## Common Pitfalls

1. **Circular relationships**: Define inverse on only ONE side
2. **Enum in predicates**: Use string literals instead of enum raw values
3. **Cross-actor mutations**: Return DTOs from actors, not models
4. **Date math**: Use `DateMath.elapsedDays()` for timezone-aware calculations
5. **Force unwraps**: Avoid `!` without proper validation
