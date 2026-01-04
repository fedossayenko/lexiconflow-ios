# Contributing to LexiconFlow

Thank you for your interest in contributing to LexiconFlow! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites

- Xcode 26.0+
- iOS 26.0+ SDK
- macOS Sequoia+
- Swift 6 compiler

### Setup

1. **Fork the repository**
   - Go to https://github.com/fedossayenko/lexiconflow-ios
   - Click "Fork" in the top right

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/lexiconflow-ios.git
   cd lexiconflow-ios
   ```

3. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/fedossayenko/lexiconflow-ios.git
   ```

4. **Open in Xcode**
   ```bash
   open LexiconFlow.xcodeproj
   ```

5. **Resolve dependencies**
   ```bash
   xcodebuild -resolvePackageDependencies
   ```

6. **Run tests**
   ```bash
   xcodebuild test -project LexiconFlow.xcodeproj -scheme LexiconFlow \
     -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1'
   ```

## Development Workflow

### Branch Strategy

```
main (protected)
  └── develop (integration)
    ├── feature/your-feature-name
    ├── fix/your-bug-fix
    └── refactor/your-refactor
```

**Rules**:
- Never commit directly to `main`
- Always branch from `develop`
- Target PRs to `develop` (NOT `main`)

### Creating a Branch

```bash
git checkout develop
git pull upstream develop
git checkout -b feature/your-feature-name
```

**Branch naming conventions**:
- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `refactor/component-name` - Code refactoring
- `docs/update-description` - Documentation updates
- `test/test-description` - Test additions

## Making Changes

### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Max line length: 120 characters
- Use meaningful variable/function names

### Project Conventions

#### 1. Naming: Flashcard vs Card

Use `Flashcard` instead of `Card` to avoid collision with FSRS library's `Card` type.

#### 2. Safe View Initialization

```swift
// ✅ CORRECT
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

// ❌ AVOID
struct MyView: View {
    @StateObject private var viewModel = ViewModel(modelContext: ModelContext(try! container))
}
```

#### 3. Error Handling

```swift
// ✅ CORRECT: Show error to user
@State private var errorMessage: String?

private func save() {
    do {
        try modelContext.save()
    } catch {
        errorMessage = error.localizedDescription
        Analytics.trackError("save_failed", error: error)
    }
}

// ❌ AVOID: Silent failures
private func save() {
    do {
        try modelContext.save()
    } catch {
        print("Failed to save: \(error)")
    }
}
```

#### 4. Reactive Updates

```swift
// ✅ CORRECT: Automatic updates with @Query
struct MyView: View {
    @Query private var items: [Item]

    var body: some View {
        List(items) { item in Text(item.name) }
    }
}

// ❌ AVOID: Manual refresh
struct MyView: View {
    @State private var items: [Item] = []

    var body: some View {
        List(items) { item in Text(item.name) }
            .onAppear { loadItems() }
    }
}
```

#### 5. String Literals in Predicates

```swift
// ✅ CORRECT
#Predicate<FSRSState> { state in
    state.stateEnum != "new"
}

// ❌ AVOID
#Predicate<FSRSState> { state in
    state.stateEnum != FlashcardState.new.rawValue
}
```

### Testing

1. **Add tests for new features** (>80% coverage target)
2. **Use Swift Testing framework** (`import Testing`)
3. **Use in-memory SwiftData containers**
4. **Mark test suites with `@MainActor`**
5. **Run tests before committing**

See [TESTING.md](docs/TESTING.md) for comprehensive testing guide.

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `perf`: Performance improvements

**Examples**:
```
feat(models): add Flashcard model with SwiftData

fix(scheduler): prevent card advancement on review failure

test(onboarding): add error handling tests

docs(readme): update build instructions
```

### Submitting Changes

1. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**
   - Go to https://github.com/fedossayenko/lexiconflow-ios/pulls
   - Click "New Pull Request"
   - Base: `develop` (NOT `main`)
   - Compare: `feature/your-feature-name`

3. **Fill PR template**
   ```markdown
   ## Summary
   - Bullet point describing the change
   - Another bullet point

   ## Test plan
   - [ ] Tests pass locally
   - [ ] Manual testing completed
   - [ ] Documentation updated

   ## Checklist
   - [ ] Code follows project conventions
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] Commit messages follow Conventional Commits
   ```

4. **Code Review**
   - Address review feedback promptly
   - Keep PRs small and focused (< 500 lines)
   - Request review from team members

5. **Merge**
   - Maintainer will squash and merge
   - Delete your feature branch after merge

## Project Structure

```
LexiconFlow/
├── App/                    # App entry point (@main)
├── Models/                 # SwiftData @Model classes
├── ViewModels/             # @MainActor coordinators
├── Services/               # Analytics, DataImporter
├── Utils/                  # FSRSWrapper, DateMath, FSRSConstants
├── Views/                  # SwiftUI views
│   ├── Components/         # Reusable UI components
│   ├── Study/              # Study session views
│   ├── Decks/              # Deck management
│   ├── Cards/              # Card management
│   └── Onboarding/         # First-run experience
├── Assets.xcassets/        # Images, colors
└── LexiconFlowTests/       # Unit tests
```

## Documentation

- **CLAUDE.md** - AI assistant guidance (read before coding)
- **ARCHITECTURE.md** - Technical architecture
- **TESTING.md** - Testing guide
- **WORKFLOW.md** - Git workflow and commits
- **ROADMAP.md** - Development phases

## Testing Guidelines

### Quick Test Commands

```bash
# Run all tests
xcodebuild test -project LexiconFlow.xcodeproj -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1'

# Run specific test suite
xcodebuild test -project LexiconFlow.xcodeproj -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1' \
  -only-testing:LexiconFlowTests/ModelTests
```

## Questions?

- **Check existing docs**: Start with [CLAUDE.md](CLAUDE.md) and [TESTING.md](docs/TESTING.md)
- **Search issues**: Look for similar issues in [GitHub Issues](https://github.com/fedossayenko/lexiconflow-ios/issues)
- **Create new issue**: If your question hasn't been answered
- **Start a discussion**: For general questions or ideas

## Code of Conduct

Be respectful, constructive, and inclusive. We're all here to build something great.

- Give and receive feedback gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to LexiconFlow!**
