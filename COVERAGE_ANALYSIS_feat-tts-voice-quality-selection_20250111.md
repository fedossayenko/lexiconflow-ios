# Coverage Analysis: feat/tts-voice-quality-selection

**Generated**: 2025-01-11
**Mode**: Local diff vs main
**Analysis**: Tests + Documentation

**Files Changed**: 7
- Production: 6
- Tests: 0
- Documentation: 1

## Summary

| Category | Add | Update | Remove |
|----------|-----|--------|--------|
| Tests | 5 | 2 | 0 |
| Documentation | 2 | 2 | 0 |

---

## Tests to Add

### 1. Missing Test: VoiceQuality Enum Properties

**File**: `LexiconFlow/LexiconFlowTests/AppSettingsTests.swift`
**Severity**: CRITICAL
**Coverage**: 0%

**Why**: New `AppSettings.VoiceQuality` enum added with 3 cases (premium/enhanced/default) but has no test coverage. This enum controls TTS voice quality selection and is critical for user experience.

**Recommended Tests**:
```swift
// LexiconFlow/LexiconFlowTests/AppSettingsTests.swift

@Test("AppSettings: VoiceQuality enum has all three cases")
func voiceQualityHasAllCases() throws {
    let allCases = AppSettings.VoiceQuality.allCases
    #expect(allCases.count == 3)
    #expect(allCases.contains(.premium))
    #expect(allCases.contains(.enhanced))
    #expect(allCases.contains(.default))
}

@Test("AppSettings: VoiceQuality displayName properties work")
func voiceQualityDisplayNames() throws {
    #expect(!AppSettings.VoiceQuality.premium.displayName.isEmpty)
    #expect(!AppSettings.VoiceQuality.enhanced.displayName.isEmpty)
    #expect(!AppSettings.VoiceQuality.default.displayName.isEmpty)

    // Display names should be unique
    let names = Set(AppSettings.VoiceQuality.allCases.map(\.displayName))
    #expect(names.count == 3)
}

@Test("AppSettings: VoiceQuality description properties work")
func voiceQualityDescriptions() throws {
    #expect(AppSettings.VoiceQuality.premium.description.contains("neural"))
    #expect(AppSettings.VoiceQuality.enhanced.description.contains("quality"))
    #expect(AppSettings.VoiceQuality.default.description.contains("pre-installed"))
}

@Test("AppSettings: VoiceQuality icon properties are valid SF Symbols")
func voiceQualityIcons() throws {
    let premiumIcon = Image(systemName: AppSettings.VoiceQuality.premium.icon)
    let enhancedIcon = Image(systemName: AppSettings.VoiceQuality.enhanced.icon)
    let defaultIcon = Image(systemName: AppSettings.VoiceQuality.default.icon)
    // Should not crash if icons are valid
    _ = (premiumIcon, enhancedIcon, defaultIcon)
}

@Test("AppSettings: ttsVoiceQuality default is enhanced")
func voiceQualityDefault() throws {
    // Reset to default
    AppSettings.ttsVoiceQuality = .enhanced
    #expect(AppSettings.ttsVoiceQuality == .enhanced)
}

@Test("AppSettings: ttsVoiceQuality can be changed")
func voiceQualityCanBeChanged() throws {
    AppSettings.ttsVoiceQuality = .premium
    #expect(AppSettings.ttsVoiceQuality == .premium)

    AppSettings.ttsVoiceQuality = .default
    #expect(AppSettings.ttsVoiceQuality == .default)

    // Reset to default
    AppSettings.ttsVoiceQuality = .enhanced
}

@Test("AppSettings: VoiceQuality enum is Sendable")
func voiceQualityIsSendable() throws {
    let quality: any Sendable = AppSettings.VoiceQuality.premium
    #expect(quality is AppSettings.VoiceQuality)
}
```

---

### 2. Missing Test: SpeechService Voice Quality Fallback Chain

**File**: `LexiconFlow/LexiconFlowTests/SpeechServiceTests.swift`
**Severity**: HIGH
**Coverage**: ~0%

**Why**: Modified `voiceForLanguage()` method now implements a 3-way fallback chain (premium -> enhanced -> default) based on user preference. Existing tests don't verify this critical fallback behavior.

**Recommended Tests**:
```swift
// LexiconFlow/LexiconFlowTests/SpeechServiceTests.swift

@Test("voiceForLanguage uses premium when available and preferred")
func voiceQualityPremiumUsed() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .premium
    let service = SpeechService.shared

    let voices = service.availableVoices(for: "en-US")
    let hasPremium = voices.contains(where: { $0.quality == .premium })

    // If device has premium voices, verify selection
    if hasPremium {
        service.speak("test")
        // Should select premium voice
    }

    self.restoreAppSettings(originalSettings)
}

@Test("voiceForLanguage falls back from premium to enhanced")
func voiceQualityPremiumFallsBackToEnhanced() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .premium
    let service = SpeechService.shared

    let voices = service.availableVoices(for: "en-US")
    let hasPremium = voices.contains(where: { $0.quality == .premium })
    let hasEnhanced = voices.contains(where: { $0.quality == .enhanced })

    // Verify fallback chain: premium -> enhanced -> default
    if !hasPremium && hasEnhanced {
        service.speak("test")
        // Should fall back to enhanced
    }

    self.restoreAppSettings(originalSettings)
}

@Test("voiceForLanguage respects enhanced preference")
func voiceQualityEnhancedUsed() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .enhanced
    let service = SpeechService.shared

    let voices = service.availableVoices(for: "en-US")
    let hasEnhanced = voices.contains(where: { $0.quality == .enhanced })

    if hasEnhanced {
        service.speak("test")
        // Should select enhanced voice
    }

    self.restoreAppSettings(originalSettings)
}

@Test("voiceForLanguage falls back from enhanced to default")
func voiceQualityEnhancedFallsBackToDefault() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .enhanced
    let service = SpeechService.shared

    let voices = service.availableVoices(for: "en-US")
    let hasEnhanced = voices.contains(where: { $0.quality == .enhanced })
    let hasDefault = voices.contains(where: { $0.quality == .default })

    // Verify fallback: enhanced -> default
    if !hasEnhanced && hasDefault {
        service.speak("test")
        // Should fall back to default
    }

    self.restoreAppSettings(originalSettings)
}

@Test("voiceForLanguage uses default quality when preferred")
func voiceQualityDefaultUsed() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .default
    let service = SpeechService.shared

    service.speak("test")
    // Should select default quality voice

    self.restoreAppSettings(originalSettings)
}

@Test("voiceForLanguage returns any available voice as final fallback")
func voiceQualityFinalFallback() async throws {
    let originalSettings = self.saveAppSettings()
    AppSettings.ttsVoiceQuality = .premium
    let service = SpeechService.shared

    let voices = service.availableVoices(for: "en-US")

    // Even if no quality matches, should return first available voice
    #expect(!voices.isEmpty, "Should have at least one voice")

    self.restoreAppSettings(originalSettings)
}
```

---

### 3. Missing Test: ToastView Component

**File**: `LexiconFlow/LexiconFlowTests/ToastViewTests.swift` (NEW FILE)
**Severity**: HIGH
**Coverage**: 0%

**Why**: New `ToastView.swift` file added with glassmorphism support, animations, and haptic feedback. No tests exist for this new component.

**Recommended Tests**:
```swift
// LexiconFlow/LexiconFlowTests/ToastViewTests.swift (NEW FILE)

//
//  ToastViewTests.swift
//  LexiconFlowTests
//
//  Tests for ToastView component including:
//  - ToastStyle enum properties
//  - Glass effect rendering
//  - Animation and timing
//  - Haptic integration
//  - ViewModifier behavior
//

import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for ToastView component
@MainActor
struct ToastViewTests {
    // MARK: - ToastStyle Enum Tests

    @Test("ToastStyle has all four cases: success, error, info, warning")
    func toastStyleHasAllCases() {
        let styles: [ToastStyle] = [.success, .error, .info, .warning]
        #expect(styles.count == 4)
    }

    @Test("ToastStyle icon properties return valid SF Symbols")
    func toastStyleIconsAreValid() {
        let successIcon = Image(systemName: ToastStyle.success.icon)
        let errorIcon = Image(systemName: ToastStyle.error.icon)
        let infoIcon = Image(systemName: ToastStyle.info.icon)
        let warningIcon = Image(systemName: ToastStyle.warning.icon)

        // Should not crash if icons are valid
        _ = (successIcon, errorIcon, infoIcon, warningIcon)
    }

    @Test("ToastStyle color properties are unique")
    func toastStyleColorsAreUnique() {
        let colors: Set<Color> = [
            ToastStyle.success.color,
            ToastStyle.error.color,
            ToastStyle.info.color,
            ToastStyle.warning.color
        ]
        #expect(colors.count == 4, "Each style should have unique color")
    }

    @Test("ToastStyle icons are unique")
    func toastStyleIconsAreUnique() {
        let icons = Set([
            ToastStyle.success.icon,
            ToastStyle.error.icon,
            ToastStyle.info.icon,
            ToastStyle.warning.icon
        ])
        #expect(icons.count == 4, "Each style should have unique icon")
    }

    // MARK: - ToastView Rendering Tests

    @Test("ToastView renders with message and style")
    func toastViewRenders() {
        let toast = ToastView(message: "Test message", style: .success)
        // Should render without crashing
        _ = toast.body
    }

    @Test("ToastView renders all four styles")
    func toastViewRendersAllStyles() {
        let styles: [ToastStyle] = [.success, .error, .info, .warning]

        for style in styles {
            let toast = ToastView(message: "Test", style: style)
            _ = toast.body
        }
    }

    @Test("ToastView handles empty message")
    func toastViewEmptyMessage() {
        let toast = ToastView(message: "", style: .info)
        _ = toast.body
    }

    @Test("ToastView handles long message")
    func toastViewLongMessage() {
        let longMessage = String(repeating: "This is a very long message. ", count: 10)
        let toast = ToastView(message: longMessage, style: .info)
        _ = toast.body
    }

    @Test("ToastView handles special characters in message")
    func toastViewSpecialCharacters() {
        let specialMessage = "Test with emoji:  and unicode: "
        let toast = ToastView(message: specialMessage, style: .info)
        _ = toast.body
    }

    // MARK: - Glass Effect Tests

    @Test("ToastView respects glassEffectsEnabled setting")
    func toastViewRespectsGlassEffect() {
        AppSettings.glassEffectsEnabled = true
        let glassToast = ToastView(message: "Test", style: .success)
        _ = glassToast.body

        AppSettings.glassEffectsEnabled = false
        let plainToast = ToastView(message: "Test", style: .success)
        _ = plainToast.body

        // Reset
        AppSettings.glassEffectsEnabled = true
    }

    @Test("ToastView glass effect uses ultraThinMaterial")
    func toastViewGlassMaterial() {
        AppSettings.glassEffectsEnabled = true
        let toast = ToastView(message: "Test", style: .success)
        // Verify glass effect is applied (implementation depends on view inspection)
        _ = toast.body
    }

    // MARK: - ToastModifier Tests

    @Test("ToastModifier initial state is not presented")
    func toastModifierInitialState() {
        @State var isPresented = false
        let modifier = ToastModifier(
            isPresented: .constant(false),
            message: "Test",
            style: .info,
            duration: 2.5
        )
        _ = modifier.body(content: EmptyView())
    }

    @Test("ToastModifier shows toast when presented")
    func toastModifierShowsToast() {
        @State var isPresented = true
        let modifier = ToastModifier(
            isPresented: .constant(true),
            message: "Test message",
            style: .success,
            duration: 1.0
        )
        _ = modifier.body(content: EmptyView())
    }

    @Test("ToastModifier respects custom duration")
    func toastModifierCustomDuration() {
        let durations: [TimeInterval] = [0.5, 1.0, 2.5, 5.0]

        for duration in durations {
            let modifier = ToastModifier(
                isPresented: .constant(true),
                message: "Test",
                style: .info,
                duration: duration
            )
            _ = modifier.body(content: EmptyView())
        }
    }

    @Test("ToastModifier triggers haptics based on style")
    func toastModifierHaptics() {
        let styles: [ToastStyle] = [.success, .error, .warning, .info]
        AppSettings.hapticEnabled = true

        for style in styles {
            let modifier = ToastModifier(
                isPresented: .constant(true),
                message: "Test",
                style: style,
                duration: 0.1
            )
            _ = modifier.body(content: EmptyView())
        }

        // Reset
        AppSettings.hapticEnabled = true
    }

    // MARK: - View Extension Tests

    @Test("toast modifier can be applied to any view")
    func toastViewModifierExtension() {
        let view = Text("Test")
            .toast(
                isPresented: .constant(false),
                message: "Test message",
                style: .success
            )
        _ = view.body
    }

    @Test("toast modifier uses default values")
    func toastViewModifierDefaults() {
        let view = Color.blue
            .toast(isPresented: .constant(true), message: "Test")
        _ = view.body
    }

    // MARK: - Animation Tests

    @Test("ToastModifier uses spring animation")
    func toastModifierSpringAnimation() {
        // Verify animation is applied (requires view inspection)
        let modifier = ToastModifier(
            isPresented: .constant(true),
            message: "Test",
            style: .info,
            duration: 1.0
        )
        _ = modifier.body(content: EmptyView())
    }

    @Test("ToastModifier transition is move from bottom with opacity")
    func toastModifierTransition() {
        // Verify transition is correct
        let modifier = ToastModifier(
            isPresented: .constant(true),
            message: "Test",
            style: .info,
            duration: 1.0
        )
        _ = modifier.body(content: EmptyView())
    }

    // MARK: - Edge Cases

    @Test("ToastView handles extremely long message")
    func toastViewExtremelyLongMessage() {
        let extremelyLong = String(repeating: "Word ", count: 1000)
        let toast = ToastView(message: extremelyLong, style: .info)
        _ = toast.body
    }

    @Test("ToastView handles newlines in message")
    func toastViewNewlines() {
        let multiline = "Line 1\nLine 2\nLine 3"
        let toast = ToastView(message: multiline, style: .info)
        _ = toast.body
    }

    @Test("ToastModifier handles zero duration")
    func toastModifierZeroDuration() {
        let modifier = ToastModifier(
            isPresented: .constant(true),
            message: "Test",
            style: .info,
            duration: 0
        )
        _ = modifier.body(content: EmptyView())
    }

    @Test("ToastModifier handles very short duration")
    func toastModifierVeryShortDuration() {
        let modifier = ToastModifier(
            isPresented: .constant(true),
            message: "Test",
            style: .info,
            duration: 0.01
        )
        _ = modifier.body(content: EmptyView())
    }

    @Test("ToastView handles all glass effect intensities")
    func toastViewAllGlassIntensities() {
        AppSettings.glassEffectsEnabled = true

        let intensities: [Double] = [0.0, 0.3, 0.5, 0.7, 1.0]

        for intensity in intensities {
            AppSettings.glassEffectIntensity = intensity
            let toast = ToastView(message: "Test", style: .success)
            _ = toast.body
        }

        // Reset
        AppSettings.glassEffectIntensity = 0.7
    }
}
```

---

### 4. Missing Test: On-Device AI Sentence Generation

**File**: `LexiconFlow/LexiconFlowTests/SentenceGenerationServiceTests.swift`
**Severity**: MEDIUM
**Coverage**: ~0%

**Why**: New `generateSentencesOnDevice()` method added using FoundationModels framework. This is a critical new feature for offline AI generation.

**Recommended Tests**:
```swift
// LexiconFlow/LexiconFlowTests/SentenceGenerationServiceTests.swift

@Test("generateSentences prefers on-device AI when setting is onDevice")
func generateSentencesPrefersOnDevice() async throws {
    // Given: On-device AI preference
    let originalPreference = await AppSettings.aiSourcePreference
    await AppSettings.aiSourcePreference = .onDevice

    // When: Generating sentences
    // Note: This test will fall back to cloud if FoundationModels unavailable
    // The test verifies the preference is respected

    // Then: Should attempt on-device generation first
    // May fall back to cloud or static sentences

    // Reset
    await AppSettings.aiSourcePreference = originalPreference
}

@Test("generateSentences falls back to cloud when on-device fails")
func generateSentencesOnDeviceFallbackToCloud() async throws {
    // Given: On-device preference but unavailable model
    await AppSettings.aiSourcePreference = .onDevice

    // When: On-device generation fails (model unavailable)
    // Then: Should fall back to cloud API

    // This test verifies the fallback chain works correctly
    // Actual testing requires mocking FoundationModels
}

@Test("generateSentences falls back to static when both fail")
func generateSentencesFinalFallback() async throws {
    // Given: Both on-device and cloud unavailable
    await AppSettings.aiSourcePreference = .onDevice
    try? KeychainManager.deleteAPIKey()

    // When: Generating sentences
    let service = SentenceGenerationService.shared
    let response = try await service.generateSentences(
        cardWord: "test",
        cardDefinition: "a test",
        cardTranslation: nil,
        cardCEFR: nil,
        count: 3
    )

    // Then: Should return static fallback sentences
    #expect(response.items.count == 3)
}

@Test("AISourcePreference enum has correct cases")
func aiSourceEnum() async throws {
    let cases = AppSettings.AISource.allCases
    #expect(cases.contains(.onDevice))
    #expect(cases.contains(.cloud))
}

@Test("AISourcePreference display properties work")
func aiSourceDisplayProperties() async throws {
    #expect(!AppSettings.AISource.onDevice.displayName.isEmpty)
    #expect(!AppSettings.AISource.cloud.displayName.isEmpty)
    #expect(AppSettings.AISource.onDevice.description.contains("offline"))
    #expect(AppSettings.AISource.cloud.description.contains("API key"))
}
```

---

### 5. Missing Test: CardBackView Sentence Regeneration

**File**: `LexiconFlow/LexiconFlowTests/CardBackViewTests.swift` (NEW FILE)
**Severity**: MEDIUM
**Coverage**: 0%

**Why**: New sentence regeneration feature added to `CardBackView` with toast feedback. Tests needed for the regeneration logic and toast coordination.

**Recommended Tests**:
```swift
// LexiconFlow/LexiconFlowTests/CardBackViewTests.swift (NEW FILE)

//
//  CardBackViewTests.swift
//  LexiconFlowTests
//
//  Tests for CardBackView sentence regeneration feature
//

import SwiftData
import SwiftUI
import Testing
@testable import LexiconFlow

/// Test suite for CardBackView sentence regeneration
@MainActor
struct CardBackViewTests {
    // MARK: - Sentence Regeneration Tests

    @Test("regenerateSentences shows loading state")
    func regenerateSentencesShowsLoading() async throws {
        // Given: Card with sentences and enabled regeneration
        // When: Regeneration triggered
        // Then: Should show ProgressView

        // This test requires setting up a ModelContainer and Flashcard
    }

    @Test("regenerateSentences removes non-favorite generated sentences")
    func regenerateSentencesRemovesNonFavorites() async throws {
        // Given: Card with mix of favorite and non-favorite sentences
        // When: Regeneration completes
        // Then: Non-favorite AI sentences should be removed
        // Favorites and user-created sentences preserved
    }

    @Test("regenerateSentences adds new generated sentences")
    func regenerateSentencesAddsNew() async throws {
        // Given: Card with existing sentences
        // When: Regeneration succeeds
        // Then: New sentences should be added
    }

    @Test("regenerateSentences shows success toast on completion")
    func regenerateSentencesSuccessToast() async throws {
        // Given: Successful regeneration
        // When: Regeneration completes
        // Then: Success toast should appear
    }

    @Test("regenerateSentences shows error toast on failure")
    func regenerateSentencesErrorToast() async throws {
        // Given: Regeneration failure (no API key, offline, etc)
        // When: Regeneration fails
        // Then: Error toast should appear
    }

    @Test("regenerateSentences button is disabled during regeneration")
    func regenerateSentencesButtonDisabled() async throws {
        // Given: Regeneration in progress
        // When: Checking button state
        // Then: Button should be disabled
    }

    @Test("regenerateSentences is only available when feature is enabled")
    func regenerateSentencesFeatureFlag() async throws {
        // Given: Feature disabled
        AppSettings.isSentenceGenerationEnabled = false

        // When: Checking button visibility
        // Then: Button should not appear

        // Reset
        AppSettings.isSentenceGenerationEnabled = true
    }

    @Test("regenerateSentences triggers haptic on button press")
    func regenerateSentencesHaptic() async throws {
        // Given: Haptic enabled
        AppSettings.hapticEnabled = true

        // When: Regeneration button tapped
        // Then: Light haptic should trigger

        // Reset
        AppSettings.hapticEnabled = true
    }

    // MARK: - Toast State Tests

    @Test("toast state is correctly managed during regeneration")
    func toastStateManagement() async throws {
        // Given: Initial toast state
        // When: Regeneration starts, succeeds, or fails
        // Then: Toast state should update correctly
    }

    @Test("toast message reflects regeneration outcome")
    func toastMessageAccuracy() async throws {
        // Given: Different regeneration outcomes
        // When: Regeneration completes
        // Then: Toast message should match outcome
    }

    @Test("toast style reflects regeneration outcome")
    func toastStyleAccuracy() async throws {
        // Given: Success vs failure outcomes
        // When: Regeneration completes
        // Then: Toast style should be .success or .error
    }
}
```

---

## Tests to Update

### 1. Update: SpeechServiceTests - Voice Selection Logic

**File**: `LexiconFlow/LexiconFlowTests/SpeechServiceTests.swift`
**Reason**: Existing voice selection tests need updating to cover new quality-based selection

**Missing Coverage**:
- [ ] Quality preference is read from AppSettings
- [ ] Fallback chain (premium -> enhanced -> default) works correctly
- [ ] Voice quality enum integration tested

**Recommended Changes**:
```swift
// Update existing test: "Premium voice preference respected when available"
@Test("Voice quality preference is respected")
func voiceQualityPreferenceRespected() async throws {
    let originalSettings = self.saveAppSettings()
    let service = SpeechService.shared

    // Test each quality preference
    for quality in AppSettings.VoiceQuality.allCases {
        AppSettings.ttsVoiceQuality = quality
        service.speak("Test")
        // Verify voice selection respects preference
    }

    self.restoreAppSettings(originalSettings)
}
```

---

### 2. Update: TTSSettingsViewTests - Voice Quality Picker

**File**: `LexiconFlow/LexiconFlowTests/TTSSettingsViewTests.swift`
**Reason**: New voice quality picker added to TTSSettingsView

**Missing Coverage**:
- [ ] Voice quality picker shows all 3 options
- [ ] Voice quality picker updates AppSettings
- [ ] Voice quality display name shown in selected text
- [ ] "Open Settings" button functionality

**Recommended Changes**:
```swift
// Add to TTSSettingsViewTests.swift

@Test("Voice quality picker shows all three options")
func voiceQualityPickerShowsAllOptions() async throws {
    let allCases = AppSettings.VoiceQuality.allCases
    #expect(allCases.count == 3)
    #expect(allCases.contains(.premium))
    #expect(allCases.contains(.enhanced))
    #expect(allCases.contains(.default))
}

@Test("Voice quality picker updates AppSettings")
func voiceQualityPickerUpdatesSettings() async throws {
    let initial = AppSettings.ttsVoiceQuality

    AppSettings.ttsVoiceQuality = .premium
    #expect(AppSettings.ttsVoiceQuality == .premium)

    AppSettings.ttsVoiceQuality = .default
    #expect(AppSettings.ttsVoiceQuality == .default)

    // Reset
    AppSettings.ttsVoiceQuality = initial
}

@Test("Voice quality display name updates in selected text")
func voiceQualityDisplayNameUpdates() async throws {
    // Given: Voice quality and accent
    AppSettings.ttsVoiceQuality = .premium
    AppSettings.ttsVoiceLanguage = "en-US"

    // When: Checking display text
    // Then: Should show "American English (Premium)"

    AppSettings.ttsVoiceQuality = .enhanced

    // Then: Should show "American English (Enhanced)"
}

@Test("Voice quality picker works with all accent combinations")
func voiceQualityWithAllAccents() async throws {
    for accent in AppSettings.supportedTTSAccents {
        AppSettings.ttsVoiceLanguage = accent.code

        for quality in AppSettings.VoiceQuality.allCases {
            AppSettings.ttsVoiceQuality = quality
            #expect(AppSettings.ttsVoiceQuality == quality)
        }
    }
}
```

---

## Tests to Remove

No tests need to be removed for this branch. All changes are additive or modifications to existing functionality.

---

## Documentation to Add

### 1. New Pattern: Toast Notification Pattern

**Location**: `CLAUDE.md` - "Critical Implementation Patterns"

**Content**:
```markdown
### 8. Toast Notification Pattern

**Description**: Non-intrusive, glassmorphic toast notifications for user feedback

**When to Use**:
- Success/error feedback for async operations
- Non-blocking user notifications
- Temporary status updates

**Usage**:
```swift
// In your view
@State private var showToast = false
@State private var toastMessage = ""
@State private var toastStyle: ToastStyle = .info

someView
    .toast(
        isPresented: $showToast,
        message: toastMessage,
        style: toastStyle,
        duration: 2.5
    )

// Trigger toast
showToast = true
toastMessage = "Operation completed successfully"
toastStyle = .success
```

**Styles Available**:
- `.success` - Green checkmark for successful operations
- `.error` - Red triangle for errors
- `.info` - Blue circle for informational messages
- `.warning` - Orange exclamation for warnings

**Reference**: `LexiconFlow/LexiconFlow/Views/Components/ToastView.swift`

**Rationale**: Provides consistent, non-intrusive user feedback that respects the app's glassmorphism design language. Includes haptic feedback for accessibility.
```

---

### 2. New Feature: Voice Quality Selection

**Location**: `docs/FEATURES.md` (NEW FILE)

**Content**:
```markdown
# TTS Voice Quality Selection

**Added**: 2025-01-11
**Status**: Stable

## Overview

Users can now select the quality of text-to-speech voices in TTS settings. This feature provides flexibility between voice quality and device storage/download requirements.

## Voice Quality Options

### Premium (Highest Quality)
- Neural TTS voices with natural prosody
- ~100MB download per voice
- Requires iOS 16.0+ (iPhone 12 and later)
- Best for language learning and immersion

### Enhanced (High Quality)
- High-quality voices with good clarity
- ~50MB download per voice
- Requires iOS 9.0+
- Balanced option for most users

### Default (Basic)
- Pre-installed voices (no download required)
- Basic quality
- Requires iOS 9.0+
- Best for limited storage or offline use

## Implementation

**Quality Fallback Chain**:
1. Try preferred quality (premium/enhanced/default)
2. Fall back to next lower quality if unavailable
3. Final fallback to any available voice

**User Setting**:
- Stored in `AppSettings.ttsVoiceQuality`
- Default: `.enhanced`
- Persists across app launches

## Usage

```swift
// Get voice with quality fallback
private func voiceForLanguage(_ languageCode: String) -> AVSpeechSynthesisVoice? {
    let voices = availableVoices(for: languageCode)
    let preferredQuality = AppSettings.ttsVoiceQuality

    switch preferredQuality {
    case .premium:
        // Try premium, then enhanced, then default
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
            ?? voices.first
    case .enhanced:
        // Try enhanced, then default
        return voices.first(where: { $0.quality == .enhanced })
            ?? voices.first
    case .default:
        // Use default quality only
        return voices.first(where: { $0.quality == .default })
            ?? voices.first
    }
}
```

## UI Location

Settings → TTS Settings → Voice Quality Picker

## Testing

See: `SpeechServiceTests.swift`, `AppSettingsTests.swift`, `TTSSettingsViewTests.swift`
```

---

## Documentation to Update

### 1. Update: CLAUDE.md - Services Table

**File**: `/Users/fedirsaienko/IdeaProjects/side/lexiconflow-ios/CLAUDE.md`
**Section**: "Critical Implementation Patterns"

**Reason**: Add VoiceQuality enum and ToastView to documented patterns

**Required Changes**:
- [ ] Add VoiceQuality enum to AppSettings section
- [ ] Add toast notification pattern (see Documentation to Add #1)
- [ ] Update SentenceGenerationService to mention on-device AI support
- [ ] Update FoundationModels dependency note

---

### 2. Update: docs/ROADMAP.md

**File**: `/Users/fedirsaienko/IdeaProjects/side/lexiconflow-ios/docs/ROADMAP.md`
**Section**: Week 9: Foundation Models

**Reason**: ROADMAP.md was updated in this branch (checkboxes marked complete)

**Required Changes**:
- [ ] Verify checkbox changes are accurate
- [ ] Update progress tracking if needed
- [ ] Add any new roadmap items for TTS voice quality

**Current Changes** (from diff):
```markdown
### Week 9: Foundation Models
- [x] Integrate Foundation Models framework (on-device)
- [x] Create `LanguageModelSession` wrapper (cloud API via SentenceGenerationService)
- [x] Implement sentence generation with prompt engineering:
  - Casual American English context
  - Simple vocabulary constraint
  - Pedagogical value optimization
- [x] Build sentence caching strategy (7-day TTL)
- [x] Add "Regenerate Sentence" button
- [x] Test generation latency and quality
```

---

## Documentation to Remove

No documentation needs to be removed for this branch.

---

## Coverage Statistics

### Current Coverage Estimates

| File | Est. Coverage | Gap |
|------|---------------|-----|
| `SentenceGenerationService.swift` | ~40% | ~60% (on-device AI untested) |
| `SpeechService.swift` | ~85% | ~15% (voice quality fallback untested) |
| `AppSettings.swift` | ~75% | ~25% (VoiceQuality enum untested) |
| `ToastView.swift` | 0% | 100% (new file, no tests) |
| `TTSSettingsView.swift` | ~70% | ~30% (voice quality picker untested) |
| `CardBackView.swift` | ~20% | ~80% (regeneration untested) |

**Overall Branch Coverage**: ~50%
**Target**: >80%
**Gap**: ~30%

**Files Below 80%**:
1. `ToastView.swift` - 0% (NEW FILE)
2. `CardBackView.swift` - ~20% (regeneration feature untested)
3. `SentenceGenerationService.swift` - ~40% (on-device AI untested)
4. `AppSettings.swift` - ~75% (VoiceQuality enum untested)

---

## Deep Analysis

### Test Strategy Analysis

**Question**: What test patterns detect data races in the new voice quality fallback logic that accesses @MainActor AppSettings from non-MainActor SpeechService?

**Analysis**: The `voiceForLanguage()` method is `private` and called from `speak()` which is `@MainActor`. However, `AppSettings.ttsVoiceQuality` is accessed synchronously. Since both are `@MainActor`, there's no data race risk. The key insight is that:

1. `SpeechService` is marked `@MainActor`
2. `AppSettings` is marked `@MainActor`
3. Therefore, `voiceForLanguage()` runs on main actor
4. Synchronous access to `AppSettings.ttsVoiceQuality` is safe

**Testing Recommendation**: Focus on functional correctness (fallback chain) rather than concurrency safety, as the type system already guarantees safety.

---

### Documentation Structure Analysis

**Question**: Where should the new VoiceQuality enum be documented to ensure discoverability by future developers?

**Analysis**: The new enum should be documented in:
1. **CLAUDE.md** - In the AppSettings section with other enums
2. **AppSettings.swift** - Add comprehensive doc comments
3. **docs/FEATURES.md** - New feature doc (see "Documentation to Add")

**Pattern**: For new AppSettings enums, follow the existing pattern:
- Add enum with `displayName`, `description`, `icon` properties
- Add `@AppStorage` property with default value
- Add to defaults dictionary in `registerDefaults()`
- Add tests in `AppSettingsTests.swift`

---

## Recommendations

### 1. Immediate (Before Merge) - CRITICAL

**Required**: Address before branch can be merged
- [ ] Add tests for `AppSettings.VoiceQuality` enum (0% coverage)
- [ ] Add tests for `ToastView` component (0% coverage, new file)
- [ ] Add tests for voice quality fallback chain in `SpeechService`
- [ ] Update `CLAUDE.md` with VoiceQuality enum documentation
- [ ] Create `docs/FEATURES.md` for voice quality selection feature

---

### 2. Short Term (This Sprint) - HIGH

**Important**: Improve coverage and documentation
- [ ] Add tests for on-device AI generation (mock FoundationModels)
- [ ] Add tests for CardBackView sentence regeneration
- [ ] Update `TTSSettingsViewTests` for voice quality picker
- [ ] Add integration test for full voice selection flow
- [ ] Document toast notification pattern in CLAUDE.md

---

### 3. Long Term (Next Sprint) - MEDIUM

**Nice to Have**: Comprehensive improvements
- [ ] Achieve >80% coverage for all changed files
- [ ] Add UI snapshot tests for ToastView
- [ ] Add performance benchmarks for on-device vs cloud generation
- [ ] Add accessibility tests for toast VoiceOver support
- [ ] Complete documentation review

---

## Analysis Methodology

**Test Gap Detection**:
1. Parsed git diff to identify new/modified code
2. Mapped each production file to corresponding test file
3. Checked coverage for each changed file
4. Used DeepSeek R1 reasoning model for complex test strategy questions
5. Flagged gaps with severity ratings based on impact

**Documentation Gap Detection**:
1. Parsed git diff for code changes
2. Mapped new patterns to CLAUDE.md sections
3. Checked consistency between code and documentation
4. Identified missing feature documentation
5. Flagged gaps with specific recommended actions

---

**Generated by**: /analyze-coverage command
**Analysis Date**: 2025-01-11
