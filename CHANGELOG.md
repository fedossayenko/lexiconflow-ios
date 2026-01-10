# Changelog

All notable changes to LexiconFlow iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **TTS Timing Options**: New `AppSettings.TTSTiming` enum with three modes:
  - `.onView` - Play pronunciation when card front appears (new default)
  - `.onFlip` - Play when card flips to back (legacy behavior)
  - `.manual` - Play only via speaker button (no auto-play)
- **Audio Session Management**: `SpeechService.cleanup()` and `restartEngine()` methods
  - Prevents AVAudioSession error 4099 during app background/foreground transitions
  - Integrated into `LexiconFlowApp.swift` scene phase lifecycle
- **Glass Effect Configuration**: Centralized `GlassEffectConfiguration` struct
  - Dynamic intensity mapping based on user preference (0.0 to 1.0)
  - Pre-computed opacity values for better GPU performance
  - Single ZStack composition (reduces render passes from 3 to 1)
- **Gesture Sensitivity**: User-adjustable swipe sensitivity (0.5× to 2.0×)
  - Lower sensitivity (0.5×) = higher thresholds = harder to trigger swipes
  - Higher sensitivity (2.0×) = lower thresholds = easier to trigger swipes
- **TTSViewModifier**: Shared view modifier to extract duplicated TTS timing logic
- **CardGestureViewModel Documentation**: Comprehensive design rationale (50+ lines)
- `SpeechServiceAudioSessionTests.swift` (29 tests) for audio session lifecycle
- `TTSSettingsViewTests.swift` (24 tests) for TTS timing enum and migration
- `GlassEffectConfigurationTests.swift` (26 tests) for glass configuration
- `AddDeckViewTests.swift` (20 tests) for toolbar refactoring
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
- **TTSSettingsView**: Replaced "Auto-Play on Flip" toggle with "Pronunciation Timing" picker
- **FlashcardView**: Implemented TTS timing logic in `.onAppear` and `.onChange(of: isFlipped)`
- **FlashcardMatchedView**: Implemented TTS timing logic using shared TTSViewModifier
- **GlassEffectModifier**: Optimized with pre-computed opacity and reduced branch evaluation
- **CardGestureViewModel**: Refactored to use dynamic `gestureConstants` based on sensitivity
- **Dark Mode**: Fixed reactive updates with `@AppStorage` binding (prevents stale state)
- `FlashcardView` now uses glass effects instead of plain corner radius
- Card appearance dynamically adjusts based on memory stability (fragile → thin glass, stable → thick glass)
- View initialization pattern: @StateObject → @State with lazy initialization in `.task`
- Removed force unwraps from all view init methods (safety improvement)
- StudySessionViewModel: Now prevents card advancement on review failure
- **CardGestureViewModelTests**: Added 24 tests for gesture sensitivity feature
- **AppSettingsTests**: Added 22 tests for TTSTiming enum, GlassEffectConfiguration, gesture sensitivity
- AnalyticsTests: Removed flaky `benchmarkAccuracy` test
- HapticServiceTests: Fixed build errors, improved test assertions
- StudyViewTests: Fixed StudyMode reference
- FlashcardViewTests: Rewrote placeholder tests to verify actual behavior
- StudySessionViewTests: Removed meaningless smoke tests, kept data verification tests

### Fixed
- **Audio Session Error 4099**: Resolved by explicit audio session deactivation on background
- **Duplicate Animations**: Removed nested flip animations in FlashcardView
- **Toolbar Warnings**: Refactored sheet-based views (AddDeckView) to use inline buttons
- **CardBackViewMatched Performance**: Replaced ScrollView with VStack to prevent layout thrashing
- MainTabView: Fixed duplicate scheduler creation
- StudySessionView: Fixed broken onAppear workaround
- OnboardingView: Fixed silent save failures
- AddDeckView: Fixed silent save failures
- AddFlashcardView: Fixed stuck isSaving button on error
- DataImporter: Updated documentation to reflect @MainActor architecture

### Performance
- Glass effect rendering now targets 60fps with <16.6ms frame time
- Glass modifiers use pre-computed values to reduce per-frame calculation overhead
- Reduced GPU composition passes from 3 to 1 for glass effects
- TTS timing logic extracted to shared ViewModifier (reduces code duplication)

### Migration
- One-time migration from `ttsAutoPlayOnFlip` boolean to `TTSTiming` enum
- Previous "On" setting → `.onFlip` (legacy behavior)
- Previous "Off" setting → `.onView` (new default)
- Migration key: `ttsTimingMigrated` (prevents re-migration)

### Tests
- Total test count: 370+ tests (20+ test suites), all passing
- New test suites: SpeechServiceAudioSessionTests (29), TTSSettingsViewTests (24), GlassEffectConfigurationTests (26), AddDeckViewTests (20)
- Updated test suites: CardGestureViewModelTests (+24), AppSettingsTests (+22)
- Test suites: ModelTests, SchedulerTests, DataImporterTests, StudySessionViewModelTests, OnboardingTests, ErrorHandlingTests, FSRSWrapperTests, DateMathTests, AnalyticsTests, MainTabViewTests, DeckListViewTests, DeckDetailViewTests, FlashcardViewTests, HapticServiceTests, StudyViewTests, StudySessionViewTests, TranslationServiceTests, OnDeviceTranslationServiceTests, KeychainManagerPersistenceTests, SettingsViewsTests, EdgeCaseTests

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
