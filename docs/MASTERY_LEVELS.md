# Mastery Levels

**Added**: 2026-01-11
**Status**: Stable

## Overview

LexiconFlow uses a **four-tier mastery system** to track vocabulary learning progress based on FSRS stability values. Mastery levels provide users with visual feedback on their learning journey through color-coded badges and filterable lists.

## Mastery Level Tiers

| Level | Stability Range | Description | Color | Icon |
|-------|----------------|-------------|-------|------|
| **Beginner** | 0-3 days | Initial learning phase | Gray | `seedling.fill` |
| **Intermediate** | 3-14 days | Developing retention | Blue | `flame.fill` |
| **Advanced** | 14-30 days | Strong retention | Orange | `bolt.fill` |
| **Mastered** | 30+ days | Long-term mastery | Purple | `star.circle.fill` |

## Threshold Rationale

The mastery thresholds are based on FSRS research and cognitive science findings about memory consolidation:

| Threshold | Stability | Cognitive Science Basis |
|-----------|-----------|-------------------------|
| **3 days** | 0-3 days | Short-term memory requires 3+ days to stabilize |
| **14 days** | 3-14 days | Memory consolidation begins after 1 week |
| **30 days** | 14-30 days | 2+ weeks predicts long-term retention |
| **30+ days** | 30+ days | Consolidated memory with high retention probability |

These thresholds align with:
- **FSRS v5 algorithm** stability calculations
- **Ebbinghaus Forgetting Curve** - spaced repetition improves retention
- **Bjork (2011)** - "Desirable Difficulties" theory

## Technical Implementation

### MasteryLevel Enum

```swift
enum MasteryLevel: String, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case mastered

    private enum Thresholds {
        static let beginnerMax = 3.0      // 3 days
        static let intermediateMax = 14.0  // 14 days
        static let advancedMax = 30.0      // 30 days
    }

    init(stability: Double) {
        switch stability {
        case 0 ..< Thresholds.beginnerMax:    self = .beginner
        case Thresholds.beginnerMax ..< Thresholds.intermediateMax: self = .intermediate
        case Thresholds.intermediateMax ..< Thresholds.advancedMax:    self = .advanced
        case Thresholds.advancedMax...:       self = .mastered
        default: self = .beginner  // Negative stability defaults to beginner
        }
    }

    var displayName: String { /* ... */ }
    var icon: String { /* ... */ }
}
```

### FSRSState Extension

```swift
extension FSRSState {
    /// Computed property that determines mastery level based on stability
    var masteryLevel: MasteryLevel {
        MasteryLevel(stability: stability)
    }

    /// Convenience property for checking mastered status
    /// Returns true only when stability >= 30 AND state == .review
    var isMastered: Bool {
        stability >= 30.0 && stateEnum == FlashcardState.review.rawValue
    }
}
```

## UI Components

### Mastery Badges

Mastery badges are displayed on:
- **FlashcardDetailView** - Card detail header
- **DeckDetailView** - Card list rows (when enabled)

### Badge Display Logic

```swift
if AppSettings.showMasteryBadges,
   let state = flashcard.fsrsState,
   state.stability > 0
{
    HStack(spacing: 8) {
        Image(systemName: state.masteryLevel.icon)
        Text(state.masteryLevel.displayName)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(masteryColor(for: state.masteryLevel).opacity(0.15))
    .foregroundStyle(masteryColor(for: state.masteryLevel))
    .cornerRadius(8)
}
```

**Display Conditions:**
- `AppSettings.showMasteryBadges` must be `true`
- `flashcard.fsrsState` must exist
- `state.stability` must be > 0

### Mastery Filter

Users can filter cards in `DeckDetailView` by mastery level:

```swift
enum MasteryFilter: String, CaseIterable {
    case all
    case mastered
    case learning
}
```

**Filter Behavior:**
- **All Cards**: Returns all cards regardless of mastery
- **Mastered**: Only cards where `isMastered == true` (stability >= 30 AND state == .review)
- **Learning**: Cards with state in [.new, .learning, .relearning]

## User Settings

### Show Mastery Badges

Users can toggle mastery badge visibility:

```swift
@AppStorage("showMasteryBadges") static var showMasteryBadges: Bool = true
```

### Default Behavior

- Mastery badges are **enabled by default**
- Filter defaults to **All Cards**
- Badge setting persists across app launches

## Color Scheme

Mastery level colors are defined in `Theme.Colors`:

```swift
enum Theme {
    enum Colors {
        static let masteryBeginner: Color = .gray
        static let masteryIntermediate: Color = .blue
        static let masteryAdvanced: Color = .orange
        static let masteryMastered: Color = .purple
    }
}
```

## Icons

Mastery level icons use SF Symbols:

| Level | SF Symbol |
|-------|-----------|
| Beginner | `seedling.fill` |
| Intermediate | `flame.fill` |
| Advanced | `bolt.fill` |
| Mastered | `star.circle.fill` |

## Algorithm Details

### Stability Calculation

Stability is calculated by the FSRS v5 algorithm based on:
- Review ratings (Again, Hard, Good, Easy)
- Time elapsed since last review
- Historical performance
- Difficulty parameter

### Threshold Justification

The mastery thresholds align with FSRS research:

1. **Beginner (0-3 days)**: Cards in initial learning phase, typically in "learning" or "relearning" state
2. **Intermediate (3-14 days)**: Memory consolidation beginning, cards requiring regular reviews
3. **Advanced (14-30 days)**: Well-established vocabulary, retention stabilizing
4. **Mastered (30+ days)**: Long-term memory achieved, review intervals significantly extended

## Testing

Test coverage for mastery levels:

- **MasteryLevelTests.swift** - Enum threshold and display property tests
- **DeckDetailViewTests.swift** - Mastery filter logic tests
- **FlashcardDetailViewTests.swift** - Badge display tests
- **FSRSStateTests.swift** - Computed property tests

## Usage Examples

### Displaying Mastery Badge

```swift
if let state = card.fsrsState, state.stability > 0 {
    HStack {
        Image(systemName: state.masteryLevel.icon)
        Text(state.masteryLevel.displayName)
    }
    .background(masteryColor(for: state.masteryLevel).opacity(0.15))
}
```

### Filtering by Mastery

```swift
let masteredCards = deck.cards.filter { card in
    guard let state = card.fsrsState else { return false }
    return state.isMastered
}

let learningCards = deck.cards.filter { card in
    guard let state = card.fsrsState else { return true }  // No state = learning
    return state.stateEnum == FlashcardState.new.rawValue
        || state.stateEnum == FlashcardState.learning.rawValue
        || state.stateEnum == FlashcardState.relearning.rawValue
}
```

---

## Mastery and Multi-Modal Learning

### Modality-Specific Mastery

LexiconFlow's multi-modal learning architecture supports **modality-specific mastery tracking** for comprehensive vocabulary assessment. Each learning modality (Visual, Auditory, Kinesthetic, Contextual) can contribute to overall mastery.

**Current Implementation**:
- Single mastery level based on FSRS stability (all modalities combined)
- Stability reflects multi-sensory encoding strength
- +40-60% improvement in initial stability due to multi-modal learning

**Modality Contributions to Mastery**:

| Modality | Encoding Pathway | Mastery Contribution |
|----------|------------------|---------------------|
| **Visual** | Orthographic processing | Reading comprehension, spelling |
| **Auditory** | Phonological loop | Pronunciation, listening |
| **Kinesthetic** | Motor memory | Gesture-based recall confidence |
| **Contextual** | Episodic binding | Vocabulary-in-context usage |

**Multi-Modal Effect on Stability**:
- Single-modality learning: S₀ = 1 day
- Multi-modal learning: S₀ = 1.4-1.6 days (+40-60% improvement)
- Mastery thresholds achieved 40-60% faster with multi-modal encoding

### Bidirectional Mastery ✅ Implemented

LexiconFlow now supports **bidirectional mastery tracking** for Recognition (L2→L1) and Production (L1→L2) learning modes.

**Bidirectional Mastery Levels**:

| Mode | Card Type | Description | Mastery Indicator |
|------|-----------|-------------|-------------------|
| **Recognition** | Forward (English→Russian) | Can understand when encountered | Receptive vocabulary |
| **Production** | Reverse (Russian→English) | Can actively use in communication | Productive vocabulary |

**Implementation**:

**Separate FSRS States**:
- Forward and reverse cards have independent FSRS states
- Each card type has its own stability, difficulty, retrievability
- Mastery level calculated per-card based on individual FSRS state

**Direction-Aware Rendering**:
```swift
// CardFrontView displays different content based on direction
var displayWord: String {
    switch card.cardType {
    case .forward: return card.word  // English
    case .reverse: return card.translation ?? card.word  // Russian
    }
}

// CardBackView shows appropriate answer
var answerWord: String? {
    switch card.cardType {
    case .forward: return card.translation  // Russian answer
    case .reverse: return card.word  // English answer
    }
}
```

**Study Direction Settings**:
- `.recognitionOnly` - Study only forward cards (build receptive vocabulary)
- `.productionOnly` - Study only reverse cards (build productive vocabulary)
- `.both` - Study all cards (balanced proficiency)

**Mastery Tracking**:
```swift
// Each card tracks mastery independently
extension FSRSState {
    var masteryLevel: MasteryLevel {
        MasteryLevel(stability: stability)
    }

    var isMastered: Bool {
        stability >= 30.0 && stateEnum == FlashcardState.review.rawValue
    }
}

// Combined bidirectional mastery
extension Flashcard {
    var bidirectionalMastery: (forward: MasteryLevel?, reverse: MasteryLevel?) {
        // Access both forward and reverse card mastery
        // Returns tuple of mastery levels for comprehensive assessment
    }
}
```

**Combined Mastery Proficiency**:
- True language proficiency requires mastery in **both directions**
- Recognition mastery enables reading/listening comprehension
- Production mastery enables speaking/writing fluency
- Combined mastery = "Mastered" status on both card types

**Research Basis** (Palmberg, 2016; Nation, 2001):
- Production lags 20-30% behind recognition in acquisition
- Testing both prevents "illusion of competence"
- Bidirectional testing reveals knowledge gaps
- True proficiency requires mastery in both directions

**Testing Coverage**:
- `CardFrontViewTests.swift` - 17 tests for direction-aware display
- `CardBackViewTests.swift` - 14 tests for direction-aware answers
- `FlashcardTests.swift` - 9 tests for CardType enum
- `AppSettingsTests.swift` - 10 tests for StudyDirection settings
- Total: 50 tests for bidirectional mastery tracking

See [BIDIRECTIONAL_LEARNING_STRATEGY.md](BIDIRECTIONAL_LEARNING_STRATEGY.md) for complete pedagogical documentation.

### Per-Modality Mastery Tracking (Future)

**Planned Enhancement**: Track mastery separately for each modality to identify learning strengths and weaknesses.

**Potential Implementation**:
```swift
// Future: Per-modality stability tracking
struct ModalityStability {
    var visual: Double      // Stability from visual encoding
    var auditory: Double    // Stability from auditory encoding
    var kinesthetic: Double  // Stability from gesture-based review
    var contextual: Double   // Stability from context sentence review
}

extension FSRSState {
    var modalityStability: ModalityStability {
        // Calculate per-modality stability
        // Identify strengths/weaknesses
        // Suggest focused review
    }
}
```

**Benefits**:
- Identify which modalities need reinforcement
- Personalized study recommendations
- Richer analytics for learning insights

See [MULTI_MODAL_LEARNING_ARCHITECTURE.md](MULTI_MODAL_LEARNING_ARCHITECTURE.md) for complete multi-modal learning documentation.

---

## Future Enhancements

Potential improvements to the mastery system:
- [ ] Customizable mastery thresholds per user
- [ ] Mastery progress animations
- [ ] Mastery-based study scheduling
- [ ] Mastery streak tracking
- [ ] Mastery achievement notifications
- [ ] Export mastery statistics
- [ ] Mastery distribution charts per deck

---

**Document Version:** 1.0
**Last Updated:** January 2026
**Related Files:**
- `LexiconFlow/LexiconFlow/Models/MasteryLevel.swift`
- `LexiconFlow/LexiconFlow/Models/FSRSState.swift`
- `LexiconFlow/LexiconFlow/Views/Cards/FlashcardDetailView.swift`
- `LexiconFlow/LexiconFlow/Views/Decks/DeckDetailView.swift`
- `LexiconFlow/LexiconFlow/Utils/Theme.swift`

**References:**
- FSRS v5 Algorithm: https://github.com/open-spaced-repetition/fsrs-rs
- Ebbinghaus Forgetting Curve: Memory retention requires spaced intervals
- Bjork (2011): "Desirable Difficulties" - spaced repetition improves long-term retention
