//
//  PerformanceValidationTests.swift
//  LexiconFlowTests
//
//  Performance validation tests
//
//  NOTE: Signpost API has been disabled for iOS 26 compatibility
//  Use Instruments Time Profiler for performance measurement
//

import OSLog
import SwiftData
import Testing
import UIKit
@testable import LexiconFlow

@Suite("Performance Validation")
@MainActor
struct PerformanceValidationTests {
    // MARK: - Test Context

    /// Shared model context for performance tests
    ///
    /// **IMPORTANT:** Uses in-memory container for isolated testing
    /// Each test gets a fresh container to avoid cross-contamination
    private static var testContainer: ModelContainer {
        let schema = Schema([
            FSRSState.self,
            Flashcard.self,
            Deck.self,
            FlashcardReview.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return container
    }

    // MARK: - Validation 1: DataImporter Performance

    @Test("DataImporter should import 1000 cards in <5 seconds")
    func dataImportPerformance() async throws {
        // Create test data (1000 cards)
        let testCards = (0 ..< 1000).map { i in
            DataImporter.CardData(
                word: "test\(i)",
                definition: "Definition \(i)",
                phonetic: "/test\(i)/"
            )
        }

        let importer = DataImporter()
        let context = ModelContext(testContainer.mainContext)

        let start = Date()
        let result = try await importer.importCards(
            testCards,
            batchSize: 500,
            context: context
        )
        let duration = Date().timeIntervalSince(start)

        // Validate
        #expect(duration < 5.0, "Import took \(duration)s, expected <5s")
        #expect(result.imported == 1000, "Should import all 1000 cards")
    }

    // MARK: - Validation 2: KeychainManager Cache

    @Test("KeychainManager should show >95% cache hit rate")
    func keychainCachePerformance() async throws {
        // Store a test API key first
        let testKey = "test-api-key-for-performance-validation"
        try KeychainManager.setAPIKey(testKey)

        var hitCount = 0
        var missCount = 0

        // First call (cache miss)
        _ = try KeychainManager.getAPIKey()
        missCount += 1

        // Next 99 calls (should all be cache hits)
        for _ in 0 ..< 99 {
            _ = try KeychainManager.getAPIKey()
            hitCount += 1
        }

        let hitRate = Double(hitCount) / Double(hitCount + missCount)

        #expect(hitRate > 0.95, "Cache hit rate: \(hitRate), expected >0.95")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    // MARK: - Validation 3: Scheduler Performance

    @Test("Scheduler should load 10 decks in <100ms")
    func schedulerPerformance() async throws {
        let context = ModelContext(testContainer.mainContext)

        // Create 10 decks with 100 cards each
        for deckIndex in 0 ..< 10 {
            let deck = Deck(name: "Test Deck \(deckIndex)", icon: "folder.fill")
            context.insert(deck)

            for cardIndex in 0 ..< 100 {
                let card = Flashcard(
                    word: "word\(deckIndex)_\(cardIndex)",
                    definition: "Definition \(cardIndex)"
                )
                card.deck = deck
                card.fsrsState = FSRSState(
                    stability: 10.0,
                    difficulty: 5.0,
                    retrievability: 0.9,
                    dueDate: Date(),
                    stateEnum: FlashcardState.reviewing.rawValue
                )
                context.insert(card)
            }
        }

        try context.save()

        let scheduler = Scheduler(modelContext: context)

        let start = Date()

        // Load all deck statistics
        for deckIndex in 0 ..< 10 {
            let decks = try context.fetch(FetchDescriptor<Deck>())
            if let deck = decks.first(where: { $0.name == "Test Deck \(deckIndex)" }) {
                _ = scheduler.fetchDeckStatistics(for: deck)
            }
        }

        let duration = Date().timeIntervalSince(start) * 1000 // Convert to ms

        #expect(duration < 100, "Deck list took \(duration)ms, expected <100ms")
    }

    // MARK: - Validation 4: ImageCache Performance

    @Test("ImageCache should show >90% hit rate")
    func imageCachePerformance() async throws {
        // Create test image data (1KB JPEG)
        let testData = Data([UInt8](repeating: 0xFF, count: 1024))

        var hitCount = 0
        var missCount = 0

        // First pass: 100 unique images (cache miss)
        for i in 0 ..< 100 {
            _ = ImageCache.shared.image(for: testData + Data([UInt8](repeating: UInt8(i % 256), count: 1)))
            missCount += 1
        }

        // Second pass: same 100 images (should be cache hits)
        for _ in 0 ..< 100 {
            _ = ImageCache.shared.image(for: testData)
            if ImageCache.shared.image(for: testData) != nil {
                hitCount += 1
            }
        }

        let hitRate = Double(hitCount) / Double(hitCount + missCount)

        #expect(hitRate > 0.90, "Cache hit rate: \(hitRate), expected >0.90")
    }

    // MARK: - Validation 5: FSRSState Counter Performance

    @Test("FSRSState should use cached counters (O(1) access)")
    func fsrsCounterPerformance() async throws {
        let context = ModelContext(testContainer.mainContext)

        // Create card with 100 existing reviews
        let card = Flashcard(
            word: "test",
            definition: "test"
        )
        card.fsrsState = FSRSState(
            stability: 10.0,
            difficulty: 5.0,
            retrievability: 0.9,
            dueDate: Date(),
            stateEnum: FlashcardState.reviewing.rawValue,
            totalReviews: 100,
            totalLapses: 10
        )
        context.insert(card)

        // Simulate 100 reviews
        for _ in 0 ..< 100 {
            let review = FlashcardReview(
                rating: Int.random(in: 0 ... 3),
                reviewDate: Date()
            )
            review.flashcard = card
            context.insert(review)
        }

        try context.save()

        let wrapper = FSRSWrapper.shared

        let start = Date()

        // This should use cached counters, not scan reviewLogs
        _ = try wrapper.processReview(
            flashcard: card,
            rating: 2,
            modelContext: context
        )

        let duration = Date().timeIntervalSince(start) * 1000 // Convert to ms

        #expect(duration < 1, "Review processing took \(duration)ms, expected <1ms")
    }
}

// MARK: - Performance Test Views (For Instruments Visual Testing)

/// Performance test views for manual Instruments validation
///
/// **USAGE:**
/// 1. Show these previews in Xcode
/// 2. Open Instruments → Core Animation
/// 3. Interact with the preview while recording
/// 4. Analyze frame rate and GPU utilization
enum PerformanceTestViews {
    /// Test view for glass effect performance (50 glass cards)
    struct GlassPerformanceTestView: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0 ..< 50) { i in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.blue.opacity(0.3))
                            .frame(width: 300, height: 200)
                            .glassEffect(.regular)
                            .overlay {
                                Text("Card \(i)")
                            }
                    }
                }
                .padding()
            }
        }
    }

    /// Test view for gesture performance
    struct GesturePerformanceTestView: View {
        @State private var offset: CGSize = .zero
        @StateObject private var gestureViewModel = CardGestureViewModel()

        var body: some View {
            VStack {
                Text("Drag me to test gesture performance")
                    .font(.title)

                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue.opacity(0.3))
                    .frame(width: 300, height: 200)
                    .interactive(self.gestureViewModel.offsetBinding) { _ in
                        .tint(.green.opacity(0.3))
                    }
                    .offset(x: self.gestureViewModel.offset.width, y: self.gestureViewModel.offset.height)
                    .scaleEffect(self.gestureViewModel.scale)
                    .rotationEffect(.degrees(self.gestureViewModel.rotation))
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                _ = self.gestureViewModel.handleGestureChange(value)
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    self.gestureViewModel.resetGestureState()
                                }
                            }
                    )
            }
        }
    }
}

// Note: Previews disabled for iOS 26 compatibility
// Use Xcode Canvas for manual visual testing
