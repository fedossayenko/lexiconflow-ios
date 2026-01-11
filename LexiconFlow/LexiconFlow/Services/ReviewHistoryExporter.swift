//
//  ReviewHistoryExporter.swift
//  LexiconFlow
//
//  CSV export service for review history with proper escaping
//  Returns String for ShareLink integration with error tracking
//

import Foundation
import OSLog
import SwiftData

/// CSV export service for review history
///
/// **Architecture**: @MainActor service for safe access to SwiftData models.
/// **Output**: Returns CSV as String for use with SwiftUI ShareLink.
/// **Error Handling**: Analytics tracking for export failures.
///
/// **CSV Format**:
/// - Headers: Word,Definition,Rating,Review Date,Scheduled Days,Elapsed Days,State Change
/// - Proper RFC 4180 escaping: quotes, commas, newlines
/// - UTF-8 encoding for international characters
///
/// **Usage**:
/// ```swift
/// let exporter = ReviewHistoryExporter()
/// let csv = try await exporter.exportCSV(
///     reviews: reviews,
///     flashcard: flashcard
/// )
/// // Share with ShareLink(item: csv, preview: SharePreview("Review History"))
/// ```
@MainActor
final class ReviewHistoryExporter {
    /// Logger for export operations
    private static let logger = Logger(subsystem: "com.lexiconflow.exporter", category: "ReviewHistoryExport")

    // MARK: - Formatters

    /// Shared date formatter for CSV export (ISO 8601 format)
    ///
    /// **Why static**: DateFormatter is expensive to create (~10KB per instance).
    /// Using a single shared instance prevents memory accumulation when multiple
    /// exports occur simultaneously or when multiple views create exporters.
    ///
    /// **Thread safety**: DateFormatter is not thread-safe, but ReviewHistoryExporter
    /// is @MainActor isolated, so all access is serialized on the main thread.
    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    // MARK: - CSV Export

    /// Export review history as CSV string
    ///
    /// **CSV Format**: Follows RFC 4180 standard with proper escaping:
    /// - Fields containing commas, quotes, or newlines are wrapped in double quotes
    /// - Double quotes within fields are escaped by doubling ("")
    /// - CRLF line endings for Windows compatibility
    ///
    /// **Performance**: O(n) complexity, handles 100+ reviews efficiently.
    ///
    /// - Parameters:
    ///   - reviews: Array of FlashcardReview to export
    ///   - flashcard: The flashcard being exported (for word/definition)
    /// - Returns: CSV string ready for ShareLink
    /// - Throws: ExportError if encoding or formatting fails
    func exportCSV(
        _ reviews: [FlashcardReview],
        for flashcard: Flashcard
    ) async throws -> String {
        Self.logger.info("Starting CSV export for '\(flashcard.word)' with \(reviews.count) reviews")

        // Validate input
        guard !reviews.isEmpty else {
            Self.logger.warning("No reviews to export")
            throw ExportError.noReviews
        }

        // Build CSV rows
        var rows: [[String]] = []

        // Add header row
        rows.append([
            "Word",
            "Definition",
            "Rating",
            "Review Date",
            "Scheduled Days",
            "Elapsed Days",
            "State Change"
        ])

        // Add data rows
        for review in reviews {
            let row = self.buildRow(for: review, flashcard: flashcard)
            rows.append(row)
        }

        // Convert to CSV string
        let csv = rows.map { row in
            row.map { self.escapeCSVField($0) }.joined(separator: ",")
        }.joined(separator: "\r\n")

        // Validate output
        guard !csv.isEmpty else {
            Self.logger.error("CSV generation resulted in empty string")
            throw ExportError.emptyResult
        }

        Self.logger.info("CSV export complete: \(csv.utf8.count) bytes")

        Analytics.trackEvent("review_history_exported", metadata: [
            "flashcard_word": flashcard.word,
            "review_count": "\(reviews.count)",
            "csv_size_bytes": "\(csv.utf8.count)"
        ])

        return csv
    }

    /// Export filtered review history as CSV string
    ///
    /// **Why separate method**: Allows exporting with a time filter applied
    /// without modifying the original review array.
    ///
    /// - Parameters:
    ///   - reviews: Array of FlashcardReviewDTO to export
    ///   - flashcard: The flashcard being exported
    ///   - filter: The time filter applied (for analytics)
    /// - Returns: CSV string ready for ShareLink
    /// - Throws: ExportError if encoding or formatting fails
    func exportFilteredCSV(
        _ reviews: [FlashcardReviewDTO],
        for flashcard: Flashcard,
        filter: ReviewHistoryFilter
    ) async throws -> String {
        Self.logger.info("Starting filtered CSV export for '\(flashcard.word)' with \(reviews.count) reviews (filter: \(filter.rawValue))")

        guard !reviews.isEmpty else {
            Self.logger.warning("No reviews to export")
            throw ExportError.noReviews
        }

        var rows: [[String]] = []

        // Add header row
        rows.append([
            "Word",
            "Definition",
            "Rating",
            "Review Date",
            "Scheduled Days",
            "Elapsed Days",
            "State Change"
        ])

        // Add data rows from DTOs
        for dto in reviews {
            let row = self.buildRow(for: dto, flashcard: flashcard)
            rows.append(row)
        }

        let csv = rows.map { row in
            row.map { self.escapeCSVField($0) }.joined(separator: ",")
        }.joined(separator: "\r\n")

        guard !csv.isEmpty else {
            Self.logger.error("CSV generation resulted in empty string")
            throw ExportError.emptyResult
        }

        Self.logger.info("Filtered CSV export complete: \(csv.utf8.count) bytes")

        Analytics.trackEvent("review_history_exported_filtered", metadata: [
            "flashcard_word": flashcard.word,
            "filter_type": filter.rawValue,
            "review_count": "\(reviews.count)",
            "csv_size_bytes": "\(csv.utf8.count)"
        ])

        return csv
    }

    // MARK: - Row Building

    /// Build a CSV row for a FlashcardReview
    ///
    /// **Why separate method**: Encapsulates field mapping logic for reuse
    /// and easier testing.
    ///
    /// - Parameters:
    ///   - review: The review to convert
    ///   - flashcard: The associated flashcard
    /// - Returns: Array of string fields for CSV row
    private func buildRow(
        for review: FlashcardReview,
        flashcard: Flashcard
    ) -> [String] {
        let ratingLabel = CardRating.validate(review.rating).label

        // Format date as ISO 8601 for spreadsheet compatibility
        let dateString = Self.csvDateFormatter.string(from: review.reviewDate)

        // Format scheduled and elapsed days
        let scheduledDays = String(format: "%.2f", review.scheduledDays)
        let elapsedDays = String(format: "%.2f", review.elapsedDays)

        return [
            flashcard.word,
            flashcard.definition,
            ratingLabel,
            dateString,
            scheduledDays,
            elapsedDays,
            "" // State change not available in FlashcardReview model
        ]
    }

    /// Build a CSV row for a FlashcardReviewDTO
    ///
    /// **Why separate method**: DTO version includes state change information
    /// from the review history processing.
    ///
    /// - Parameters:
    ///   - dto: The DTO to convert
    ///   - flashcard: The associated flashcard
    /// - Returns: Array of string fields for CSV row
    private func buildRow(
        for dto: FlashcardReviewDTO,
        flashcard: Flashcard
    ) -> [String] {
        let ratingLabel = dto.ratingLabel
        let stateChange = dto.stateChangeBadge ?? ""

        // Format date as ISO 8601
        let dateString = Self.csvDateFormatter.string(from: dto.reviewDate)

        // Format scheduled and elapsed days
        let scheduledDays = String(format: "%.2f", dto.scheduledDays)
        let elapsedDays = String(format: "%.2f", dto.elapsedDays)

        return [
            flashcard.word,
            flashcard.definition,
            ratingLabel,
            dateString,
            scheduledDays,
            elapsedDays,
            stateChange
        ]
    }

    // MARK: - CSV Escaping

    /// Escape a field value according to RFC 4180 CSV standard
    ///
    /// **RFC 4180 Rules**:
    /// - Fields containing commas, double quotes, or newlines must be wrapped in double quotes
    /// - Double quotes within fields are escaped by doubling ("" -> "")
    ///
    /// **Examples**:
    /// - "hello" → "hello"
    /// - "hello, world" → "\"hello, world\""
    /// - "say \"hi\"" → "\"say \"\"hi\"\"\""
    ///
    /// - Parameter field: The field value to escape
    /// - Returns: Properly escaped CSV field value
    private func escapeCSVField(_ field: String) -> String {
        // Check if field needs escaping
        let needsEscaping = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")

        guard needsEscaping else {
            return field
        }

        // Escape double quotes by doubling them
        let escapedQuotes = field.replacingOccurrences(of: "\"", with: "\"\"")

        // Wrap in double quotes
        return "\"\(escapedQuotes)\""
    }

    /// Generate filename for CSV export
    ///
    /// **Format**: `{word}_review_history_{timestamp}.csv`
    /// **Sanitization**: Replaces spaces with underscores, removes invalid characters
    ///
    /// - Parameter flashcard: The flashcard being exported
    /// - Returns: Filename safe for file system
    func generateFilename(for flashcard: Flashcard) -> String {
        // Sanitize word for filename
        var sanitized = flashcard.word
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

        // Limit length
        if sanitized.count > 50 {
            sanitized = String(sanitized.prefix(50))
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        return "\(sanitized)_review_history_\(timestamp).csv"
    }
}

// MARK: - Export Errors

/// Errors that can occur during CSV export
enum ExportError: LocalizedError {
    /// No reviews provided for export
    case noReviews

    /// CSV generation resulted in empty string
    case emptyResult

    /// Encoding failure for special characters
    case encodingError(String)

    var errorDescription: String? {
        switch self {
        case .noReviews:
            "No reviews to export"
        case .emptyResult:
            "Failed to generate CSV data"
        case let .encodingError(details):
            "Encoding error: \(details)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noReviews:
            false
        case .emptyResult:
            true
        case .encodingError:
            true
        }
    }
}
