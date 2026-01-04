# Lexicon Flow iOS - Spaced Repetition Algorithm Specifications

## Overview

This document provides detailed specifications for the Spaced Repetition System (SRS) algorithm implemented in Lexicon Flow: **FSRS v5** (Free Spaced Repetition Scheduler).

---

## Theoretical Foundation

### The Ebbinghaus Forgetting Curve

Memory decay follows an exponential function:

```
R(t) = e^(-t/S)
```

Where:
- **R(t)** = Retrievability (probability of recall at time t)
- **t** = Time elapsed since last review
- **S** = Stability (time for R to drop from 100% to 90%)

**Goal of SRS:** Schedule reviews when R drops to approximately 90% (the "optimal review threshold").

---

## Why FSRS v5 Instead of SM-2?

### SM-2 Limitations

| Issue | Description | Impact |
|-------|-------------|--------|
| **Static Multipliers** | Interval = previous_interval × EF | Cannot adapt to individual learning patterns |
| **Single Difficulty Metric** | EF combines multiple factors | Can't distinguish between "hard to learn" vs "fast to forget" |
| **Lateness Blindness** | Calculates based on scheduled date, not actual date | If user reviews late and remembers, interval doesn't increase appropriately |
| **Rigid Intervals** | No adjustment for early reviews | Users forced to wait or break algorithm |
| **No Retrievability Tracking** | Doesn't model memory decay | Can't optimize review timing |

### FSRS Advantages

| Feature | SM-2 | FSRS v5 |
|---------|------|---------|
| **Difficulty Modeling** | Single EF | Separate Difficulty (D) and Stability (S) |
| **Late Reviews** | Ignores actual review date | Increases stability if recalled late |
| **Early Reviews** | Breaks algorithm | Handles gracefully with fractional bonus |
| **Memory Decay** | Not modeled | Explicit Retrievability (R) calculation |
| **Adaptability** | Fixed parameters | Learns from user's review history |

---

## FSRS v5 Algorithm

### Three-Component Model

FSRS models memory using three distinct variables:

| Component | Symbol | Mathematical Role | Physical Meaning |
|-----------|--------|-------------------|------------------|
| **Stability** | S | Determines interval length | Days for R to drop from 100% to 90% |
| **Difficulty** | D | Affects initial stability | Intrinsic complexity of information (0-10) |
| **Retrievability** | R | Triggers review timing | Probability of recall right now |

### The Mathematical Model

#### Retrievability Calculation

```
R(t) = (1 + factor × t/S)^decay
```

Where:
- **t** = Time elapsed since last review (in days)
- **S** = Current stability
- **factor** = FSRS parameter (typically ~9)
- **decay** = FSRS parameter (typically ~-0.5)

#### Interval Calculation

When a card is reviewed with rating `r`:

```
S' = S × (1 + factor × e^(-k × (r - r0)))
```

Where:
- **S'** = New stability
- **r** = User rating (0-3 scale)
- **r0** = Reference rating
- **k** = Scaling factor
- **factor** = Difficulty-dependent multiplier

#### Difficulty Update

```
D' = D - w × (r - expected_rating)
```

Where:
- **D'** = New difficulty
- **w** = Learning rate
- **expected_rating** = Predicted rating based on current R

---

## Rating Scale

FSRS uses a 4-point rating scale:

| Rating | Label | Description | Memory Strength |
|--------|-------|-------------|-----------------|
| 1 | **Again** | Complete blackout | None |
| 2 | **Hard** | Remembered with significant difficulty | Weak |
| 3 | **Good** | Remembered correctly | Adequate |
| 4 | **Easy** | Remembered instantly | Strong |

**Note**: FSRS ratings are 1-indexed. The SwiftFSRS library maps these to an enum.

---

## Card States

FSRS models cards in four distinct states:

| State | Description | Interval Calculation |
|-------|-------------|---------------------|
| **New** | Never been reviewed | Initial S based on D |
| **Learning** | Recently failed, in short-term learning | Minutes-scale intervals |
| **Review** | Long-term retention | Days-scale intervals using S |
| **Relearning** | Failed after being in Review | Hybrid approach |

---

## SwiftFSRS Integration

### Basic Usage

```swift
import SwiftFSRS

// Initialize scheduler
let scheduler = FSRS()

// Create a new card
var card = Card()
card.state = .new
card.difficulty = 5.0  // Default mid-range difficulty
card.stability = 0.0
card.retrievability = 0.9

// Review the card
let now = Date()
let rating: Rating = .good

let result = scheduler.review(card: card, rating: rating)

// Result contains:
// - new due date
// - updated stability
// - updated difficulty
// - updated retrievability
// - new state
```

### State Persistence

```swift
@Model
final class FSRSState {
    var stability: Double
    var difficulty: Double
    var retrievability: Double
    var dueDate: Date
    var state: CardState

    func toFSRSCard() -> Card {
        Card(
            state: State(rawValue: state.rawValue) ?? .new,
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability
        )
    }

    func update(from result: ReviewResult) {
        self.stability = result.stability
        self.difficulty = result.difficulty
        self.retrievability = result.retrievability
        self.dueDate = result.dueDate
        self.state = CardState(from: result.state)
    }
}
```

---

## Cram Mode Implementation

### Problem

Users want to study cards before they're due (e.g., before an exam), but FSRS (like all SRS algorithms) is designed for optimal review timing.

### Solution

Separate "Cram Sessions" from "Scheduled Reviews":

| Mode | Updates SRS | Description |
|------|-------------|-------------|
| **Scheduled Review** | Yes | Standard FSRS progression when R < threshold |
| **Cram Session** | No | Temporary refresher, algorithm unchanged |

### Implementation

```swift
enum StudyMode {
    case scheduled
    case cram
}

struct StudySession {
    let mode: StudyMode
    let deck: Deck

    func fetchCards() -> [Card] {
        switch mode {
        case .scheduled:
            // Fetch cards where R < 0.9 (due)
            return fetchDueCards()

        case .cram:
            // Fetch cards with lowest stability, regardless of R
            return fetchCardsByStability(limit: 50)
        }
    }

    func processReview(card: Card, rating: Rating) async {
        switch mode {
        case .scheduled:
            // Update FSRS state
            await scheduler.update(card: card, rating: rating)

        case .cram:
            // Only track for analytics, don't update SRS
            logCramReview(card: card, rating: rating)
        }
    }
}
```

### Why This Works

FSRS can accept a review log that happens "early" and will simply calculate a smaller increase in Stability. This means:

1. Cramming doesn't "break" the algorithm
2. It provides minimal long-term benefit (which is pedagogically correct)
3. Users can study whenever they want without guilt

---

## Algorithm Configuration

### Default Parameters

```swift
struct FSRSParameters {
    // Request retention: 90% probability
    let requestRetention: Double = 0.9

    // Maximum interval: ~100 years
    let maximumInterval: Int = 36500

    // FSRS v5 weights (standard)
    let weights: [Double] = [
        0.4,   // w[0]: Stability for Again
        0.6,   // w[1]: Stability for Hard
        2.4,   // w[2]: Stability for Good
        5.8,   // w[3]: Stability for Easy
        4.93,  // w[4]: Difficulty for Again
        0.29,  // w[5]: Difficulty for Hard
        0.02,  // w[6]: Difficulty for Good
        -0.34  // w[7]: Difficulty for Easy
    ]
}
```

### Parameter Tuning

#### Global Settings

```swift
struct SRSSettings {
    var requestRetention: Double = 0.9        // Target: 80%-95%
    var maximumInterval: Int = 36500          // ~100 years max
    var enableShortTerm: Bool = true          // Enable Learning state
}
```

#### Per-Deck Customization

```swift
@Model
final class Deck {
    // ... existing properties

    var customRetention: Double?              // Override global if set
    var enableFSRS: Bool = true               // Can disable per deck
    var fsrsWeights: Data?                    // Custom weights (advanced)
}
```

---

## Review Logging

### Importance of Logs

FSRS optimization requires comprehensive review history. Every review must be logged with:

```swift
@Model
final class ReviewLog {
    var id: UUID
    var rating: Rating
    var reviewDate: Date

    // FSRS-specific state at time of review
    var state: CardState
    var stabilityBefore: Double
    var stabilityAfter: Double
    var difficultyBefore: Double
    var difficultyAfter: Double

    // Timing information
    var scheduledDays: Int                    // Days the card was scheduled for
    var elapsedDays: Int                      // Days actually elapsed
    var timeTaken: TimeInterval               // Seconds user spent on card

    @Relationship(inverse: \Card.reviewLogs)
    var card: Card?

    init(
        rating: Rating,
        state: CardState,
        stabilityBefore: Double,
        stabilityAfter: Double,
        difficultyBefore: Double,
        difficultyAfter: Double,
        scheduledDays: Int,
        elapsedDays: Int,
        timeTaken: TimeInterval
    ) {
        self.id = UUID()
        self.rating = rating
        self.reviewDate = Date()
        self.state = state
        self.stabilityBefore = stabilityBefore
        self.stabilityAfter = stabilityAfter
        self.difficultyBefore = difficultyBefore
        self.difficultyAfter = difficultyAfter
        self.scheduledDays = scheduledDays
        self.elapsedDays = elapsedDays
        self.timeTaken = timeTaken
    }
}
```

---

## Optimization Algorithm

### Background Optimizer

FSRS includes an optimizer that runs periodically to tune weights based on user's actual review history.

```swift
actor FSRSOptimizer {
    func optimize(for cards: [Card]) async -> FSRSParameters {
        // Extract review logs
        var logs: [ReviewLog] = []
        for card in cards {
            logs.append(contentsOf: card.reviewLogs)
        }

        // Run FSRS optimizer algorithm
        let newWeights = try? FSRS.optimize(
            logs: logs,
            requestRetention: 0.9
        )

        // Return updated parameters
        return FSRSParameters(weights: newWeights ?? defaultWeights)
    }
}
```

### Optimization Triggers

1. **After 100 reviews** - Initial calibration
2. **Every 500 reviews** - Ongoing refinement
3. **Manual trigger** - User-initiated in settings
4. **Drift detection** - If actual retention deviates >5% from target

---

## Testing Strategy

### Unit Tests

```swift
import XCTest
import SwiftFSRS

final class FSRSTests: XCTestCase {
    var scheduler: FSRS!

    override func setUp() {
        scheduler = FSRS()
    }

    func testNewCardFirstReview() {
        var card = Card(state: .new, difficulty: 5.0)

        let result = scheduler.review(card: card, rating: .good)

        XCTAssertGreaterThan(result.stability, 0)
        XCTAssertEqual(result.state, .learning)
    }

    func testAgainResetsState() {
        var card = Card(
            state: .review,
            difficulty: 5.0,
            stability: 100.0
        )

        let result = scheduler.review(card: card, rating: .again)

        XCTAssertEqual(result.state, .relearning)
        XCTAssertLessThan(result.stability, 100)
    }

    func testEasyIncreasesStability() {
        var card = Card(
            state: .review,
            difficulty: 5.0,
            stability: 10.0
        )

        let before = card.stability
        let result = scheduler.review(card: card, rating: .easy)

        XCTAssertGreaterThan(result.stability, before)
    }

    func testLateReviewBonus() {
        var card = Card(
            state: .review,
            difficulty: 5.0,
            stability: 10.0
        )

        // Simulate late review
        let result = scheduler.review(
            card: card,
            rating: .good,
            elapsedDays: 20  // More than scheduled
        )

        // Should get bonus stability for remembering despite delay
        XCTAssertGreaterThan(result.stability, 10.0)
    }
}
```

### Integration Tests

```swift
func testFullStudySession() async throws {
    // Create test deck
    let deck = try await createTestDeck(cardCount: 100)

    // Simulate 30 days of study
    for day in 1...30 {
        let dueCards = await fetchDueCards(from: deck)

        for card in dueCards {
            let rating = simulateUserRating(for: card)
            await scheduler.update(card: card, rating: rating)
        }

        try await Task.sleep(for: .seconds(1))  // Simulate day passing
    }

    // Verify retention
    let retention = await calculateRetention(for: deck)
    XCTAssertGreaterThanOrEqual(retention, 0.85)  // ~85% actual retention
}
```

---

## Performance Considerations

### Query Optimization

```swift
// Efficient query for due cards
let predicate = #Predicate<Card> { card in
    card.fsrsState.dueDate <= now
}

let descriptor = FetchDescriptor<Card>(
    predicate: predicate,
    sortBy: [SortDescriptor(\.fsrsState.dueDate)]
)
```

### Background Processing

```swift
// Run scheduler off main actor
actor Scheduler {
    func processBatch(_ cards: [Card], ratings: [Rating]) async {
        for (card, rating) in zip(cards, ratings) {
            let result = fsrs.review(card: card, rating: rating)
            updateCard(card, with: result)
        }
    }
}
```

---

## Migration Strategy

### No Migration Needed

Since Lexicon Flow launches with FSRS v5 from day one, no migration from SM-2 is required.

### Future Algorithm Upgrades

The modular architecture allows for future algorithm upgrades:

```swift
protocol SpacedRepetitionScheduler {
    func review(card: Card, rating: Rating) -> ReviewResult
}

extension FSRSWrapper: SpacedRepetitionScheduler {
    func review(card: Card, rating: Rating) -> ReviewResult {
        // FSRS v5 implementation
    }
}

// Future: FSRS v6, SM-15, etc.
```

---

## References

1. **Open Spaced Repetition** - FSRS v4.5/v5 Algorithm Specification
2. **L-M-Sher** - Original FSRS research and benchmarks
3. **SwiftFSRS** - Swift implementation package
4. **SuperMemo** - Original SM-2 algorithm (for comparison)
5. **Jarrett Ye** - FSRS creator and maintainer

---

**Document Version**: 1.0
**Last Updated**: January 2026
**Algorithm**: FSRS v5
**Implementation**: SwiftFSRS package
