# Audio-Only Cards Feature

**Added**: January 2026
**Status**: Stable
**Card Type**: `.audio`

## Overview

Audio-only cards train listening comprehension by hiding text during text-to-speech playback. The word is revealed only after audio completes, preventing learners from relying on visual processing.

## Pedagogical Foundation

### Cognitive Targets

- **Primary Auditory Cortex** (Heschl's gyrus): Sound processing
- **Wernicke's Area**: Language comprehension
- **Phonological Loop** (Baddeley): Auditory working memory

### Benefits

1. **Pure listening comprehension** without visual crutch
2. **Phonetic discrimination training**
3. **Accent familiarization**
4. **Improved spelling** through orthographic-phonological binding

## Card Type Behavior

### Audio Card Properties

| Property | Value | Description |
|----------|-------|-------------|
| `cardType` | `.audio` | CardType enum value |
| `displayName` | "Audio-Only" | UI display name |
| `iconName` | "speaker.wave.2" | SF Symbol icon |
| `arrowSymbol` | "🔊" | Visual indicator |
| `color` | `.purple` | Theme color |

### Study Direction Compatibility

Audio cards are **Recognition mode** cards:

| Study Direction | Audio Cards Included |
|-----------------|---------------------|
| `recognitionOnly` | ✅ Yes |
| `productionOnly` | ❌ No |
| `both` | ✅ Yes |

**Rationale**: Audio cards train receptive vocabulary (listening), similar to forward cards (reading).

## User Flow

1. **Card appears** with animated speaker icon
2. **TTS auto-plays** the word (no text visible)
3. **Text fades in** after audio completes (0.12s per character + 0.5s buffer)
4. **User taps** to reveal answer
5. **User rates** their recall

## Settings

### Enable Audio-Only Cards

**Location**: Settings → Study → Card Types → "Include Audio-Only Cards"

**Default**: `false` (disabled until user creates audio cards)

**Dependency**: Requires TTS enabled to function properly

### TTS Language Detection

Audio cards use direction-aware language selection:

| Card Type | Language Source |
|-----------|-----------------|
| `.audio` (forward) | `AppSettings.ttsVoiceLanguage` |
| `.audio` (reverse) | `"ru-RU"` (hardcoded for Russian) |

## Implementation Details

### CardFrontView Changes

```swift
struct CardFrontView: View {
    var isAudioOnly: Bool {
        card.cardType == .audio
    }

    var body: some View {
        if isAudioOnly {
            AudioOnlyCardContent(card: card)
        } else {
            standardCardContent
        }
    }
}
```

### Scheduler Changes

```swift
func matchesStudyDirection(_ cardType: CardType, _ direction: StudyDirection) -> Bool {
    switch (cardType, direction) {
    case (.forward, .recognitionOnly), (.audio, .recognitionOnly):
        true  // Audio cards are recognition mode
    // ... other cases
    }
}
```

### CardType Enum

```swift
enum CardType: String, Codable {
    case forward
    case reverse
    case audio  // New case

    var displayName: String {
        switch self {
        case .audio: return "Audio-Only"
        // ...
        }
    }
}
```

### AudioOnlyCardContent Component

```swift
struct AudioOnlyCardContent: View {
    let card: Flashcard
    @State private var revealText = false
    @State private var isSpeaking = false

    var speechLanguage: String {
        // Reverse cards use "ru-RU", others use AppSettings
    }

    var wordToSpeak: String {
        // Forward/Audio use card.word, Reverse uses translation
    }

    var body: some View {
        VStack(spacing: 30) {
            // Card type badge (purple)
            // Animated speaker icon
            // Text reveals after audio
        }
        .onAppear {
            playAudio()  // Auto-play on appear
        }
    }

    private func playAudio() {
        guard AppSettings.ttsEnabled else {
            revealText = true
            return
        }

        isSpeaking = true
        SpeechService.shared.speak(wordToSpeak, language: speechLanguage)

        // Calculate duration and reveal text
        let duration = Double(wordToSpeak.count) * 0.12 + 0.5
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation {
                    revealText = true
                    isSpeaking = false
                }
            }
        }
    }
}
```

## Testing

### Unit Tests

**File**: `LexiconFlowTests/AudioOnlyCardTests.swift`

Coverage includes:
- CardType enum properties (displayName, iconName, arrowSymbol)
- Flashcard model audio card type assignment
- Scheduler matching logic for all study directions
- CardFrontView isAudioOnly computed property
- SpeechService language parameter handling
- AppSettings.includeAudioOnlyCards persistence

### Test Coverage

| Component | Coverage | Notes |
|-----------|----------|-------|
| CardType.audio | 100% | All enum cases tested |
| Scheduler.matchesStudyDirection | 90% | Audio card coverage added |
| CardFrontView | 60% | New isAudioOnly property tested |
| SpeechService | 80% | Language parameter tested |
| AudioOnlyCardContent | 0% | SwiftUI view testing limitation |
| StreakChimeService | 85% | Smoke tests for AVFoundation |

**Gaps**:
- AudioOnlyContentView view tests are documentation-only (SwiftUI limitation)
- Actual audio playback cannot be asserted without protocol injection

## Migration

No data migration required. Audio cards are opt-in:
- New `AppSettings.includeAudioOnlyCards` defaults to `false`
- Existing cards unaffected
- Users must explicitly enable feature

## Future Enhancements

1. **Voice Recording Comparison**: Record user pronunciation, compare with TTS
2. **Speed Adjustment**: Variable playback speed (0.5x - 2.0x)
3. **Accent Options**: Multiple accent choices for audio-only cards
4. **Transcription Mode**: Type what you hear (dictation practice)

## References

- `docs/AUDIO_LEARNING_PEDAGOGY.md` - Pedagogical foundation
- `docs/BIDIRECTIONAL_LEARNING_STRATEGY.md` - Card type strategy
- `CLAUDE.md` Pattern 11 - Implementation pattern
- `LexiconFlow/LexiconFlow/Views/Study/AudioOnlyCardContent.swift` - View component
- `LexiconFlow/LexiconFlow/Services/StreakChimeService.swift` - Milestone chimes
