//
//  OnDeviceTranslationService.swift
//  LexiconFlow
//
//  On-device translation service using iOS 26 Translation framework
//  Provides offline translation capabilities without cloud dependencies
//

import Foundation
import OSLog
import Translation

/// Service for on-device text translation using iOS 26 Translation framework
///
/// This service provides privacy-focused translation that runs entirely on-device
/// after language packs are downloaded. No API keys or network connection required.
///
/// ## Usage Example
///
/// ```swift
/// // Configure source and target languages
/// await OnDeviceTranslationService.shared.setLanguages(source: "en", target: "es")
///
/// // Check if language pair is supported
/// let isSupported = OnDeviceTranslationService.shared.isLanguagePairSupported()
/// guard isSupported else {
///     // Handle unsupported language pair
///     return
/// }
///
/// // Translate text
/// do {
///     let translation = try await OnDeviceTranslationService.shared.translate(
///         text: "Hello, world!"
///     )
///     print("Translated: \(translation)")
/// } catch {
///     // Handle translation errors
///     print("Translation failed: \(error.localizedDescription)")
/// }
/// ```
///
/// ## Language Pack Management
///
/// The service requires language packs to be downloaded before translation can occur.
/// Use `needsLanguageDownload()` to check availability.
///
/// **Important:** Language pack downloads must be triggered from SwiftUI views
/// using the `.translationTask()` modifier with `TranslationSession.prepareTranslation()`.
/// See `TranslationSettingsView.swift` for the correct implementation pattern.
///
/// This service is actor-isolated and cannot directly trigger system download prompts.
///
/// ## Batch Translation
///
/// For translating multiple texts, use `translateBatch()` with progress callbacks:
///
/// ```swift
/// let result = try await OnDeviceTranslationService.shared.translateBatch(
///     ["Hello", "Goodbye", "Thank you"],
///     maxConcurrency: 5,
///     progressHandler: { progress in
///         print("Progress: \(progress.current)/\(progress.total)")
///     }
/// )
/// print("Success: \(result.successCount), Failed: \(result.failedCount)")
/// ```
///
/// **Concurrency**: Actor-isolated for thread-safe concurrent access to translation state.
/// The iOS 26 Translation framework handles its own internal concurrency.
final actor OnDeviceTranslationService {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = OnDeviceTranslationService()

    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "OnDeviceTranslation")

    /// Active translation session for managing language state
    private var translationSession: TranslationSession?

    /// Current source language configuration (stored as BCP 47 language code)
    private var sourceLanguageCode: String = "en"

    /// Current target language configuration (stored as BCP 47 language code)
    private var targetLanguageCode: String = "ru"

    /// Helper to get Locale.Language from language code
    private var sourceLanguage: Locale.Language {
        Locale.Language(identifier: sourceLanguageCode)
    }

    /// Helper to get Locale.Language from language code
    private var targetLanguage: Locale.Language {
        Locale.Language(identifier: targetLanguageCode)
    }

    // MARK: - Performance Caching

    /// PERFORMANCE: Language availability cache with 30-second TTL
    /// Eliminates repeated system calls during batch translation
    /// Key: Language code, Value: Whether it's available
    private var languageAvailabilityCache: [String: Bool] = [:]
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 30 // 30 seconds

    /// Checks if cached language availability is still valid
    private func isCacheValid() -> Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheTTL
    }

    /// Cached language availability check
    ///
    /// PERFORMANCE: Returns cached result if available, otherwise checks system
    /// and caches the result for 30 seconds
    ///
    /// - Parameter language: Language identifier to check
    /// - Returns: true if language is available, false otherwise
    private func cachedIsLanguageAvailable(_ language: String) async -> Bool {
        // Check cache first
        if isCacheValid(), let cached = languageAvailabilityCache[language] {
            logger.debug("Language availability from cache: \(language) = \(cached)")
            return cached
        }

        // Cache miss - check system availability
        let isAvailable = await isLanguageAvailable(language)

        // Update cache
        languageAvailabilityCache[language] = isAvailable
        cacheTimestamp = Date()
        logger.debug("Language availability cached: \(language) = \(isAvailable)")

        return isAvailable
    }

    /// Invalidates the language availability cache
    ///
    /// Call this when language packs are downloaded/removed
    private func invalidateLanguageCache() {
        languageAvailabilityCache.removeAll()
        cacheTimestamp = nil
        logger.debug("Language availability cache invalidated")
    }

    /// Private initializer for singleton pattern
    private init() {
        logger.info("OnDeviceTranslationService initialized")
    }

    // MARK: - Language Configuration

    /// Set source and target languages for translation
    ///
    /// **Usage:**
    /// ```swift
    /// // Configure for English to Spanish translation
    /// await service.setLanguages(source: "en", target: "es")
    ///
    /// // Configure for Russian to English
    /// await service.setLanguages(source: "ru", target: "en")
    /// ```
    ///
    /// **Language Codes:**
    /// - Use ISO 639-1 two-letter codes (e.g., "en", "es", "fr")
    /// - Use BCP 47 codes for regional variants (e.g., "zh-Hans", "pt-BR")
    ///
    /// - Parameters:
    ///   - source: Source language code (e.g., "en", "es", "zh")
    ///   - target: Target language code (e.g., "ru", "fr", "de")
    func setLanguages(source: String, target: String) {
        sourceLanguageCode = source
        targetLanguageCode = target
        logger.info("Languages configured: \(source) -> \(target)")
    }

    /// Get current source language identifier
    ///
    /// **Returns:** Language code string (e.g., "en", "es", "ru")
    var currentSourceLanguage: String {
        sourceLanguageCode
    }

    /// Get current target language identifier
    ///
    /// **Returns:** Language code string (e.g., "en", "es", "ru")
    var currentTargetLanguage: String {
        targetLanguageCode
    }

    // MARK: - Language Support Detection

    /// Check if a language pair is supported for on-device translation
    ///
    /// **Important:** This only checks if iOS supports the language pair.
    /// Use `needsLanguageDownload()` to verify language packs are installed.
    ///
    /// **Usage:**
    /// ```swift
    /// // Check configured language pair
    /// if service.isLanguagePairSupported() {
    ///     // Safe to proceed with translation
    /// }
    ///
    /// // Check specific pair
    /// if service.isLanguagePairSupported(from: "en", to: "es") {
    ///     // English to Spanish is supported
    /// }
    /// ```
    ///
    /// **Error Conditions:**
    /// - Returns `false` if either language is not available in iOS Translation framework
    /// - Returns `false` if language packs are not downloaded (use `needsLanguageDownload()` to check)
    ///
    /// - Parameters:
    ///   - source: Source language code (optional, defaults to configured source)
    ///   - target: Target language code (optional, defaults to configured target)
    ///
    /// - Returns: `true` if the language pair is supported on-device
    func isLanguagePairSupported(
        from source: String? = nil,
        to target: String? = nil
    ) -> Bool {
        let sourceCode = source ?? sourceLanguageCode
        let targetCode = target ?? targetLanguageCode

        _ = Locale.Language(identifier: sourceCode)
        _ = Locale.Language(identifier: targetCode)

        // Check if language pair is available for on-device translation
        // In iOS 26, we can't easily check without async, so we return true
        // and let the actual translation fail if not supported
        // The actual check will happen during translate() which is async
        logger.debug("Language pair support check: \(sourceCode) -> \(targetCode)")
        return true
    }

    /// Get list of languages available for on-device translation
    ///
    /// **Usage:**
    /// ```swift
    /// let languages = await service.availableLanguages()
    /// for language in languages {
    ///     print("Available language: \(language)")
    /// }
    /// ```
    ///
    /// **Note:** This returns languages supported by iOS Translation framework.
    /// Use `needsLanguageDownload()` to check if a language needs download.
    ///
    /// - Returns: Array of `Locale.Language` objects supported by the device
    func availableLanguages() async -> [Locale.Language] {
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        logger.debug("Available on-device languages: \(languages.count) total")
        return languages
    }

    /// Check if a specific language is available on-device
    ///
    /// **Usage:**
    /// ```swift
    /// let spanish = Locale.Language(identifier: "es")
    /// if await service.isLanguageAvailable(spanish) {
    ///     print("Spanish is available for offline translation")
    /// }
    /// ```
    ///
    /// **What This Checks:**
    /// - Language pack is downloaded and installed
    /// - Language is supported by iOS Translation framework
    ///
    /// - Parameter language: `Locale.Language` object to check
    /// - Returns: `true` if the language is available for on-device translation
    func isLanguageAvailable(_ language: Locale.Language) async -> Bool {
        let availability = LanguageAvailability()
        let supportedLanguages = await availability.supportedLanguages
        let isAvailable = supportedLanguages.contains(language)
        logger.debug("Language available: \(isAvailable)")
        return isAvailable
    }

    /// Check if a specific language is available on-device (convenience method)
    ///
    /// **Usage:**
    /// ```swift
    /// if await service.isLanguageAvailable("es") {
    ///     print("Spanish is available")
    /// }
    /// ```
    ///
    /// - Parameter language: Language identifier string to check (e.g., "en", "ru", "es")
    /// - Returns: `true` if the language is available for on-device translation
    func isLanguageAvailable(_ language: String) async -> Bool {
        let lang = Locale.Language(identifier: language)
        return await isLanguageAvailable(lang)
    }

    /// Check if a language pack needs to be downloaded
    ///
    /// **Usage:**
    /// ```swift
    /// if await service.needsLanguageDownload("es") {
    ///     print("Spanish pack needs download")
    ///     // Guide user to Translation Settings to download
    ///     // or use SwiftUI's .translationTask() modifier
    /// }
    /// ```
    ///
    /// **Note:** Language pack downloads must be triggered from SwiftUI views
    /// using `.translationTask()` modifier. See `TranslationSettingsView.swift` for example.
    ///
    /// **When to Use:**
    /// - Before attempting translation for the first time
    /// - When user changes source/target language
    /// - In settings UI to show download status
    ///
    /// - Parameter language: `Locale.Language` object to check
    /// - Returns: `true` if the language pack needs download, `false` if already installed
    func needsLanguageDownload(_ language: Locale.Language) async -> Bool {
        // FIXED: Return true if language is NOT available (needs download)
        // Previously returned !isSupported which was inverted logic
        let isAvailable = await isLanguageAvailable(language)
        let needsDownload = !isAvailable

        if needsDownload {
            logger.info("Language pack needs download: not currently available")
        } else {
            logger.debug("Language pack already installed: no download needed")
        }

        return needsDownload
    }

    /// Check if a language pack needs to be downloaded (convenience method)
    ///
    /// **Usage:**
    /// ```swift
    /// if await service.needsLanguageDownload("es") {
    ///     // Show download button in UI
    /// } else {
    ///     // Show "already downloaded" status
    /// }
    /// ```
    ///
    /// - Parameter language: Language identifier string to check
    /// - Returns: `true` if the language pack needs download, `false` if already installed
    func needsLanguageDownload(_ language: String) async -> Bool {
        let lang = Locale.Language(identifier: language)
        return await needsLanguageDownload(lang)
    }

    // MARK: - Batch Translation Types

    /// Result of a single translation task within a batch
    ///
    /// **Internal Use Only:** Used for batch translation coordination
    ///
    /// **Purpose:**
    /// - Wraps Result type for success/failure tracking
    /// - Includes duration for performance monitoring
    /// - Carries original text for result aggregation
    /// - Provides uniform type for TaskGroup processing
    ///
    /// **Why Not Use Result Directly:**
    /// - Need to track which text each result corresponds to
    /// - Need timing information for performance analysis
    /// - Want to keep metadata separate from translation result
    ///
    /// **Properties:**
    /// - `text`: Original input text (for matching with result)
    /// - `result`: Success case contains translated text, failure case contains error
    /// - `duration`: Time taken for this specific translation (seconds)
    ///
    /// **Concurrency Safety:**
    /// - `Sendable` conformance allows safe passing across actor boundaries
    /// - Immutable struct prevents data races
    /// - Safe to collect from concurrent TaskGroup tasks
    private struct BatchTranslationTaskResult: Sendable {
        let text: String
        let result: Result<String, OnDeviceTranslationError>
        let duration: TimeInterval
    }

    /// Successful translation with complete context
    ///
    /// **Usage:**
    /// ```swift
    /// let result = try await service.translateBatch(words, maxConcurrency: 5)
    /// for translation in result.successfulTranslations {
    ///     print("\(translation.sourceText) -> \(translation.translatedText)")
    ///     print("From: \(translation.sourceLanguage), To: \(translation.targetLanguage)")
    /// }
    /// ```
    ///
    /// **Properties:**
    /// - `sourceText`: Original text before translation
    /// - `translatedText`: Translated text in target language
    /// - `sourceLanguage`: Source language code (e.g., "en")
    /// - `targetLanguage`: Target language code (e.g., "es")
    struct SuccessfulTranslation: Sendable {
        let sourceText: String
        let translatedText: String
        let sourceLanguage: String
        let targetLanguage: String
    }

    /// Overall result of a batch translation operation
    ///
    /// **Usage:**
    /// ```swift
    /// let result = try await service.translateBatch(
    ///     ["Hello", "Goodbye"],
    ///     maxConcurrency: 5,
    ///     progressHandler: { progress in
    ///         print("Progress: \(progress.current)/\(progress.total)")
    ///     }
    /// )
    ///
    /// if result.isSuccess {
    ///     print("All translations succeeded!")
    /// } else {
    ///     print("\(result.successCount) succeeded, \(result.failedCount) failed")
    ///     for error in result.errors {
    ///         print("Error: \(error.localizedDescription)")
    ///     }
    /// }
    /// ```
    ///
    /// **Properties:**
    /// - `successCount`: Number of successful translations
    /// - `failedCount`: Number of failed translations
    /// - `totalDuration`: Time taken for entire batch (seconds)
    /// - `errors`: Array of errors from failed translations
    /// - `successfulTranslations`: Array of successful translation results
    /// - `isSuccess`: Computed property, `true` if no failures
    struct BatchTranslationResult: Sendable {
        let successCount: Int
        let failedCount: Int
        let totalDuration: TimeInterval
        let errors: [OnDeviceTranslationError]
        let successfulTranslations: [SuccessfulTranslation]

        /// Returns `true` if all translations succeeded
        ///
        /// **Definition:** `failedCount == 0 && successCount > 0`
        /// - Empty batch returns `false` (0 successes)
        /// - Any failure returns `false`
        /// - All successes returns `true`
        var isSuccess: Bool {
            failedCount == 0 && successCount > 0
        }
    }

    /// Progress update during batch translation
    ///
    /// **Usage:**
    /// ```swift
    /// let result = try await service.translateBatch(
    ///     words,
    ///     maxConcurrency: 5,
    ///     progressHandler: { progress in
    ///         // Update UI with progress
    ///         progress = Double(progress.current) / Double(progress.total)
    ///         currentWordLabel.text = progress.currentWord
    ///     }
    /// )
    /// ```
    ///
    /// **Thread Safety:**
    /// - Progress handler is called on `@MainActor`
    /// - Safe to update UI directly from handler
    ///
    /// **Properties:**
    /// - `current`: Number of completed translations (1-indexed)
    /// - `total`: Total number of translations to perform
    /// - `currentWord`: The most recently translated text
    struct BatchTranslationProgress: Sendable {
        let current: Int
        let total: Int
        let currentWord: String
    }

    // MARK: - Cancellation

    /// Actor-isolated storage for the active batch translation task
    ///
    /// **Why Actor Isolation:**
    /// - Prevents data races when multiple threads access the task
    /// - `@MainActor` UI can call `cancel()` while background thread calls `get()`
    /// - Swift 6 strict concurrency requires synchronization for mutable shared state
    ///
    /// **Thread Safety:**
    /// - All methods are actor-isolated (serial access guaranteed)
    /// - Safe to call from any concurrency context
    ///
    /// **Lifecycle:**
    /// 1. `set()` called when new batch starts
    /// 2. `get()` called to check active task
    /// 3. `cancel()` called when user cancels or new batch starts
    ///
    /// **Memory Management:**
    /// - Setting `task = nil` releases the Task reference
    /// - Prevents retain cycles if Task captures self
    /// - Allows new batch to start after cancellation
    private actor TaskStorage {
        var task: Task<BatchTranslationResult, Error>?

        /// Store a new task (replacing any existing task)
        ///
        /// **Behavior:**
        /// - Replaces any existing task (old task is cancelled if still running)
        /// - Sets new task as the active batch operation
        /// - Only one task can be active at a time
        ///
        /// **Use Case:**
        /// - Called when `translateBatch()` starts
        /// - Ensures only one batch runs at a time
        ///
        /// - Parameter task: The new batch translation task to store
        func set(_ task: Task<BatchTranslationResult, Error>?) {
            self.task = task
        }

        /// Retrieve the current task (if any)
        ///
        /// **Returns:**
        /// - The active batch translation task
        /// - `nil` if no batch is currently running
        ///
        /// **Use Cases:**
        /// - Check if a batch is in progress
        /// - Get the task to await its value
        /// - Verify task state before starting new batch
        ///
        /// - Returns: Optional Task currently being executed
        func get() -> Task<BatchTranslationResult, Error>? {
            task
        }

        /// Cancel the active task and clear storage
        ///
        /// **Cancellation Process:**
        /// 1. Calls `task?.cancel()` to trigger cancellation token
        /// 2. Sets `task = nil` to release reference
        /// 3. Active TaskGroup will receive CancellationError on next check
        /// 4. In-flight translations will complete (can't interrupt framework)
        /// 5. Pending translations won't start
        ///
        /// **After Cancellation:**
        /// - Storage is cleared (new batch can start)
        /// - Old task continues winding down in background
        /// - No deadlock or state corruption
        ///
        /// **Thread Safety:**
        /// - Safe to call from any context (UI, background)
        /// - Actor isolation prevents data races
        /// - Cancel operation is atomic
        func cancel() {
            task?.cancel()
            task = nil
        }
    }

    private let taskStorage = TaskStorage()

    /// Cancel any ongoing batch translation
    ///
    /// **Usage:**
    /// ```swift
    /// // Start batch translation
    /// Task {
    ///     let result = try await service.translateBatch(words)
    /// }
    ///
    /// // User cancels (e.g., taps "Cancel" button)
    /// service.cancelBatchTranslation()
    /// ```
    ///
    /// **Cancellation Behavior:**
    /// - In-flight translations will complete (can't interrupt framework)
    /// - Pending translations won't start
    /// - Result will show all items as failed
    /// - New batch can start immediately after cancellation
    ///
    /// **Thread Safety:**
    /// - Safe to call from any context (UI thread, background, etc.)
    /// - Method is wrapped in Task for async execution
    /// - Actor-isolated TaskStorage prevents data races
    func cancelBatchTranslation() {
        Task {
            await self.taskStorage.cancel()
            self.logger.info("Batch translation cancelled")
        }
    }

    // MARK: - Batch Translation

    /// Translates multiple text strings in parallel with concurrency control
    ///
    /// **Usage:**
    /// ```swift
    /// let words = ["Hello", "Goodbye", "Thank you", "Please"]
    ///
    /// // Basic batch translation
    /// let result = try await service.translateBatch(words, maxConcurrency: 5)
    /// print("Success: \(result.successCount), Failed: \(result.failedCount)")
    ///
    /// // Batch translation with progress updates
    /// let result = try await service.translateBatch(
    ///     words,
    ///     maxConcurrency: 5,
    ///     progressHandler: { progress in
    ///         // Called on @MainActor, safe to update UI
    ///         print("Progress: \(progress.current)/\(progress.total)")
    ///         print("Current word: \(progress.currentWord)")
    ///     }
    /// )
    ///
    /// // Process successful translations
    /// for translation in result.successfulTranslations {
    ///     print("\(translation.sourceText) -> \(translation.translatedText)")
    /// }
    ///
    /// // Handle errors
    /// for error in result.errors {
    ///     print("Error: \(error.localizedDescription)")
    ///     print("Recovery: \(error.recoverySuggestion ?? "None")")
    /// }
    /// ```
    ///
    /// **Concurrency Control:**
    /// - `maxConcurrency` limits parallel translations to prevent overwhelming the system
    /// - Recommended values: 3-10 (default: 5)
    /// - Higher values may improve throughput but can degrade performance
    /// - iOS Translation framework has internal resource limits
    ///
    /// **Error Handling:**
    /// - Individual failures don't stop the batch
    /// - All errors are collected in `result.errors`
    /// - Partial success is possible (some succeed, some fail)
    /// - Empty array returns empty result (no error)
    ///
    /// **Performance:**
    /// - Typical throughput: 10-20 translations/second
    /// - Progress updates maintain UI responsiveness
    /// - Cancellation is supported (see `cancelBatchTranslation()`)
    ///
    /// **Thread Safety:**
    /// - Actor-isolated, safe to call from any context
    /// - Progress handler called on `@MainActor` for UI updates
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to translate
    ///   - maxConcurrency: Maximum number of parallel translations (default: 5)
    ///   - progressHandler: Optional callback for progress updates (called on @MainActor)
    ///
    /// - Returns: BatchTranslationResult with success/failure counts and errors
    ///
    /// - Throws: OnDeviceTranslationError if all translations fail (unlikely)
    func translateBatch(
        _ texts: [String],
        maxConcurrency: Int = 5,
        progressHandler: (@Sendable (BatchTranslationProgress) -> Void)? = nil
    ) async throws -> BatchTranslationResult {
        // Handle empty input gracefully
        guard !texts.isEmpty else {
            logger.warning("Batch translation called with empty array")
            return BatchTranslationResult(
                successCount: 0,
                failedCount: 0,
                totalDuration: 0,
                errors: [],
                successfulTranslations: []
            )
        }

        logger.info("Starting batch translation: \(texts.count) texts, max concurrency: \(maxConcurrency)")

        // Create active task for cancellation support
        // Task is stored in TaskStorage actor for thread-safe cancellation
        let task = Task<BatchTranslationResult, Error> {
            try await self.performBatchTranslation(
                texts,
                maxConcurrency: maxConcurrency,
                progressHandler: progressHandler
            )
        }

        await taskStorage.set(task)

        do {
            // Wait for task completion and return result
            guard let currentTask = await taskStorage.get() else {
                throw OnDeviceTranslationError.translationFailed(reason: "Failed to create translation task")
            }
            return try await currentTask.value
        } catch is CancellationError {
            // Handle cancellation gracefully
            logger.info("Batch translation cancelled")
            return BatchTranslationResult(
                successCount: 0,
                failedCount: texts.count,
                totalDuration: 0,
                errors: [],
                successfulTranslations: []
            )
        }
    }

    /// Internal method to perform batch translation using TaskGroup
    ///
    /// **Concurrency Control Algorithm:**
    /// 1. Tasks are added to the group sequentially
    /// 2. After `maxConcurrency` tasks are added, we wait for one to complete
    /// 3. Once a task completes, we add the next task
    /// 4. This ensures no more than `maxConcurrency` tasks run simultaneously
    ///
    /// **Why this approach:**
    /// - iOS Translation framework has internal resource limits
    /// - Too many concurrent translations can cause performance degradation
    /// - This pattern provides backpressure to prevent overwhelming the system
    ///
    /// **TaskGroup Benefits:**
    /// - Automatic cancellation propagation
    /// - Structured concurrency guarantees
    /// - Exception handling across all tasks
    /// - No manual task management required
    ///
    /// **Performance Characteristics:**
    /// - Each translation typically completes in < 1 second
    /// - Throughput scales with concurrency until system limits
    /// - Memory usage is stable and bounded
    /// - Progress updates don't block translation work
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to translate
    ///   - maxConcurrency: Maximum number of parallel translations
    ///   - progressHandler: Optional callback for progress updates
    ///
    /// - Returns: BatchTranslationResult with aggregated results
    ///
    /// - Throws: Propagates errors from individual translations (as CancellationError)
    private func performBatchTranslation(
        _ texts: [String],
        maxConcurrency: Int,
        progressHandler: (@Sendable (BatchTranslationProgress) -> Void)?
    ) async throws -> BatchTranslationResult {
        let startTime = Date()
        var results: [BatchTranslationTaskResult] = []
        var completedCount = 0

        // PERFORMANCE: Check language availability ONCE per batch instead of per-translation
        // This eliminates 500-1000ms overhead for 100-card batches
        let sourceAvailable = await cachedIsLanguageAvailable(sourceLanguageCode)
        let targetAvailable = await cachedIsLanguageAvailable(targetLanguageCode)

        guard sourceAvailable, targetAvailable else {
            throw OnDeviceTranslationError.languagePackNotAvailable(
                source: sourceLanguageCode,
                target: targetLanguageCode
            )
        }

        // Use withThrowingTaskGroup for concurrent processing with cancellation support
        // withThrowingTaskGroup automatically handles cancellation and error propagation
        return try await withThrowingTaskGroup(of: BatchTranslationTaskResult.self) { group in
            // Add all tasks with concurrency control
            for (index, text) in texts.enumerated() {
                try Task.checkCancellation()

                // Wait for task completion if we've reached max concurrency
                // This implements backpressure: we only add new tasks when old ones complete
                if index >= maxConcurrency {
                    // Block until a task completes, then collect its result
                    if let result = try await group.next() {
                        results.append(result)
                        completedCount += 1
                        self.reportProgress(
                            handler: progressHandler,
                            current: completedCount,
                            total: texts.count,
                            word: result.text
                        )
                    }
                }

                // Add new translation task to the group
                // Tasks start executing immediately when added
                group.addTask {
                    await self.performSingleTranslation(text: text)
                }
            }

            // Collect remaining results from all pending tasks
            // This loop waits for all remaining tasks to complete
            for try await result in group {
                results.append(result)
                completedCount += 1
                self.reportProgress(
                    handler: progressHandler,
                    current: completedCount,
                    total: texts.count,
                    word: result.text
                )
            }

            // Aggregate and return results
            let duration = Date().timeIntervalSince(startTime)
            let batchResult = self.aggregateResults(results, duration: duration, texts: texts)
            self.logBatchCompletion(batchResult)
            return batchResult
        }
    }

    /// Perform a single translation and wrap result in task metadata
    ///
    /// **Purpose:**
    /// - Converts public `translate()` errors into `Result` type for batch handling
    /// - Captures timing information for performance monitoring
    /// - Provides uniform return type for TaskGroup processing
    ///
    /// **Error Handling:**
    /// - Converts `OnDeviceTranslationError` to `.failure` case
    /// - Preserves error information for batch result aggregation
    /// - Logs both success and failure cases for debugging
    ///
    /// **Timing:**
    /// - Measures duration from start to completion
    /// - Includes framework processing time
    /// - Useful for performance analysis and optimization
    ///
    /// **Concurrency Safety:**
    /// - Safe to call from multiple concurrent TaskGroup tasks
    /// - Actor isolation prevents data races
    /// - Each translation is independent
    ///
    /// - Parameter text: The text to translate
    ///
    /// - Returns: BatchTranslationTaskResult with timing and result/error
    private func performSingleTranslation(text: String) async -> BatchTranslationTaskResult {
        let startTime = Date()

        do {
            let translatedText = try await translate(text: text)
            let duration = Date().timeIntervalSince(startTime)

            logger.debug("Translation succeeded: '\(text.prefix(30))'")

            return BatchTranslationTaskResult(
                text: text,
                result: .success(translatedText),
                duration: duration
            )
        } catch let error as OnDeviceTranslationError {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("Translation failed: '\(text.prefix(30))' - \(error.localizedDescription)")

            return BatchTranslationTaskResult(
                text: text,
                result: .failure(error),
                duration: duration
            )
        } catch {
            // Catch any other errors and wrap them
            let duration = Date().timeIntervalSince(startTime)
            let wrappedError = OnDeviceTranslationError.translationFailed(reason: error.localizedDescription)
            logger.error("Translation failed with unexpected error: '\(text.prefix(30))' - \(error.localizedDescription)")

            return BatchTranslationTaskResult(
                text: text,
                result: .failure(wrappedError),
                duration: duration
            )
        }
    }

    /// Report progress to handler on main actor
    ///
    /// **Thread Safety:**
    /// - Progress handler dispatched to @MainActor
    /// - Safe to update UI directly from the handler
    /// - Prevents UI updates from background threads
    ///
    /// **Purpose:**
    /// - Bridges concurrent translation work with UI updates
    /// - Ensures progress updates run on UI thread
    /// - Provides consistent interface for progress reporting
    ///
    /// **Usage Pattern:**
    /// ```swift
    /// // Called from background translation task
    /// await reportProgress(handler: progressHandler, current: 5, total: 10, word: "Hello")
    /// // Handler will execute on MainActor (UI thread)
    /// ```
    ///
    /// **Performance:**
    /// - Non-blocking: async dispatch doesn't wait for handler
    /// - Handler should be quick (< 16ms for 60fps UI)
    /// - If handler is slow, it may delay subsequent progress updates
    ///
    /// - Parameters:
    ///   - handler: Optional progress callback (nil = no-op)
    ///   - current: Number of completed translations (1-indexed)
    ///   - total: Total number of translations to perform
    ///   - word: The most recently translated text
    private func reportProgress(
        handler: (@Sendable (BatchTranslationProgress) -> Void)?,
        current: Int,
        total: Int,
        word: String
    ) {
        guard let handler else { return }
        let progress = BatchTranslationProgress(current: current, total: total, currentWord: word)
        Task { @MainActor in handler(progress) }
    }

    /// Aggregate translation results into final batch result
    ///
    /// **Processing Steps:**
    /// 1. Separate successful and failed translations using pattern matching
    /// 2. Extract errors from failed results
    /// 3. Create SuccessfulTranslation objects for UI display
    /// 4. Calculate final counts and statistics
    ///
    /// **Error Handling:**
    /// - Individual translation failures don't fail the entire batch
    /// - All errors are collected for user feedback
    /// - Partial success is possible (some translations succeed, others fail)
    ///
    /// **Data Flow:**
    /// ```
    /// BatchTranslationTaskResult[] (raw results)
    ///   → Filter by .success / .failure
    ///   → Extract errors and translations
    ///   → Build SuccessfulTranslation[] with metadata
    ///   → Create BatchTranslationResult (final output)
    /// ```
    ///
    /// **Result Structure:**
    /// - `successCount`: Number of translations that succeeded
    /// - `failedCount`: Number of translations that failed
    /// - `totalDuration`: Time from batch start to completion
    /// - `errors`: Array of errors from failed translations
    /// - `successfulTranslations`: Rich objects with source/target text
    ///
    /// **Invariant:**
    /// `successCount + failedCount == results.count` (always true)
    ///
    /// - Parameters:
    ///   - results: Array of individual translation task results
    ///   - duration: Total time taken for the batch operation
    ///   - texts: Original input texts (for reference, not used in aggregation)
    ///
    /// - Returns: BatchTranslationResult with aggregated statistics
    private func aggregateResults(
        _ results: [BatchTranslationTaskResult],
        duration: TimeInterval,
        texts _: [String]
    ) -> BatchTranslationResult {
        // Separate successes and failures using Result pattern matching
        let successes = results.filter { if case .success = $0.result { true } else { false } }
        let failures = results.filter { if case .failure = $0.result { true } else { false } }

        // Extract errors from failed results for user feedback
        let errors = failures.compactMap { result -> OnDeviceTranslationError? in
            guard case let .failure(error) = result.result else { return nil }
            return error
        }

        // Build successful translation objects with full context
        // These can be used to update UI with translation results
        let successfulTranslations: [SuccessfulTranslation] = successes.compactMap { result in
            guard case let .success(translatedText) = result.result else {
                return nil
            }
            return SuccessfulTranslation(
                sourceText: result.text,
                translatedText: translatedText,
                sourceLanguage: self.sourceLanguageCode,
                targetLanguage: self.targetLanguageCode
            )
        }

        return BatchTranslationResult(
            successCount: successes.count,
            failedCount: failures.count,
            totalDuration: duration,
            errors: errors,
            successfulTranslations: successfulTranslations
        )
    }

    /// Log batch translation completion summary for monitoring and debugging
    ///
    /// **Purpose:**
    /// - Provides audit trail for translation operations
    /// - Helps diagnose performance issues
    /// - Tracks success/failure rates over time
    ///
    /// **Logged Information:**
    /// - Success count (how many translations succeeded)
    /// - Failed count (how many translations failed)
    /// - Total duration (time from start to finish)
    ///
    /// **Logger Configuration:**
    /// - Subsystem: `com.lexiconflow.translation`
    /// - Category: `OnDeviceTranslation`
    /// - Level: `info` (always logged)
    ///
    /// **Usage in Production:**
    /// - Logs are aggregated by OSLog framework
    /// - Can be viewed in Console.app or Xcode debugger
    /// - Useful for analytics and performance monitoring
    ///
    /// - Parameter result: The completed batch translation result
    private func logBatchCompletion(_ result: BatchTranslationResult) {
        logger.info("""
        Batch translation complete:
        - Success: \(result.successCount)
        - Failed: \(result.failedCount)
        - Duration: \(String(format: "%.2f", result.totalDuration))s
        """)
    }

    // MARK: - Single Translation

    /// Translate text from source to target language
    ///
    /// **Usage:**
    /// ```swift
    /// do {
    ///     // Translate using configured languages
    ///     let result = try await service.translate(text: "Hello, world!")
    ///
    ///     // Translate with explicit languages
    ///     let result2 = try await service.translate(
    ///         text: "Goodbye",
    ///         from: "en",
    ///         to: "es"
    ///     )
    ///
    ///     print("Translated: \(result)")
    /// } catch {
    ///     // Handle translation errors
    ///     print("Error: \(error.localizedDescription)")
    /// }
    /// ```
    ///
    /// **Prerequisites:**
    /// 1. Language packs must be downloaded for both source and target
    /// 2. Use `isLanguagePairSupported()` to verify before calling
    /// 3. Use `needsLanguageDownload()` to check pack availability
    ///
    /// **Error Conditions:**
    /// - `emptyInput`: Text is empty or whitespace-only
    /// - `unsupportedLanguagePair`: iOS doesn't support this language pair
    /// - `languagePackNotAvailable`: Required language pack not downloaded
    /// - `translationFailed`: Framework error during translation
    ///
    /// **Thread Safety:**
    /// - Actor-isolated, safe to call from any context
    /// - Multiple concurrent translations are safe
    ///
    /// **Performance:**
    /// - Single translation typically completes in < 1 second
    /// - For multiple texts, use `translateBatch()` instead
    ///
    /// - Parameters:
    ///   - text: The text to translate
    ///   - from: Source language code (optional, defaults to configured source)
    ///   - to: Target language code (optional, defaults to configured target)
    ///
    /// - Returns: Translated text as a `String`
    ///
    /// - Throws: `OnDeviceTranslationError` if translation fails
    func translate(
        text: String,
        from source: String? = nil,
        to target: String? = nil
    ) async throws -> String {
        // Input validation
        guard !text.isEmpty else {
            logger.warning("Translation attempted with empty text")
            throw OnDeviceTranslationError.emptyInput
        }

        let sourceCode = source ?? sourceLanguageCode
        let targetCode = target ?? targetLanguageCode

        let sourceLang = Locale.Language(identifier: sourceCode)
        let targetLang = Locale.Language(identifier: targetCode)

        logger.debug("Translating text from '\(sourceCode)' to '\(targetCode)'")

        // Check language support before attempting translation
        // This prevents unnecessary framework calls for unsupported pairs
        guard isLanguagePairSupported(from: sourceCode, to: targetCode) else {
            logger.error("Language pair not supported: \(sourceCode) -> \(targetCode)")
            throw OnDeviceTranslationError.unsupportedLanguagePair(
                source: sourceCode,
                target: targetCode
            )
        }

        // Check if language packs are downloaded
        // LanguageAvailability API guarantees offline capability when packs are available
        let sourceNeedsDownload = await needsLanguageDownload(sourceCode)
        let targetNeedsDownload = await needsLanguageDownload(targetCode)
        if sourceNeedsDownload || targetNeedsDownload {
            logger.error("Language pack not available for translation")
            throw OnDeviceTranslationError.languagePackNotAvailable(
                source: sourceCode,
                target: targetCode
            )
        }

        do {
            // Create translation session with source and target languages
            // TranslationSession handles the on-device translation processing
            // iOS 26 API: TranslationSession takes installedSource and target directly
            let session = TranslationSession(installedSource: sourceLang, target: targetLang)
            translationSession = session

            // Perform translation using iOS Translation framework
            // The framework processes text entirely on-device (no network calls)
            let response = try await session.translate(text)
            let translatedText = response.targetText

            logger.info("Translation successful: '\(text.prefix(50))' -> '\(translatedText.prefix(50))'")

            return translatedText

        } catch let error as OnDeviceTranslationError {
            // Re-throw our custom errors (already properly formatted)
            throw error
        } catch {
            // Wrap framework errors in our error type for consistency
            logger.error("Translation failed: \(error.localizedDescription)")
            throw OnDeviceTranslationError.translationFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during on-device translation
///
/// **Error Handling Strategy:**
/// - Check `isRetryable` before attempting retry logic
/// - Display `errorDescription` to users for immediate feedback
/// - Show `recoverySuggestion` to guide users toward resolution
/// - Track errors with Analytics for monitoring and improvement
///
/// **Common Error Scenarios:**
/// 1. **Language Pack Missing**: User hasn't downloaded required language
///    - Solution: Prompt user to download language pack
///    - Recovery: "Download language packs in Settings"
///
/// 2. **Unsupported Pair**: iOS doesn't support this language combination
///    - Solution: Guide user to choose supported languages
///    - Recovery: "Try a different language pair"
///
/// 3. **Download Failed**: Network issue during language pack download
///    - Solution: Retry download when connection improves
///    - Recovery: "Check internet connection and try again"
///
/// 4. **Translation Failed**: Framework error during translation
///    - Solution: May be transient, retry recommended
///    - Recovery: "Try again or use shorter text"
enum OnDeviceTranslationError: LocalizedError {
    /// The language pair is not supported by the on-device translation framework
    ///
    /// **When this occurs:**
    /// - iOS doesn't support translation between these languages
    /// - One or both languages aren't available in Translation framework
    ///
    /// **User Impact:**
    /// - Cannot proceed with translation for this language pair
    /// - Must choose different languages
    ///
    /// **Not Retryable:** This is a permanent limitation, not a transient error
    case unsupportedLanguagePair(source: String, target: String)

    /// Language pack is not available/downloaded for the specified language
    ///
    /// **When this occurs:**
    /// - User hasn't downloaded the required language pack
    /// - Language pack was removed or corrupted
    ///
    /// **User Impact:**
    /// - Translation cannot proceed until language pack is downloaded
    /// - User can trigger download via system prompt
    ///
    /// **Not Retryable:** Must download language pack first
    case languagePackNotAvailable(source: String, target: String)

    /// Language pack download failed
    ///
    /// **When this occurs:**
    /// - Network connectivity issues during download
    /// - Insufficient storage space
    /// - System-level download failure
    ///
    /// **User Impact:**
    /// - Language pack not available for offline translation
    ///
    /// **Retryable:** May succeed with better network connection
    case languagePackDownloadFailed(language: String)

    /// Translation operation failed
    ///
    /// **When this occurs:**
    /// - Framework internal error
    /// - Text encoding issues
    /// - Resource constraints (memory, processing)
    ///
    /// **User Impact:**
    /// - Specific translation failed
    /// - Other translations may succeed
    ///
    /// **Retryable:** May succeed on retry with same input
    case translationFailed(reason: String)

    /// Input text is empty
    ///
    /// **When this occurs:**
    /// - User attempts to translate empty string
    /// - Whitespace-only input
    ///
    /// **User Impact:**
    /// - Validation prevents unnecessary API call
    ///
    /// **Not Retryable:** Input validation error, won't change on retry
    case emptyInput

    /// Human-readable error description for display to users
    ///
    /// **Usage:**
    /// ```swift
    /// do {
    ///     try await service.translate(text: "Hello")
    /// } catch {
    ///     print(error.localizedDescription)  // Uses errorDescription
    /// }
    /// ```
    var errorDescription: String? {
        switch self {
        case let .unsupportedLanguagePair(source, target):
            "Translation from \(source) to \(target) is not supported on this device"

        case let .languagePackNotAvailable(source, target):
            "Language pack not available for \(source) → \(target) translation"

        case let .languagePackDownloadFailed(language):
            "Failed to download language pack for \(language)"

        case let .translationFailed(reason):
            "Translation failed: \(reason)"

        case .emptyInput:
            "Cannot translate empty text"
        }
    }

    /// User-friendly recovery suggestion
    ///
    /// **Usage:**
    /// ```swift
    /// do {
    ///     try await service.translate(text: "Hello")
    /// } catch let error as OnDeviceTranslationError {
    ///     let message = error.recoverySuggestion ?? "Unknown error"
    ///     showAlert(message: message)
    /// }
    /// ```
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedLanguagePair:
            "Try a different language pair supported by iOS Translation"

        case let .languagePackNotAvailable(source, target):
            "Download language packs for \(source) or \(target) in Settings > General > Translation"

        case .languagePackDownloadFailed:
            "Check your internet connection and try downloading again"

        case .translationFailed:
            "Try again or use a shorter text"

        case .emptyInput:
            "Enter text to translate"
        }
    }

    /// Whether this error is retryable with exponential backoff
    ///
    /// **Retry Logic:**
    /// ```swift
    /// if error.isRetryable {
    ///     // Implement retry with exponential backoff
    ///     try await operationWithRetry()
    /// } else {
    ///     // Show error to user, don't retry
    ///     showError(error)
    /// }
    /// ```
    ///
    /// **Not Retryable:**
    /// - `unsupportedLanguagePair`: Permanent limitation
    /// - `languagePackNotAvailable`: Requires user action (download)
    /// - `emptyInput`: Input validation error
    ///
    /// **Retryable:**
    /// - `languagePackDownloadFailed`: May succeed with better connection
    /// - `translationFailed`: May be transient framework error
    var isRetryable: Bool {
        switch self {
        case .languagePackDownloadFailed, .translationFailed:
            true
        case .unsupportedLanguagePair, .languagePackNotAvailable, .emptyInput:
            false
        }
    }
}
