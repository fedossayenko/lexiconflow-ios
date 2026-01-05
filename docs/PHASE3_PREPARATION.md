# Phase 3: Intelligence & Content - Preparation Guide

## Overview

Phase 3 transforms Lexicon Flow from a functional flashcard app into an intelligent vocabulary acquisition system. This phase integrates on-device AI, translation services, neural text-to-speech, and bulk dictionary import capabilities.

**Timeline**: Weeks 9-12 (4 weeks)
**Target Start**: Week 9 (after Phase 2 completion)
**Key Frameworks**: Foundation Models, Translation, AVFoundation

---

## Phase 3 at a Glance

| Week | Focus | Key Framework | Deliverable |
|------|-------|---------------|-------------|
| **9** | Foundation Models | `FoundationModels` | AI sentence generation |
| **10** | Translation API | `Translation` | Tap-to-translate, batch import |
| **11** | Audio System | `AVSpeechSynthesizer` | Neural TTS with accents |
| **12** | Dictionary Import | `ModelActor` | 10k word import pipeline |

---

## Week 9: Foundation Models Integration

### Objective
Generate contextual example sentences for vocabulary words using on-device AI.

### Technical Requirements

#### Framework Integration
```swift
import FoundationModels
import Observation

@Observable
@MainActor
class LanguageModelService {
    private var session: LanguageModelSession?

    func initialize() async throws {
        // Load default on-device model
        session = try LanguageModelSession()
    }
}
```

#### Prompt Engineering Strategy
```
System Prompt:
"You are a vocabulary teacher for English language learners.
Generate a single, natural example sentence using the word '{word}'.
Constraints:
- Use casual, conversational American English
- Keep sentence under 15 words
- Avoid idioms or slang
- Make context clear for beginners

Output ONLY the sentence, no explanations."

User: "ephemeral"
Assistant: "The beautiful sunset was ephemeral, lasting only a few minutes."
```

### Implementation Plan

#### 1. Model Wrapper Architecture
```swift
// Services/LanguageModelService.swift
actor LanguageModelService {
    private var session: LanguageModelSession?

    func generateSentence(for word: String) async throws -> String {
        guard let session else {
            throw ModelError.notInitialized
        }

        let prompt = buildPrompt(for: word)
        let output = try await session.generate(prompt: prompt)

        return parseSentence(from: output)
    }

    private func buildPrompt(for word: String) -> String {
        """
        Generate a natural example sentence using the word "\(word)".
        Keep it simple, conversational, and under 15 words.
        Output ONLY the sentence.
        """
    }
}
```

#### 2. Caching Strategy
```swift
// Models/GeneratedSentence.swift
@Model
final class GeneratedSentence {
    var word: String
    var sentence: String
    var generatedAt: Date
    var qualityRating: Int? // User feedback 1-5

    init(word: String, sentence: String) {
        self.word = word
        self.sentence = sentence
        self.generatedAt = Date()
    }

    var isExpired: Bool {
        generatedAt.distance(to: Date()) > 7 * 24 * 60 * 60 // 7 days TTL
    }
}
```

#### 3. UI Components
```swift
// Views/SentenceGeneratorView.swift
struct SentenceGeneratorView: View {
    @Bindable var flashcard: Flashcard
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let example = flashcard.exampleSentence {
                Text(example)
                    .font(.body)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Regenerate") {
                        Task { await regenerateSentence() }
                    }
                    .disabled(isGenerating)

                    Spacer()

                    Button("Thumbs Up") {
                        rateSentence(quality: .good)
                    }

                    Button("Thumbs Down") {
                        rateSentence(quality: .poor)
                    }
                }
            } else {
                Button("Generate Example Sentence") {
                    Task { await generateSentence() }
                }
                .disabled(isGenerating)
            }
        }
        .alert("Generation Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func generateSentence() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let service = LanguageModelService.shared
            let sentence = try await service.generateSentence(for: flashcard.word)
            flashcard.exampleSentence = sentence
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Testing Strategy

#### Unit Tests
```swift
// Tests/LanguageModelServiceTests.swift
@Test
func testSentenceGeneration() async throws {
    let service = LanguageModelService.shared
    try await service.initialize()

    let sentence = try await service.generateSentence(for: "ephemeral")

    #expect(sentence.contains("ephemeral"))
    #expect(sentence.count < 100) // Reasonable length
}

@Test
func testSentenceCaching() async throws {
    // Test that repeated requests return cached version
    let service = LanguageModelService.shared
    let word = "test"

    let sentence1 = try await service.generateSentence(for: word)
    let sentence2 = try await service.generateSentence(for: word)

    #expect(sentence1 == sentence2) // Should be cached
}
```

#### Performance Tests
- Generation latency target: <2 seconds on iPhone 15 Pro
- Memory usage target: <50MB increase during generation
- Battery impact: <1% per 10 generations

### Potential Issues & Mitigation

| Issue | Probability | Mitigation |
|-------|-------------|------------|
| Model unavailable on device | Low | Graceful degradation; offer manual input |
| Generation quality inconsistent | Medium | User rating system; prompt iteration |
| Slow generation on older devices | High | Loading indicator; timeout after 5s |
| High memory usage | Low | Release session after use; batch limit |

---

## Week 10: Translation API Integration

### Objective
Enable tap-to-translate for example sentences and batch translation for bulk word imports.

### Technical Requirements

#### Translation Session Manager
```swift
// Services/TranslationService.swift
import Translation

@Observable
@MainActor
class TranslationService: NSObject {
    static let shared = TranslationService()

    private var session: TranslationSession?

    var isTranslationAvailable: Bool {
        TranslationSession.LanguageAvailability(by: .init(languageCode: .english))
            .contains(.init(languageCode: .spanish))
    }

    func initialize() async throws {
        session = try TranslationSession()
    }
}
```

### Implementation Plan

#### 1. Tap-to-Translate UI
```swift
// Views/TranslatableTextView.swift
struct TranslatableTextView: View {
    let text: String
    let sourceLanguage: Locale.Language
    @State private var translatedText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)

            if let translated = translatedText {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.caption)
                    Text(translated)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await translate() }
        }
    }

    private func translate() async {
        guard let session = TranslationService.shared.session else { return }

        do {
            let response = try await session.translate(
                text,
                from: sourceLanguage
            )
            translatedText = response.targetText
        } catch {
            // Handle translation error
        }
    }
}
```

#### 2. Batch Translation for Import
```swift
// Services/BatchTranslationService.swift
actor BatchTranslationService {
    private let session: TranslationSession

    func translateBatch(
        _ words: [String],
        from source: Locale.Language,
        to target: Locale.Language,
        progress: @escaping (Int, Int) -> Void
    ) async throws -> [String: String] {
        var results: [String: String] = [:]
        let batchSize = 10 // Rate limiting

        for index in stride(from: 0, to: words.count, by: batchSize) {
            let batch = Array(words[index..<min(index + batchSize, words.count)])

            for word in batch {
                do {
                    let response = try await session.translate(word, from: source)
                    results[word] = response.targetText
                } catch {
                    results[word] = nil // Mark as failed
                }
            }

            progress(index + batch.count, words.count)

            // Throttle to prevent rate limiting
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        return results
    }
}
```

#### 3. Language Availability Check
```swift
// Utils/TranslationAvailability.swift
struct TranslationAvailability {
    static func checkLanguageSupport(
        _ language: Locale.Language
    ) -> LanguageAvailabilityStatus {
        let availability = TranslationSession.LanguageAvailability(by: .init(languageCode: .english))

        if availability.contains(.init(languageCode: language)) {
            return .available
        } else if availability.requiresAppInstallation(for: .init(languageCode: language)) {
            return .requiresDownload
        } else {
            return .unavailable
        }
    }

    enum LanguageAvailabilityStatus {
        case available
        case requiresDownload
        case unavailable
    }
}
```

#### 4. Share Extension Integration
```swift
// ShareExtension/ShareViewController.swift
@main
struct ShareExtension: App {
    var body: some Scene {
        WindowGroup {
            ShareView()
        }
    }
}

struct ShareView: View {
    @Environment(\.extensionContext) var extensionContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(detectedWords) { word in
                    Button("Create card for '\(word)'") {
                        createFlashcard(for: word)
                    }
                }
            }
            .navigationTitle("Add to Lexicon Flow")
        }
    }

    private var detectedWords: [String] {
        // Extract words from shared text
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let textProvider = item.attachments?.first as? NSItemProvider,
              textProvider.hasItemConformingToTypeIdentifier("public.plain-text") else {
            return []
        }

        // Parse and return unique words
        return ["word1", "word2"] // Placeholder
    }

    private func createFlashcard(for word: String) {
        // Create flashcard and open app
        extensionContext?.completeRequest(returningItems: nil)
    }
}
```

### Testing Strategy

#### Unit Tests
```swift
// Tests/TranslationServiceTests.swift
@Test
func testLanguageAvailability() async throws {
    let service = TranslationService.shared
    try await service.initialize()

    #expect(service.isTranslationAvailable == true)
}

@Test
func testBatchTranslation() async throws {
    let service = BatchTranslationService(session: mockSession)
    let words = ["hello", "world"]

    let results = try await service.translateBatch(
        words,
        from: .english,
        to: .spanish,
        progress: { _, _ in }
    )

    #expect(results.count == 2)
    #expect(results["hello"] == "hola")
}
```

### Offline Support

#### Language Pack Detection
```swift
// Utils/LanguagePackManager.swift
struct LanguagePackManager {
    static func getAvailableLanguagePacks() async throws -> [LanguagePack] {
        let session = try TranslationSession()

        let installed = try await session.installedLanguages
        let available = try await session.availableLanguages

        return available.map { language in
            LanguagePack(
                language: language,
                isInstalled: installed.contains(language),
                size: estimateSize(for: language)
            )
        }
    }

    static func downloadLanguagePack(
        _ language: Locale.Language
    ) async throws {
        let session = try TranslationSession()

        try await session.prepareLanguage(for: language)
        // Show download progress
    }
}

struct LanguagePack: Identifiable {
    let id = UUID()
    let language: Locale.Language
    var isInstalled: Bool
    let size: Int // In bytes
}
```

### Potential Issues & Mitigation

| Issue | Probability | Mitigation |
|-------|-------------|------------|
| Translation unavailable offline | High | Clear UI indication; prompt for download |
| Rate limiting on batch import | Medium | Implement adaptive throttling |
| Unsupported language pairs | Low | Show availability before import |
| Share Extension context passing | Medium | Extensive testing; error handling |

---

## Week 11: Audio System Implementation

### Objective
Provide neural text-to-speech playback with multiple accent options for pronunciation learning.

### Technical Requirements

#### Voice Quality Hierarchy
```
Premium (Enhanced) > Enhanced > Default
```

#### Implementation Architecture
```swift
// Services/SpeechService.swift
import AVFoundation

@Observable
@MainActor
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying = false
    @Published var currentVoice: AVSpeechSynthesisVoice?

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float = 0.5) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        utterance.rate = rate

        synthesizer.speak(utterance)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func synthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isPlaying = true
        }
    }

    nonisolated func synthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isPlaying = false
        }
    }
}
```

### Implementation Plan

#### 1. Voice Selection by Quality
```swift
// Services/VoiceManager.swift
struct VoiceManager {
    enum VoiceQuality: Int, CaseIterable {
        case premium = 2
        case enhanced = 1
        case standard = 0

        var displayName: String {
            switch self {
            case .premium: return "Premium"
            case .enhanced: return "Enhanced"
            case .standard: return "Standard"
            }
        }
    }

    static func getAvailableVoices(
        for language: Locale.Language,
        quality: VoiceQuality = .premium
    ) -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        let languageVoices = allVoices.filter { voice in
            voice.language.hasPrefix(language.identifier)
        }

        // Sort by quality (premium > enhanced > default)
        let sorted = languageVoices.sorted { voice1, voice2 in
            qualityValue(for: voice1) > qualityValue(for: voice2)
        }

        // Filter by requested quality threshold
        return sorted.filter { voice in
            qualityValue(for: voice) >= quality.rawValue
        }
    }

    private static func qualityValue(for voice: AVSpeechSynthesisVoice) -> Int {
        if voice.description.contains("Premium") || voice.description.contains("Enhanced") {
            return VoiceQuality.premium.rawValue
        } else if voice.description.contains("Enhanced") || voice.description.contains("Compact") {
            return VoiceQuality.enhanced.rawValue
        } else {
            return VoiceQuality.standard.rawValue
        }
    }
}
```

#### 2. Accent Selection UI
```swift
// Views/VoiceSettingsView.swift
struct VoiceSettingsView: View {
    @State private var selectedAccent: Locale.Language = .english
    @State private var selectedQuality: VoiceManager.VoiceQuality = .premium
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isPlaying = false

    let accents: [Locale.Language] = [
        .english, // en-US (American)
        .englishUnitedKingdom, // en-GB (British)
        .englishAustralia, // en-AU (Australian)
        .englishIreland // en-IE (Irish)
    ]

    var body: some View {
        Form {
            Section("Accent") {
                Picker("Accent", selection: $selectedAccent) {
                    ForEach(accents, id: \.self) { accent in
                        Text(accent.identifier).tag(accent)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("Voice Quality") {
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(VoiceManager.VoiceQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Available Voices") {
                ForEach(availableVoices, id: \.identifier) { voice in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(voice.name)
                                .font(.headline)
                            Text(voice.language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isPlaying {
                            ProgressView()
                        } else {
                            Button("Test") {
                                testVoice(voice)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Settings")
        .onChange(of: selectedAccent) { _, _ in loadVoices() }
        .onChange(of: selectedQuality) { _, _ in loadVoices() }
        .onAppear { loadVoices() }
    }

    private func loadVoices() {
        availableVoices = VoiceManager.getAvailableVoices(
            for: selectedAccent,
            quality: selectedQuality
        )
    }

    private func testVoice(_ voice: AVSpeechSynthesisVoice) {
        SpeechService.shared.currentVoice = voice
        SpeechService.shared.speak("Hello, this is a test of the voice quality.")
    }
}
```

#### 3. Playback Rate Controls
```swift
// Views/SpeechControlsView.swift
struct SpeechControlsView: View {
    let text: String
    @State private var playbackRate: Double = 0.5
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 16) {
            // Play/Pause button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
            }

            // Rate slider
            VStack(alignment: .leading) {
                Text("Speed: \(rateLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $playbackRate, in: 0.25...1.0) {
                    Text("Playback Rate")
                }
            }
            .padding(.horizontal)

            // Speed presets
            HStack(spacing: 12) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { rate in
                    Button(rateLabel(for: rate)) {
                        playbackRate = rate
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: playbackRate) { _, newValue in
            if isPlaying {
                // Restart with new rate
                SpeechService.shared.speak(text, rate: Float(newValue))
            }
        }
    }

    private var rateLabel: String {
        if playbackRate <= 0.33 { return "Slow" }
        if playbackRate <= 0.66 { return "Normal" }
        return "Fast"
    }

    private func rateLabel(for rate: Double) -> String {
        if rate == 0.25 { return "0.25x" }
        if rate == 0.5 { return "0.5x" }
        if rate == 0.75 { return "0.75x" }
        return "1.0x"
    }

    private func togglePlayback() {
        if isPlaying {
            SpeechService.shared.synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
        } else {
            SpeechService.shared.speak(text, rate: Float(playbackRate))
            isPlaying = true
        }
    }
}
```

#### 4. Auto-Play on Card Flip
```swift
// ViewModels/StudySessionViewModel.swift
@MainActor
class StudySessionViewModel: ObservableObject {
    @AppStorage("autoPlayPronunciation") private var autoPlay = true

    func flipCard() {
        isFlipped.toggle()

        if isFlipped && autoPlay {
            playPronunciation()
        }
    }

    private func playPronunciation() {
        guard let card = currentCard else { return }

        SpeechService.shared.speak(
            card.word,
            rate: Float(AppSettings.playbackRate)
        )
    }
}
```

#### 5. Premium Voice Download Prompt
```swift
// Views/VoiceDownloadPromptView.swift
struct VoiceDownloadPromptView: View {
    let requiredVoice: AVSpeechSynthesisVoice
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Alert(
            title: Text("Premium Voice Required"),
            message: Text("""
                This feature requires a premium voice download (~150MB).
                Download now to enable enhanced pronunciation.
            """),
            primaryButton: .default(Text("Download"), action: onConfirm),
            secondaryButton: .cancel(Text("Later"), action: onCancel)
        )
    }

    static func checkAndPrompt(
        for voice: AVSpeechSynthesisVoice,
        in context: View
    ) -> some View {
        // Logic to check if premium voice is installed
        // and prompt if not
        context
    }
}
```

### Testing Strategy

#### Unit Tests
```swift
// Tests/SpeechServiceTests.swift
@Test
func testVoiceAvailability() async throws {
    let voices = VoiceManager.getAvailableVoices(
        for: .english,
        quality: .premium
    )

    #expect(voices.isEmpty == false)
}

@Test
func testPlaybackRateControl() async throws {
    let service = SpeechService.shared

    // Test different rates
    let rates: [Float] = [0.25, 0.5, 0.75, 1.0]

    for rate in rates {
        service.speak("Test", rate: rate)
        // Verify rate is applied
    }
}
```

#### Performance Tests
- Playback latency target: <100ms
- Memory usage target: <20MB
- Battery impact: <0.5% per 100 playbacks

### Potential Issues & Mitigation

| Issue | Probability | Mitigation |
|-------|-------------|------------|
| Premium voices require download | High | Clear UI prompt; optional feature |
| Playback interrupted by system | Medium | Handle interruptions gracefully |
| Voice quality varies by iOS version | Low | Fallback to lower quality |
| Audio focus conflicts with music | Medium | Respect audio session categories |

---

## Week 12: Dictionary Import Pipeline

### Objective
Enable bulk import of 10,000 curated vocabulary words with definitions, pronunciations, and example sentences.

### Technical Requirements

#### JSON Import Format Specification
```json
{
  "version": "1.0",
  "metadata": {
    "title": "English Vocabulary Builder",
    "description": "10,000 essential English words",
    "wordCount": 10000,
    "language": "en",
    "targetLevel": "B2-C1"
  },
  "words": [
    {
      "word": "ephemeral",
      "phonetic": "/ɪˈfem.ər.əl/",
      "partOfSpeech": "adjective",
      "definition": "lasting for only a short time",
      "exampleSentence": "The beautiful sunset was ephemeral, lasting only a few minutes.",
      "difficulty": 4,
      "frequencyRank": 5234,
      "tags": ["academic", "literary"]
    }
  ]
}
```

### Implementation Plan

#### 1. ModelActor for Background Import
```swift
// Services/DictionaryImporter.swift
import SwiftData

actor DictionaryImporter: ModelActor {
    let modelExecutor: ModelExecutor
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.modelExecutor = modelContext.modelExecutor
    }

    func importDictionary(
        from url: URL,
        into deck: Deck,
        progress: @escaping (ImportProgress) -> Void
    ) async throws -> ImportResult {
        // Decode JSON
        let data = try Data(contentsOf: url)
        let dictionary = try JSONDecoder().decode(DictionaryFormat.self, from: data)

        var successCount = 0
        var failureCount = 0

        let totalWords = dictionary.words.count

        // Batch insert to avoid memory pressure
        let batchSize = 100

        for index in stride(from: 0, to: totalWords, by: batchSize) {
            let batch = Array(dictionary.words[index..<min(index + batchSize, totalWords)])

            for wordData in batch {
                do {
                    let flashcard = Flashcard(from: wordData, deck: deck)
                    modelContext.insert(flashcard)
                    successCount += 1
                } catch {
                    failureCount += 1
                    logger.error("Failed to import word: \(wordData.word)")
                }
            }

            // Save batch
            try modelContext.save()

            // Report progress
            progress(ImportProgress(
                completed: index + batch.count,
                total: totalWords,
                currentWord: batch.last?.word ?? ""
            ))
        }

        return ImportResult(
            totalCount: totalWords,
            successCount: successCount,
            failureCount: failureCount
        )
    }
}

struct DictionaryFormat: Codable {
    let version: String
    let metadata: Metadata
    let words: [WordData]

    struct Metadata: Codable {
        let title: String
        let description: String
        let wordCount: Int
        let language: String
        let targetLevel: String
    }

    struct WordData: Codable {
        let word: String
        let phonetic: String?
        let partOfSpeech: String?
        let definition: String
        let exampleSentence: String?
        let difficulty: Int?
        let frequencyRank: Int?
        let tags: [String]?
    }
}

struct ImportProgress {
    let completed: Int
    let total: Int
    let currentWord: String

    var fractionCompleted: Double {
        Double(completed) / Double(total)
    }
}

struct ImportResult {
    let totalCount: Int
    let successCount: Int
    let failureCount: Int
}
```

#### 2. Flashcard Initialization from Import Data
```swift
// Models/Flashcard+Import.swift
extension Flashcard {
    init(from wordData: DictionaryImporter.WordData, deck: Deck) {
        self.init(
            word: wordData.word,
            definition: wordData.definition,
            phonetic: wordData.phonetic,
            partOfSpeech: wordData.partOfSpeech,
            exampleSentence: wordData.exampleSentence,
            deck: deck
        )

        // Initialize FSRS state
        self.fsrsState = FSRSState(
            flashcard: self,
            state: .new,
            stability: 0.0,
            difficulty: 0.0
        )
    }
}
```

#### 3. Import Progress UI
```swift
// Views/DictionaryImportProgressView.swift
struct DictionaryImportProgressView: View {
    @State private var progress: ImportProgress?
    @State private var result: ImportResult?
    @State private var isImporting = false
    @State private var errorMessage: String?

    let deck: Deck
    let fileURL: URL

    var body: some View {
        VStack(spacing: 24) {
            if isImporting, let progress = progress {
                // Progress visualization
                VStack(spacing: 16) {
                    ProgressView(value: progress.fractionCompleted)

                    Text("\(progress.completed) / \(progress.total) words")
                        .font(.headline)

                    Text("Importing: \(progress.currentWord)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

            } else if let result = result {
                // Result summary
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Import Complete!")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Success:")
                            Spacer()
                            Text("\(result.successCount)").foregroundStyle(.green)
                        }

                        if result.failureCount > 0 {
                            HStack {
                                Text("Failed:")
                                Spacer()
                                Text("\(result.failureCount)").foregroundStyle(.red)
                            }
                        }

                        Divider()

                        HStack {
                            Text("Total:")
                            Spacer()
                            Text("\(result.totalCount)")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.callout)
                }

            } else {
                // Start import button
                Button("Start Import") {
                    Task { await startImport() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Import Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func startImport() async {
        isImporting = true

        do {
            let importer = DictionaryImporter(modelContext: modelContext)

            let importResult = try await importer.importDictionary(
                from: fileURL,
                into: deck,
                progress: { progress in
                    Task { @MainActor in
                        self.progress = progress
                    }
                }
            )

            result = importResult
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }
}
```

#### 4. Cancellation Support
```swift
// Services/DictionaryImporter.swift
actor DictionaryImporter: ModelActor {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func importDictionary(
        from url: URL,
        into deck: Deck,
        progress: @escaping (ImportProgress) -> Void
    ) async throws -> ImportResult {
        isCancelled = false

        // ... existing import logic ...

        for index in stride(from: 0, to: totalWords, by: batchSize) {
            // Check for cancellation
            if isCancelled {
                throw ImportError.cancelled
            }

            // ... batch processing ...
        }

        return result
    }
}

enum ImportError: Error {
    case cancelled
    case invalidFormat
    case fileNotFound
}
```

#### 5. Incremental Updates
```swift
// Services/DictionaryUpdater.swift
actor DictionaryUpdater {
    func updateExistingCards(
        from url: URL,
        modelContext: ModelContext
    ) async throws -> UpdateResult {
        // Fetch existing cards
        let descriptor = FetchDescriptor<Flashcard>()
        let existingCards = try modelContext.fetch(descriptor)
        let existingWords = Set(existingCards.map { $0.word })

        // Load new dictionary
        let data = try Data(contentsOf: url)
        let dictionary = try JSONDecoder().decode(DictionaryFormat.self, from: data)

        var updatedCount = 0
        var addedCount = 0

        for wordData in dictionary.words {
            if existingWords.contains(wordData.word) {
                // Update existing card
                if let card = existingCards.first(where: { $0.word == wordData.word }) {
                    card.definition = wordData.definition
                    card.exampleSentence = wordData.exampleSentence
                    updatedCount += 1
                }
            } else {
                // Add new card
                // ... insert logic ...
                addedCount += 1
            }
        }

        try modelContext.save()

        return UpdateResult(
            updatedCount: updatedCount,
            addedCount: addedCount
        )
    }
}

struct UpdateResult {
    let updatedCount: Int
    let addedCount: Int
}
```

#### 6. Batch Image Processing (Optional)
```swift
// Services/ImageProcessor.swift
actor ImageProcessor {
    func processImagesForCards(
        _ cards: [Flashcard],
        progress: @escaping (Int, Int) -> Void
    ) async throws {
        let batchSize = 10

        for index in stride(from: 0, to: cards.count, by: batchSize) {
            let batch = Array(cards[index..<min(index + batchSize, cards.count)])

            await withTaskGroup(of: Void.self) { group in
                for card in batch {
                    group.addTask {
                        await self.fetchAndAttachImage(for: card)
                    }
                }
            }

            progress(index + batch.count, cards.count)
        }
    }

    private func fetchAndAttachImage(for card: Flashcard) async {
        // Use image search API or local database
        // Download image, resize, and attach to card
    }
}
```

### Testing Strategy

#### Unit Tests
```swift
// Tests/DictionaryImporterTests.swift
@Test
func testJSONDecoding() async throws {
    let jsonString = """
    {
      "version": "1.0",
      "metadata": {
        "title": "Test Dictionary",
        "description": "Test",
        "wordCount": 1,
        "language": "en",
        "targetLevel": "B2"
      },
      "words": [
        {
          "word": "test",
          "phonetic": "/test/",
          "partOfSpeech": "noun",
          "definition": "a test",
          "exampleSentence": "This is a test.",
          "difficulty": 1,
          "frequencyRank": 100,
          "tags": ["test"]
        }
      ]
    }
    """

    let data = jsonString.data(using: .utf8)!
    let dictionary = try JSONDecoder().decode(DictionaryFormat.self, from: data)

    #expect(dictionary.words.count == 1)
    #expect(dictionary.words.first?.word == "test")
}

@Test
func testBatchImport() async throws {
    let container = try ModelContainer(for: Flashcard.self, configurations: [.init(isStoredInMemoryOnly: true)])
    let context = ModelContext(container)

    let deck = Deck(name: "Test")
    context.insert(deck)

    let importer = DictionaryImporter(modelContext: context)

    let result = try await importer.importDictionary(
        from: testDictionaryURL,
        into: deck,
        progress: { _, _ in }
    )

    #expect(result.successCount > 0)
}
```

#### Performance Tests
- Import target: <30 seconds for 10,000 words
- Memory usage: <200MB peak during import
- Database size: ~50MB for 10,000 cards (without images)

### Potential Issues & Mitigation

| Issue | Probability | Mitigation |
|-------|-------------|------------|
| Large file memory pressure | Medium | Batch processing; stream parsing |
| Duplicate words in import | High | Deduplication logic |
| Invalid JSON format | Medium | Validation; error recovery |
| Import interruption | Low | Cancellation support; resume |
| Database corruption | Low | Transactions; error handling |

---

## Cross-Cutting Concerns

### Error Handling

All services should implement proper error handling:
```swift
enum Phase3Error: Error {
    case modelNotAvailable
    case translationFailed(underlying: Error)
    case voiceNotAvailable
    case importFailed(reason: String)
    case networkUnavailable

    var localizedDescription: String {
        switch self {
        case .modelNotAvailable:
            return "AI model is not available on this device."
        case .translationFailed(let error):
            return "Translation failed: \(error.localizedDescription)"
        case .voiceNotAvailable:
            return "Selected voice is not available."
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .networkUnavailable:
            return "Network connection is required."
        }
    }
}
```

### Analytics Integration

Track usage for all Phase 3 features:
```swift
// Utils/Analytics+Phase3.swift
extension Analytics {
    enum Phase3Event {
        static func sentenceGenerated(word: String, qualityRating: Int?) {
            track("sentence_generated", properties: [
                "word": word,
                "quality_rating": qualityRating ?? 0
            ])
        }

        static func translationRequested(sourceLanguage: String, targetLanguage: String) {
            track("translation_requested", properties: [
                "source": sourceLanguage,
                "target": targetLanguage
            ])
        }

        static func voicePlayback(accent: String, rate: Double) {
            track("voice_playback", properties: [
                "accent": accent,
                "rate": rate
            ])
        }

        static func dictionaryStarted(wordCount: Int) {
            track("dictionary_import_started", properties: [
                "word_count": wordCount
            ])
        }

        static func dictionaryCompleted(successCount: Int, failureCount: Int) {
            track("dictionary_import_completed", properties: [
                "success_count": successCount,
                "failure_count": failureCount
            ])
        }
    }
}
```

### Settings Integration

Add Phase 3-specific settings:
```swift
// Utils/AppSettings+Phase3.swift
extension AppSettings {
    // Foundation Models
    @AppStorage("sentenceCachingEnabled") static var sentenceCachingEnabled = true
    @AppStorage("sentenceCacheTTL") static var sentenceCacheTTL: TimeInterval = 7 * 24 * 60 * 60

    // Translation
    @AppStorage("autoTranslateOnImport") static var autoTranslateOnImport = false
    @AppStorage("preferredTranslationLanguage") static var preferredTranslationLanguage = "es"

    // Audio
    @AppStorage("autoPlayPronunciation") static var autoPlayPronunciation = true
    @AppStorage("preferredAccent") static var preferredAccent = "en-US"
    @AppStorage("playbackRate") static var playbackRate: Double = 0.5

    // Dictionary
    @AppStorage("lastImportDate") static var lastImportDate: Date?
    @AppStorage("importedImageQuality") static var importedImageQuality = "medium"
}
```

---

## Exit Criteria Verification

### Week 9: Foundation Models
- [ ] LanguageModelService generates coherent sentences
- [ ] Generation completes in <2 seconds on iPhone 15 Pro
- [ ] Sentence caching works correctly with 7-day TTL
- [ ] User can rate and regenerate sentences
- [ ] Graceful fallback when model unavailable

### Week 10: Translation API
- [ ] Tap-to-translate works on example sentences
- [ ] Batch translation handles 100+ words
- [ ] Language availability checking works
- [ ] Offline language pack download prompts appear
- [ ] Share Extension successfully creates cards

### Week 11: Audio System
- [ ] Neural voices play with correct accent
- [ ] Voice quality selector works (Premium > Enhanced > Default)
- [ ] Playback rate slider controls speed
- [ ] Auto-play on card flip works
- [ ] Premium voice download prompt appears

### Week 12: Dictionary Import
- [ ] 10,000-word JSON imports in <30 seconds
- [ ] Progress UI shows accurate completion percentage
- [ ] Cancellation stops import mid-process
- [ ] Incremental updates modify existing cards
- [ ] Batch image processing attaches images

---

## Dependencies and Prerequisites

### System Requirements
- iOS 26.0+
- iPhone 13 or newer (for Foundation Models)
- 500MB free storage (for dictionary + language packs)

### Framework Availability
- `FoundationModels` - iOS 26+
- `Translation` - iOS 18+
- `AVFoundation` - iOS 8+

### External Resources
- 10,000-word English dictionary (licensed or open-source)
- Image database (optional) for word illustrations
- Translation language packs (downloaded on-demand)

### Existing Code Readiness
- [x] SwiftData models (Flashcard, Deck, FSRSState)
- [x] ModelActor infrastructure (DataImporter)
- [x] AppSettings infrastructure
- [x] Analytics infrastructure
- [x] KeychainManager for API keys (if needed)

---

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Foundation Models quality** | High | Medium | User rating system; manual input fallback |
| **Translation offline limits** | Medium | High | Clear UI indication; download prompts |
| **Premium voice size** | Medium | High | Optional feature; progressive download |
| **Dictionary license cost** | Low | Medium | Use open-source (Wiktionary, ETS) |
| **Import performance** | Medium | Low | Batch processing; background threading |
| **Memory pressure** | High | Low | Streaming; incremental processing |

---

## Next Steps

1. **Week 9 Start Date**: Confirm after Phase 2 completion
2. **Resource Allocation**: 1 iOS Engineer (full-time)
3. **Beta Access**: Apply for Translation API access (if needed)
4. **Dictionary Acquisition**: License 10k word dataset
5. **Test Devices**: Ensure iPhone 13+ available for testing

---

## Glossary

- **Foundation Models**: Apple's on-device AI framework
- **Language Pack**: Downloadable translation data for offline use
- **Neural TTS**: Text-to-speech using neural networks
- **ModelActor**: SwiftData actor for background operations
- **Sentence Caching**: Storing AI-generated sentences locally

---

**Document Version**: 1.0
**Created**: January 2026
**Phase**: 3 (Intelligence & Content)
**Duration**: 4 weeks (Weeks 9-12)
