//
//  ReviewHistoryExporterTests.swift
//  LexiconFlowTests
//
//  Tests for CSV export service for review history
//  Covers: CSV format validation, special character escaping, error handling
//

import Testing
import Foundation
import SwiftData
@testable import LexiconFlow

/// Test suite for ReviewHistoryExporter
@MainActor
struct ReviewHistoryExporterTests {

    /// Get a fresh isolated context for testing
    private func freshContext() -> ModelContext {
        return TestContainers.freshContext()
    }

    // MARK: - CSV Export Tests

    @Test("Export single review as CSV")
    func exportSingleReview() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "A test word")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 3.0,
            elapsedDays: 2.5
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Verify CSV is not empty
        #expect(!csv.isEmpty, "CSV should not be empty")

        // Verify header row
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count >= 2, "CSV should have header and at least one data row")

        let header = lines[0]
        #expect(header.contains("Word"), "Header should contain Word column")
        #expect(header.contains("Rating"), "Header should contain Rating column")
        #expect(header.contains("Review Date"), "Header should contain Review Date column")

        // Verify data row contains expected values
        let dataRow = lines[1]
        #expect(dataRow.contains("test"), "Data row should contain word")
        #expect(dataRow.contains("Good"), "Data row should contain rating label")
    }

    @Test("Export multiple reviews as CSV")
    func exportMultipleReviews() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "hola", definition: "Hello in Spanish")
        context.insert(flashcard)

        var reviews: [FlashcardReview] = []

        // Create three reviews with different ratings
        for rating in [0, 2, 3] {
            let review = FlashcardReview(
                rating: rating,
                scheduledDays: Double(rating + 1),
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
            reviews.append(review)

            // Small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV(reviews, for: flashcard)

        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count == 4, "CSV should have header + 3 data rows")

        // Verify all ratings are present
        #expect(csv.contains("Again"), "Should contain Again rating")
        #expect(csv.contains("Good"), "Should contain Good rating")
        #expect(csv.contains("Easy"), "Should contain Easy rating")
    }

    @Test("Export with empty review array throws error")
    func exportEmptyReviews() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let exporter = ReviewHistoryExporter()
        do {
            try await exporter.exportCSV([], for: flashcard)
            #expect(Bool(false), "Should have thrown ExportError")
        } catch is ExportError {
            // Expected error
        }
    }

    // MARK: - Special Character Escaping Tests

    @Test("Escape commas in field values")
    func escapeCommas() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "This is a definition, with commas, in it"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Fields with commas should be wrapped in quotes
        #expect(csv.contains("\""), "CSV should contain quotes for fields with commas")
        // Verify the definition is properly escaped
        #expect(csv.contains("\"This is a definition, with commas, in it\""))
    }

    @Test("Escape quotes in field values")
    func escapeQuotes() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "This is a \"quoted\" word"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Quotes should be escaped by doubling ("")
        #expect(csv.contains("\"\"quoted\"\""), "Quotes should be doubled for escaping")
    }

    @Test("Escape newlines in field values")
    func escapeNewlines() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "Line 1\nLine 2\nLine 3"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Fields with newlines should be wrapped in quotes
        #expect(csv.contains("\""), "CSV should contain quotes for fields with newlines")
    }

    @Test("Handle mixed special characters")
    func mixedSpecialCharacters() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "test",
            definition: "Has \"quotes\", commas, and\nnewlines"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Should handle all special characters
        #expect(csv.contains("\""), "Should contain quotes")
        #expect(csv.contains("\"\"quotes\"\""), "Should escape quotes")
    }

    // MARK: - Unicode and Internationalization Tests

    @Test("Handle Unicode characters in word")
    func unicodeCharacters() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "日本語",
            definition: "Japanese language"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Unicode characters should be preserved
        #expect(csv.contains("日本語"), "Unicode characters should be preserved")
    }

    @Test("Handle emoji characters")
    func emojiCharacters() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "celebration 🎉",
            definition: "A festive event 🎊"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 3,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // Emoji should be preserved
        #expect(csv.contains("🎉"), "Emoji should be preserved")
        #expect(csv.contains("🎊"), "Emoji should be preserved")
    }

    @Test("Handle RTL languages")
    func rightToLeftLanguages() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(
            word: "مرحبا",
            definition: "Hello in Arabic"
        )
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // RTL text should be preserved
        #expect(csv.contains("مرحبا"), "RTL text should be preserved")
    }

    // MARK: - DTO Export Tests

    @Test("Export DTOs with state changes")
    func exportDTOsStateChanges() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 3.0,
            elapsedDays: 2.5
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        // Create DTO with state change
        let dto = FlashcardReviewDTO(
            id: review.id,
            rating: review.rating,
            reviewDate: review.reviewDate,
            scheduledDays: review.scheduledDays,
            elapsedDays: review.elapsedDays,
            stateChange: .graduated
        )

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportFilteredCSV([dto], for: flashcard, filter: .allTime)

        // Verify state change is included
        #expect(csv.contains("Graduated"), "CSV should contain state change")
    }

    @Test("Export DTOs with first review")
    func exportDTOsFirstReview() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        // Create DTO with first review state
        let dto = FlashcardReviewDTO(
            id: review.id,
            rating: review.rating,
            reviewDate: review.reviewDate,
            scheduledDays: review.scheduledDays,
            elapsedDays: review.elapsedDays,
            stateChange: .firstReview
        )

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportFilteredCSV([dto], for: flashcard, filter: .allTime)

        // Verify first review is included
        #expect(csv.contains("First Review"), "CSV should contain first review marker")
    }

    @Test("Export DTOs with relearning state")
    func exportDTOsRelearning() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 0,
            scheduledDays: 0,
            elapsedDays: 5.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        // Create DTO with relearning state
        let dto = FlashcardReviewDTO(
            id: review.id,
            rating: review.rating,
            reviewDate: review.reviewDate,
            scheduledDays: review.scheduledDays,
            elapsedDays: review.elapsedDays,
            stateChange: .relearning
        )

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportFilteredCSV([dto], for: flashcard, filter: .allTime)

        // Verify relearning is included
        #expect(csv.contains("Relearning"), "CSV should contain relearning marker")
    }

    // MARK: - Filename Generation Tests

    @Test("Generate filename for normal word")
    func generateNormalFilename() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let exporter = ReviewHistoryExporter()
        let filename = exporter.generateFilename(for: flashcard)

        #expect(filename.contains("test"), "Filename should contain word")
        #expect(filename.hasSuffix(".csv"), "Filename should end with .csv")
        #expect(filename.contains("review_history"), "Filename should contain review_history")
    }

    @Test("Generate filename sanitizes spaces")
    func sanitizeSpacesInFilename() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "hello world", definition: "test")
        context.insert(flashcard)

        let exporter = ReviewHistoryExporter()
        let filename = exporter.generateFilename(for: flashcard)

        // Spaces should be replaced with underscores
        #expect(filename.contains("hello_world"), "Spaces should be replaced with underscores")
        #expect(!filename.contains(" "), "Filename should not contain spaces")
    }

    @Test("Generate filename sanitizes special characters")
    func sanitizeSpecialCharsInFilename() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test/word", definition: "test")
        context.insert(flashcard)

        let exporter = ReviewHistoryExporter()
        let filename = exporter.generateFilename(for: flashcard)

        // Forward slashes should be replaced with dashes
        #expect(filename.contains("test-word"), "Slashes should be replaced with dashes")
        #expect(!filename.contains("/"), "Filename should not contain slashes")
    }

    @Test("Generate filename limits length")
    func limitFilenameLength() async throws {
        let context = freshContext()
        try context.clearAll()

        let longWord = String(repeating: "a", count: 100)
        let flashcard = Flashcard(word: longWord, definition: "test")
        context.insert(flashcard)

        let exporter = ReviewHistoryExporter()
        let filename = exporter.generateFilename(for: flashcard)

        // Extract just the word part (before "review_history")
        let wordPart = filename.components(separatedBy: "_review_history_")[0]

        #expect(wordPart.count <= 50, "Word part should be limited to 50 characters")
    }

    // MARK: - Date Format Tests

    @Test("Date formatting uses ISO 8601")
    func dateFormatting() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let reviewDate = Date()
        let review = FlashcardReview(
            rating: 2,
            reviewDate: reviewDate,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // ISO 8601 format contains 'T' between date and time
        #expect(csv.contains("T"), "Date should be in ISO 8601 format with 'T' separator")
    }

    // MARK: - Rating Label Tests

    @Test("All rating labels are exported")
    func allRatingLabels() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        var reviews: [FlashcardReview] = []

        for rating in [0, 1, 2, 3] {
            let review = FlashcardReview(
                rating: rating,
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
            reviews.append(review)

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV(reviews, for: flashcard)

        #expect(csv.contains("Again"), "Should contain Again label")
        #expect(csv.contains("Hard"), "Should contain Hard label")
        #expect(csv.contains("Good"), "Should contain Good label")
        #expect(csv.contains("Easy"), "Should contain Easy label")
    }

    // MARK: - Performance Tests

    @Test("Export performance with 100 reviews")
    func exportPerformance() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        var reviews: [FlashcardReview] = []

        // Create 100 reviews
        for _ in 0..<100 {
            let review = FlashcardReview(
                rating: 2,
                scheduledDays: 1.0,
                elapsedDays: 1.0
            )
            review.card = flashcard
            context.insert(review)
            reviews.append(review)
        }

        try context.save()

        let exporter = ReviewHistoryExporter()
        let startTime = Date()
        let csv = try await exporter.exportCSV(reviews, for: flashcard)
        let duration = Date().timeIntervalSince(startTime)

        // Should complete in reasonable time (< 1 second)
        #expect(duration < 1.0, "Export should complete in < 1 second")
        #expect(!csv.isEmpty, "CSV should not be empty")

        // Should have 101 lines (header + 100 data rows)
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count == 101, "Should have header + 100 data rows")
    }

    // MARK: - Error Handling Tests

    @Test("ExportError.noReviews has correct description")
    func noReviewsErrorDescription() {
        let error = ExportError.noReviews
        #expect(error.errorDescription == "No reviews to export")
    }

    @Test("ExportError.emptyResult has correct description")
    func emptyResultErrorDescription() {
        let error = ExportError.emptyResult
        #expect(error.errorDescription == "Failed to generate CSV data")
    }

    @Test("ExportError.encodingError has correct description")
    func encodingErrorDescription() {
        let error = ExportError.encodingError("test error")
        #expect(error.errorDescription == "Encoding error: test error")
    }

    @Test("ExportError retryable property")
    func errorRetryableProperty() {
        #expect(ExportError.noReviews.isRetryable == false)
        #expect(ExportError.emptyResult.isRetryable == true)
        #expect(ExportError.encodingError("test").isRetryable == true)
    }

    // MARK: - CSV Format Validation Tests

    @Test("CSV follows RFC 4180 format")
    func csvFormatValidation() async throws {
        let context = freshContext()
        try context.clearAll()

        let flashcard = Flashcard(word: "test", definition: "test")
        context.insert(flashcard)

        let review = FlashcardReview(
            rating: 2,
            scheduledDays: 1.0,
            elapsedDays: 1.0
        )
        review.card = flashcard
        context.insert(review)
        try context.save()

        let exporter = ReviewHistoryExporter()
        let csv = try await exporter.exportCSV([review], for: flashcard)

        // RFC 4180: CRLF line endings
        #expect(csv.contains("\r\n"), "CSV should use CRLF line endings")

        // RFC 4180: Header row present
        let firstLine = csv.components(separatedBy: "\r\n").first ?? ""
        #expect(!firstLine.isEmpty, "First line (header) should not be empty")

        // RFC 4180: Same number of fields in each row
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        let fieldCounts = lines.map { $0.components(separatedBy: ",").count }
        let allSameCount = Set(fieldCounts).count == 1
        #expect(allSameCount, "All rows should have the same number of fields")
    }
}
