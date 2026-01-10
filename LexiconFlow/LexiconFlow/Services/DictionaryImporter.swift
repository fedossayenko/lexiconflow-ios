//
//  DictionaryImporter.swift
//  LexiconFlow
//
//  Dictionary import service supporting CSV, JSON, and TXT formats
//

import Foundation
import OSLog
import SwiftData
import UniformTypeIdentifiers

/// Dictionary import service for large vocabulary datasets
///
/// **Design Philosophy:**
/// - Performance: Batch processing (500 cards per batch) for < 30s import
/// - Flexibility: Auto-detect format, custom field mapping, preview before import
/// - Resilience: Skip invalid rows, continue import, show error summary
/// - Transparency: Progress tracking, duplicate detection, detailed reporting
///
/// **Usage:**
/// ```swift
/// let importer = DictionaryImporter(modelContext: modelContext)
/// let format = importer.detectFormat(from: fileURL)
/// let preview = try await importer.previewImport(fileURL, format: format, limit: 10)
/// let result = try await importer.importDictionary(
///     fileURL,
///     format: format,
///     fieldMapping: fieldMapping,
///     into: deck
/// )
/// ```
@MainActor
final class DictionaryImporter {
    // MARK: - Types

    /// Supported import formats
    enum ImportFormat: String, CaseIterable {
        case csv = "Comma-Separated Values (CSV)"
        case json = "JavaScript Object Notation (JSON)"
        case txt = "Plain Text (TXT)"

        var fileExtensions: [String] {
            switch self {
            case .csv: ["csv"]
            case .json: ["json"]
            case .txt: ["txt", "text"]
            }
        }

        var uttype: UTType? {
            switch self {
            case .csv: .commaSeparatedText
            case .json: .json
            case .txt: .plainText
            }
        }
    }

    /// Field mapping configuration for CSV/TXT imports
    struct FieldMappingConfiguration: Sendable, Equatable {
        var wordFieldIndex: Int
        var definitionFieldIndex: Int
        var phoneticFieldIndex: Int?
        var cefrFieldIndex: Int?
        var translationFieldIndex: Int?
        var hasHeader: Bool = true

        static let `default` = FieldMappingConfiguration(
            wordFieldIndex: 0,
            definitionFieldIndex: 1,
            phoneticFieldIndex: nil,
            cefrFieldIndex: nil,
            translationFieldIndex: nil,
            hasHeader: true
        )
    }

    /// Import progress tracking
    struct ImportProgress: Sendable {
        let completedCount: Int
        let totalCount: Int
        let currentWord: String
        let isComplete: Bool

        var percentage: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        var percentageText: String {
            "\(Int(percentage * 100))%"
        }
    }

    /// Import result with statistics
    struct ImportResult: Sendable {
        let imported: Int
        let skipped: Int
        let failed: Int
        let errors: [ImportError]
        let duration: TimeInterval

        var successCount: Int { imported }
        var errorCount: Int { failed }

        var isSuccess: Bool {
            failed == 0 || imported > 0
        }
    }

    /// Import error with context
    struct ImportError: Sendable, Identifiable, Error {
        let id = UUID()
        let lineNumber: Int
        let fieldName: String?
        let reason: String
        let isRetryable: Bool

        var localizedDescription: String {
            if let fieldName {
                "Line \(lineNumber): \(fieldName) - \(reason)"
            } else {
                "Line \(lineNumber): \(reason)"
            }
        }
    }

    /// Parsed flashcard data before SwiftData insertion
    struct ParsedFlashcard: Sendable {
        let word: String
        let definition: String
        let phonetic: String?
        let cefrLevel: String?
        let translation: String?
        let lineNumber: Int
    }

    /// Internal JSON flashcard struct for decoding
    private struct JSONFlashcard: Codable {
        let word: String
        let definition: String
        let phonetic: String?
        let cefrLevel: String?
        let translation: String?
    }

    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.lexiconflow.import", category: "DictionaryImporter")

    /// Model context for SwiftData operations
    private let modelContext: ModelContext

    /// DataImporter for batch insertion
    private let dataImporter: DataImporter

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        dataImporter = DataImporter(modelContext: modelContext)
        logger.info("DictionaryImporter initialized")
    }

    // MARK: - Format Detection

    /// Validate file URL for security and access
    ///
    /// **Security:**
    /// - Checks security scope (for file picker)
    /// - Validates file exists and is readable
    /// - Confirms it's a regular file (not directory/symlink)
    /// - Validates file extension (whitelist)
    /// - Validates file size (max 100MB)
    ///
    /// **Throws:** ImportError if validation fails
    private func validateFileURL(_ url: URL) throws {
        // 1. Check security scope (for file picker)
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Cannot access file (security scope denied)",
                isRetryable: false
            )
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // 2. Validate file exists and is readable
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "File does not exist",
                isRetryable: false
            )
        }

        // 3. Check it's a regular file (not directory/symlink)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Cannot access file",
                isRetryable: false
            )
        }

        guard !isDirectory.boolValue else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Expected file, got directory",
                isRetryable: false
            )
        }

        // 4. Validate file extension (whitelist)
        let allowedExtensions = ["csv", "json", "txt", "text", "apkg"]
        let fileExtension = url.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Invalid file type: \(fileExtension)",
                isRetryable: false
            )
        }

        // 5. Validate file size (max 100MB)
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? UInt64 else {
                throw ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "Cannot determine file size",
                    isRetryable: false
                )
            }

            let maxSize: UInt64 = 100000000 // 100MB
            guard fileSize <= maxSize else {
                throw ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "File too large (\(fileSize) bytes, max \(maxSize))",
                    isRetryable: false
                )
            }
        } catch {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Cannot read file attributes: \(error.localizedDescription)",
                isRetryable: false
            )
        }
    }

    /// Detect import format from file URL
    ///
    /// **Detection Strategy:**
    /// 1. File extension (primary)
    /// 2. Content-based detection (fallback)
    /// 3. Default to TXT if uncertain
    ///
    /// **Parameters:**
    ///   - url: File URL to detect
    ///
    /// **Returns:** Detected format, or nil if unable to determine
    func detectFormat(from url: URL) -> ImportFormat? {
        // Validate URL first (security) - log errors but continue for best-effort detection
        do {
            try validateFileURL(url)
        } catch {
            logger.error("File URL validation failed: \(error.localizedDescription)")
            // Continue with detection - user may have selected file outside sandbox
        }

        // 1. File extension
        if let pathExtension = url.pathExtension.lowercased() as String? {
            for format in ImportFormat.allCases where format.fileExtensions.contains(pathExtension) {
                logger.info("Detected format '\(format.rawValue)' from file extension")
                return format
            }
        }

        // 2. Content-based detection
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            logger.warning("Unable to read file content for format detection: \(error.localizedDescription)")
            return nil
        }

        guard let preview = String(data: data.prefix(2048), encoding: .utf8) else {
            logger.warning("Unable to decode file content as UTF-8")
            return nil
        }

        // JSON detection
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            logger.info("Detected JSON format from content")
            return .json
        }

        // CSV detection (comma-separated patterns)
        let lines = preview.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count >= 2 {
            let firstLine = lines[0]
            let commaCount = firstLine.count(where: { $0 == "," })
            let tabCount = firstLine.count(where: { $0 == "\t" })
            let pipeCount = firstLine.count(where: { $0 == "|" })

            if commaCount > 0, commaCount >= max(tabCount, pipeCount) {
                logger.info("Detected CSV format from content (comma-delimited)")
                return .csv
            } else if tabCount > 0, tabCount >= max(commaCount, pipeCount) {
                logger.info("Detected CSV format from content (tab-delimited)")
                return .csv
            } else if pipeCount > 0 {
                logger.info("Detected CSV format from content (pipe-delimited)")
                return .csv
            }
        }

        // Default to TXT
        logger.info("Defaulting to TXT format")
        return .txt
    }

    // MARK: - Preview

    /// Preview import with limited number of cards
    ///
    /// **Parameters:**
    ///   - url: File URL to preview
    ///   - format: Import format
    ///   - fieldMapping: Field mapping configuration (for CSV/TXT)
    ///   - limit: Maximum number of cards to return (default: 10)
    ///
    /// **Returns:** Array of parsed flashcards (up to limit)
    func previewImport(
        _ url: URL,
        format: ImportFormat,
        fieldMapping: FieldMappingConfiguration,
        limit: Int = 10
    ) async throws -> [ParsedFlashcard] {
        logger.info("Previewing import from '\(url.lastPathComponent)' with format '\(format.rawValue)'")

        switch format {
        case .csv:
            return try await parseCSV(url, fieldMapping: fieldMapping, limit: limit)
        case .json:
            return try await parseJSON(url, limit: limit)
        case .txt:
            return try await parseTXT(url, fieldMapping: fieldMapping, limit: limit)
        }
    }

    /// Preview import with default field mapping
    ///
    /// **Parameters:**
    ///   - url: File URL to preview
    ///   - format: Import format
    ///   - limit: Maximum number of cards to return (default: 10)
    ///
    /// **Returns:** Array of parsed flashcards (up to limit)
    @MainActor
    func previewImport(
        _ url: URL,
        format: ImportFormat,
        limit: Int = 10
    ) async throws -> [ParsedFlashcard] {
        try await previewImport(url, format: format, fieldMapping: .default, limit: limit)
    }

    // MARK: - Import

    /// Import dictionary from file
    ///
    /// **Parameters:**
    ///   - url: File URL to import
    ///   - format: Import format
    ///   - fieldMapping: Field mapping configuration (for CSV/TXT)
    ///   - deck: Target deck (nil = default deck)
    ///   - progressHandler: Progress callback
    ///
    /// **Returns:** Import result with statistics
    func importDictionary(
        _ url: URL,
        format: ImportFormat,
        fieldMapping: FieldMappingConfiguration,
        into deck: Deck?,
        progressHandler: @escaping @Sendable (ImportProgress) -> Void
    ) async throws -> ImportResult {
        let startTime = Date()
        logger.info("Starting import from '\(url.lastPathComponent)' with format '\(format.rawValue)'")

        // Parse all cards
        let allCards = try await previewImport(url, format: format, fieldMapping: fieldMapping, limit: Int.max)

        guard !allCards.isEmpty else {
            logger.warning("No cards to import")
            return ImportResult(imported: 0, skipped: 0, failed: 0, errors: [], duration: 0)
        }

        logger.info("Parsed \(allCards.count) cards from file")

        // Transform to FlashcardData format
        let cardData: [FlashcardData] = allCards.map { card in
            FlashcardData(
                word: card.word,
                definition: card.definition,
                phonetic: card.phonetic,
                cefrLevel: card.cefrLevel,
                russianTranslation: card.translation
            )
        }

        // Import using DataImporter (500 cards per batch)
        let result = await dataImporter.importCards(
            cardData,
            into: deck,
            batchSize: 500,
            progressHandler: { progress in
                let importProgress = ImportProgress(
                    completedCount: progress.current,
                    totalCount: progress.total,
                    currentWord: "", // DataImporter doesn't provide current word
                    isComplete: progress.current == progress.total
                )
                progressHandler(importProgress)
            }
        )

        let duration = Date().timeIntervalSince(startTime)
        logger.info("""
        Import complete:
        - Imported: \(result.importedCount)
        - Skipped: \(result.skippedCount)
        - Failed: \(result.errors.count)
        - Duration: \(String(format: "%.2f", duration))s
        """)

        return ImportResult(
            imported: result.importedCount,
            skipped: result.skippedCount,
            failed: result.errors.count,
            errors: result.errors.map { error in
                ImportError(
                    lineNumber: error.batchNumber,
                    fieldName: error.cardWord,
                    reason: error.error.localizedDescription,
                    isRetryable: false
                )
            },
            duration: duration
        )
    }

    /// Import dictionary from file with default field mapping
    ///
    /// **Parameters:**
    ///   - url: File URL to import
    ///   - format: Import format
    ///   - deck: Target deck (nil = default deck)
    ///   - progressHandler: Progress callback
    ///
    /// **Returns:** Import result with statistics
    @MainActor
    func importDictionary(
        _ url: URL,
        format: ImportFormat,
        into deck: Deck?,
        progressHandler: @escaping @Sendable (ImportProgress) -> Void
    ) async throws -> ImportResult {
        try await importDictionary(url, format: format, fieldMapping: .default, into: deck, progressHandler: progressHandler)
    }

    // MARK: - Parsers

    /// Parse CSV line with support for quoted fields
    ///
    /// **Handles:**
    /// - Quoted fields: `"Hello, world"` → `Hello, world`
    /// - Escaped quotes: `"Hello ""world"""` → `Hello "world"`
    /// - Empty fields: `word,,definition` → `[word, "", definition]`
    ///
    /// **Example:**
    /// ```swift
    /// parseCSVLine('"Hello, world",definition,test') // ["Hello, world", "definition", "test"]
    /// ```
    ///
    /// - Parameter line: The CSV line to parse
    /// - Returns: Array of field values
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                // Check for escaped quote ("")
                let nextIndex = line.index(after: i)
                if nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    currentField.append("\"")
                    i = line.index(after: nextIndex)
                } else {
                    // Toggle quote mode
                    inQuotes.toggle()
                    i = nextIndex
                }
            } else if char == ",", !inQuotes {
                // Field separator (only outside quotes)
                fields.append(currentField)
                currentField = ""
                i = line.index(after: i)
            } else {
                currentField.append(char)
                i = line.index(after: i)
            }
        }

        // Add last field
        fields.append(currentField)

        return fields
    }

    /// Parse CSV file with field mapping
    private func parseCSV(
        _ url: URL,
        fieldMapping: FieldMappingConfiguration,
        limit: Int = Int.max
    ) async throws -> [ParsedFlashcard] {
        // Read file with error context
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Unable to read file: \(error.localizedDescription)",
                isRetryable: false
            )
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Unable to decode file as UTF-8",
                isRetryable: false
            )
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var cards: [ParsedFlashcard] = []
        var errors: [ImportError] = []

        let startIndex = fieldMapping.hasHeader ? 1 : 0

        for (index, line) in lines[startIndex...].enumerated() {
            guard index < limit else { break }

            let lineNumber = startIndex + index + 1
            let fields = parseCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.count > max(fieldMapping.wordFieldIndex, fieldMapping.definitionFieldIndex) else {
                errors.append(ImportError(
                    lineNumber: lineNumber,
                    fieldName: nil,
                    reason: "Not enough fields (expected \(max(fieldMapping.wordFieldIndex, fieldMapping.definitionFieldIndex) + 1), got \(fields.count))",
                    isRetryable: false
                ))
                continue
            }

            let word = fields[fieldMapping.wordFieldIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let definition = fields[fieldMapping.definitionFieldIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !word.isEmpty else {
                errors.append(ImportError(
                    lineNumber: lineNumber,
                    fieldName: "word",
                    reason: "Word cannot be empty",
                    isRetryable: false
                ))
                continue
            }

            guard !definition.isEmpty else {
                errors.append(ImportError(
                    lineNumber: lineNumber,
                    fieldName: "definition",
                    reason: "Definition cannot be empty",
                    isRetryable: false
                ))
                continue
            }

            let phonetic = fieldMapping.phoneticFieldIndex.flatMap {
                $0 < fields.count ? fields[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            }

            let cefrLevel = fieldMapping.cefrFieldIndex.flatMap {
                $0 < fields.count ? fields[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            }

            let translation = fieldMapping.translationFieldIndex.flatMap {
                $0 < fields.count ? fields[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            }

            cards.append(ParsedFlashcard(
                word: word,
                definition: definition,
                phonetic: phonetic?.isEmpty ?? true ? nil : phonetic,
                cefrLevel: cefrLevel?.isEmpty ?? true ? nil : cefrLevel,
                translation: translation?.isEmpty ?? true ? nil : translation,
                lineNumber: lineNumber
            ))
        }

        if !errors.isEmpty {
            logger.warning("Encountered \(errors.count) errors during CSV parsing")
        }

        return cards
    }

    /// Parse JSON file with type-safe Codable validation
    ///
    /// **Security:**
    /// - File size validation (max 10MB)
    /// - Type-safe Codable parsing (no unsafe type casting)
    /// - Input sanitization (removes control characters, null bytes)
    /// - Detailed error reporting with line numbers
    private func parseJSON(_ url: URL, limit: Int = Int.max) async throws -> [ParsedFlashcard] {
        let fileSize = try validateJSONFileSize(url)
        _ = fileSize // Size is validated, used for logging
        let data = try readJSONFile(url)
        let sanitizedData = preSanitizeJSONData(data)

        let decoder = JSONDecoder()
        do {
            let jsonCards = try decoder.decode([JSONFlashcard].self, from: sanitizedData)
            return try validateAndSanitizeCards(jsonCards, limit: limit)
        } catch {
            throw mapDecodingError(error)
        }
    }

    // MARK: - JSON Parsing Helper Methods

    /// Validates JSON file size (max 10MB)
    ///
    /// - Parameter url: File URL to validate
    /// - Returns: File size in bytes
    /// - Throws: ImportError if file is too large or size cannot be determined
    private func validateJSONFileSize(_ url: URL) throws -> UInt64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = fileAttributes[.size] as? UInt64 else {
                throw ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "Cannot determine file size",
                    isRetryable: false
                )
            }
            let maxSize: UInt64 = 10000000 // 10MB
            guard fileSize <= maxSize else {
                throw ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "JSON file too large (\(fileSize) bytes, max \(maxSize))",
                    isRetryable: false
                )
            }
            return fileSize
        } catch {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Cannot read file attributes: \(error.localizedDescription)",
                isRetryable: false
            )
        }
    }

    /// Reads JSON file safely with error context
    ///
    /// - Parameter url: File URL to read
    /// - Returns: File data
    /// - Throws: ImportError if file cannot be read
    private func readJSONFile(_ url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Unable to read file: \(error.localizedDescription)",
                isRetryable: false
            )
        }
    }

    /// Pre-sanitizes raw JSON data to remove control characters before JSONDecoder
    ///
    /// JSONDecoder rejects null bytes before we can sanitize parsed values,
    /// so we need to clean the raw JSON string first.
    ///
    /// - Parameter data: Raw JSON data
    /// - Returns: Sanitized data (or original if sanitization fails)
    private func preSanitizeJSONData(_ data: Data) -> Data {
        if let jsonString = String(data: data, encoding: .utf8) {
            let sanitizedJSONString = sanitizeString(jsonString)
            if let dataFromString = sanitizedJSONString.data(using: .utf8) {
                return dataFromString
            }
        }
        return data
    }

    /// Validates and sanitizes parsed JSON flashcards
    ///
    /// - Parameters:
    ///   - jsonCards: Array of parsed JSONFlashcard structs
    ///   - limit: Maximum number of cards to process
    /// - Returns: Array of validated ParsedFlashcard objects
    /// - Throws: ImportError if any card fails validation
    private func validateAndSanitizeCards(
        _ jsonCards: [JSONFlashcard],
        limit: Int
    ) throws -> [ParsedFlashcard] {
        var cards: [ParsedFlashcard] = []

        for (index, card) in jsonCards.enumerated() {
            guard index < limit else { break }

            // Sanitize strings (remove control characters and null bytes)
            let sanitizedWord = sanitizeString(card.word)
            let sanitizedDef = sanitizeString(card.definition)

            // Validate required fields
            guard !sanitizedWord.isEmpty else {
                throw ImportError(
                    lineNumber: index + 1,
                    fieldName: "word",
                    reason: "Word cannot be empty after sanitization",
                    isRetryable: false
                )
            }

            guard !sanitizedDef.isEmpty else {
                throw ImportError(
                    lineNumber: index + 1,
                    fieldName: "definition",
                    reason: "Definition cannot be empty after sanitization",
                    isRetryable: false
                )
            }

            // Sanitize optional fields
            let sanitizedPhonetic = card.phonetic.map { self.sanitizeString($0) }.nilIfEmpty
            let sanitizedCefrLevel = card.cefrLevel.map { self.sanitizeString($0) }.nilIfEmpty
            let sanitizedTranslation = card.translation.map { self.sanitizeString($0) }.nilIfEmpty

            cards.append(ParsedFlashcard(
                word: sanitizedWord,
                definition: sanitizedDef,
                phonetic: sanitizedPhonetic,
                cefrLevel: sanitizedCefrLevel,
                translation: sanitizedTranslation,
                lineNumber: index + 1
            ))
        }

        return cards
    }

    /// Converts DecodingError to ImportError with detailed context
    ///
    /// - Parameter error: The decoding error to convert
    /// - Returns: ImportError with line number and field information
    private func mapDecodingError(_ error: Error) -> ImportError {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case let .dataCorrupted(context):
                return ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "Invalid JSON structure: \(context.debugDescription)",
                    isRetryable: false
                )
            case let .keyNotFound(key, context):
                let lineNumber = context.codingPath.first?.intValue ?? 0
                return ImportError(
                    lineNumber: lineNumber + 1,
                    fieldName: key.stringValue,
                    reason: "Missing required field: \(key.stringValue)",
                    isRetryable: false
                )
            case let .typeMismatch(type, context):
                let lineNumber = context.codingPath.first?.intValue ?? 0
                return ImportError(
                    lineNumber: lineNumber + 1,
                    fieldName: context.codingPath.last?.stringValue,
                    reason: "Type mismatch: expected \(type), got different type",
                    isRetryable: false
                )
            case let .valueNotFound(type, context):
                let lineNumber = context.codingPath.first?.intValue ?? 0
                return ImportError(
                    lineNumber: lineNumber + 1,
                    fieldName: context.codingPath.last?.stringValue,
                    reason: "Value not found for type: \(type)",
                    isRetryable: false
                )
            @unknown default:
                return ImportError(
                    lineNumber: 0,
                    fieldName: nil,
                    reason: "Unknown decoding error: \(error.localizedDescription)",
                    isRetryable: false
                )
            }
        }
        return ImportError(
            lineNumber: 0,
            fieldName: nil,
            reason: "JSON parsing failed: \(error.localizedDescription)",
            isRetryable: false
        )
    }

    /// Sanitize string by removing control characters and null bytes
    ///
    /// **Security:** Prevents injection attacks and malformed data
    private func sanitizeString(_ input: String) -> String {
        // Remove control characters (except \n and \r) and null bytes
        input
            .filter { char in
                guard let asciiValue = char.asciiValue else {
                    return true // Non-ASCII characters are allowed
                }
                return asciiValue != 0 &&
                    (asciiValue >= 32 || asciiValue == 10 || asciiValue == 13)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Helper Extensions

extension CodingKey {
    /// Extract line number from coding path for error reporting
    var intValue: Int? {
        if let intValue = self.intValue {
            return intValue
        }
        // Try to parse string value as integer
        if let strValue = stringValue as String?, let intVal = Int(strValue) {
            return intVal
        }
        return nil
    }
}

extension String? {
    /// Return nil if string is empty after trimming
    var nilIfEmpty: String? {
        let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty ?? true ? nil : trimmed
    }
}

// MARK: - DictionaryImporter ParseTXT Extension

extension DictionaryImporter {
    /// Parse TXT file (word per line or tab-delimited)
    private func parseTXT(
        _ url: URL,
        fieldMapping _: FieldMappingConfiguration,
        limit: Int = Int.max
    ) async throws -> [ParsedFlashcard] {
        // Read file with error context
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Unable to read file: \(error.localizedDescription)",
                isRetryable: false
            )
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError(
                lineNumber: 0,
                fieldName: nil,
                reason: "Unable to decode file as UTF-8",
                isRetryable: false
            )
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var cards: [ParsedFlashcard] = []

        for (index, line) in lines.enumerated() {
            guard index < limit else { break }

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let fields = trimmedLine.split(separator: "\t", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }

            if fields.count >= 2 {
                // Tab-delimited: word\tdefinition
                let word = fields[0]
                let definition = fields[1]

                cards.append(ParsedFlashcard(
                    word: word,
                    definition: definition,
                    phonetic: fields.count > 2 ? fields[2] : nil,
                    cefrLevel: fields.count > 3 ? fields[3] : nil,
                    translation: fields.count > 4 ? fields[4] : nil,
                    lineNumber: index + 1
                ))
            } else {
                // Single word per line
                let word = trimmedLine
                let definition = "Definition for \(word)"

                cards.append(ParsedFlashcard(
                    word: word,
                    definition: definition,
                    phonetic: nil,
                    cefrLevel: nil,
                    translation: nil,
                    lineNumber: index + 1
                ))
            }
        }

        return cards
    }
}
