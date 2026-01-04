# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Glass morphism effects for flashcards with stability-based thickness visualization
- `GlassEffectModifier` with `.glassEffect()` modifier for iOS "Liquid Glass" design
- `GlassThickness` enum (thin, regular, thick) mapped to FSRS stability values
- Swift 6 `Sendable` constraint on glass modifier generic type for strict concurrency

### Changed
- `FlashcardView` now uses glass effects instead of plain corner radius
- Card appearance dynamically adjusts based on memory stability (fragile → thin glass, stable → thick glass)

## [0.1.0] - 2026-01-04

### Added
- Initial project setup with Swift 6 and SwiftUI
- SwiftData models: Flashcard, Deck, FSRSState, FlashcardReview
- FSRS v5 algorithm integration for spaced repetition
- Basic UI: Deck list, card detail, study session views
- Onboarding flow with sample data
- 131 unit tests across 9 test suites

[Unreleased]: https://github.com/fedossayenko/lexiconflow-ios/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fedossayenko/lexiconflow-ios/releases/tag/v0.1.0
