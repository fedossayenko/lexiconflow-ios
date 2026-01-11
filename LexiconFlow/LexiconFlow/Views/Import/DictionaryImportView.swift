//
//  DictionaryImportView.swift
//  LexiconFlow
//
//  Dictionary import view with file selection, preview, and progress tracking
//

import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Dictionary import view with file selection, preview, and progress tracking
struct DictionaryImportView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedFileURL: URL?
    @State private var showingFileImporter = false
    @State private var detectedFormat: DictionaryImporter.ImportFormat?
    @State private var previewCards: [DictionaryImporter.ParsedFlashcard] = []
    @State private var isPreviewLoading = false
    @State private var isImporting = false
    @State private var importProgress: DictionaryImporter.ImportProgress?
    @State private var importResult: DictionaryImporter.ImportResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var fieldMapping: DictionaryImporter.FieldMappingConfiguration = .default

    // MARK: - Constants

    private let logger = Logger(subsystem: "com.lexiconflow.import", category: "DictionaryImportView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // File Selection Section
                Section {
                    if let selectedFileURL {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedFileURL.lastPathComponent)
                                    .font(.headline)
                                if let format = detectedFormat {
                                    Text(format.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button("Change") {
                                self.showingFileImporter = true
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button {
                            self.showingFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Select File")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("File Selection")
                } footer: {
                    Text("Supported formats: CSV, JSON, TXT")
                }

                // Field Mapping Section (CSV/TXT only)
                if let format = detectedFormat, format == .csv || format == .txt {
                    Section {
                        Toggle("Has Header Row", isOn: Binding(
                            get: { self.fieldMapping.hasHeader },
                            set: {
                                self.fieldMapping.hasHeader = $0
                                Task { await self.refreshPreview() }
                            }
                        ))

                        Picker("Word Field", selection: Binding(
                            get: { self.fieldMapping.wordFieldIndex },
                            set: {
                                self.fieldMapping.wordFieldIndex = $0
                                Task { await self.refreshPreview() }
                            }
                        )) {
                            ForEach(0 ..< 10) { index in
                                Text("Column \(index + 1)").tag(index)
                            }
                        }

                        Picker("Definition Field", selection: Binding(
                            get: { self.fieldMapping.definitionFieldIndex },
                            set: {
                                self.fieldMapping.definitionFieldIndex = $0
                                Task { await self.refreshPreview() }
                            }
                        )) {
                            ForEach(0 ..< 10) { index in
                                Text("Column \(index + 1)").tag(index)
                            }
                        }

                        Picker("Phonetic Field", selection: Binding(
                            get: { self.fieldMapping.phoneticFieldIndex ?? -1 },
                            set: {
                                self.fieldMapping.phoneticFieldIndex = $0 == -1 ? nil : $0
                                Task { await self.refreshPreview() }
                            }
                        )) {
                            Text("None").tag(-1)
                            ForEach(0 ..< 10) { index in
                                Text("Column \(index + 1)").tag(index)
                            }
                        }

                        Picker("CEFR Field", selection: Binding(
                            get: { self.fieldMapping.cefrFieldIndex ?? -1 },
                            set: {
                                self.fieldMapping.cefrFieldIndex = $0 == -1 ? nil : $0
                                Task { await self.refreshPreview() }
                            }
                        )) {
                            Text("None").tag(-1)
                            ForEach(0 ..< 10) { index in
                                Text("Column \(index + 1)").tag(index)
                            }
                        }

                        Picker("Translation Field", selection: Binding(
                            get: { self.fieldMapping.translationFieldIndex ?? -1 },
                            set: {
                                self.fieldMapping.translationFieldIndex = $0 == -1 ? nil : $0
                                Task { await self.refreshPreview() }
                            }
                        )) {
                            Text("None").tag(-1)
                            ForEach(0 ..< 10) { index in
                                Text("Column \(index + 1)").tag(index)
                            }
                        }
                    } header: {
                        Text("Field Mapping")
                    } footer: {
                        Text("Map the file columns to flashcard fields.")
                    }
                }

                // Preview Section
                if !self.previewCards.isEmpty {
                    Section {
                        ForEach(self.previewCards.prefix(10), id: \.lineNumber) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(card.word)
                                        .font(.headline)
                                    Spacer()
                                    if let cefrLevel = card.cefrLevel {
                                        Text(cefrLevel)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Theme.Colors.cefrBadge.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(card.definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let phonetic = card.phonetic {
                                    Text(phonetic)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Preview (\(self.previewCards.count) cards)")
                    }
                }

                // Progress Section
                if let progress = importProgress {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Importing...")
                                    .font(.headline)
                                Spacer()
                                Text(progress.percentageText)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress.percentage)

                            Text(progress.currentWord)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Progress")
                    }
                }

                // Import Button Section
                if self.selectedFileURL != nil, self.detectedFormat != nil, !self.isImporting, self.importResult == nil {
                    Section {
                        Button {
                            Task {
                                await self.startImport()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import Dictionary")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(self.previewCards.isEmpty)
                    }
                }

                // Result Section
                if let result = importResult {
                    Section {
                        if result.isSuccess {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 16) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.success)
                                    Text("Import Complete")
                                        .font(.headline)
                                }

                                Divider()

                                HStack {
                                    Text("Imported:")
                                        .foregroundStyle(.secondary)
                                    Text("\(result.imported)")
                                        .font(.headline)
                                }

                                if result.skipped > 0 {
                                    HStack {
                                        Text("Skipped:")
                                            .foregroundStyle(.secondary)
                                        Text("\(result.skipped)")
                                            .foregroundStyle(Theme.Colors.warning)
                                    }
                                }

                                if result.failed > 0 {
                                    HStack {
                                        Text("Failed:")
                                            .foregroundStyle(.secondary)
                                        Text("\(result.failed)")
                                            .foregroundStyle(Theme.Colors.error)
                                    }
                                }

                                HStack {
                                    Text("Duration:")
                                        .foregroundStyle(.secondary)
                                    Text("\(String(format: "%.2f", result.duration))s")
                                }

                                Button("Done") {
                                    self.dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 8)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 16) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.error)
                                    Text("Import Failed")
                                        .font(.headline)
                                }

                                Text("Failed to import dictionary. Please check the file format and try again.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Dismiss") {
                                    self.importResult = nil
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text("Result")
                    }
                }
            }
            .navigationTitle("Import Dictionary")
            .fileImporter(
                isPresented: self.$showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                self.handleFileSelection(result)
            }
            .alert("Error", isPresented: self.$showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(self.errorMessage)
            }
        }
    }

    // MARK: - File Selection Handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            // Request security scope access
            guard url.startAccessingSecurityScopedResource() else {
                self.errorMessage = "Unable to access file"
                self.showingError = true
                return
            }

            self.selectedFileURL = url

            Task {
                await self.detectFormatAndPreview()
                url.stopAccessingSecurityScopedResource()
            }

        case let .failure(error):
            self.errorMessage = error.localizedDescription
            self.showingError = true
        }
    }

    // MARK: - Format Detection and Preview

    private func detectFormatAndPreview() async {
        guard let url = selectedFileURL else { return }

        let importer = DictionaryImporter(modelContext: modelContext)

        // Detect format
        if let format = importer.detectFormat(from: url) {
            self.detectedFormat = format
            self.logger.info("Detected format: \(format.rawValue)")
        } else {
            self.errorMessage = "Unable to detect file format"
            self.showingError = true
            return
        }

        // Load preview
        await self.refreshPreview()
    }

    private func refreshPreview() async {
        guard let url = selectedFileURL,
              let format = detectedFormat else { return }

        self.isPreviewLoading = true

        let importer = DictionaryImporter(modelContext: modelContext)

        do {
            let preview = try await importer.previewImport(
                url,
                format: format,
                fieldMapping: self.fieldMapping,
                limit: 10
            )
            self.previewCards = preview
            self.logger.info("Loaded preview with \(preview.count) cards")
        } catch {
            self.errorMessage = error.localizedDescription
            self.showingError = true
        }

        self.isPreviewLoading = false
    }

    // MARK: - Import

    private func startImport() async {
        guard let url = selectedFileURL,
              let format = detectedFormat else { return }

        self.isImporting = true
        self.importResult = nil

        let importer = DictionaryImporter(modelContext: modelContext)

        do {
            let result = try await importer.importDictionary(
                url,
                format: format,
                fieldMapping: self.fieldMapping,
                into: nil, // Use default deck
                progressHandler: { progress in
                    Task { @MainActor in
                        self.importProgress = progress
                    }
                }
            )

            self.importResult = result
            self.logger.info("Import complete: \(result.imported) imported, \(result.failed) failed")
        } catch {
            self.errorMessage = error.localizedDescription
            self.showingError = true
        }

        self.isImporting = false
        self.importProgress = nil
    }
}

#Preview {
    DictionaryImportView()
        .modelContainer(for: Flashcard.self, inMemory: true)
}
