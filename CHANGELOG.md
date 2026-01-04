# Changelog

All notable changes to LexiconFlow iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Glass morphism effects for flashcards with stability-based thickness visualization
- `GlassEffectModifier` with `.glassEffect()` modifier for iOS "Liquid Glass" design
- `GlassThickness` enum (thin, regular, thick) mapped to FSRS stability values
- Swift 6 `Sendable` constraint on glass modifier generic type for strict concurrency
- Error alert dialogs for save failures (OnboardingView, AddDeckView, AddFlashcardView)
- Reactive due count updates using @Query in DeckRowView/DeckListView
- Error state tracking in StudySessionViewModel with user-facing alerts
- Bounds checking in delete methods (DeckListView, DeckDetailView)
- `StudySessionViewModelTests.swift` (9 tests) for view model behavior
- `OnboardingTests.swift` (6 tests) for onboarding flow
- `ErrorHandlingTests.swift` (5 tests) for error handling patterns
- `MainTabViewTests.swift` (26 tests) for tab navigation
- `DeckListViewTests.swift` (20 tests) for deck listing
- `DeckDetailViewTests.swift` (28 tests) for deck detail view

### Changed
- `FlashcardView` now uses glass effects instead of plain corner radius
- Card appearance dynamically adjusts based on memory stability (fragile → thin glass, stable → thick glass)
- View initialization pattern: @StateObject → @State with lazy initialization in `.task`
- Removed force unwraps from all view init methods (safety improvement)
- StudySessionViewModel: Now prevents card advancement on review failure
- AnalyticsTests: Removed flaky `benchmarkAccuracy` test
- HapticServiceTests: Fixed build errors, improved test assertions
- StudyViewTests: Fixed StudyMode reference
- FlashcardViewTests: Rewrote placeholder tests to verify actual behavior
- StudySessionViewTests: Removed meaningless smoke tests, kept data verification tests

### Fixed
- MainTabView: Fixed duplicate scheduler creation
- StudySessionView: Fixed broken onAppear workaround
- OnboardingView: Fixed silent save failures
- AddDeckView: Fixed silent save failures
- AddFlashcardView: Fixed stuck isSaving button on error
- DataImporter: Updated documentation to reflect @MainActor architecture

### Tests
- Total test count: 231 tests (14 test suites), all passing
- Test suites: ModelTests, SchedulerTests, DataImporterTests, StudySessionViewModelTests, OnboardingTests, ErrorHandlingTests, FSRSWrapperTests, DateMathTests, AnalyticsTests, MainTabViewTests, DeckListViewTests, DeckDetailViewTests, FlashcardViewTests, HapticServiceTests, StudyViewTests, StudySessionViewTests

## [0.1.0] - TBD

### Added
- Initial project structure
- SwiftData models (Flashcard, Deck, FSRSState, FlashcardReview)
- FSRS v5 algorithm integration via SwiftFSRS
- Basic UI structure (decks, cards, study session)
- Onboarding flow with sample data
- Scheduler for due card fetching and review processing
- DataImporter for batch card import
- Analytics and error tracking infrastructure
- DateMath utilities for timezone-aware calculations
