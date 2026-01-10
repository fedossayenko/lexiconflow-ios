//
//  DataManagementView.swift
//  LexiconFlow
//
//  Data import/export and progress management
//

import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImportPicker = false
    @State private var showingShareSheet = false
    @State private var showingClearAlert = false
    @State private var showingDictionaryImport = false
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false

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

                    Button("Import Dictionary") {
                        showingDictionaryImport = true
                    }
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Import flashcards from a backup file or dictionary (CSV, JSON, TXT)")
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
            Button("Cancel", role: .cancel) {}
            Button("Reset Progress", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This will reset all card progress to \"new\" state but keep your cards. This action cannot be undone.")
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK") {}
        } message: {
            if let result = importResult {
                Text(importSummary(result))
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingDictionaryImport) {
            DictionaryImportView()
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
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
        let mb = Double(estimatedBytes) / 1000000
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
        version = "1.0"
        exportDate = ISO8601DateFormatter().string(from: Date())
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

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .modelContainer(for: [Flashcard.self, Deck.self, FSRSState.self], inMemory: true)
}
