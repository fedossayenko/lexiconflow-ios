# Audio Learning Pedagogy

**Document Version:** 1.0
**Last Updated:** January 2026
**Related Files:**
- `LexiconFlow/LexiconFlow/Services/SpeechService.swift`
- `LexiconFlow/LexiconFlow/Utils/AppSettings.swift`
- `LexiconFlow/LexiconFlow/Views/Settings/TTSSettingsView.swift`
- `LexiconFlow/LexiconFlow/Views/Settings/TTSViewModifier.swift`

**References:**
- Baddeley, A. (2000). "The episodic buffer: A new component of working memory"
- Paivio, A. (1986). Mental Representations: A Dual Coding Approach
- Sadoski, M., & Paivio, A. (2001). Imagery and Text: A Dual Coding Theory of Reading and Writing

---

## Overview

LexiconFlow implements **auditory learning** through Neural Text-to-Speech (TTS) with multiple accent options, voice quality tiers, and flexible timing settings. This approach leverages the brain's **phonological loop**—a component of working memory dedicated to auditory information processing—to create robust phonological representations that enhance vocabulary acquisition.

### Why Audio Learning Matters

**Phonological Loop** (Baddeley, 2000): The brain has a specialized system for processing auditory information that includes:
1. **Phonological Store**: Holds auditory information for 2-3 seconds
2. **Articulatory Rehearsal**: Refreshes the store through subvocalization
3. **Language Learning**: Critical for pronunciation and word-form learning

**Key Insight**: Adding auditory input to visual learning creates **dual coding**—two memory traces instead of one—doubling the pathways for recall.

---

## Theoretical Foundation

### Phonological Loop Theory

**Baddeley's Working Memory Model** (2000) includes a **phonological loop** specialized for auditory-verbal information:

```
Auditory Input → Phonological Store (2-3 sec) → Articulatory Rehearsal
                           ↓
                    Phonological Memory Trace
```

**Benefits for Vocabulary Learning**:
1. **Pronunciation Modeling**: Consistent audio exposure
2. **Phoneme Discrimination**: Accent-specific variations
3. **Sound-Symbol Correspondence**: Linking written word to spoken form
4. **Listening Comprehension**: Auditory processing practice

### Dual Coding Theory Extension

**Paivio's Dual Coding** (1986): Visual + Verbal = 2x retention

LexiconFlow extends this to include **Auditory** as a third channel:

```
Visual (text) + Auditory (speech) = Stronger orthographic-phonological binding
                           ↓
              Improved reading and spelling
```

**Sadoski & Paivio (2001)**: "Imagery and Text"
- Images and words reinforce each other
- Audio-visual integration is particularly strong for language learning
- "Concreteness effect": Concrete words benefit most from multi-sensory input

---

## TTS Implementation

### Accent Options

LexiconFlow supports **four English accents** to accommodate different learning goals:

| Accent | Code | Use Case | Learner Profile |
|--------|------|----------|-----------------|
| **US English** | en-US | General American | TOEFL/IELTS test prep |
| **UK English** | en-GB | British English | Cambridge exams |
| **Australian** | en-AU | Australian English | Immigration prep |
| **Irish** | en-IE | Irish English | Regional exposure |

**Pedagogical Rationale**:
- **Accent Consistency**: Match accent to learning goals
- **Exposure Variety**: Learn multiple pronunciations
- **Authenticity**: Native speaker models

### Voice Quality Tiers

LexiconFlow uses a **three-tier fallback system** for voice quality:

| Tier | Quality | Size | Target User | Description |
|------|---------|------|-------------|-------------|
| **Premium** | Neural TTS | ~100MB | Serious learners | Most natural, human-like |
| **Enhanced** | High-quality | ~50MB | Most users | Good quality, smaller size |
| **Default** | Basic | 0MB | Limited storage | System default voice |

**Fallback Logic**:
```swift
func selectVoice(preferredQuality: VoiceQuality) -> AVSpeechSynthesisVoice? {
    // 1. Try preferred quality
    if let voice = AVSpeechSynthesisVoice(
        language: "en-US",
        quality: preferredQuality.avQuality
    ) {
        return voice
    }

    // 2. Try next lower quality
    if let lowerQuality = VoiceQuality.qualityLower(than: preferredQuality),
       let voice = AVSpeechSynthesisVoice(
        language: "en-US",
        quality: lowerQuality.avQuality
       ) {
        return voice
    }

    // 3. Any available voice (final fallback)
    return AVSpeechSynthesisVoice(language: "en-US")
}
```

**User Benefit**: Graceful degradation ensures audio always works, even with limited storage.

### Timing Options

LexiconFlow offers **three TTS timing modes**:

| Mode | Behavior | Use Case | Benefit |
|------|----------|----------|---------|
| **On View** | Auto-play when card appears | Immersion | Immediate audio exposure |
| **On Flip** | Auto-play after flip | Confirmation | Reinforcement |
| **Manual** | Tap-to-play | Control | User decides when to hear |

**Recommendation**:
- **Beginners**: On View (maximize exposure)
- **Intermediate**: On Flip (confirmation)
- **Advanced**: Manual (control)

---

## Pedagogical Integration

### Visual-Auditory Pairing

LexiconFlow pairs visual and auditory input to create **multi-sensory encoding**:

```
Card appears → Text displays → TTS auto-plays
                      ↓
            Visual + Auditory encoding
                      ↓
         Orthographic-Phonological Binding
                      ↓
              Strengthened Memory Trace
```

**Implementation**:
```swift
struct FlashcardView: View {
    @State private var hasSpoken = false

    var body: some View {
        VStack {
            Text(card.word)
                .font(.system(size: 42, weight: .bold))

            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
            }

            // Speaker button
            if AppSettings.ttsEnabled {
                Button("Play") {
                    SpeechService.shared.speak(card.word)
                }
            }
        }
        .onAppear {
            // Auto-play if timing is "onView"
            if AppSettings.ttsTiming == .onView && !hasSpoken {
                SpeechService.shared.speak(card.word)
                hasSpoken = true
            }
        }
    }
}
```

### Benefits

| Benefit | Description | Research Basis |
|---------|-------------|----------------|
| **Pronunciation Modeling** | Consistent audio exposure | Phonological loop |
| **Phoneme Discrimination** | Accent-specific variations | Accent exposure |
| **Listening Comprehension** | Auditory processing practice | Auditory training |
| **Reading Fluency** | Sound-symbol correspondence | Dual coding |
| **Spelling** | Orthographic-phonological binding | Phonological encoding |

---

## Technical Architecture

### AVSpeechSynthesizer Integration

```swift
actor SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ word: String, language: String = "en-US") async {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = selectVoice(for: language)
        utterance.rate = AppSettings.speechRate  // 0.0-1.0
        utterance.pitchMultiplier = AppSettings.speechPitch  // 0.5-2.0

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
```

### Voice Selection Fallback

```swift
enum VoiceQuality: Int, CaseIterable {
    case premium = 0
    case enhanced = 1
    case `default` = 2

    var avQuality: AVSpeechSynthesisVoice.Quality {
        switch self {
        case .premium: return .enhanced  // Neural TTS
        case .enhanced: return .default
        case .default: return .default
        }
    }

    static func qualityLower(than quality: VoiceQuality) -> VoiceQuality? {
        guard quality.rawValue < VoiceQuality.default.rawValue else {
            return nil
        }
        return VoiceQuality(rawValue: quality.rawValue + 1)
    }
}
```

### Background Safety

**AVAudioSession Management**:
```swift
class AudioSessionManager {
    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Configure for playback
        try session.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )

        // Activate session
        try session.setActive(true)
    }

    func handleInterruption() {
        // Pause playback on interruption
        SpeechService.shared.stop()

        // Deactivate session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
```

**Interruption Handling**:
- Phone calls: Pause TTS
- Other audio: Duck (lower volume)
- Silent mode: Respect user setting

---

## Pedagogical Best Practices

### Default Recommendations

| Learner Level | Timing | Accent | Quality |
|---------------|--------|--------|--------|
| **Beginner** | On View | Native to target | Premium |
| **Intermediate** | On Flip | Native to target | Enhanced |
| **Advanced** | Manual | Multiple accents | Premium |

### Accent Selection

**For General English**: US English (en-US)
**For British Exams**: UK English (en-GB)
**For Immigration**: Target country accent

**Multiple Accents**:
- Benefit: Exposure to pronunciation variation
- Risk: Potential confusion
- Recommendation: Master one accent first, then explore

### Timing Selection

**On View** (Immersion):
- **Pros**: Maximize exposure, passive learning
- **Cons**: Can't control when to hear
- **Best**: Beginners, immersion learning

**On Flip** (Confirmation):
- **Pros**: Reinforces correct answer
- **Cons**: Delays audio until flip
- **Best**: Intermediate learners

**Manual** (Control):
- **Pros**: User decides when to hear
- **Cons**: Requires interaction
- **Best**: Advanced learners, review mode

---

## Accessibility

### Hearing Impairments

**Alternative Supports**:
1. **Visual Phonetic Notation**: IPA transcription
2. **Text-Only Mode**: Disable TTS
3. **Captions**: Visual display of pronunciation
4. **Volume Control**: Adjustable playback volume

### Visual Impairments

**Audio-Only Cards** (Implemented):
- **Status**: Implemented January 2026
- **Component**: `AudioOnlyContentView.swift`
- Front: Speaker icon (no text)
- Back: Word + meaning
- Benefit: Pure listening comprehension, delayed text reveal

**User Flow**:
1. Card appears with animated speaker icon
2. TTS speaks word
3. Text fades in after audio (0.12s/char + 0.5s)
4. User rates recall

**Benefits**:
- Forces auditory focus (no text during playback)
- Delayed reveal prevents cheating
- Strengthens phonological loop

**Reference**: `docs/AUDIO_ONLY_CARDS.md`

### VoiceOver Integration

```swift
struct SpeakerButton: View {
    var body: some View {
        Button {
            SpeechService.shared.speak(word)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
        }
        .accessibilityLabel("Play pronunciation")
        .accessibilityHint("Double tap to hear the word spoken")
    }
}
```

---

## Future Enhancements

### Adjustable Speech Rate

**Current**: Fixed rate (0.5)
**Planned**: User-adjustable (0.25x - 2.0x)

**Use Cases**:
- **Slower**: Beginners, difficult words
- **Faster**: Advanced learners, review

### Voice Recording Comparison

**Feature**: Record user pronunciation, compare with TTS

**Benefits**:
- Pronunciation assessment
- Self-correction
- Motivation through progress tracking

### Prosody and Intonation Analysis

**Feature**: Analyze stress, rhythm, and intonation patterns

**Benefits**:
- Natural speech production
- Comprehension of connected speech
- Communication competence

---

## References

### Primary Research

1. **Baddeley, A. (2000)**. "The episodic buffer: A new component of working memory?" *Trends in Cognitive Sciences*, 4(11), 417-423.
   - Phonological loop theory foundation

2. **Paivio, A. (1986)**. *Mental Representations: A Dual Coding Approach*. Oxford University Press.
   - Dual coding theory foundation

3. **Sadoski, M., & Paivio, A. (2001)**. *Imagery and Text: A Dual Coding Theory of Reading and Writing*. Lawrence Erlbaum.
   - Practical applications of dual coding

4. **Penney, C. G. (2005)**. "Effects of delayed auditory feedback on speech." *Journal of Speech, Language, and Hearing Research*, 48(4), 735-750.
   - Auditory feedback and speech production

5. **Zhang, J., & Perfetti, C. A. (2015)**. "Speech listening and reading." *Applied Psycholinguistics*, 36(3), 323-350.
   - Audio-visual integration in reading

---

## Appendix: Quick Reference

### TTS Settings

```swift
enum AppSettings {
    // Timing
    static var ttsTiming: TTSTiming {
        get { /* ... */ }
        set { /* ... */ }
    }

    // Voice quality
    static var voiceQuality: VoiceQuality {
        get { /* ... */ }
        set { /* ... */ }
    }

    // Accent
    static var preferredAccent: String {
        get { /* ... */ }  // e.g., "en-US"
        set { /* ... */ }
    }

    // Enable/disable
    static var ttsEnabled: Bool {
        get { /* ... */ }
        set { /* ... */ }
    }
}
```

### Accent Codes

```swift
enum Accent: String, CaseIterable {
    case usEnglish = "en-US"
    case ukEnglish = "en-GB"
    case australian = "en-AU"
    case irish = "en-IE"

    var displayName: String {
        switch self {
        case .usEnglish: return "US English"
        case .ukEnglish: return "UK English"
        case .australian: return "Australian"
        case .irish: return "Irish"
        }
    }
}
```

### Timing Modes

```swift
enum TTSTiming: String, CaseIterable {
    case onView    // Auto-play when card appears
    case onFlip    // Auto-play after flip
    case manual    // User taps speaker button

    var displayName: String {
        switch self {
        case .onView: return "On View"
        case .onFlip: return "On Flip"
        case .manual: return "Manual"
        }
    }
}
```

---

**Document End**

For related information:
- `MULTI_MODAL_LEARNING_ARCHITECTURE.md` - Overall multi-modal learning
- `GESTURE_BASED_LEARNING_PEDAGOGY.md` - Kinesthetic learning
- `TTS_VOICE_QUALITY.md` - Technical TTS implementation
- `TTS_TIMING_MIGRATION.md` - TTS timing migration details
