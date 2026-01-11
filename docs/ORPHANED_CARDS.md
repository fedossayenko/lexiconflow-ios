# Orphaned Cards Management

**Added**: 2026-01-11
**Status**: Stable

## Overview

**Orphaned cards** are flashcards that have no deck assignment (`deck == nil`). This occurs when:
1. A deck is deleted (cards persist due to `.nullify` delete rule)
2. A card is created without deck assignment
3. A card's deck reference is explicitly set to `nil`

## Architecture

### Delete Rule Change

**Previous Behavior (cascade):**
- Deleting a deck deleted all associated cards
- User loses all FSRS progress when deck is deleted

**Current Behavior (nullify):**
- Deleting a deck preserves the cards
- Cards become "orphaned" (deck reference is `nil`)
- FSRS progress is retained
- Cards can be reassigned to existing decks

**Rationale:** Preserves user learning progress (FSRS state) when deck is deleted, preventing accidental data loss while maintaining data integrity.

## Data Model

### Orphaned Card Query

```swift
@Query(filter: #Predicate<Flashcard> { $0.deck == nil }, sort: \Flashcard.createdAt)
private var orphanedCards: [Flashcard]
```

### Card-Deck Relationship

```swift
@Model
final class Flashcard {
    @Relationship(deleteRule: .nullify) var deck: Deck?
    // When deck is deleted, this becomes nil
}
```

**Note:** Both `Deck.cards` and `Flashcard.deck` use `.nullify` to prevent cascade loops and preserve cards on deck deletion.

## Service Layer

### OrphanedCardsService

`OrphanedCardsService` provides CRUD operations for managing orphaned cards:

```swift
@MainActor
final class OrphanedCardsService: Sendable {
    static let shared = OrphanedCardsService()

    // Fetch all orphaned cards
    func fetchOrphanedCards(context: ModelContext) -> [Flashcard]

    // Reassign cards to a deck
    func reassignCards(_ cards: [Flashcard], to deck: Deck, context: ModelContext) async throws -> Int

    // Bulk delete orphaned cards
    func deleteOrphanedCards(_ cards: [Flashcard], context: ModelContext) async throws -> Int

    // Get count of orphaned cards
    func orphanedCardCount(context: ModelContext) -> Int
}
```

## User Interface

### OrphanedCardsView

The `OrphanedCardsView` provides:
- List of all orphaned cards
- Multi-select functionality for bulk operations
- Reassignment to existing decks
- Bulk deletion with confirmation dialog
- Empty state handling

**Location:** `LexiconFlow/Views/Decks/OrphanedCardsView.swift`

### Navigation

Access via **DeckListView**:
```swift
NavigationLink("Orphaned Cards") {
    OrphanedCardsView()
}
```

### Onboarding Alert

First-time users with orphaned cards see an alert:

```
Alert: "Orphaned Cards Found"
Message: "You have N card(s) without deck assignment.
         These appear when decks are deleted.
         You can reassign them to existing decks in the Orphaned Cards section."
Actions:
  - "View Orphaned Cards" → Navigate to OrphanedCardsView
  - "Later" → Dismiss (marks as shown)
```

**Trigger condition:**
```swift
!AppSettings.hasShownOrphanedCardsPrompt && orphanedCount > 0
```

### UI Components

#### OrphanedCardRow

Single row in the orphaned cards list displaying:
- Selection indicator (checkmark or circle)
- Card word and definition
- "No Deck" badge (orange background)

#### OrphanedCardDeckReassignmentView

Sheet view for selecting target deck:
- Lists all available decks
- Shows deck icons and names
- Highlights selected deck
- Empty state when no decks exist

## Common Workflows

### Reassigning Orphaned Cards

1. Navigate to **DeckListView**
2. Tap **Orphaned Cards**
3. Select cards to reassign (multi-select)
4. Tap **Reassign** button
5. Choose target deck from list
6. Cards move to target deck
7. Selection is cleared
8. Cache is invalidated

### Bulk Deleting Orphaned Cards

1. Navigate to **OrphanedCardsView**
2. Tap **Edit** or select cards
3. Select cards to delete
4. Tap **Delete** button
5. Confirm deletion (alert shows count)
6. Cards are deleted with cascade:
   - FSRSState deleted
   - FlashcardReview deleted
   - GeneratedSentence deleted
7. Selection is cleared
8. Cache is invalidated

### Preventing Orphaned Cards

To avoid creating orphans:
- Always assign cards to decks during creation
- Use `DataImporter` with explicit deck parameter
- Verify deck exists before bulk operations
- Use deck deletion confirmation warnings

## Cache Invalidation

Orphaned card operations invalidate the `DeckStatisticsCache`:

```swift
// After reassignment
func reassignCards(...) async throws -> Int {
    // ... reassign cards ...
    try modelContext.save()
    DeckStatisticsCache.shared.invalidate() // Clear all decks cache
}

// After deletion
func deleteOrphanedCards(...) async throws -> Int {
    // ... delete cards ...
    try modelContext.save()
    DeckStatisticsCache.shared.invalidate() // Clear all decks cache
}
```

**Why full invalidation?**
- Reassignment affects both source (orphan count) and target (card count) decks
- Deletion affects deck statistics
- Simpler to invalidate all than track affected deck IDs

## Error Handling

### Reassignment Errors

```swift
do {
    let reassigned = try await OrphanedCardsService.shared.reassignCards(
        cards,
        to: deck,
        context: modelContext
    )
} catch {
    Analytics.trackError("reassign_orphaned_cards", error: error)
    errorMessage = "Failed to reassign cards: \(error.localizedDescription)"
}
```

### Deletion Errors

```swift
do {
    let deleted = try await OrphanedCardsService.shared.deleteOrphanedCards(
        cards,
        context: modelContext
    )
} catch {
    Analytics.trackError("delete_orphaned_cards", error: error)
    errorMessage = "Failed to delete cards: \(error.localizedDescription)"
}
```

## Analytics Tracking

Orphaned card operations are tracked for monitoring:

```swift
// Reassignment
Analytics.trackEvent("cards_reassigned", metadata: [
    "count": String(cards.count),
    "deck_id": deck.id.uuidString,
    "deck_name": deck.name
])

// Deletion
Analytics.trackEvent("orphaned_cards_deleted", metadata: [
    "count": String(cards.count)
])
```

## Data Model Relationships

### Cascade Delete Behavior

When deleting orphaned cards:

| Relationship | Delete Rule | Behavior |
|-------------|-------------|----------|
| `Flashcard.fsrsState` | `.cascade` | FSRSState deleted with card |
| `Flashcard.reviewLogs` | `.cascade` | FlashcardReview deleted with card |
| `Flashcard.generatedSentences` | `.cascade` | GeneratedSentence deleted with card |
| `Flashcard.deck` | `.nullify` | Deck preserved (already nil for orphans) |

### Query Performance

Fetching orphaned cards uses a predicate query:
- **O(n)** where n = total cards
- Optimized with SwiftData indexing on `deck` field
- No joins required (simple nil check)

**Performance characteristics:**
- Acceptable for typical datasets (< 10,000 cards)
- No caching needed for orphan count (changes infrequently)
- Sorted by `createdAt` for consistent ordering

## Testing

### Test Coverage

- **OrphanedCardsServiceTests.swift** - Service layer tests (331 lines)
- **OrphanedCardsViewTests.swift** - View layer tests (NEW)
- **MainTabViewTests.swift** - Onboarding alert tests

### Test Fixtures

```swift
private func createOrphanedCard(in context: ModelContext, word: String) -> Flashcard {
    let card = Flashcard(word: word, definition: "Test", phonetic: "/test/")
    // Intentionally NOT setting deck to create orphan
    context.insert(card)
    return card
}
```

## Statistics Impact

Orphaned cards are **NOT included** in deck statistics (due/new/total counts). They only appear in the dedicated Orphaned Cards section.

**Rationale:** Orphaned cards are not part of any deck's study schedule, so they should not affect deck statistics.

## User Experience Considerations

### Empty State

When no orphaned cards exist:
- Shows `ContentUnavailableView` with "No Orphaned Cards"
- Message: "All cards are properly assigned to decks"
- Provides positive reinforcement

### Bulk Actions

- Multi-select for efficient reassignment/deletion
- Clear count indicator ("N selected")
- Confirm dialogs prevent accidental data loss
- Selection cleared after successful operations

### Onboarding Flow

- Alert only shown once (`hasShownOrphanedCardsPrompt` flag)
- Non-intrusive (can be dismissed with "Later")
- Direct navigation to OrphanedCardsView
- Contextual count in alert message

## Future Enhancements

Potential improvements:
- [ ] Undo functionality for bulk deletion
- [ ] Smart reassignment suggestions (based on card content)
- [ ] Orphaned card export/import
- [ ] Automatic cleanup of old orphans (> 30 days)
- [ ] Merge multiple orphaned cards into new deck
- [ ] Orphaned card analytics dashboard
- [ ] Quick reassign to most recently used deck

---

**Document Version:** 1.0
**Last Updated:** January 2026
**Related Files:**
- `LexiconFlow/LexiconFlow/Services/OrphanedCardsService.swift`
- `LexiconFlow/LexiconFlow/Views/Decks/OrphanedCardsView.swift`
- `LexiconFlow/LexiconFlow/Views/Components/MainTabView.swift`
- `LexiconFlow/LexiconFlow/Models/Flashcard.swift`
- `LexiconFlow/LexiconFlow/Models/Deck.swift`

**Test Files:**
- `LexiconFlow/LexiconFlowTests/OrphanedCardsServiceTests.swift`
- `LexiconFlow/LexiconFlowTests/OrphanedCardsViewTests.swift`
- `LexiconFlow/LexiconFlowTests/MainTabViewTests.swift`
