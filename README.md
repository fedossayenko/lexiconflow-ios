# Lexicon Flow iOS

> **The Next-Generation Vocabulary App for iOS 26.1+**

---

## Project Identity

**Name:** Lexicon Flow

**Mission:** Eliminate friction from language learning by combining advanced Spaced Repetition, on-device AI, and iOS 26's "Liquid Glass" design to create a state of flow in vocabulary acquisition.

**Status:** 🏗️ Phase 1 Foundation (90% Complete)

**Target Launch:** Q2 2026 (June)

---

## Executive Summary

Lexicon Flow is a native iOS application for English vocabulary acquisition using the **Free Spaced Repetition Scheduler (FSRS v5)** algorithm. Built with **Swift 6**, **SwiftUI**, **SwiftData**, and **iOS 26** frameworks, Lexicon Flow represents a paradigm shift from static, interval-gated learning to dynamic, AI-enriched, and fluidly designed experiences.

### Key Differentiators

| Feature | Legacy Apps | Lexicon Flow |
|---------|-------------|--------------|
| **Algorithm** | SM-2 (rigid) | FSRS v5 (adaptive) |
| **UI Design** | Generic/Flat | iOS 26 "Liquid Glass" |
| **Content** | Static database | On-device AI (Foundation Models - disabled, planned Phase 3) |
| **Audio** | Standard TTS | Neural voices (4 accents) |
| **Translation** | Cloud APIs | On-device API |
| **Study Modes** | Scheduled only | Scheduled + Cram |

---

## Quick Links

| Document | Description |
|----------|-------------|
| [Strategic Engineering Report](docs/STRATEGIC_ENGINEERING_REPORT.md) | Comprehensive product blueprint |
| [Technical Architecture](docs/ARCHITECTURE.md) | SwiftData schema, algorithm design, iOS 26 APIs |
| [Algorithm Specifications](docs/ALGORITHM_SPECS.md) | FSRS v5 implementation details |
| [Product Vision](docs/PRODUCT_VISION.md) | Market positioning and philosophy |
| [Development Roadmap](docs/ROADMAP.md) | 16-week phased development plan |

---

## Technology Stack

| Component | Technology | Justification |
|-----------|------------|---------------|
| **Language** | Swift 6 | Strict concurrency, Sendable protocols, Actors |
| **UI Framework** | SwiftUI | Native "Liquid Glass" APIs, morphing transitions |
| **Data Layer** | SwiftData | @Model macro, CloudKit sync, @Query integration |
| **Algorithm** | FSRS v5 | Three-component model (S, D, R), superior to SM-2 |
| **AI/ML** | Foundation Models | On-device LLM (implemented but disabled via feature flag) |
| **Translation** | Translation API | On-device, zero-latency translation |
| **Audio** | AVSpeechSynthesizer | Neural TTS voices, accent selection |
| **Haptics** | CoreHaptics | Custom vibration patterns |
| **Widgets** | WidgetKit | Lock Screen, Live Activities |
| **Testing** | Swift Testing | Unit + integration testing |
| **Minimum Target** | iOS 26.1 | No legacy fallbacks |

---

## Testing

LexiconFlow uses **Swift Testing** (iOS 26+) with comprehensive test coverage:

- **63+ test suites** with comprehensive coverage
- >80% coverage target for new code
- In-memory SwiftData for test isolation
- CI/CD via GitHub Actions

See [TESTING.md](docs/TESTING.md) for testing guide.

---

## Core Features

### MVP (Phase 1-4)

| Feature | Description |
|---------|-------------|
| **FSRS v5 Algorithm** | Three-component memory model (Stability, Difficulty, Retrievability) |
| **"Liquid Glass" UI** | GlassEffectContainer with reactive refraction and morphing transitions |
| **Gesture-Based Grading** | Swipe right/left/up/down for rating with haptic feedback |
| **On-Device AI** | Foundation Models (infrastructure in place, disabled via feature flag) |
| **Neural TTS** | Four accent options (US, UK, AU, IE) with premium voices |
| **Translation API** | On-device translation with offline support |
| **Cram Mode** | Study anytime without breaking the algorithm |
| **Lock Screen Widgets** | AccessoryCircular and AccessoryRectangular widgets |
| **Live Activities** | Dynamic Island and Lock Screen session tracking |
| **Freemium Model** | Full FSRS for free; Pro for unlimited AI and cloud sync |

### Future (Post-Launch)

- Multi-language support (Spanish, French, German, Mandarin)
- Mac app via Mac Catalyst
- Apple Watch micro-learning
- Community deck marketplace
- AI-powered curriculum paths
- Pronunciation assessment using Speech Recognition

---

## Data Model

```
Deck (1) ────< (N) Flashcard (1) ────< (N) ReviewLog
     │                │
     │                └─── (1) FSRSState
     │
     └─── iconData (@Attribute(.externalStorage))
```

### Core Entities

- **Deck**: Container for cards with name, icon, order
- **Flashcard**: Word with definition, phonetic, image, generated sentence
- **FSRSState**: Stability, difficulty, retrievability, due date, state
- **ReviewLog**: Historical analytics for FSRS optimization

---

## Algorithm: FSRS v5

### Why FSRS Instead of SM-2?

**SM-2 Limitations:**
- Static multipliers don't adapt to individual learning patterns
- Single difficulty metric can't distinguish "hard to learn" from "fast to forget"
- Late reviews don't increase stability appropriately
- No explicit modeling of memory decay

**FSRS Advantages:**
- Three-component model (S, D, R) captures memory dynamics
- Adapts to individual forgetting curves
- Handles late and early reviews gracefully
- Optimizes based on user's actual review history

### The Mathematical Model

```
R(t) = (1 + factor × t/S)^decay
```

Where:
- **R(t)** = Probability of recall at time t
- **S** = Stability (time for R to drop from 100% to 90%)
- **D** = Difficulty (intrinsic complexity, 0-10)

### Implementation

Lexicon Flow uses the open-source **SwiftFSRS** package:

```swift
import SwiftFSRS

let scheduler = FSRS()  // v5 parameters
let result = scheduler.review(card: card, rating: .good)
// Returns: new due date, stability, difficulty, retrievability
```

---

## "Liquid Glass" Design System

### Visual Philosophy

iOS 26 introduces "Liquid Glass"—a dynamic material that blurs, refracts, and morphs in response to interaction. Lexicon Flow uses this to visualize memory:

- **Fragile memory** (low stability): Thin, transparent glass
- **Stable memory** (high stability): Thick, frosted glass

### Technical Implementation

```swift
GlassEffectContainer(spacing: 20) {
    ForEach(cards) { card in
        FlashcardView(card: card)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .interactive($offset) { dragOffset in
                // Reactive refraction based on swipe direction
            }
    }
}
```

### Morphing Transitions

Instead of standard 3D flip, cards use `glassEffectTransition(.materialize)`:

- Front content blurs into glass
- Back content sharpens from refraction
- `matchedGeometryEffect` for smooth element transitions

---

## Development Roadmap

| Phase | Duration | Focus | Deliverables |
|-------|----------|-------|--------------|
| **1** | Weeks 1-4 | Foundation | Data model, FSRS integration |
| **2** | Weeks 5-8 | Liquid UI | GlassEffectContainer, gestures, haptics |
| **3** | Weeks 9-12 | Intelligence | AI, translation, neural TTS |
| **4** | Weeks 13-16 | Polish & Launch | Widgets, freemium, beta, App Store |

**Target Launch:** June 2026 (16 weeks total)

---

## Monetization Strategy

### Freemium Model

| Feature | Free Tier | Pro Tier |
|---------|-----------|----------|
| **FSRS Algorithm** | Full (never crippled) | Full |
| **New Words/Day** | 20 | Unlimited |
| **AI Sentences** | Limited | Unlimited |
| **TTS Accents** | Basic | All 4 (Neural quality) |
| **Cloud Sync** | — | Multi-device via CloudKit |
| **Knowledge Graph** | Basic view | Full visualization |
| **Price** | $0 | $6.99/mo or $39.99/yr |

**Philosophy:** Users pay for *more of what works*, not for *basic functionality*.

---

## Getting Started (Development)

### Prerequisites

- Xcode 26.0+
- iOS 26.1+ SDK
- macOS Sequoia+
- Swift 6 compiler

### Initial Setup (Once Created)

```bash
# Clone repository
git clone https://github.com/fedossayenko/lexiconflow-ios.git
cd lexiconflow-ios

# Open in Xcode
open LexiconFlow.xcodeproj

# Build and run
# Product > Run (⌘R)
```

### Dependencies

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/open-spaced-repetition/swift-fsrs",
        from: "1.0.0"
    )
]
```

---

## Project Structure

```
LexiconFlow/
├── App/
│   ├── LexiconFlowApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Card.swift
│   ├── Deck.swift
│   ├── ReviewLog.swift
│   └── FSRSState.swift
├── Views/
│   ├── FlashcardView.swift
│   ├── DeckGridView.swift
│   └── StudySessionView.swift
├── ViewModels/
│   └── Scheduler.swift
├── Services/
│   ├── SentenceGenerator.swift
│   ├── TranslationService.swift
│   └── HapticService.swift
├── Widgets/
│   └── LexiconFlowWidget.swift
├── Resources/
│   └── dictionary.json
└── Tests/
    └── FSRSTests.swift
```

---

## Success Metrics

### North Star Metric

**Weekly Active Learners (WAL)** - Users who complete ≥5 study sessions/week

### Leading Indicators (Month 1-3)

- 45% Day 1 retention
- 25% Day 7 retention
- 15% Day 30 retention
- 8 min avg. session length

### Lagging Indicators (Month 6-12)

- 5,000 Weekly Active Learners
- 500 paying subscribers (10% conversion)
- 60+ Net Promoter Score
- 4.7+ App Store rating

---

## Contributing

**Status:** See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## License

**Decision Pending:** Options include:
- MIT (open source, community contributions)
- Proprietary (commercial venture)

To be determined before alpha release.

---

## Brand Assets

### Positioning Statement

> "For the serious English language learner who demands efficiency and elegance, Lexicon Flow is the vocabulary app that adapts to your life."

### Core Attributes

1. **Fluid** - Like water, flows around your schedule
2. **Intelligent** - On-device AI that respects privacy
3. **Beautiful** - "Liquid Glass" design that delights
4. **Scientific** - FSRS v5 grounded in research
5. **Native** - Pure iOS experience

---

## Acknowledgments

This project is informed by:
- **Open Spaced Repetition** - For the FSRS v5 algorithm
- **Jarrett Ye** - FSRS creator and maintainer
- **SwiftFSRS Contributors** - Native Swift implementation
- **Apple Inc.** - For iOS 26 "Liquid Glass" design and Foundation Models

---

## Contact

**Project Lead:** [To be assigned]

**Status:** Pre-Seed / Solo Founder

**Repository:** https://github.com/fedossayenko/lexiconflow-ios

---

**Last Updated:** January 2026

**Project Phase:** 🏗️ Phase 1 Foundation (Late Stage)

**Target iOS:** 26.1 (Deployment Target)

**Swift Version:** 6.0
