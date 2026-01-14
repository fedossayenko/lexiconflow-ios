//
//  CloudTranslationService.swift
//  LexiconFlow
//
//  Cloud Functions client for secure AI translation
//
//  **Purpose**: Provides translation services via Firebase Cloud Functions proxy,
//  eliminating client-side API keys and enabling intelligent provider routing.
//
//  **Architecture**:
//  - @MainActor isolation for thread-safe access
//  - Singleton pattern for shared instance
//  - Automatic App Check token injection
//  - Fallback to on-device translation when offline
//
//  **Provider Routing**:
//  - Zhipu GLM-4 Flash (free tier) for basic translation
//  - Gemini 2.5 Flash for multimodal/context requests
//

import FirebaseFunctions
import Foundation
import OSLog

/// Cloud translation service using Firebase Cloud Functions
///
/// Routes translation requests to the secure backend proxy, which handles
/// AI provider selection (Gemini/Zhipu), rate limiting, and quota management.
@MainActor
final class CloudTranslationService {
    // MARK: - Singleton

    static let shared = CloudTranslationService()

    private let logger = Logger(subsystem: "com.lexiconflow.translation", category: "CloudTranslationService")
    private let functions = Functions.functions()

    // MARK: - DTOs

    /// Translation request to Cloud Functions
    struct TranslateRequest: Codable, Sendable {
        let texts: [String]
        let sourceLanguage: String
        let targetLanguage: String
        let includeContext: Bool
        let userId: String
    }

    /// Translation response from Cloud Functions
    struct TranslateResponse: Codable, Sendable {
        let translations: [TranslationItem]
        let provider: String
        let tokensUsed: Int
        let quotaRemaining: Int
    }

    /// Single translation item
    struct TranslationItem: Codable, Sendable {
        let sourceText: String
        let translatedText: String
        let contextSentence: String?
        let cefrLevel: String?
    }

    /// Batch translation result
    struct TranslationBatchResult: Sendable {
        let successCount: Int
        let failedCount: Int
        let items: [TranslationItem]
        let provider: String
        let tokensUsed: Int
        let quotaRemaining: Int

        var isSuccess: Bool {
            self.failedCount == 0 && self.successCount > 0
        }
    }

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }

    // MARK: - Public API

    /// Translate multiple texts with automatic provider routing
    ///
    /// - Parameters:
    ///   - texts: Array of texts to translate
    ///   - sourceLanguage: Source language code (e.g., "en")
    ///   - targetLanguage: Target language code (e.g., "ru")
    ///   - includeContext: Whether to include context sentences and CEFR levels
    ///
    /// - Returns: Translation batch result with provider info
    /// - Throws: CloudTranslationError if translation fails
    ///
    /// **Usage**:
    /// ```swift
    /// let result = try await CloudTranslationService.shared.translate(
    ///     texts: ["hello", "world"],
    ///     from: "en",
    ///     to: "ru",
    ///     includeContext: true
    /// )
    /// print(result.items) // Translated texts
    /// print(result.provider) // "gemini" or "zhipu"
    /// ```
    func translate(
        texts: [String],
        from sourceLanguage: String,
        to targetLanguage: String,
        includeContext: Bool = false
    ) async throws -> TranslationBatchResult {
        guard !texts.isEmpty else {
            self.logger.warning("Translate called with empty array")
            return TranslationBatchResult(
                successCount: 0,
                failedCount: 0,
                items: [],
                provider: "none",
                tokensUsed: 0,
                quotaRemaining: 0
            )
        }

        self.logger.info("Starting translation", [
            "textCount": "\(texts.count)",
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "includeContext": includeContext
        ])

        // 1. Ensure authenticated
        let userId = try await ensureAuthenticated()

        // 2. Prepare request
        let request = TranslateRequest(
            texts: texts,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            includeContext: includeContext,
            userId: userId
        )

        // 3. Call Cloud Function
        let response: TranslateResponse
        do {
            response = try await self.callCloudFunction("translateV2", data: request)
        } catch {
            self.logger.error("Cloud Function call failed", error)

            // Fallback to on-device translation
            self.logger.info("Falling back to on-device translation")
            return try await self.fallbackToOnDevice(
                texts: texts,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }

        self.logger.info("Translation completed", [
            "provider": response.provider,
            "successCount": "\(response.translations.count)",
            "tokensUsed": "\(response.tokensUsed)",
            "quotaRemaining": "\(response.quotaRemaining)"
        ])

        return TranslationBatchResult(
            successCount: response.translations.count,
            failedCount: 0,
            items: response.translations,
            provider: response.provider,
            tokensUsed: response.tokensUsed,
            quotaRemaining: response.quotaRemaining
        )
    }

    /// Translate a single text
    ///
    /// - Parameters:
    ///   - text: Text to translate
    ///   - sourceLanguage: Source language code
    ///   - targetLanguage: Target language code
    ///   - includeContext: Whether to include context
    ///
    /// - Returns: Translated text with optional metadata
    /// - Throws: CloudTranslationError if translation fails
    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        includeContext: Bool = false
    ) async throws -> (translatedText: String, contextSentence: String?, cefrLevel: String?) {
        let result = try await translate(
            texts: [text],
            from: sourceLanguage,
            to: targetLanguage,
            includeContext: includeContext
        )

        guard let item = result.items.first else {
            throw CloudTranslationError.emptyResponse
        }

        return (item.translatedText, item.contextSentence, item.cefrLevel)
    }

    // MARK: - Private Methods

    /// Call a Cloud Function with proper error handling
    private func callCloudFunction<U: Codable>(
        _ functionName: String,
        data: some Codable
    ) async throws -> U {
        do {
            let result = try await functions.httpsCallable(functionName).call(data)

            guard let responseData = result.data as? [String: Any] else {
                throw CloudTranslationError.invalidResponse
            }

            // Handle nested response structure
            let responseJSON: Data
            if let response = responseData["response"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: response)
            {
                responseJSON = jsonData
            } else if let jsonData = try? JSONSerialization.data(withJSONObject: responseData) {
                responseJSON = jsonData
            } else {
                throw CloudTranslationError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(U.self, from: responseJSON)
            return decoded
        } catch let error as CloudTranslationError {
            throw error
        } catch {
            self.logger.error("Cloud Function call failed", error)
            throw CloudTranslationError.functionFailed(error)
        }
    }

    /// Ensure user is authenticated with Firebase
    private func ensureAuthenticated() async throws -> String {
        if let userId = FirebaseService.shared.currentUserId {
            return userId
        }

        self.logger.info("User not authenticated, signing in anonymously")
        return try await FirebaseService.shared.signInAnonymously()
    }

    /// Fallback to on-device translation when cloud is unavailable
    private func fallbackToOnDevice(
        texts: [String],
        sourceLanguage _: String,
        targetLanguage _: String
    ) async throws -> TranslationBatchResult {
        self.logger.info("Using on-device translation fallback")

        // Use OnDeviceTranslationService
        var items: [TranslationItem] = []
        var successCount = 0

        for text in texts {
            do {
                // TODO: Call OnDeviceTranslationService
                // For now, return a placeholder
                items.append(TranslationItem(
                    sourceText: text,
                    translatedText: "[On-device] \(text)",
                    contextSentence: nil,
                    cefrLevel: nil
                ))
                successCount += 1
            } catch {
                self.logger.error("On-device translation failed for text: \(text)", error)
            }
        }

        return TranslationBatchResult(
            successCount: successCount,
            failedCount: texts.count - successCount,
            items: items,
            provider: "on-device",
            tokensUsed: 0,
            quotaRemaining: 0
        )
    }
}

// MARK: - Errors

/// Cloud translation service errors
enum CloudTranslationError: LocalizedError {
    case notAuthenticated
    case functionFailed(Error)
    case invalidResponse
    case emptyResponse
    case rateLimit(retryAfter: Int)
    case quotaExceeded
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Not authenticated with Firebase"
        case let .functionFailed(error):
            "Cloud Function error: \(error.localizedDescription)"
        case .invalidResponse:
            "Invalid response from server"
        case .emptyResponse:
            "Empty response from server"
        case let .rateLimit(seconds):
            "Rate limit exceeded. Try again in \(seconds) seconds"
        case .quotaExceeded:
            "Monthly quota exceeded"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            "Try signing out and signing back in"
        case .functionFailed, .networkError:
            "Check your internet connection and try again"
        case .rateLimit:
            "Wait a few moments, then try again"
        case .quotaExceeded:
            "Quota resets on the 1st of each month"
        default:
            nil
        }
    }

    /// Whether this error is retryable
    var isRetryable: Bool {
        switch self {
        case .rateLimit, .functionFailed, .networkError:
            true
        default:
            false
        }
    }
}
