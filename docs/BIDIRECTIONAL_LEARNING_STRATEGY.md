# Bidirectional Learning Strategy

**Document Version:** 1.0
**Last Updated:** January 2026
**Related Files:**
- `LexiconFlow/LexiconFlow/Models/Flashcard.swift` (current)
- `LexiconFlow/LexiconFlow/Models/Note.swift` (planned)
- `LexiconFlow/LexiconFlow/Models/Card.swift` (planned)
- `LexiconFlow/LexiconFlow/Services/DataMigrationService.swift` (planned)

**References:**
- Palmberg, R. (2016). "The role of vocabulary in learning English"
- Nation, I. S. P. (2001). *Learning Vocabulary in Another Language*
- Webb, S. (2008). "Receptive and productive vocabulary learning"

---

## Overview

LexiconFlow plans to implement **bidirectional learning** to support both **Recognition** (L2→L1: Russian→English) and **Production** (L1→L2: English→Russian) modes. This document outlines the pedagogical foundation, technical implementation, data migration strategy, and rollout roadmap for this feature.

**Current State**: Unidirectional English→Russian flashcards

**Target State**: Full bidirectional support with user-selectable study modes

---

## Pedagogical Foundation

### Recognition vs. Production

**Recognition Mode** (Receptive Knowledge):
- **Stimulus**: Russian word (L2)
- **Response**: English meaning (L1)
- **Cognitive Process**: Decoding, comprehension
- **Difficulty Level**: Lower
- **Use Case**: Reading comprehension, listening

**Production Mode** (Productive Knowledge):
- **Stimulus**: English meaning (L1)
- **Response**: Russian word (L2)
- **Cognitive Process**: Retrieval, recall
- **Difficulty Level**: Higher
- **Use Case**: Speaking, writing

### Why Both Matter

**Research Finding** (Palmberg, 2016; Nation, 2001):
- Production lags behind recognition in acquisition
- Testing both prevents "illusion of competence"
- Bidirectional testing reveals knowledge gaps

**Key Insight**: Many learners can *recognize* words they cannot *produce*. This creates a false sense of proficiency.

### Knowledge Types

| Type | Definition | Example | Mastery Indicator |
|------|------------|---------|-------------------|
| **Receptive** | Can understand when encountered | "I know this means 'dog'" | Recognition mode |
| **Productive** | Can actively use in communication | "I can say/write this" | Production mode |

**Goal**: True proficiency requires both receptive and productive mastery.

---

## Data Model Changes

### Current: Flashcard Model

```swift
@Model
final class Flashcard {
    var id: UUID
    var word: String        // English
    var definition: String
    var translation: String? // Russian (unidirectional)
    var phonetic: String?
    var cefrLevel: String?

    @Relationship var deck: Deck?
    @Relationship var fsrsState: FSRSState?
    @Relationship var reviewLogs: [FlashcardReview]
}
```

**Limitations**:
- Unidirectional (English→Russian only)
- Can't create multiple card types per word
- No separation between concept and reviewable item

### Planned: Note/Card Separation

```swift
@Model
final class Note {
    var id: UUID
    var word: String           // Vocabulary item (language-agnostic)
    var definition: String
    var phonetic: String?
    var cefrLevel: String?
    var createdAt: Date
    var updatedAt: Date

    // Single-sided inverse (no inverse here)
    @Relationship(deleteRule: .cascade) var cards: [Card] = []
    @Relationship(deleteRule: .nullify) var deck: Deck?

    init(word: String, definition: String) {
        self.id = UUID()
        self.word = word
        self.definition = definition
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class Card {
    var id: UUID
    var cardType: CardType    // .forward, .reverse, .audio, .cloze
    var isActive: Bool         // Enable/disable per note
    var ordinal: Int           // Display order
    var createdAt: Date

    // Inverse relationship (defined on Note.cards)
    @Relationship(deleteRule: .cascade, inverse: \Note.cards) var note: Note?
    @Relationship(deleteRule: .cascade) var fsrsState: FSRSState?
    @Relationship(deleteRule: .cascade) var reviewLogs: [FlashcardReview] = []

    init(cardType: CardType, note: Note, ordinal: Int = 0) {
        self.id = UUID()
        self.cardType = cardType
        self.isActive = true
        self.ordinal = ordinal
        self.createdAt = Date()
        self.note = note
    }
}

enum CardType: String, Codable, Sendable {
    case forward    // L2→L1: Show English, recall Russian (Recognition)
    case reverse    // L1→L2: Show Russian, recall English (Production)
    case audio      // Audio-only: Hear word, type meaning
    case cloze      // Cloze deletion: Fill in blank

    var displayName: String {
        switch self {
        case .forward: return "Recognition"
        case .reverse: return "Production"
        case .audio: return "Audio"
        case .cloze: return "Cloze"
        }
    }

    var iconName: String {
        switch self {
        case .forward: return "arrow.right"
        case .reverse: return "arrow.left"
        case .audio: return "speaker.wave.2"
        case .cloze: return "text.badge.ellipsis"
        }
    }
}
```

**Rationale**: Separates semantic concept (Note) from reviewable items (Card), enabling multiple card types per vocabulary item.

---

## Card Types

### Forward Card (Recognition)

**Front**: English word
**Back**: Russian translation + definition
**Current Implementation**: Existing Flashcard model

**Pedagogical Purpose**: Build receptive vocabulary, reading comprehension

### Reverse Card (Production)

**Front**: Russian translation
**Back**: English word + phonetic
**Status**: Planned

**Pedagogical Purpose**: Build productive vocabulary, speaking/writing skills

### Audio Card (Listening)

**Front**: Spoken Russian (no text initially)
**Back**: Russian word + English meaning
**Status**: Planned

**Pedagogical Purpose**: Pure listening comprehension, prevent visual crutch

### Cloze Card (Context)

**Front**: Sentence with missing word
**Back**: Complete sentence + vocabulary
**Status**: Planned

**Pedagogical Purpose**: Contextual learning, syntax practice

---

## Implementation Roadmap

### Phase 1: Data Migration (Week 1-2)

**Objective**: Migrate existing Flashcard data to Note/Card schema without data loss.

**Tasks**:
1. Create Note and Card models
2. Build migration service: Flashcard → Note + 1 Forward Card
3. Migrate existing 10,000+ flashcards
4. Test data integrity and rollback

**Migration Logic**:
```swift
func migrateToNoteCardSchema(context: ModelContext) async throws -> MigrationResult {
    let flashcardDescriptor = FetchDescriptor<Flashcard>()
    let flashcards = try context.fetch(flashcardDescriptor)

    for flashcard in flashcards {
        // Create Note from Flashcard
        let note = Note(
            word: flashcard.word,
            definition: flashcard.definition
        )
        note.phonetic = flashcard.phonetic
        note.cefrLevel = flashcard.cefrLevel
        note.deck = flashcard.deck

        // Create Forward card (active, preserves FSRS state)
        let forwardCard = Card(cardType: .forward, note: note, ordinal: 0)
        forwardCard.fsrsState = flashcard.fsrsState  // Copy state

        // Copy review logs
        for log in flashcard.reviewLogs {
            let newLog = FlashcardReview(
                rating: log.rating,
                reviewDate: log.reviewDate,
                scheduledDays: log.scheduledDays,
                elapsedDays: log.elapsedDays
            )
            forwardCard.reviewLogs.append(newLog)
        }

        // Create Reverse card (inactive by default - opt-in)
        let reverseCard = Card(cardType: .reverse, note: note, ordinal: 1)
        reverseCard.isActive = false

        // Create Audio card (inactive by default)
        let audioCard = Card(cardType: .audio, note: note, ordinal: 2)
        audioCard.isActive = false

        context.insert(note)
        context.insert(forwardCard)
        context.insert(reverseCard)
        context.insert(audioCard)
    }

    try context.save()
}
```

**Exit Criteria**:
- [ ] All existing flashcards migrated to Notes
- [ ] Each Note has 1 active Forward card (preserves FSRS state)
- [ ] Each Note has 2 inactive cards (Reverse, Audio)
- [ ] Zero data loss: All translations, definitions, images preserved

### Phase 2: Reverse Card Generation (Week 3)

**Objective**: Auto-generate reverse cards for existing Notes.

**Tasks**:
1. User opt-in setting for reverse mode
2. Batch generation of reverse cards
3. UI for card type filtering

**Generation Logic**:
```swift
func generateReverseCards(for notes: [Note], context: ModelContext) async {
    for note in notes {
        // Check if reverse card already exists
        let hasReverse = note.cards.contains { $0.cardType == .reverse }

        if !hasReverse && AppSettings.enableReverseCards {
            let reverseCard = Card(cardType: .reverse, note: note, ordinal: 1)
            reverseCard.isActive = true
            context.insert(reverseCard)
        }
    }

    try context.save()
}
```

**User Setting**:
```swift
enum AppSettings {
    static var enableReverseCards: Bool {
        get { UserDefaults.standard.bool(forKey: "enableReverseCards") }
        set { UserDefaults.standard.set(newValue, forKey: "enableReverseCards") }
    }
}
```

### Phase 3: Direction-Aware UI (Week 4)

**Objective**: Update flashcard view to detect card type and render accordingly.

**Tasks**:
1. Update FlashcardView to use Card instead of Flashcard
2. Adjust text hierarchy based on direction
3. Conditional TTS auto-play (audio cards only)

**Implementation**:
```swift
struct FlashcardView: View {
    @Bindable var card: Card  // Changed from Flashcard

    var body: some View {
        VStack(spacing: 24) {
            // Card type badge
            HStack(spacing: 8) {
                Image(systemName: card.cardType.iconName)
                Text(card.cardType.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Direction-aware content
            switch card.cardType {
            case .forward:
                if let note = card.note {
                    Text(note.word)  // English
                    if let phonetic = note.phonetic {
                        Text(phonetic)
                    }
                }

            case .reverse:
                if let note = card.note {
                    Text(note.translation ?? "")  // Russian
                }

            case .audio:
                Image(systemName: "speaker.wave.3.fill")
                Text("Tap to play")

            case .cloze:
                Text(card.clozeTemplate ?? "")
            }
        }
        .onAppear {
            // Auto-play audio for audio cards
            if card.cardType == .audio && AppSettings.ttsEnabled {
                playAudio()
            }
        }
    }
}
```

### Phase 4: Sibling Interference Prevention (Week 5)

**Objective**: Implement bury mechanism to prevent related cards appearing in same session.

**Tasks**:
1. Implement bury logic (10-20% fuzz)
2. Update card queue filtering
3. Add sibling bury toggle in settings

**Bury Logic**:
```swift
actor SiblingInterferenceService {
    func burySiblings(
        reviewedCard: Card,
        reviewedInterval: Double,
        context: ModelContext
    ) async throws {
        guard let note = reviewedCard.note,
              let siblings = note.cards.filter({ $0.id != reviewedCard.id && $0.isActive }),
              !siblings.isEmpty else { return }

        // Fuzz: 10-20% of interval
        let fuzzPercentage = 0.15 + Double.random(in: -0.05...0.05)
        let fuzzDays = reviewedInterval * fuzzPercentage

        for sibling in siblings {
            guard let siblingState = sibling.fsrsState else { continue }

            let intervalDifference = abs(
                siblingState.dueDate.timeIntervalSince(Date()) / 86400 - reviewedInterval
            )

            // Bury if within fuzz range
            if intervalDifference <= fuzzDays {
                let burialDuration = reviewedInterval + fuzzDays
                siblingState.buriedUntil = Date().addingTimeInterval(burialDuration * 86400)
                siblingState.isBuried = true
            }
        }

        try context.save()
    }
}
```

**Pedagogical Benefit**: Spaced retrieval prevents proactive interference (newer memories blocking older ones).

---

## User Settings

### Study Direction Selection

```swift
enum StudyDirection {
    case recognitionOnly   // Russian→English
    case productionOnly    // English→Russian
    case both              // Mixed session

    var displayName: String {
        switch self {
        case .recognitionOnly: return "Recognition Only"
        case .productionOnly: return "Production Only"
        case .both: return "Both Modes"
        }
    }
}
```

### Card Type Preferences

```swift
enum AppSettings {
    // Study direction
    static var studyDirection: StudyDirection {
        get { /* ... */ }
        set { /* ... */ }
    }

    // Card type toggles
    static var enableReverseCards: Bool { /* ... */ }
    static var enableAudioCards: Bool { /* ... */ }
    static var enableClozeCards: Bool { /* ... */ }

    // Sibling interference
    static var siblingBurialEnabled: Bool { /* ... */ }
    static var fuzzPercentage: Double { /* ... */ }  // 10-20
}
```

### Settings UI

```swift
struct MultiModalSettingsView: View {
    @AppStorage("studyDirection") private var direction = StudyDirection.both
    @AppStorage("enableReverseCards") private var enableReverse = false
    @AppStorage("siblingBurialEnabled") private var burialEnabled = true

    var body: some View {
        Form {
            Section("Study Direction") {
                Picker("Direction", selection: $direction) {
                    Text("Recognition Only").tag(StudyDirection.recognitionOnly)
                    Text("Production Only").tag(StudyDirection.productionOnly)
                    Text("Both Modes").tag(StudyDirection.both)
                }
            }

            Section("Card Types") {
                Toggle("Reverse Cards (Production)", isOn: $enableReverse)
                Toggle("Audio Cards", isOn: $enableAudioCards)
                Toggle("Cloze Deletion", isOn: $enableClozeCards)
            }

            Section("Sibling Interference") {
                Toggle("Enable Burying", isOn: $burialEnabled)
                if burialEnabled {
                    Slider(value: $fuzzPercentage, in: 10...20) {
                        Text("Fuzz: \(Int(fuzzPercentage))%")
                    }
                }
            }
        }
    }
}
```

---

## Migration Strategy

### Data Integrity Guarantees

1. **All existing Flashcards become Notes**
2. **Each Note gets 1 Forward Card** (preserves FSRS state)
3. **Reverse cards generated as new cards** (start fresh)
4. **No data loss**: All translations, definitions, images preserved

### Rollback Plan

**Reversible Migration**:
```swift
func rollbackToFlashcardSchema(context: ModelContext) async throws {
    let noteDescriptor = FetchDescriptor<Note>()
    let notes = try context.fetch(noteDescriptor)

    for note in notes {
        // Find forward card
        guard let forwardCard = note.cards.first(where: { $0.cardType == .forward }),
              let flashcard = Flashcard(from: note, card: forwardCard) else {
            continue
        }

        context.insert(flashcard)
        context.delete(note)
    }

    try context.save()
}
```

**Git History**: Schema rollback available via git revert

---

## Testing Strategy

### Unit Tests

```swift
@Test("Migration preserves FSRS state")
func testMigrationPreservesFSRSState() async throws {
    let container = try TestContainer()
    let context = container.mainContext

    // Create original flashcard
    let flashcard = Flashcard(word: "test", definition: "test")
    flashcard.fsrsState = FSRSState(stability: 10.0, difficulty: 5.0)
    context.insert(flashcard)
    try context.save()

    // Migrate
    try await DataMigrationService.shared.migrateToNoteCardSchema(context: context)

    // Verify
    let noteDescriptor = FetchDescriptor<Note>()
    let notes = try context.fetch(noteDescriptor)
    let note = notes.first

    let forwardCard = note?.cards.first(where: { $0.cardType == .forward })
    #expect(forwardCard?.fsrsState?.stability == 10.0)
}
```

### Integration Tests

```swift
@Test("Direction-aware rendering")
func testDirectionAwareRendering() {
    let note = Note(word: "test", definition: "test")
    let forwardCard = Card(cardType: .forward, note: note)
    let reverseCard = Card(cardType: .reverse, note: note)

    // Test forward card shows English
    let forwardView = FlashcardView(card: forwardCard)
    // Verify: Shows "test"

    // Test reverse card shows Russian
    let reverseView = FlashcardView(card: reverseCard)
    // Verify: Shows Russian translation
}
```

### Performance Tests

- Migration of 10,000 cards: < 30 seconds
- Card queue filtering: < 100ms for 1000 cards
- Direction-aware rendering: < 16ms per card

---

## Pedagogical Outcomes

### Recognition Mode (Russian→English)

**Target Skills**:
- Reading comprehension
- Listening comprehension
- Vocabulary size

**Mastery Indicator**: "Can understand when encountered"

### Production Mode (English→Russian)

**Target Skills**:
- Speaking
- Writing
- Active recall

**Mastery Indicator**: "Can actively use in communication"

### Combined Mastery

**Requirement**: Both Recognition and Production cards at Mastered level

**Benefit**: Mirrors real-world language proficiency

**Expected Outcome**:
- **Recognition Mode**: Build receptive vocabulary
- **Production Mode**: Strengthen recall ability
- **Combined**: Balanced language proficiency
- **Expected**: 30% faster progression to mastery

---

## Comparison

### Before and After

| Aspect | Before (Unidirectional) | After (Bidirectional) |
|--------|------------------------|----------------------|
| **Study Modes** | 1 (English→Russian) | 3 (Recognition, Production, Both) |
| **Card Types** | 1 (Basic) | 4 (Forward, Reverse, Audio, Cloze) |
| **Data Model** | Flashcard only | Note + Card separation |
| **Proficiency Tracking** | Single metric | Per-modality tracking |
| **Sibling Interference** | Not prevented | Bury mechanism (10-20% fuzz) |

---

## References

### Primary Research

1. **Palmberg, R. (2016)**. "The role of vocabulary in learning English." *Vocabulary Learning and Instruction*, 17-32.
   - Receptive vs productive vocabulary distinction

2. **Nation, I. S. P. (2001)**. *Learning Vocabulary in Another Language*. Cambridge University Press.
   - Comprehensive vocabulary acquisition framework

3. **Webb, S. (2008)**. "Receptive and productive vocabulary learning." *The Modern Language Journal*, 92(4), 682-703.
   - Relationship between receptive and productive knowledge

4. **Laufer, B. (1998)**. "The development of passive and active vocabulary." *Learning and Instruction*, 7(2), 101-124.
   - Passive-active vocabulary gap

5. **Henriksen, B. (1999)**. "Three dimensions of vocabulary development." *Studies in Second Language Acquisition*, 18, 67-93.
   - Breadth, depth, and productive use

---

## Appendix: Data Model Comparison

### Before (Flashcard Only)

```
Flashcard
├── word (English)
├── translation (Russian)
├── definition
├── phonetic
└── FSRSState
```

**Limitation**: Can't create multiple card types per word.

### After (Note + Cards)

```
Note (Semantic Concept)
├── word
├── definition
├── phonetic
└── cards [Card]
    ├── Card 1: Forward (active, preserves FSRS)
    ├── Card 2: Reverse (inactive, opt-in)
    ├── Card 3: Audio (inactive, opt-in)
    └── Card 4: Cloze (inactive, opt-in)
        └── FSRSState (per card)
```

**Advantage**: Multiple card types per word, independent FSRS tracking.

---

**Document End**

For related information:
- `MULTI_MODAL_LEARNING_ARCHITECTURE.md` - Overall multi-modal learning
- `ARCHITECTURE.md` - Technical architecture details
- `ALGORITHM_SPECS.md` - FSRS v5 algorithm
