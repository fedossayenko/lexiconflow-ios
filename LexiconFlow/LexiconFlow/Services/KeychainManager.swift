//
//  KeychainManager.swift
//  LexiconFlow
//
//  Secure storage wrapper for sensitive data like API keys
//  Uses iOS Keychain Services for encrypted, persistent storage
//

import Foundation
import Security
import OSLog

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
    static func setAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            logger.warning("Attempted to store empty API key")
            throw KeychainError.emptyKey
        }

        guard let data = key.data(using: .utf8) else {
            logger.error("Failed to encode API key as UTF-8")
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zai_api_key",
            kSecValueData as String: data
        ]

        // Delete existing key first (update operation)
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to store API key in Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        logger.info("API key stored securely in Keychain")
    }

    /// Retrieve API key from Keychain
    ///
    /// - Returns: The API key if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails (except not found)
    static func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            if status == errSecItemNotFound {
                logger.debug("No API key found in Keychain")
                return nil
            }
            logger.error("Failed to retrieve API key from Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        guard let apiKey = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode API key data as UTF-8")
            throw KeychainError.invalidData
        }

        logger.debug("API key retrieved from Keychain")
        return apiKey
    }

    /// Delete API key from Keychain
    ///
    /// - Throws: KeychainError if deletion fails
    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zai_api_key"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete API key from Keychain: OSStatus \(status)")
            throw KeychainError.unhandledError(status)
        }

        if status == errSecSuccess {
            logger.info("API key deleted from Keychain")
        } else {
            logger.debug("No API key to delete (item not found)")
        }
    }

    /// Check if API key exists in Keychain
    ///
    /// - Returns: true if API key exists, false otherwise
    static func hasAPIKey() -> Bool {
        do {
            return try getAPIKey() != nil
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
    static func set(_ value: String, forAccount account: String) throws {
        guard !value.isEmpty else {
            throw KeychainError.emptyKey
        }

        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode value as UTF-8 for account '\(account)'")
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
    static func get(forAccount account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
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
    static func delete(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
                return "Cannot store empty key"
            case .invalidData:
                return "Invalid data format in Keychain"
            case .unhandledError(let status):
                return "Keychain operation failed with OSStatus: \(status)"
            }
        }
    }
}
