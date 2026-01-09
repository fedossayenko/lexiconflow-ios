//
//  KeychainManager.swift
//  LexiconFlow
//
//  Secure storage wrapper for sensitive data like API keys
//  Uses iOS Keychain Services for encrypted, persistent storage
//

import Foundation
import OSLog
import Security

/// Secure storage manager using iOS Keychain Services
///
/// Provides a simple interface for storing and retrieving sensitive data
/// like API keys in the iOS Keychain, which is encrypted and tied to the app's
/// provisioning profile.
enum KeychainManager {
    private static let service = "com.lexiconflow"
    private static let logger = Logger(subsystem: "com.lexiconflow.keychain", category: "KeychainManager")

    // MARK: - API Key Operations

    /// Store API key securely in Keychain
    ///
    /// - Parameter key: The API key to store
    /// - Throws: KeychainError if storage fails
    @MainActor
    static func setAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            self.logger.warning("Attempted to store empty API key")
            throw KeychainError.emptyKey
        }

        guard let data = key.data(using: .utf8) else {
            self.logger.error("Failed to encode API key as UTF-8")
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: "zai_api_key",
            kSecValueData as String: data
        ]

        // Delete existing key first (update operation)
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            self.logger.error("Failed to store API key in Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        self.logger.info("API key stored securely in Keychain")
    }

    /// Retrieve API key from Keychain
    ///
    /// - Returns: The API key if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails (except not found)
    @MainActor
    static func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: "zai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data
        else {
            if status == errSecItemNotFound {
                self.logger.debug("No API key found in Keychain")
                return nil
            }
            self.logger.error("Failed to retrieve API key from Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        guard let apiKey = String(data: data, encoding: .utf8) else {
            self.logger.error("Failed to decode API key data as UTF-8")
            throw KeychainError.invalidData
        }

        self.logger.debug("API key retrieved from Keychain")
        return apiKey
    }

    /// Delete API key from Keychain
    ///
    /// - Throws: KeychainError if deletion fails
    @MainActor
    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: "zai_api_key"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            self.logger.error("Failed to delete API key from Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        if status == errSecSuccess {
            self.logger.info("API key deleted from Keychain")
        } else {
            self.logger.debug("No API key to delete (item not found)")
        }
    }

    /// Check if API key exists in Keychain
    ///
    /// - Returns: true if API key exists, false otherwise
    @MainActor
    static func hasAPIKey() -> Bool {
        do {
            return try self.getAPIKey() != nil
        } catch {
            return false
        }
    }

    // MARK: - Generic Operations (for future use)

    /// Store a generic value in Keychain
    ///
    /// - Parameters:
    ///   - value: The value to store
    ///   - account: The account identifier (key)
    /// - Throws: KeychainError if storage fails
    @MainActor
    static func set(_ value: String, forAccount account: String) throws {
        guard !value.isEmpty else {
            throw KeychainError.emptyKey
        }

        guard let data = value.data(using: .utf8) else {
            self.logger.error("Failed to encode value as UTF-8 for account '\(account)'")
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    /// Retrieve a generic value from Keychain
    ///
    /// - Parameter account: The account identifier (key)
    /// - Returns: The value if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails
    @MainActor
    static func get(forAccount account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unhandledError(status)
        }

        return value
    }

    /// Delete a generic value from Keychain
    ///
    /// - Parameter account: The account identifier (key)
    /// - Throws: KeychainError if deletion fails
    @MainActor
    static func delete(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    // MARK: - Errors

    /// Errors that can occur during Keychain operations
    enum KeychainError: LocalizedError {
        case emptyKey
        case invalidData
        case unhandledError(OSStatus)

        var errorDescription: String? {
            switch self {
            case .emptyKey:
                "Cannot store empty key"
            case .invalidData:
                "Invalid data format in Keychain"
            case let .unhandledError(status):
                "Keychain operation failed with OSStatus: \(status)"
            }
        }
    }
}
