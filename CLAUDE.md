# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lexicon Flow** is a native iOS vocabulary acquisition app built with **Swift 6**, **SwiftUI**, **SwiftData**, and the **FSRS v5** spaced repetition algorithm. It targets iOS 26.1+ and uses "Liquid Glass" design patterns for a fluid, state-of-flow learning experience.

**Core Differentiators:**
- FSRS v5 algorithm (adaptive, superior to SM-2)
- iOS 26 "Liquid Glass" UI with reactive glass effects
- On-device AI (Foundation Models) for privacy
  > ⚠️ **NOTE**: Foundation Models integration is implemented but **disabled via feature flag** (planned for Phase 3)
- **On-device translation** (iOS 26 Translation framework) - 100% offline, no API costs
- Two study modes: Scheduled (respects due dates) and Cram (for practice)

## MCP Memory for LexiconFlow

Project-specific memory using semantic search (see Global CLAUDE.md for tool reference)

### Project Usage

**Search project context:**
```
mcp__memory__search_nodes({query: "LexiconFlow architecture SwiftData"})
```

**Add project entity:**
```
mcp__memory__create_entities({
  entities: [{
    name: "StudyStreakFeature",
    entityType: "feature",
    observations: ["Study streak tracking", "@Observable state", "DailyStats integration"]
  }]
})
```

**Update LexiconFlow entity:**
```
mcp__memory__add_observations({
  observations: [{
    entityName: "LexiconFlow",
    contents: ["Added Quick Translation (Pattern 24) - Jan 2026"]
  }]
})
```

### Current Entities

- **LexiconFlow** (project) - iOS vocabulary app: Swift 6, SwiftUI, SwiftData, FSRS v5
- **Fedir** (developer) - iOS developer, MacBook M2 Pro 16GB
- **FSRS** (algorithm) - Free Spaced Repetition Scheduler v5

### Project Best Practices

- Always search memory before asking user
- Name entities with "LexiconFlow" prefix for project-specific items
- Store architectural decisions as they're made
- Add bug fixes and their resolutions

## Build and Test Commands

### Build
```bash
cd LexiconFlow
xcodebuild build \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
```

### Run Tests
```bash
# Run all tests (serialized execution required for shared container)
cd LexiconFlow
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' \
  -only-testing:LexiconFlowTests \
  -parallel-testing-enabled NO

# Run specific test suite
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' \
  -only-testing:LexiconFlowTests/TranslationServiceTests \
  -parallel-testing-enabled NO
```

### Dependencies
- **SwiftFSRS**: `https://github.com/open-spaced-repetition/swift-fsrs` (v5.0.0)
- **Translation**: iOS 26 Translation framework (on-device translation, no package dependency)
- Resolve with: `xcodebuild -resolvePackageDependencies` (from `LexiconFlow/` directory)

### External Documentation
- **SwiftData**: [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- **Swift Concurrency**: [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- **Translation Framework**: [Translation API Reference](https://developer.apple.com/documentation/translation)
- **CoreHaptics**: [CoreHaptics Framework](https://developer.apple.com/documentation/corehaptics)
- **Swift Testing**: [Swift Testing Package](https://developer.apple.com/documentation/testing)

### Bundle Resource Paths

**IMPORTANT:** This project uses Xcode 26's `PBXFileSystemSynchronizedRootGroup` for resource management.

**Key Behavior:**
- Source files in `Resources/` directory are copied to bundle root (NOT preserving `Resources/` subdirectory)
- Source: `LexiconFlow/Resources/IELTS/file.json` → Bundle: `{bundle}/file.json`

**When accessing bundle resources:**
```swift
// ✅ CORRECT: Files are at bundle root (no Resources/ prefix)
Bundle.main.url(forResource: "ielts-vocabulary-smartool", withExtension: "json")

// ❌ WRONG: Resources/ prefix doesn't exist in bundle
Bundle.main.url(forResource: "Resources/IELTS/ielts-vocabulary-smartool", withExtension: "json")
```

**Debugging bundle paths:**
```swift
#if DEBUG
if let resourcePath = Bundle.main.resourcePath {
    let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
    print("Bundle contents:", files ?? [])
}
#endif
```

## Architecture

**See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed technical specifications including:**
- Complete MVVM + SwiftData architecture
- Swift 6 concurrency model and actor isolation
- DTO pattern for cross-actor safety
- Complete data flow diagrams

**Quick Reference:**

**Pattern**: MVVM with SwiftData
- **Models**: `@Model` classes in `Models/` (Flashcard, Deck, FSRSState, FlashcardReview, DailyStats, StudySession)
- **ViewModels**: `@MainActor` classes in `ViewModels/` (Scheduler, StatisticsViewModel)
- **Views**: SwiftUI views in `Views/` observing via `@Bindable` and `@Query`

**Concurrency**: All ViewModels use `@MainActor` for thread-safe SwiftData access. DTO pattern (Pattern 6) prevents cross-actor mutations.

**Study Modes**:
- **scheduled**: Respects due dates, updates FSRS state after each review
- **cram**: Ignores due dates, logs reviews only (doesn't update FSRS)

## Critical Implementation Patterns

### 1. Naming: Flashcard vs Card
- Use `Flashcard` instead of `Card` to avoid collision with FSRS library's `Card` type

### 2. ModelContainer Fallback Pattern (No fatalError)
**NEVER use `fatalError` for ModelContainer creation** - it causes immediate app crash:
```swift
// ❌ AVOID: Crashes app on any database error
var sharedModelContainer: ModelContainer = {
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")  // CRASH!
    }
}()

// ✅ CORRECT: Graceful degradation with fallback
var sharedModelContainer: ModelContainer = {
    let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    let schema = Schema([FSRSState.self, Flashcard.self, Deck.self, FlashcardReview.self])

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        logger.critical("ModelContainer creation failed: \(error)")
        Analytics.trackError("model_container_failed", error: error)

        // Fallback to in-memory for recovery
        let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        } catch {
            // Last resort: minimal app with error UI
            return ModelContainer(for: [])
        }
    }
}()
```
**Rationale**: Database corruption, permissions, or disk full should not crash the app. Use in-memory fallback to allow user to see error and attempt recovery.

### 3. KeychainManager Security Pattern
**Use KeychainManager for sensitive data** (API keys, tokens):
```swift
// Store API key securely
try KeychainManager.setAPIKey("sk-test-...")

// Retrieve API key
if let apiKey = try KeychainManager.getAPIKey() {
    // Use API key
}

// Check if API key exists
if KeychainManager.hasAPIKey() {
    // API key is configured
}

// Delete API key
try KeychainManager.deleteAPIKey()
```
**Key Features**:
- UTF-8 encoding support (emoji, CJK, RTL languages)
- Generic account storage for custom data
- Empty key validation
- Secure storage with kSecClassGenericPassword

### 4. AppSettings Centralization (Not @AppStorage)
**Use `AppSettings` class instead of direct `@AppStorage`** for centralized state management:
```swift
// ✅ CORRECT: Use AppSettings properties
struct MyView: View {
    var body: some View {
        Toggle("Translation", isOn: Binding(
            get: { AppSettings.isTranslationEnabled },
            set: { AppSettings.isTranslationEnabled = $0 }
        ))
    }
}

// ❌ AVOID: Direct @AppStorage
struct MyView: View {
    @AppStorage("translationEnabled") private var translationEnabled = true
    // ^^^ Scattered across views, hard to maintain
}
```
**Rationale**: Single source of truth, easier to test, centralized defaults.

### 5. Translation Services

**Two translation options are available:**

**Cloud Translation** (`TranslationService`): Requires API key, provides CEFR levels and context sentences.
**On-Device Translation** (`OnDeviceTranslationService`): 100% offline, iOS 26 Translation framework, no API key needed.

**Cloud vs On-Device Comparison:**

| Feature | Cloud Translation | On-Device Translation |
|---------|------------------|----------------------|
| **Privacy** | Data sent to external API | 100% local, no data leaves device |
| **Internet** | Required | Not required after language packs downloaded |
| **Cost** | API costs | Free (iOS framework) |
| **Setup** | Requires API key in Keychain | Language pack download (50-200MB each, one-time) |
| **Languages** | Depends on provider | 24 languages (iOS 26 framework) |
| **CEFR Levels** | Supported | Not supported (text-only) |
| **Context Sentences** | Supported | Not supported (text-only) |

**On-Device Translation Usage:**
```swift
// Configure and translate
let service = OnDeviceTranslationService.shared
await service.setLanguages(source: "en", target: "es")

// Check language pack availability
if service.needsLanguageDownload("es") {
    try await service.requestLanguageDownload("es")  // System prompts user
}

// Single translation
let translation = try await service.translate(text: "Hello")

// Batch translation with progress
let result = try await service.translateBatch(
    words,
    maxConcurrency: 5,
    progressHandler: { progress in
        print("Progress: \(progress.current)/\(progress.total)")
    }
)
```

**Cloud Translation Usage:**
```swift
// Requires API key in Keychain
try KeychainManager.setAPIKey("sk-test-...")
let result = try await TranslationService.shared.translateBatch(
    cards,
    maxConcurrency: 5,
    progressHandler: { progress in
        print("Progress: \(progress.completedCount)/\(progress.totalCount)")
    }
)
```

**Error Types** (OnDeviceTranslationError):
- `unsupportedLanguagePair`: Not supported by iOS framework (not retryable)
- `languagePackNotAvailable`: Pack not downloaded (not retryable)
- `translationFailed`: Framework error (retryable)

**Supported Languages** (24): ar, zh-Hans, zh-Hant, nl, en, fr, de, el, he, hi, hu, id, it, ja, ko, pl, pt, ru, es, sv, th, tr, uk, vi

**Quick Translation** (Pattern 24): Instant on-device translation for selected text via context menu. See `QuickTranslationService` for implementation details.

### 6. DTO Pattern for Concurrency
```swift
// FSRSWrapper actor returns DTO (not model mutation)
func processReview(flashcard: Flashcard, rating: Int) throws -> FSRSReviewResult

// Scheduler (@MainActor) applies DTO updates
func processReview(flashcard: Flashcard, rating: Int) async -> FlashcardReview?
```

### 7. Single-Sided Inverse Relationships
Define `@Relationship` inverse on **only ONE side** to avoid SwiftData circular macro expansion errors:
```swift
// Flashcard.swift - inverse NOT defined here
@Relationship(deleteRule: .cascade) var fsrsState: FSRSState?

// FSRSState.swift - inverse defined HERE
@Relationship(inverse: \Flashcard.fsrsState) var card: Flashcard?
```

### 8. Cached lastReviewDate
Cache last review date in `FSRSState.lastReviewDate` for O(1) access vs O(n) scan through reviewLogs

### 9. String Literals in Predicates
Use string literals instead of enum raw values in `#Predicate`:
```swift
// CORRECT: String literal
#Predicate<FSRSState> { state in
    state.stateEnum != "new"
}

// AVOID: Can cause SwiftData key path issues
#Predicate<FSRSState> { state in
    state.stateEnum != FlashcardState.new.rawValue
}
```

### 10. External Storage for Images
```swift
@Attribute(.externalStorage) var imageData: Data?
```

### 11. Timezone-Aware Date Math
Use `DateMath.elapsedDays()` for calendar-aware calculations (handles DST, timezone boundaries)

### 12. Reactive Updates with @Query
Use `@Query` for automatic SwiftData updates instead of manual refresh:
```swift
// ❌ AVOID: Manual refresh with .onAppear
struct MyView: View {
    @State private var items: [Item] = []

    var body: some View {
        List(items) { item in Text(item.name) }
            .onAppear { loadItems() }  // Never updates!
    }
}

// ✅ CORRECT: Automatic updates with @Query
struct MyView: View {
    @Query private var items: [Item]

    var body: some View {
        List(items) { item in Text(item.name) }  // Auto-updates
    }
}
```
**Rationale**: @Query automatically tracks SwiftData changes and updates the view.

### 13. Error Handling with User Alerts
Always show errors to users with Analytics tracking:
```swift
struct MyView: View {
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button("Save") { save() }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            Analytics.trackError("save_failed", error: error)
        }
    }
}
```
**Rationale**: Silent failures create poor UX. Users need to know when operations fail.

### 14. CoreHaptics with UIKit Fallback Pattern
**Use CoreHaptics for custom haptic patterns with graceful UIKit fallback:**
```swift
// HapticService.swift
@MainActor
class HapticService {
    static let shared = HapticService()

    private var hapticEngine: CHHapticEngine?
    private var fallbackLight: UIImpactFeedbackGenerator?
    private var fallbackMedium: UIImpactFeedbackGenerator?
    private var fallbackHeavy: UIImpactFeedbackGenerator?

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func triggerSwipe(direction: SwipeDirection, progress: CGFloat) {
        guard AppSettings.hapticEnabled else { return }
        guard progress > 0.3 else { return }

        if supportsHaptics, let engine = hapticEngine {
            triggerCoreHapticSwipe(direction: direction, progress: progress, engine: engine)
        } else {
            triggerUIKitSwipe(direction: direction, progress: progress)
        }
    }
}
```
**Key Features:**
- Device capability detection with `CHHapticEngine.capabilitiesForHardware()`
- Custom haptic patterns for each swipe direction
- Graceful UIKit fallback for older devices
- Engine lifecycle management (setup, reset, restart)
- Analytics tracking for haptic failures

**Rationale**: CoreHaptics enables "Liquid Glass" haptic design with custom temporal patterns, while UIKit fallback ensures compatibility.

### 15. Matched Geometry Effect Pattern

**Use `@Namespace` and `matchedGeometryEffect` for smooth element transitions:**

```swift
// Define namespace in parent view
struct FlashcardMatchedView: View {
    @Bindable var card: Flashcard
    @Binding var isFlipped: Bool

    // Namespace for matched geometry effect
    @Namespace private var flipAnimation

    var body: some View {
        ZStack {
            if isFlipped {
                CardBackViewMatched(card: card, namespace: flipAnimation)
            } else {
                CardFrontViewMatched(card: card, namespace: flipAnimation)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFlipped)
    }
}

// Child views use same namespace with matching IDs
struct CardFrontViewMatched: View {
    let card: Flashcard
    var namespace: Namespace.ID

    var body: some View {
        VStack {
            Text(card.word)
                .matchedGeometryEffect(id: "word", in: namespace)

            Text(card.phonetic ?? "")
                .matchedGeometryEffect(id: "phonetic", in: namespace)
        }
    }
}
```

**Key Concepts:**
- **Namespace**: Shared identifier space for matched elements
- **ID**: String identifier that must match across views
- **Animation**: Spring animation for smooth, fluid transitions
- **State Toggle**: `@Binding` controls which view is visible

**When to Use:**
- Card flip animations (front ↔ back)
- Element position changes (list ↔ detail)
- Shared element transitions
- Morphing layouts

**Performance**: Transitions complete in < 300ms on iPhone 12+

### 16. Glass Effects: Progress Ring Pattern

**Use circular progress rings with "Liquid Glass" styling for visual feedback:**

```swift
// Apply to deck icons for due card ratio
Image(systemName: "folder.fill")
    .font(.system(size: 24))
    .foregroundStyle(.blue)
    .glassEffectUnion(
        progress: 0.5,  // due/total ratio (0.0 to 1.0)
        thickness: .regular,
        iconSize: 60
    )
```

**Color Coding:**
- **Green (0.0-0.3)**: Low due count (good)
- **Orange (0.3-0.7)**: Medium due count (warning)
- **Red (0.7-1.0)**: High due count (urgent)

**Animation:** Smooth spring animation (response: 0.6, damping: 0.7)

**Usage in Views:**
```swift
// Calculate progress ratio
let dueCount = deck.cards.filter { $0.isDue }.count
let totalCount = deck.cards.count
let progress = totalCount > 0 ? Double(dueCount) / Double(totalCount) : 0.0

Image(systemName: deck.icon)
    .glassEffectUnion(progress: progress, thickness: .regular)
```

### 17. Interactive Glass Effect Pattern

**Use `InteractiveGlassModifier` for gesture-driven visual feedback:**

```swift
struct StudyCardView: View {
    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        CardContent()
            .interactive($offset) { dragOffset in
                // Direction-based tint
                let progress = min(max(dragOffset.width / 100, -1), 1)
                if progress > 0 {
                    return .tint(.green.opacity(0.3 * progress))
                } else {
                    return .tint(.red.opacity(0.3 * abs(progress)))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
            )
    }
}
```

**Visual Effects Applied:**
1. **Directional tint**: Color overlay based on drag direction
2. **Specular highlight**: Light refraction effect (progress > 0.1)
3. **Edge glow**: Glowing rim effect (progress > 0.2)
4. **Hue rotation**: Subtle color shift (5° max)
5. **Saturation boost**: Increased vividness (20% max)
6. **Scale swell**: 5% growth for tactile feedback
7. **3D tilt**: Perspective rotation (5° max)

**Constants (InteractiveGlassModifier.swift):**
- `maxDragDistance: 200` - Full effect at 200pt drag
- `specularHighlightOpacity: 0.3` - 30% brightness
- `edgeGlowOpacityMultiplier: 0.5` - 50% intensity
- `scaleEffectMultiplier: 0.05` - 5% swelling

**Integration with CardGestureViewModel:**
```swift
@StateObject private var gestureViewModel = CardGestureViewModel()

CardContent()
    .interactive(
        $gestureViewModel.translation,
        effect: { _ in .tint(gestureViewModel.tintColor) }
    )
    .scaleEffect(gestureViewModel.scale)
    .rotation3DEffect(
        .degrees(gestureViewModel.rotation),
        axis: (x: 0, y: 1, z: 0)
    )
```

### 18. GlassEffectContainer Pattern

**Use `GlassEffectContainer` for performance-optimized glass effects:**

```swift
// Single glass element
GlassEffectContainer(thickness: .regular) {
    Text("Content")
        .padding()
}

// Multiple glass elements (optimized with .drawingGroup)
ScrollView {
    ForEach(0..<10) { i in
        GlassEffectContainer(thickness: .regular) {
            Text("Item \(i)")
        }
    }
}
```

**When to Use:**
- Multiple glass elements on screen (card stacks, deck lists)
- Complex glass effects with multiple visual layers
- Performance-critical views with frequent redraws

**When NOT to Use:**
- Single static glass element (optimization overhead unnecessary)
- Very simple content (plain text with no graphics)

**Thickness Levels:**
- **Thin**: `cornerRadius: 12`, `shadowRadius: 5`, `overlayOpacity: 0.1`
- **Regular**: `cornerRadius: 16`, `shadowRadius: 10`, `overlayOpacity: 0.2`
- **Thick**: `cornerRadius: 20`, `shadowRadius: 15`, `overlayOpacity: 0.3`

**Performance:**
- `.drawingGroup()` caches rendering as GPU bitmap
- Target: 60fps with < 16.6ms frame time
- Measured with Xcode Instruments → Core Animation

**Centralized Configuration:**
```swift
let config = AppSettings.glassConfiguration

// Dynamic thickness based on intensity
let thickness = config.effectiveThickness(base: .regular)

// Scaled opacity for intensity control
let opacity = baseOpacity * config.opacityMultiplier
```

**User Preferences:**
- `AppSettings.glassEffectsEnabled: Bool` - Master toggle
- `AppSettings.glassEffectIntensity: Double` - Intensity slider (0.0 to 1.0)
- Settings available in Appearance Settings

### 19. Audio Session Lifecycle Pattern

**Manage AVAudioSession lifecycle to prevent error 4099:**

```swift
// In LexiconFlowApp.swift
@Environment(\.scenePhase) private var scenePhase

var body: some Scene {
    WindowGroup { ContentView() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                // Deactivate audio session to prevent AVAudioSession error 4099
                SpeechService.shared.cleanup()
            case .active:
                if oldPhase == .background || oldPhase == .inactive {
                    // Reactivate audio session for text-to-speech
                    SpeechService.shared.restartEngine()
                }
            default:
                break
            }
        }
}
```

**Key Concepts:**
- iOS automatically deactivates audio sessions when apps background
- Without explicit cleanup, AVAudioSession error 4099 occurs during app termination
- `cleanup()` stops ongoing speech and deactivates session gracefully
- `restartEngine()` reconfigures session when app returns to foreground

**Rationale**: Prevents audio session errors during app lifecycle transitions.

### 20. TTS Timing Options Pattern

**Use `AppSettings.TTSTiming` enum for flexible pronunciation playback:**

```swift
enum AppSettings.TTSTiming: String, CaseIterable, Sendable {
    case onView  // Play when card front appears
    case onFlip  // Play when card flips to back
    case manual  // Play only via speaker button
}
```

**Usage with ViewModifier (recommended):**
```swift
// Extract TTS logic to shared modifier
struct TTSViewModifier: ViewModifier {
    let card: Flashcard
    @Binding var isFlipped: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard AppSettings.ttsEnabled else { return }
                guard !isFlipped else { return }
                switch AppSettings.ttsTiming {
                case .onView: SpeechService.shared.speak(card.word)
                case .onFlip, .manual: break
                }
            }
            .onChange(of: isFlipped) { _, newValue in
                guard AppSettings.ttsEnabled else { return }
                switch AppSettings.ttsTiming {
                case .onView:
                    if !newValue { SpeechService.shared.speak(card.word) }
                case .onFlip:
                    if newValue { SpeechService.shared.speak(card.word) }
                case .manual: break
                }
            }
    }
}

// Use in views
FlashcardView(card: card)
    .ttsTiming(for: card, isFlipped: $isFlipped)
```

**Migration from Boolean:**
```swift
// TTSSettingsView.swift
private func migrateTTSTiming() {
    let migrationKey = "ttsTimingMigrated"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

    if AppSettings.ttsAutoPlayOnFlip {
        AppSettings.ttsTiming = .onFlip
    } else {
        AppSettings.ttsTiming = .onView // New default
    }

    UserDefaults.standard.set(true, forKey: migrationKey)
}
```

**Rationale**: Enum provides more flexibility than boolean toggle, supporting multiple auto-play strategies.

### 21. Statistics Data Aggregation Pattern

**Description:** Pre-aggregates daily study metrics to avoid expensive queries during dashboard viewing.

**Key Features:**
- Daily aggregation of study metrics (new cards, reviews, retention, time spent)
- `DailyStats` SwiftData model for efficient querying
- Calculates retention rates and FSRS distributions
- Cache invalidation for stale metrics

**Rationale:** Avoids performance issues by pre-calculating and storing daily summaries.

**Usage:**
```swift
// StatisticsService.swift
@MainActor
class StatisticsService {
    func aggregateDailyStats(context: ModelContext) async throws -> Int {
        // Fetch completed sessions without daily stats
        let sessions = try context.fetch(FetchDescriptor<StudySession>())
            .filter { $0.endTime != nil && $0.dailyStats == nil }

        // Group by calendar day and create/update DailyStats
        for (day, daySessions) in sessionsByDay {
            let dailyStats = DailyStats(
                date: day,
                newCards: 0,
                studyTimeSeconds: daySessions.reduce(0) { $0 + $1.durationSeconds },
                retentionRate: calculateRetention(daySessions)
            )
            context.insert(dailyStats)
        }

        try context.save()
        return aggregatedCount
    }

    // Cache with 1-minute TTL
    func invalidateCache() {
        self.cachedMetrics = nil
        self.cacheTimestamp = nil
    }
}
```

### 22. Review History Filtering and Export Pattern

**Description:** View, filter, sort, and export `FlashcardReview` records.

**Key Features:**
- Dynamic filtering by date range, rating, card state, deck
- Sorting options (by review date, card name)
- CSV export functionality

**Rationale:** Provides users with insights into their learning process.

**Usage:**
```swift
// ReviewHistoryService.swift
@MainActor
class ReviewHistoryService {
    func fetchReviews(
        context: ModelContext,
        startDate: Date?,
        endDate: Date?,
        ratingFilter: Rating?,
        deckFilter: Deck?
    ) async throws -> [FlashcardReview] {
        // Build predicates dynamically
        let descriptor = FetchDescriptor<FlashcardReview>(
            predicate: finalPredicate,
            sortBy: [SortDescriptor(\.reviewDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func exportReviewsToCSV(_ reviews: [FlashcardReview]) -> String {
        // Generate CSV string
        return "card,rating,date,scheduledDays\n..."
    }
}
```

### 23. Gesture Sensitivity Configuration Pattern

**Description:** Users can customize swipe distance required to trigger review actions.

**Key Features:**
- AppSettings.swipeThreshold for user preference storage
- Dynamic gesture threshold adjustment
- Per-device sensitivity calibration

**Rationale:** Accommodates different user preferences and device interaction styles.

**Usage:**
```swift
// AppSettings.swift
enum AppSettings {
    static var swipeThreshold: CGFloat {
        get { UserDefaults.standard.double(forKey: "swipeThreshold", defaultValue: 50.0) }
        set { UserDefaults.standard.set(newValue, forKey: "swipeThreshold") }
    }
}

// Usage in gesture handling
let threshold = AppSettings.swipeThreshold
if abs(translation.width) > threshold {
    // Trigger action
}
```

## Project Structure

```
LexiconFlow/
├── App/                    # App entry point (@main)
├── Models/                 # SwiftData @Model classes
├── ViewModels/             # @MainActor coordinators (Scheduler)
├── Services/               # TranslationService, OnDeviceTranslationService, Analytics, DataImporter
├── Utils/                  # AppSettings, KeychainManager, FSRSWrapper, DateMath
├── Views/                  # SwiftUI views
│   ├── Cards/              # AddFlashcardView, StudySessionView
│   ├── Decks/              # DeckDetailView
│   └── Settings/           # TranslationSettingsView, AppearanceSettingsView, etc.
├── Assets.xcassets/        # Images, colors
└── LexiconFlowTests/       # Unit tests (72+ test files with comprehensive coverage)
```

## Concurrency Guidelines

- Swift 6 strict concurrency is enforced
- Use `actor` for thread-safe operations (FSRSWrapper)
- Use `@MainActor` for SwiftData model mutations (Scheduler)
- Return `Sendable` DTOs from actors, not models
- Never mutate `@Model` instances across actor boundaries

## Testing

- **Framework**: Swift Testing (`import Testing`)
- **Structure**: 72+ test files with comprehensive coverage in `LexiconFlowTests/`:
  - ModelTests, SchedulerTests, DataImporterTests
  - StudySessionViewModelTests, OnboardingTests, ErrorHandlingTests
  - FSRSWrapperTests, DateMathTests, AnalyticsTests
  - TranslationServiceTests (42 tests with concurrency stress tests)
  - **OnDeviceTranslationServiceTests** (44 tests for on-device translation)
  - **OnDeviceTranslationValidationTests** (26 tests for quality, offline, performance, edge cases)
  - AddFlashcardViewTests (23 tests for saveCard() flow)
  - KeychainManagerPersistenceTests (30 tests for UTF-8, persistence)
  - SettingsViewsTests (53 tests including on-device translation settings)
  - AppSettingsTests (updated with on-device translation settings)
  - EdgeCaseTests (40 tests for security, Unicode, input validation)
- **Pattern**: In-memory SwiftData container for isolation
- **Coverage Target**: >80% for new code
- **Test Execution**: Use `-parallel-testing-enabled NO` for shared container tests

## Code Quality Standards

### Force Unwrap Policy
- **NEVER** use force unwrap (`!`) in production code
- Use optional binding (`if let`, `guard let`) or nil coalescing (`??`)
- Exception: Static constants validated at init with `assert()`

**Examples:**
```swift
// ❌ AVOID: Force unwrap crashes on nil
let elapsedDays = flashcard.fsrsState!.lastReviewDate!

// ✅ CORRECT: Optional binding with map
let elapsedDays = flashcard.fsrsState?.lastReviewDate
    .map { DateMath.elapsedDays(since: $0) } ?? 0

// ✅ ACCEPTABLE: Static constant with assert
private static let apiURL: URL = {
    let urlString = "https://api.example.com"
    assert(URL(string: urlString) != nil, "Invalid URL: \(urlString)")
    return URL(string: urlString)!
}()
```

### FatalError Policy
- **NEVER** use `fatalError` in app initialization
- Use 3-tier graceful degradation: persistent → in-memory → minimal
- Always allow error UI to be shown to user

**Example:**
```swift
// ❌ AVOID: Crashes app on database error
fatalError("Could not create ModelContainer: \(error)")

// ✅ CORRECT: Graceful degradation
do {
    return try ModelContainer(for: schema, configurations: [config])
} catch {
    logger.critical("ModelContainer creation failed: \(error)")
    // Fallback to in-memory, then minimal app
    return try ModelContainer(for: [])
}
```

### Concurrency Best Practices
- Use `@MainActor` for all ViewModels
- Use `actor` for services with mutable state
- Return DTOs from actors, not SwiftData models
- Add rollback logic when state changes fail to persist

**Example:**
```swift
// ✅ CORRECT: Actor returns DTO
@MainActor
func processReview(flashcard: Flashcard, rating: Int) async throws {
    // Get DTO from actor
    let dto = try await FSRSWrapper.shared.processReview(
        flashcard: flashcard,
        rating: rating
    )

    // Apply updates on MainActor
    flashcard.fsrsState?.stability = dto.stability
    try modelContext.save()
}
```

### Magic Numbers
- Always document magic numbers with constants
- Use private enums for related constants
- Add Cambridge English references for CEFR thresholds

**Example:**
```swift
// ❌ AVOID: Undocumented magic number
if wordCount <= 8 { return "A1" }

// ✅ CORRECT: Documented constant with reference
private enum CEFRThresholds {
    /// Based on Cambridge English vocabulary guidelines
    /// A1: 500-1000 words (simple sentences, 8 words max)
    static let a1Max = 8
}

if wordCount <= CEFRThresholds.a1Max { return "A1" }
```

### Error Handling
- Always show errors to users with Analytics tracking
- Use typed errors with `isRetryable` property
- Implement exponential backoff for transient failures

**Example:**
```swift
// ✅ CORRECT: User-facing error with tracking
struct TranslationError: LocalizedError {
    var isRetryable: Bool = true
}

do {
    try await translate()
} catch {
    Analytics.trackError("translation_failed", error: error)
    errorMessage = error.localizedDescription
}
```

### Code Duplication
- Extract duplicate code into shared utilities
- Use generic functions for reusable patterns
- Prefer composition over copy-paste

**Shared Utilities Created:**
- `JSONExtractor.extract()` - Extracts JSON from markdown responses
- `RetryManager.executeWithRetry()` - Generic retry with exponential backoff
- `DateMath.elapsedDays()` - Timezone-aware date calculations

## Development Workflow

### Branch Strategy
```
main (protected)
  └── develop (integration)
    ├── feature/phase1-foundation
    ├── feature/phase2-liquid-ui
    ├── feature/phase3-intelligence
    └── feature/phase4-polish
```

### Commit Conventions
```
<type>(<scope>): <subject>

Types: feat, fix, refactor, test, docs, chore, perf

Example:
feat(models): add Flashcard model with SwiftData
```

## Documentation

Comprehensive documentation in `/docs/`:
- `ARCHITECTURE.md` - Technical architecture with code examples
- `ALGORITHM_SPECS.md` - FSRS v5 implementation details
- `WORKFLOW.md` - Git workflow and commit conventions
- `ROADMAP.md` - 16-week phased development plan

## Known Limitations

- On-device translation provides text-only translation (no CEFR levels or context sentences like cloud service)
- Language packs require 50-200MB per language (one-time download)
- SwiftData migration strategy: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for complete migration guidelines

## Common Pitfalls

1. **Circular relationships**: Define inverse on only ONE side
2. **Enum in predicates**: Use string literals instead of enum raw values
3. **Cross-actor mutations**: Return DTOs from actors, not models
4. **Date math**: Use `DateMath.elapsedDays()` for timezone-aware calculations
5. **Force unwraps**: Avoid `!` without proper validation
6. **fatalError in app init**: Use ModelContainer fallback pattern instead
7. **Direct @AppStorage**: Use AppSettings class for centralized state
8. **Silent error swallowing**: Always show errors to users with Analytics tracking
9. **Force view refresh**: Avoid UUID hacks, use proper @Observable state
10. **API key validation side effects**: Validate before storing to Keychain
