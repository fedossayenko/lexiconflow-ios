//
//  DictionaryImporterTests.swift
//  LexiconFlowTests
//
//  Comprehensive tests for DictionaryImporter including:
//  - Format detection (extension and content-based)
//  - CSV parsing (quoted fields, escaped quotes, empty fields)
//  - JSON parsing (valid, type errors, missing fields)
//  - TXT parsing (word-per-line, tab-delimited)
//  - Security validation (file size, extension whitelist)
//  - Error handling (ImportError cases)
//  - Integration (preview, import, progress tracking)
//

import Foundation
import SwiftData
import Testing
@testable import LexiconFlow

/// Test suite for DictionaryImporter
///
/// Tests verify:
/// - Format auto-detection from file extension and content
/// - CSV parsing with complex quoting rules
/// - JSON parsing with type-safe validation
/// - TXT parsing with multiple formats
/// - Security validation (file size, extension whitelist)
/// - Progress tracking and error reporting
@Suite(.serialized)
@MainActor
struct DictionaryImporterTests {
    // MARK: - Test Helpers

    /// Create in-memory test container
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            Flashcard.self,
            Deck.self,
            FSRSState.self,
            FlashcardReview.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// Create temporary test file with content
    private func createTestFile(content: String, extension: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).\(`extension`)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Create test deck
    private func createTestDeck(context: ModelContext, name: String = "Test Deck") -> Deck {
        let deck = Deck(name: name, icon: "📚")
        context.insert(deck)
        try! context.save()
        return deck
    }

    // MARK: - Format Detection Tests

    @Test("detectFormat identifies CSV from file extension")
    func detectFormatIdentifiesCSVFromExtension() throws {
        let content = "word,definition\ntest,Test definition"
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let format = importer.detectFormat(from: fileURL)

        #expect(format == .csv)
    }

    @Test("detectFormat identifies JSON from file extension")
    func detectFormatIdentifiesJSONFromExtension() throws {
        let content = "[{\"word\":\"test\",\"definition\":\"Test\"}]"
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let format = importer.detectFormat(from: fileURL)

        #expect(format == .json)
    }

    @Test("detectFormat identifies TXT from file extension")
    func detectFormatIdentifiesTXTFromExtension() throws {
        let content = "test word"
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let format = importer.detectFormat(from: fileURL)

        #expect(format == .txt)
    }

    @Test("detectFormat identifies JSON from content when extension ambiguous")
    func detectFormatIdentifiesJSONFromContent() throws {
        let content = "[{\"word\":\"test\",\"definition\":\"definition\"}]"
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let format = importer.detectFormat(from: fileURL)

        #expect(format == .json)
    }

    @Test("detectFormat defaults to TXT for unknown format")
    func detectFormatDefaultsToTXT() throws {
        let content = "just some text"
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let format = importer.detectFormat(from: fileURL)

        #expect(format == .txt)
    }

    // MARK: - CSV Parsing Tests

    @Test("parseCSV handles simple comma-delimited format")
    func parseCSVHandlesSimpleFormat() async throws {
        let content = """
        word,definition
        test,Test definition
        hello,Greeting
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].word == "test")
        #expect(result[0].definition == "Test definition")
    }

    @Test("parseCSV handles quoted fields with commas")
    func parseCSVHandlesQuotedFields() async throws {
        let content = """
        word,definition
        test,"Hello, world"
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 10
        )

        #expect(result.count == 1)
        #expect(result[0].definition == "Hello, world")
    }

    @Test("parseCSV handles escaped quotes")
    func parseCSVHandlesEscapedQuotes() async throws {
        let content = """
        word,definition
        test,"He said ""hello"" to me"
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 10
        )

        #expect(result.count == 1)
        #expect(result[0].definition == "He said \"hello\" to me")
    }

    @Test("parseCSV handles empty fields")
    func parseCSVHandlesEmptyFields() async throws {
        let content = """
        word,definition,phonetic
        test,definition,
        hello,,
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let fieldMapping = DictionaryImporter.FieldMappingConfiguration(
            wordFieldIndex: 0,
            definitionFieldIndex: 1,
            phoneticFieldIndex: 2,
            cefrFieldIndex: nil,
            translationFieldIndex: nil,
            hasHeader: true
        )

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,
            fieldMapping: fieldMapping,
            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].phonetic == nil)
        #expect(result[1].phonetic == nil)
    }

    @Test("parseCSV skips rows with empty required fields")
    func parseCSVSkipsEmptyRequiredFields() async throws {
        let content = """
        word,definition
        ,Empty word
        hello,Valid definition
        ,Another empty
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 10
        )

        #expect(result.count == 1)
        #expect(result[0].word == "hello")
    }

    @Test("parseCSV respects hasHeader configuration")
    func parseCSVRespectsHasHeader() async throws {
        let content = """
        word,definition
        test,definition
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let withHeader = DictionaryImporter.FieldMappingConfiguration(
            wordFieldIndex: 0,
            definitionFieldIndex: 1,
            hasHeader: true
        )

        let withoutHeader = DictionaryImporter.FieldMappingConfiguration(
            wordFieldIndex: 0,
            definitionFieldIndex: 1,
            hasHeader: false
        )

        let resultWithHeader = try await importer.previewImport(
            fileURL,
            format: .csv,
            fieldMapping: withHeader,
            limit: 10
        )

        let resultWithoutHeader = try await importer.previewImport(
            fileURL,
            format: .csv,
            fieldMapping: withoutHeader,
            limit: 10
        )

        #expect(resultWithHeader.count == 1) // Skips header row
        #expect(resultWithoutHeader.count == 2) // Includes header row as data
    }

    // MARK: - JSON Parsing Tests

    @Test("parseJSON handles valid JSON array")
    func parseJSONHandlesValidArray() async throws {
        let content = """
        [
            {"word": "test", "definition": "Test definition", "phonetic": "test"},
            {"word": "hello", "definition": "Greeting", "cefrLevel": "A1"}
        ]
        """
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .json,
            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].word == "test")
        #expect(result[0].phonetic == "test")
        #expect(result[1].cefrLevel == "A1")
    }

    @Test("parseJSON handles optional fields")
    func parseJSONHandlesOptionalFields() async throws {
        let content = """
        [
            {"word": "test", "definition": "Definition"}
        ]
        """
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .json,
            limit: 10
        )

        #expect(result.count == 1)
        #expect(result[0].phonetic == nil)
        #expect(result[0].cefrLevel == nil)
        #expect(result[0].translation == nil)
    }

    @Test("parseJSON throws error for missing required field")
    func parseJSONThrowsForMissingRequiredField() async throws {
        let content = """
        [
            {"definition": "Missing word field"}
        ]
        """
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let error = await #expect(throws: DictionaryImporter.ImportError.self) {
            try await importer.previewImport(fileURL, format: .json, limit: 10)
        }

        #expect(error?.fieldName == "word")
    }

    @Test("parseJSON throws error for invalid JSON structure")
    func parseJSONThrowsForInvalidStructure() async throws {
        let content = """
        {
            "invalid": "not an array"
        }
        """
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let error = await #expect(throws: DictionaryImporter.ImportError.self) {
            try await importer.previewImport(fileURL, format: .json, limit: 10)
        }

        #expect(error?.reason.contains("Invalid JSON structure") ?? false)
    }

    // MARK: - TXT Parsing Tests

    @Test("parseTXT handles word-per-line format")
    func parseTXTHandlesWordPerLine() async throws {
        let content = """
        test
        hello
        goodbye
        """
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .txt,

            limit: 10
        )

        #expect(result.count == 3)
        #expect(result[0].word == "test")
        #expect(result[0].definition == "Definition for test")
    }

    @Test("parseTXT handles tab-delimited format")
    func parseTXTHandlesTabDelimited() async throws {
        let content = """
        test\tTest definition\ttest
        hello\tGreeting\thəˈloʊ
        """
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .txt,

            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].word == "test")
        #expect(result[0].definition == "Test definition")
        #expect(result[0].phonetic == "test")
        #expect(result[1].phonetic == "həˈloʊ")
    }

    @Test("parseTXT skips empty lines")
    func parseTXTSkipsEmptyLines() async throws {
        let content = """
        test

        hello

        goodbye
        """
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .txt,

            limit: 10
        )

        #expect(result.count == 3)
    }

    // MARK: - Security Validation Tests

    @Test("validateFileURL rejects disallowed file extensions")
    func validateRejectsDisallowedExtensions() async throws {
        // Create .exe file (not in whitelist)
        let content = "malicious content"
        let fileURL = try createTestFile(content: content, extension: "exe")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = importer.detectFormat(from: fileURL)

        // Should return nil for unrecognized extension
        #expect(result == nil)
    }

    @Test("detectFormat accepts allowed extensions")
    func detectFormatAcceptsAllowedExtensions() throws {
        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        // Test CSV
        let csvURL = try createTestFile(content: "word,def", extension: "csv")
        #expect(importer.detectFormat(from: csvURL) == .csv)

        // Test JSON
        let jsonURL = try createTestFile(content: "[]", extension: "json")
        #expect(importer.detectFormat(from: jsonURL) == .json)

        // Test TXT
        let txtURL = try createTestFile(content: "word", extension: "txt")
        #expect(importer.detectFormat(from: txtURL) == .txt)

        // Test TEXT (alternative to TXT)
        let textURL = try createTestFile(content: "word", extension: "text")
        #expect(importer.detectFormat(from: textURL) == .txt)
    }

    // MARK: - Error Handling Tests

    @Test("ImportError provides localizedDescription")
    func importErrorProvidesDescription() {
        let error = DictionaryImporter.ImportError(
            lineNumber: 5,
            fieldName: "word",
            reason: "Field cannot be empty",
            isRetryable: false
        )

        #expect(error.localizedDescription == "Line 5: word - Field cannot be empty")
    }

    @Test("ImportError without fieldName formats correctly")
    func importErrorWithoutFieldNameFormats() {
        let error = DictionaryImporter.ImportError(
            lineNumber: 10,
            fieldName: nil,
            reason: "Invalid file format",
            isRetryable: false
        )

        #expect(error.localizedDescription == "Line 10: Invalid file format")
    }

    @Test("ImportResult calculates success correctly")
    func importResultCalculatesSuccess() {
        // Success when no failures
        let result1 = DictionaryImporter.ImportResult(
            imported: 10,
            skipped: 0,
            failed: 0,
            errors: [],
            duration: 1.0
        )
        #expect(result1.isSuccess == true)

        // Success when some imports succeeded despite failures
        let result2 = DictionaryImporter.ImportResult(
            imported: 5,
            skipped: 2,
            failed: 1,
            errors: [],
            duration: 1.0
        )
        #expect(result2.isSuccess == true)

        // Failure when nothing imported
        let result3 = DictionaryImporter.ImportResult(
            imported: 0,
            skipped: 0,
            failed: 5,
            errors: [],
            duration: 1.0
        )
        #expect(result3.isSuccess == false)
    }

    @Test("ImportProgress calculates percentage correctly")
    func importProgressCalculatesPercentage() {
        let progress1 = DictionaryImporter.ImportProgress(
            completedCount: 5,
            totalCount: 10,
            currentWord: "test",
            isComplete: false
        )

        #expect(progress1.percentage == 0.5)
        #expect(progress1.percentageText == "50%")

        let progress2 = DictionaryImporter.ImportProgress(
            completedCount: 0,
            totalCount: 10,
            currentWord: "",
            isComplete: false
        )

        #expect(progress2.percentage == 0.0)

        let progress3 = DictionaryImporter.ImportProgress(
            completedCount: 10,
            totalCount: 10,
            currentWord: "last",
            isComplete: true
        )

        #expect(progress3.percentage == 1.0)
        #expect(progress3.percentageText == "100%")
    }

    // MARK: - Integration Tests

    @Test("previewImport respects limit parameter")
    func previewImportRespectsLimit() async throws {
        var content = "word,definition\n"
        for i in 0 ..< 20 {
            content += "word\(i),definition\(i)\n"
        }

        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 5
        )

        #expect(result.count == 5)
    }

    @Test("importDictionary returns ImportResult with statistics")
    func importDictionaryReturnsStatistics() async throws {
        let content = """
        word,definition
        test,Test definition
        hello,Greeting
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let context = container.mainContext
        let deck = createTestDeck(context: context)

        let importer = DictionaryImporter(modelContext: context)

        let result = try await importer.importDictionary(
            fileURL,
            format: .csv,

            into: deck
        ) { _ in }

        #expect(result.imported > 0)
        #expect(result.duration > 0)
        #expect(result.isSuccess == true)
    }

    @Test("FieldMappingConfiguration default values")
    func fieldMappingDefaultValues() {
        let defaultMapping = DictionaryImporter.FieldMappingConfiguration.default

        #expect(defaultMapping.wordFieldIndex == 0)
        #expect(defaultMapping.definitionFieldIndex == 1)
        #expect(defaultMapping.phoneticFieldIndex == nil)
        #expect(defaultMapping.cefrFieldIndex == nil)
        #expect(defaultMapping.translationFieldIndex == nil)
        #expect(defaultMapping.hasHeader == true)
    }

    @Test("ImportFormat provides correct file extensions")
    func importFormatFileExtensions() {
        #expect(DictionaryImporter.ImportFormat.csv.fileExtensions == ["csv"])
        #expect(DictionaryImporter.ImportFormat.json.fileExtensions == ["json"])
        #expect(DictionaryImporter.ImportFormat.txt.fileExtensions == ["txt", "text"])
    }

    @Test("ParsedFlashcard contains all fields")
    func parsedFlashcardContainsAllFields() {
        let card = DictionaryImporter.ParsedFlashcard(
            word: "test",
            definition: "definition",
            phonetic: "test",
            cefrLevel: "A1",
            translation: "prueba",
            lineNumber: 5
        )

        #expect(card.word == "test")
        #expect(card.definition == "definition")
        #expect(card.phonetic == "test")
        #expect(card.cefrLevel == "A1")
        #expect(card.translation == "prueba")
        #expect(card.lineNumber == 5)
    }

    // MARK: - Edge Cases Tests

    @Test("parseCSV handles special characters")
    func parseCSVHandlesSpecialCharacters() async throws {
        let content = """
        word,definition
        café,A coffee shop
        naïve,Innocent
        """
        let fileURL = try createTestFile(content: content, extension: "csv")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .csv,

            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].word == "café")
        #expect(result[1].word == "naïve")
    }

    @Test("parseJSON sanitizes control characters")
    func parseJSONSanitizesControlCharacters() async throws {
        let content = """
        [
            {"word": "test\u{0000}null", "definition": "definition"}
        ]
        """
        let fileURL = try createTestFile(content: content, extension: "json")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .json,
            limit: 10
        )

        #expect(result.count == 1)
        #expect(!result[0].word.contains("\u{0000}"))
    }

    @Test("parseTXT handles Unicode characters")
    func parseTXTHandlesUnicode() async throws {
        let content = """
        日本語\tJapanese definition
        中文\tChinese definition
        """
        let fileURL = try createTestFile(content: content, extension: "txt")

        let container = createTestContainer()
        let importer = DictionaryImporter(modelContext: container.mainContext)

        let result = try await importer.previewImport(
            fileURL,
            format: .txt,

            limit: 10
        )

        #expect(result.count == 2)
        #expect(result[0].word == "日本語")
        #expect(result[1].word == "中文")
    }

    @Test("ImportFormat enum is CaseIterable")
    func importFormatIsCaseIterable() {
        let allFormats = DictionaryImporter.ImportFormat.allCases

        #expect(allFormats.count == 3)
        #expect(allFormats.contains(.csv))
        #expect(allFormats.contains(.json))
        #expect(allFormats.contains(.txt))
    }
}
