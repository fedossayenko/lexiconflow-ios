# Code Review: feat/tts-voice-quality-selection

**Generated**: 2026-01-11 17:40:05
**Branch**: feat/tts-voice-quality-selection
**Base Branch**: main
**Files Changed**: 7 files (+435 lines, -19 lines)
**Commits**: 2 commits

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 2 |
| HIGH | 2 |
| MEDIUM | 3 |
| LOW | 2 |
| POSITIVE | 5 |

---

## Critical Issues

### File: LexiconFlow/LexiconFlow/Services/SentenceGenerationService.swift:231

**Severity**: CRITICAL
**Category**: Concurrency - Architecture Pattern Violation
**Issue**: Direct @MainActor property access from actor creates tight coupling

**Code**:
```swift
// Line 231
if await AppSettings.aiSourcePreference == .onDevice {
```

**Problem**:
- Creates tight coupling between `SentenceGenerationService` actor and `@MainActor` AppSettings
- Requires actor hopping (performance penalty in batch operations)
- Makes testing difficult (requires @MainActor context)
- Violates DTO pattern for cross-actor data flow

**Concurrency Impact**:
- Each `await` suspends the current task and switches to main actor
- In batch operations, this could happen hundreds of times
- Creates reentrancy risks where other tasks may run during suspension

**Recommendation**:
```swift
// 1. Create DTO in AppSettings.swift
extension AppSettings {
    struct GenerationConfig: Sendable {
        let aiSource: AISource
        let sourceLanguage: String
        let targetLanguage: String

        @MainActor
        static var current: GenerationConfig {
            GenerationConfig(
                aiSource: aiSourcePreference,
                sourceLanguage: translationSourceLanguage,
                targetLanguage: translationTargetLanguage
            )
        }
    }
}

// 2. Modify service to accept DTO
actor SentenceGenerationService {
    func generateSentences(
        config: AppSettings.GenerationConfig,
        cardWord: String,
        cardDefinition: String,
        cardTranslation: String? = nil,
        cardCEFR: String? = nil,
        count: Int = Config.defaultSentencesPerCard
    ) async throws -> SentenceGenerationResponse {
        // Use config instead of direct access
        if config.aiSource == .onDevice {
            // ...
        }
    }
}
```

**Reference**: CLAUDE.md - "DTO Pattern for Concurrency"

---

### File: LexiconFlow/LexiconFlow/Views/Study/CardBackView.swift:176-186

**Severity**: CRITICAL
**Category**: Concurrency - SwiftData Model Access Before MainActor.run

**Code**:
```swift
// Lines 176-186
private func regenerateSentences() {
    self.isRegenerating = true

    Task {
        do {
            let response = try await SentenceGenerationService.shared.generateSentences(
                cardWord: self.card.word,           // DANGEROUS: @Bindable access off main actor
                cardDefinition: self.card.definition,
                cardTranslation: self.card.translation,
                cardCEFR: self.card.cefrLevel
            )
```

**Problem**:
- `self.card` is a `@Bindable var card: Flashcard` (SwiftData model)
- Accessing `card.word`, `card.definition`, etc. happens BEFORE `await MainActor.run`
- The Task is not marked with `@MainActor`, so it runs on background thread
- SwiftData models should only be accessed on @MainActor

**Data Race Risk**:
- While `@Bindable` provides some protection, accessing model properties off the main actor violates Swift 6 strict concurrency
- Could cause undefined behavior if model is mutated concurrently

**Recommendation**:
```swift
private func regenerateSentences() {
    self.isRegenerating = true

    // Capture card data on main actor BEFORE Task
    let cardWord = self.card.word
    let cardDefinition = self.card.definition
    let cardTranslation = self.card.translation
    let cardCEFR = self.card.cefrLevel

    Task { @MainActor in  // Mark Task as @MainActor
        do {
            let response = try await SentenceGenerationService.shared.generateSentences(
                cardWord: cardWord,          // Safe: captured value
                cardDefinition: cardDefinition,
                cardTranslation: cardTranslation,
                cardCEFR: cardCEFR
            )

            // No need for MainActor.run - already on main actor
            let toRemove = self.card.generatedSentences.filter {
                !$0.isFavorite && $0.source != .userCreated
            }
            // ... mutations ...

            self.toastMessage = "New examples ready!"
            self.toastStyle = .success
            self.showToast = true
        } catch {
            self.toastMessage = "Generation failed"
            self.toastStyle = .error
            self.showToast = true
        }

        self.isRegenerating = false
    }
}
```

**Reference**: CLAUDE.md - "Swift 6 Concurrency Guidelines"

---

## High Priority Issues

### File: LexiconFlow/LexiconFlow/Views/Study/CardBackView.swift:204

**Severity**: HIGH
**Category**: Code Quality - Silent Error Swallowing

**Code**:
```swift
// Line 204
if let newSentence = try? GeneratedSentence(
    sentenceText: item.sentence,
    cefrLevel: item.cefrLevel,
    source: .aiGenerated
) {
    self.card.generatedSentences.append(newSentence)
}
```

**Problem**:
- Using `try?` silently swallows initialization errors
- If `GeneratedSentence.init` throws, the sentence is silently skipped
- User may not receive expected number of sentences
- No error logging or tracking

**Recommendation**:
```swift
do {
    let newSentence = try GeneratedSentence(
        sentenceText: item.sentence,
        cefrLevel: item.cefrLevel,
        source: .aiGenerated
    )
    self.card.generatedSentences.append(newSentence)
} catch {
    self.logger.error("Failed to create GeneratedSentence: \(error.localizedDescription)")
    Analytics.trackError("sentence_creation_failed", error: error)
}
```

**Reference**: CLAUDE.md - "Error Handling with User Alerts"

---

### File: LexiconFlow/LexiconFlow/Views/Study/CardBackView.swift:195-200

**Severity**: HIGH
**Category**: Code Quality - Inefficient Array Mutation

**Code**:
```swift
// Lines 195-200
for sentence in toRemove {
    if let index = card.generatedSentences.firstIndex(of: sentence) {
        self.card.generatedSentences.remove(at: index)
    }
    self.modelContext.delete(sentence)
}
```

**Problem**:
- Manual index lookup and removal is error-prone
- `firstIndex(of:)` is O(n) operation, called in loop makes it O(n^2)
- Could fail if array is modified during iteration

**Recommendation**:
```swift
// More efficient and safer
for sentence in toRemove {
    self.card.generatedSentences.removeAll { $0.id == sentence.id }
    self.modelContext.delete(sentence)
}
```

**Reference**: SwiftData best practices for relationship management

---

## Medium Priority Issues

### File: LexiconFlow/LexiconFlow/Views/Components/ToastView.swift:11-34

**Severity**: MEDIUM
**Category**: Code Quality - Missing Sendable Conformance

**Code**:
```swift
// Lines 11-34
enum ToastStyle {
    case success
    case error
    case info
    case warning

    var icon: String { ... }
    var color: Color { ... }
}
```

**Problem**:
- `ToastStyle` enum is not marked `Sendable`
- Used in `ToastModifier` which may be shared across actor boundaries
- Swift 6 strict concurrency requires explicit `Sendable` for types crossing actors
- `Color` is not `Sendable` in SwiftUI

**Recommendation**:
```swift
enum ToastStyle: Sendable {
    case success
    case error
    case info
    case warning

    var icon: String { ... }
}
```

**Reference**: Swift 6 Sendable requirements

---

### File: LexiconFlow/LexiconFlow/Services/SpeechService.swift:31

**Severity**: MEDIUM
**Category**: Documentation - Incorrect Actor Isolation

**Code**:
```swift
// Line 31
@MainActor
class SpeechService {
```

**Problem**:
- For long-form text, consider moving to background actor
- AVSpeechSynthesizer can work from background thread

**Consideration**:
- For short words/phrases, `@MainActor` is acceptable
- Add documentation note for future enhancements

---

### File: LexiconFlow/LexiconFlow/Views/Settings/TTSSettingsView.swift:237-249

**Severity**: MEDIUM
**Category**: Code Quality - Brittle Duration Estimation

**Code**:
```swift
// Lines 237-249
func testSpeech() {
    self.isTesting = true
    SpeechService.shared.speak("Ephemeral")

    // Reset after estimated duration (roughly 0.1s per character)
    let estimatedDuration = 10 * 0.1
    Task {
        try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1000000000))
        await MainActor.run {
            self.isTesting = false
        }
    }
}
```

**Problem**:
- Fixed 0.1s per character is inaccurate
- Doesn't account for speech rate setting

**Recommendation**:
```swift
private func estimateDuration() -> TimeInterval {
    let text = "Ephemeral"
    let baseRate = 0.1
    let rateMultiplier = 1.0 / AppSettings.ttsSpeechRate
    return Double(text.count) * baseRate * rateMultiplier + 0.5
}
```

---

## Low Priority Issues

### File: LexiconFlow/LexiconFlow/Views/Settings/TTSSettingsView.swift:139

**Severity**: LOW
**Category**: UX - Hardcoded Settings URL

**Recommendation**:
- Consider deep linking to exact settings path

---

### File: LexiconFlow/LexiconFlow/Utils/AppSettings.swift:154

**Severity**: LOW
**Category**: Documentation - Missing iOS Version Requirements

**Recommendation**:
- Add iOS version availability to documentation

---

## Positive Findings

### Excellent Voice Quality Fallback Chain

**File**: `LexiconFlow/LexiconFlow/Services/SpeechService.swift:212-241`

Graceful degradation: Premium → Enhanced → Default → Any available

---

### Clean Toast Notification Implementation

**File**: `LexiconFlow/LexiconFlow/Views/Components/ToastView.swift`

Reusable modifier pattern, SwiftUI-native animations, haptic feedback integration

---

### Proper @MainActor Isolation in SpeechService

**File**: `LexiconFlow/LexiconFlow/Services/SpeechService.swift:31`

AVAudioSession operations on main actor, prevents race conditions

---

### Comprehensive On-Device AI Integration

**File**: `LexiconFlow/LexiconFlow/Services/SentenceGenerationService.swift:269-307`

Privacy-first, graceful fallback, proper error handling

---

### Good Error Handling in Toast Integration

**File**: `LexiconFlow/LexiconFlow/Views/Study/CardBackView.swift:217-223`

User-facing error notification, Main actor isolation respected

---

## Statistics

- **Files Changed**: 7
- **Lines Added**: 435
- **Lines Removed**: 19
- **Force Unwrap Found**: 0
- **FatalError Found**: 0
- **@MainActor Violations**: 2
- **Test Coverage**: No tests added for new code
- **New Components**: 1 (ToastView)
- **SwiftData Pattern Violations**: 1

---

## Files Reviewed

1. `LexiconFlow/LexiconFlow/Services/SentenceGenerationService.swift`
2. `LexiconFlow/LexiconFlow/Services/SpeechService.swift`
3. `LexiconFlow/LexiconFlow/Utils/AppSettings.swift`
4. `LexiconFlow/LexiconFlow/Views/Components/ToastView.swift`
5. `LexiconFlow/LexiconFlow/Views/Settings/TTSSettingsView.swift`
6. `LexiconFlow/LexiconFlow/Views/Study/CardBackView.swift`
7. `docs/ROADMAP.md`

---

## Recommendations

### Address Immediately (Critical)

1. **Refactor SentenceGenerationService to use DTO pattern**
2. **Fix CardBackView model access pattern**

### Fix Soon (High Priority)

3. **Replace silent error swallowing in CardBackView**
4. **Improve array mutation efficiency**

### Consider (Medium/Low Priority)

5. **Add Sendable conformance to ToastStyle**
6. **Improve test speech duration estimation**
7. **Add tests for new functionality**

---

## Next Steps

1. Fix critical concurrency issues
2. Run tests: `xcodebuild test -scheme LexiconFlow`
3. Re-run review to verify fixes

**Branch Approval Status**: REQUIRES CHANGES
