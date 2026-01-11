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

## Technical Implementation

**Quality Fallback Chain**:
1. Try preferred quality (premium/enhanced/default)
2. Fall back to next lower quality if unavailable
3. Final fallback to any available voice

**User Setting**:
- Stored in `AppSettings.ttsVoiceQuality`
- Default: `.enhanced`
- Persists across app launches via @AppStorage

**Enum Definition**:
```swift
enum VoiceQuality: String, CaseIterable, Sendable {
    case premium
    case enhanced
    case `default`

    var displayName: String { /* ... */ }
    var description: String { /* ... */ }
    var icon: String { /* ... */ }
}
```

## User Interface

**Location**: Settings → TTS Settings → Voice Quality Picker

**Implementation**: `TTSSettingsView.swift:100-122`

## Code Examples

**Voice Selection with Fallback** (`SpeechService.swift:202-241`):
```swift
private func voiceForLanguage(_ languageCode: String) -> AVSpeechSynthesisVoice? {
    let voices = self.availableVoices(for: languageCode)
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

## Testing

- `AppSettingsVoiceQualityTests.swift` - Enum property tests
- `SpeechServiceTests.swift` - Voice quality fallback tests
- `TTSSettingsViewTests.swift` - UI picker tests

## Future Enhancements

- [ ] Per-deck voice quality settings
- [ ] Voice preview playback in settings
- [ ] Automatic quality selection based on network status

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Related Files:**
- `LexiconFlow/LexiconFlow/Utils/AppSettings.swift` (VoiceQuality enum)
- `LexiconFlow/LexiconFlow/Services/SpeechService.swift` (voiceForLanguage method)
- `LexiconFlow/LexiconFlow/Views/Settings/TTSSettingsView.swift` (voice quality picker)
