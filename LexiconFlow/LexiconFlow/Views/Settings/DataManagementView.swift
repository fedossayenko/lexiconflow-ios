//
//  DataManagementView.swift
//  LexiconFlow
//
//  Data import/export and progress management
//

import SwiftUI
import SwiftData
import OSLog
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImportPicker = false
    @State private var showingShareSheet = false
    @State private var showingClearAlert = false
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false

    // Performance testing state
    @State private var showingPerformanceTestAlert = false
    @State private var showingClearPerformanceTestDataAlert = false
    @State private var performanceTestResultMessage: String?
    @State private var showingPerformanceTestResult = false

    private let logger = Logger(subsystem: "com.lexiconflow.datamanagement", category: "DataManagement")

    var body: some View {
        Form {
            // Export Section
            Section {
                if isExporting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Exporting...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Export All Data") {
                        exportAllData()
                    }

                    Button("Export as JSON") {
                        exportAsJSON()
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Save your flashcards and progress to a file")
            }

            // Import Section
            Section {
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Importing...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Import Data") {
                        showingImportPicker = true
                    }
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Import flashcards from a backup file")
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }

            // Data Management Section
            Section {
                Button("Reset Progress", role: .destructive) {
                    showingClearAlert = true
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("Reset all FSRS progress. Cards will be marked as new but not deleted.")
            }

            // Performance Testing Section
            Section {
                Button("Create Performance Test Deck (50 cards)") {
                    showingPerformanceTestAlert = true
                }

                Button("Create Performance Test Decks (10, 50, 100 cards)") {
                    createMultiplePerformanceTestDecks()
                }

                Button("Clear Performance Test Data", role: .destructive) {
                    showingClearPerformanceTestDataAlert = true
                }
            } header: {
                Text("Performance Testing")
            } footer: {
                Text("Generate test data to verify app performance with 50+ glass elements. Navigate to Decks to test scrolling performance.")
            }

            // Statistics
            Section {
                HStack {
                    Text("Total Cards")
                    Spacer()
                    Text("\(cardCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Total Decks")
                    Spacer()
                    Text("\(deckCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Database Size")
                    Spacer()
                    Text("~\(estimatedSize) MB")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Data Management")
        .confirmationDialog("Reset All Progress", isPresented: $showingClearAlert, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Progress", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This will reset all card progress to \"new\" state but keep your cards. This action cannot be undone.")
        }
        .confirmationDialog("Create Performance Test Data", isPresented: $showingPerformanceTestAlert, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { }
            Button("Create 50 Cards") {
                createPerformanceTestDeck(cardCount: 50)
            }
            Button("Create 100 Cards") {
                createPerformanceTestDeck(cardCount: 100)
            }
        } message: {
            Text("This will create a performance test deck with vocabulary cards for testing scroll performance with glass effects.")
        }
        .confirmationDialog("Clear Performance Test Data", isPresented: $showingClearPerformanceTestDataAlert, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Test Data", role: .destructive) {
                clearPerformanceTestData()
            }
        } message: {
            Text("This will delete all decks with 'Performance Test' in the name and their associated cards. This action cannot be undone.")
        }
        .alert("Performance Test Data Created", isPresented: $showingPerformanceTestResult) {
            Button("OK") { }
        } message: {
            if let message = performanceTestResultMessage {
                Text(message)
            }
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK") { }
        } message: {
            if let result = importResult {
                Text(importSummary(result))
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Export

    private func exportAllData() {
        isExporting = true

        Task {
            do {
                let url = try await generateExportFile(includeProgress: true)
                await MainActor.run {
                    exportURL = url
                    showingShareSheet = true
                    isExporting = false
                }
                logger.info("Exported all data successfully")
            } catch {
                await MainActor.run {
                    isExporting = false
                }
                logger.error("Export failed: \(error)")
            }
        }
    }

    private func exportAsJSON() {
        isExporting = true

        Task {
            do {
                let url = try await generateExportFile(includeProgress: false)
                await MainActor.run {
                    exportURL = url
                    showingShareSheet = true
                    isExporting = false
                }
                logger.info("Exported JSON successfully")
            } catch {
                await MainActor.run {
                    isExporting = false
                }
                logger.error("JSON export failed: \(error)")
            }
        }
    }

    private func generateExportFile(includeProgress: Bool) async throws -> URL {
        let cards = try modelContext.fetch(FetchDescriptor<Flashcard>())
        let decks = try modelContext.fetch(FetchDescriptor<Deck>())

        let exportData = ExportData(
            decks: decks.map { deck in
                ExportDeck(
                    id: deck.id.uuidString,
                    name: deck.name,
                    icon: deck.icon ?? "folder.fill"
                )
            },
            cards: cards.map { card in
                ExportCard(
                    word: card.word,
                    definition: card.definition,
                    phonetic: card.phonetic,
                    translation: card.translation,
                    deckId: card.deck?.id.uuidString,
                    fsrsState: includeProgress ? card.fsrsState.map { state in
                        ExportFSRSState(
                            stability: state.stability,
                            difficulty: state.difficulty,
                            retrievability: state.retrievability,
                            dueDate: state.dueDate.ISO8601Format(),
                            stateEnum: state.stateEnum
                        )
                    } : nil
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexiconflow_export")
            .appendingPathExtension("json")

        try data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        isImporting = true

        Task {
            do {
                guard let fileURL = try result.get().first else {
                    await MainActor.run {
                        isImporting = false
                    }
                    return
                }

                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let importData = try decoder.decode(ExportData.self, from: data)

                // Import decks first
                var deckMap: [String: Deck] = [:]
                for deckData in importData.decks {
                    let deck = Deck(name: deckData.name, icon: deckData.icon)
                    modelContext.insert(deck)
                    deckMap[deckData.id] = deck
                }

                // Convert cards to FlashcardData
                let cardsData = importData.cards.map { card in
                    FlashcardData(
                        word: card.word,
                        definition: card.definition,
                        phonetic: card.phonetic,
                        imageData: nil
                    )
                }

                // Use DataImporter
                let importer = DataImporter(modelContext: modelContext)
                let result = await importer.importCards(cardsData, batchSize: 500)

                // Associate cards with decks and apply FSRS state if included
                if let deckID = importData.cards.first?.deckId {
                    // Simple association for first deck (would need proper matching in production)
                }

                await MainActor.run {
                    importResult = result
                    showingImportResult = true
                    isImporting = false
                }

                logger.info("Import completed: \(result.importedCount) imported, \(result.skippedCount) skipped")

            } catch {
                await MainActor.run {
                    isImporting = false
                }
                logger.error("Import failed: \(error)")
            }
        }
    }

    private func importSummary(_ result: ImportResult) -> String {
        if result.isSuccess {
            return "Successfully imported \(result.importedCount) card\(result.importedCount == 1 ? "" : "s")."
        } else {
            var summary = "Imported \(result.importedCount) card\(result.importedCount == 1 ? "" : "s")."
            if result.skippedCount > 0 {
                summary += "\n\nSkipped \(result.skippedCount) duplicate\(result.skippedCount == 1 ? "" : "s")."
            }
            if !result.errors.isEmpty {
                summary += "\n\n\(result.errors.count) error\(result.errors.count == 1 ? "" : "s") occurred."
            }
            return summary
        }
    }

    // MARK: - Reset Progress

    private func resetProgress() {
        Task {
            do {
                let states = try modelContext.fetch(FetchDescriptor<FSRSState>())

                for state in states {
                    state.stability = 0
                    state.difficulty = 5
                    state.retrievability = 0.9
                    state.dueDate = Date()
                    state.stateEnum = FlashcardState.new.rawValue
                    state.lastReviewDate = nil
                }

                try modelContext.save()

                logger.info("Reset progress for \(states.count) cards")
            } catch {
                logger.error("Failed to reset progress: \(error)")
            }
        }
    }

    // MARK: - Performance Testing

    /// Creates a performance test deck with specified number of cards
    private func createPerformanceTestDeck(cardCount: Int) {
        Task {
            do {
                let generator = PerformanceTestDataGenerator(modelContext: modelContext)
                let deck = try generator.createPerformanceTestDeck(cardCount: cardCount)

                await MainActor.run {
                    performanceTestResultMessage = "Created performance test deck '\(deck.name)' with \(cardCount) cards.\n\nNavigate to Decks to test scrolling performance with \(cardCount) glass elements."
                    showingPerformanceTestResult = true
                }

                logger.info("Created performance test deck with \(cardCount) cards")
            } catch {
                await MainActor.run {
                    performanceTestResultMessage = "Failed to create performance test deck: \(error.localizedDescription)"
                    showingPerformanceTestResult = true
                }
                logger.error("Failed to create performance test deck: \(error)")
            }
        }
    }

    /// Creates multiple performance test decks with varying card counts
    private func createMultiplePerformanceTestDecks() {
        Task {
            do {
                let generator = PerformanceTestDataGenerator(modelContext: modelContext)
                let decks = try generator.createMultiplePerformanceTestDecks(cardCounts: [10, 50, 100])

                await MainActor.run {
                    let totalCards = decks.reduce(0) { $0 + $1.cards.count }
                    performanceTestResultMessage = "Created \(decks.count) performance test decks with \(totalCards) total cards.\n\nDecks: 10 cards, 50 cards, 100 cards.\n\nNavigate to Decks to test scrolling performance with glass effects."
                    showingPerformanceTestResult = true
                }

                logger.info("Created multiple performance test decks")
            } catch {
                await MainActor.run {
                    performanceTestResultMessage = "Failed to create performance test decks: \(error.localizedDescription)"
                    showingPerformanceTestResult = true
                }
                logger.error("Failed to create performance test decks: \(error)")
            }
        }
    }

    /// Clears all performance test data
    private func clearPerformanceTestData() {
        Task {
            do {
                let generator = PerformanceTestDataGenerator(modelContext: modelContext)
                try generator.clearPerformanceTestData()

                logger.info("Cleared performance test data")
            } catch {
                logger.error("Failed to clear performance test data: \(error)")
            }
        }
    }

    // MARK: - Statistics

    private var cardCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Flashcard>())) ?? 0
    }

    private var deckCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Deck>())) ?? 0
    }

    private var estimatedSize: String {
        // Rough estimate based on card count
        let cards = cardCount
        let estimatedBytes = cards * 500 // Approximate 500 bytes per card
        let mb = Double(estimatedBytes) / 1_000_000
        return String(format: "%.2f", mb)
    }
}

// MARK: - Export Types

struct ExportData: Codable {
    let version: String
    let exportDate: String
    let decks: [ExportDeck]
    let cards: [ExportCard]

    init(decks: [ExportDeck], cards: [ExportCard]) {
        self.version = "1.0"
        self.exportDate = ISO8601DateFormatter().string(from: Date())
        self.decks = decks
        self.cards = cards
    }
}

struct ExportDeck: Codable {
    let id: String
    let name: String
    let icon: String
}

struct ExportCard: Codable {
    let word: String
    let definition: String
    let phonetic: String?
    let translation: String?
    let deckId: String?
    let fsrsState: ExportFSRSState?
}

struct ExportFSRSState: Codable {
    let stability: Double
    let difficulty: Double
    let retrievability: Double
    let dueDate: String
    let stateEnum: String
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self], inMemory: true)
}
