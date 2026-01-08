//
//  AppSettingsDeckSelectionTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for deck selection JSON encoding/decoding
//  Tests: encoding/decoding, invalid UUIDs, malformed JSON, concurrency
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for AppSettings deck selection JSON parsing
@MainActor
@Suite("AppSettings Deck Selection Tests")
struct AppSettingsDeckSelectionTests {
    /// Helper to reset deck selection before each test
    private func resetDeckSelection() {
        AppSettings.selectedDeckIDs = []
    }

    // MARK: - Encoding/Decoding Tests

    @Test("Encoding and decoding preserves all deck IDs")
    func roundTripEncoding() throws {
        resetDeckSelection()

        let originalIDs: Set<UUID> = [
            UUID(),
            UUID(),
            UUID(),
            UUID(),
            UUID()
        ]

        // Set the IDs
        AppSettings.selectedDeckIDs = originalIDs

        // Read them back
        let retrievedIDs = AppSettings.selectedDeckIDs

        // Verify all IDs are preserved
        #expect(retrievedIDs.count == originalIDs.count, "Should preserve all \(originalIDs.count) IDs")
        #expect(retrievedIDs == originalIDs, "Round-trip should preserve exact UUIDs")
    }

    @Test("Empty array encodes and decodes correctly")
    func emptyArrayHandling() throws {
        resetDeckSelection()

        // Set empty set
        AppSettings.selectedDeckIDs = []

        // Verify
        #expect(AppSettings.selectedDeckIDs.isEmpty, "Empty set should remain empty")
        #expect(AppSettings.selectedDeckCount == 0, "Count should be 0")
        #expect(!AppSettings.hasSelectedDecks, "hasSelectedDecks should be false")
    }

    @Test("Single deck ID encodes correctly")
    func singleDeckID() throws {
        resetDeckSelection()

        let singleID = UUID()
        AppSettings.selectedDeckIDs = [singleID]

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.count == 1, "Should have exactly 1 ID")
        #expect(retrieved.first == singleID, "ID should match original")
    }

    // MARK: - Invalid UUID Tests

    @Test("Invalid UUID strings are filtered out")
    func filtersInvalidUUIDs() throws {
        resetDeckSelection()

        // Create valid UUIDs
        let validID1 = UUID()
        let validID2 = UUID()

        // Manually construct JSON with some invalid UUIDs
        let validUUIDs = [validID1.uuidString, validID2.uuidString]
        let invalidUUIDs = ["not-a-uuid", "12345678-1234-1234-1234-123456789XYZ", ""]
        let allStrings = validUUIDs + invalidUUIDs

        // Encode to JSON
        let jsonData = try JSONEncoder().encode(allStrings)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw TestError.encodingFailed
        }

        // Set the raw JSON data
        AppSettings.selectedDeckIDsData = jsonString

        // Read back - should only contain valid UUIDs
        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.count == 2, "Should filter out invalid UUIDs, keeping only 2 valid ones")
        #expect(retrieved.contains(validID1), "Should contain first valid UUID")
        #expect(retrieved.contains(validID2), "Should contain second valid UUID")
    }

    @Test("Completely invalid JSON returns empty set")
    func completelyInvalidJSON() throws {
        resetDeckSelection()

        // Set completely invalid JSON
        AppSettings.selectedDeckIDsData = "this is not json {]"

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.isEmpty, "Invalid JSON should return empty set")
        #expect(AppSettings.selectedDeckCount == 0, "Count should be 0")
    }

    @Test("Malformed JSON array returns empty set")
    func malformedJSONArray() throws {
        resetDeckSelection()

        // Set malformed JSON (missing closing bracket)
        AppSettings.selectedDeckIDsData = "[\"550e8400-e29b-41d4-a716-446655440000\""

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.isEmpty, "Malformed JSON should return empty set")
    }

    @Test("Non-array JSON returns empty set")
    func nonArrayJSON() throws {
        resetDeckSelection()

        // Set JSON object instead of array
        AppSettings.selectedDeckIDsData = "{\"key\": \"value\"}"

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.isEmpty, "Non-array JSON should return empty set")
    }

    @Test("JSON with non-string elements returns empty set")
    func nonStringElements() throws {
        resetDeckSelection()

        // Set JSON array with numbers instead of strings
        AppSettings.selectedDeckIDsData = "[123, 456, 789]"

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.isEmpty, "Array with non-string elements should return empty set")
    }

    // MARK: - Edge Cases

    @Test("Very long deck ID list is handled correctly")
    func veryLongDeckIDList() throws {
        resetDeckSelection()

        // Create 100 deck IDs
        let manyIDs = Set((0 ..< 100).map { _ in UUID() })
        AppSettings.selectedDeckIDs = manyIDs

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.count == 100, "Should handle 100 deck IDs")
        #expect(retrieved == manyIDs, "All IDs should be preserved")
    }

    @Test("Duplicate UUIDs are handled correctly")
    func duplicateUUIDs() throws {
        resetDeckSelection()

        let singleID = UUID()

        // Manually set JSON with duplicate UUIDs
        let duplicates = [singleID.uuidString, singleID.uuidString, singleID.uuidString]
        let jsonData = try JSONEncoder().encode(duplicates)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw TestError.encodingFailed
        }

        AppSettings.selectedDeckIDsData = jsonString

        let retrieved = AppSettings.selectedDeckIDs

        // Set should automatically deduplicate
        #expect(retrieved.count == 1, "Set should deduplicate to 1 element")
        #expect(retrieved.first == singleID, "Should contain the UUID")
    }

    @Test("Whitespace in JSON is handled correctly")
    func whitespaceInJSON() throws {
        resetDeckSelection()

        let validID = UUID()

        // JSON with extra whitespace
        AppSettings.selectedDeckIDsData = "[  \"\(validID.uuidString)\"  ]"

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.count == 1, "Should handle JSON with whitespace")
        #expect(retrieved.first == validID, "Should parse UUID correctly")
    }

    // MARK: - Persistence Tests

    @Test("Changes persist through UserDefaults")
    func persistsThroughUserDefaults() throws {
        resetDeckSelection()

        let originalIDs: Set<UUID> = [UUID(), UUID()]
        AppSettings.selectedDeckIDs = originalIDs

        // Simulate app restart by reading fresh
        let freshRead = AppSettings.selectedDeckIDs

        #expect(freshRead == originalIDs, "IDs should persist through UserDefaults")
    }

    // MARK: - Computed Properties Tests

    @Test("hasSelectedDecks is true when decks are selected")
    func hasSelectedDecksTrue() throws {
        resetDeckSelection()

        AppSettings.selectedDeckIDs = [UUID()]

        #expect(AppSettings.hasSelectedDecks, "hasSelectedDecks should be true")
    }

    @Test("hasSelectedDecks is false when no decks selected")
    func hasSelectedDecksFalse() throws {
        resetDeckSelection()

        #expect(!AppSettings.hasSelectedDecks, "hasSelectedDecks should be false")
    }

    @Test("selectedDeckCount returns correct count")
    func selectedDeckCount() throws {
        resetDeckSelection()

        AppSettings.selectedDeckIDs = [
            UUID(),
            UUID(),
            UUID()
        ]

        #expect(AppSettings.selectedDeckCount == 3, "Count should be 3")
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent reads are thread-safe")
    func concurrentReads() async throws {
        resetDeckSelection()

        let ids = Set((0 ..< 10).map { _ in UUID() })
        AppSettings.selectedDeckIDs = ids

        // Perform concurrent reads from MainActor
        await withTaskGroup(of: Set<UUID>.self) { group in
            for _ in 0 ..< 10 {
                group.addTask { @MainActor in
                    return AppSettings.selectedDeckIDs
                }
            }

            var allResults: [Set<UUID>] = []
            for await result in group {
                allResults.append(result)
            }

            // All reads should return the same data
            for result in allResults {
                #expect(result == ids, "Concurrent reads should return consistent data")
            }
        }
    }

    @Test("Concurrent writes are serialised correctly")
    func concurrentWrites() async throws {
        resetDeckSelection()

        // Perform concurrent writes to MainActor-isolated property
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask { @MainActor in
                    let id = UUID()
                    AppSettings.selectedDeckIDs = [id]
                }
            }
        }

        // After all writes, we should have exactly one ID
        #expect(AppSettings.selectedDeckIDs.count == 1, "After concurrent writes, should have 1 ID")
    }

    // MARK: - Special Characters Tests

    @Test("UUIDs with different versions are handled correctly")
    func differentUUIDVersions() throws {
        resetDeckSelection()

        // Create UUIDs with different versions (all valid)
        let uuid1 = UUID(uuidString: "00000000-0000-1000-8000-000000000001")! // v1
        let uuid2 = UUID(uuidString: "00000000-0000-2000-8000-000000000002")! // v2
        let uuid3 = UUID(uuidString: "00000000-0000-3000-8000-000000000003")! // v3
        let uuid4 = UUID(uuidString: "00000000-0000-4000-8000-000000000004")! // v4

        AppSettings.selectedDeckIDs = [uuid1, uuid2, uuid3, uuid4]

        let retrieved = AppSettings.selectedDeckIDs

        #expect(retrieved.count == 4, "Should handle all UUID versions")
        #expect(retrieved.contains(uuid1), "Should contain v1 UUID")
        #expect(retrieved.contains(uuid2), "Should contain v2 UUID")
        #expect(retrieved.contains(uuid3), "Should contain v3 UUID")
        #expect(retrieved.contains(uuid4), "Should contain v4 UUID")
    }

    // MARK: - Error Types

    enum TestError: Error {
        case encodingFailed
    }
}
