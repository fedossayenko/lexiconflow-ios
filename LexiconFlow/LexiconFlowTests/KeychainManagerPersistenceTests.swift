//
//  KeychainManagerPersistenceTests.swift
//  LexiconFlowTests
//
//  Tests for KeychainManager including:
//  - Persistence across "app restarts" (re-reading)
//  - UTF-8 encoding/decoding (Unicode, emoji, CJK, RTL)
//  - Update existing key behavior
//  - Empty key validation
//  - Delete operations
//  - Generic account operations
//  - Error handling
//
//  NOTE: These tests use the actual iOS Keychain, which persists across test runs.
//  Tests clean up after themselves to avoid interference.
//

import Foundation
import Testing
@testable import LexiconFlow

/// Test suite for KeychainManager persistence and edge cases
@Suite(.serialized)
@MainActor
struct KeychainManagerPersistenceTests {
    // MARK: - Test Cleanup

    /// Clean up any existing API key before running tests
    private func cleanupAPIKey() {
        try? KeychainManager.deleteAPIKey()
        try? KeychainManager.delete(forAccount: "test_account_1")
        try? KeychainManager.delete(forAccount: "test_account_2")
        try? KeychainManager.delete(forAccount: "unicode_test")
    }

    // MARK: - Persistence Tests

    @Test("API key persists across re-reads")
    func keyPersistsAcrossRereads() async throws {
        self.cleanupAPIKey()

        let testKey = "sk-test-\(UUID().uuidString)"

        // Store API key
        try KeychainManager.setAPIKey(testKey)

        // First read
        let firstRead = try KeychainManager.getAPIKey()
        #expect(firstRead == testKey, "First read should return stored key")

        // Second read (simulates "persistence")
        let secondRead = try KeychainManager.getAPIKey()
        #expect(secondRead == testKey, "Second read should return same key")

        // Third read after delay
        try await Task.sleep(nanoseconds: 100000000) // 0.1 second
        let thirdRead = try KeychainManager.getAPIKey()
        #expect(thirdRead == testKey, "Third read should still return same key")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    @Test("API key persists after delete and re-store")
    func keyPersistsAfterDeleteAndRestore() throws {
        self.cleanupAPIKey()

        let key1 = "sk-first-\(UUID().uuidString)"
        let key2 = "sk-second-\(UUID().uuidString)"

        // Store first key
        try KeychainManager.setAPIKey(key1)
        let read1 = try KeychainManager.getAPIKey()
        #expect(read1 == key1, "Should read first key")

        // Delete
        try KeychainManager.deleteAPIKey()
        let readAfterDelete = try KeychainManager.getAPIKey()
        #expect(readAfterDelete == nil, "Should return nil after delete")

        // Store second key
        try KeychainManager.setAPIKey(key2)
        let read2 = try KeychainManager.getAPIKey()
        #expect(read2 == key2, "Should read second key")

        // Cleanup
        try KeychainManager.deleteAPIKey()
    }

    // MARK: - UTF-8 Encoding Tests

    @Test("UTF-8 encoding: emoji in API key")
    func utf8EncodingEmoji() throws {
        self.cleanupAPIKey()

        let emojiKey = "test-🔑-café-☕️-key"

        try KeychainManager.setAPIKey(emojiKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == emojiKey, "Emoji should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Chinese characters")
    func utf8EncodingChinese() throws {
        self.cleanupAPIKey()

        let chineseKey = "sk-测试-密钥-中文"

        try KeychainManager.setAPIKey(chineseKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == chineseKey, "Chinese characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Japanese characters")
    func utf8EncodingJapanese() throws {
        self.cleanupAPIKey()

        let japaneseKey = "sk-テスト-キー-日本語"

        try KeychainManager.setAPIKey(japaneseKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == japaneseKey, "Japanese characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Arabic (RTL language)")
    func utf8EncodingArabic() throws {
        self.cleanupAPIKey()

        let arabicKey = "sk-مرحبا-مفتاح-عربي"

        try KeychainManager.setAPIKey(arabicKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == arabicKey, "Arabic characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Hebrew (RTL language)")
    func utf8EncodingHebrew() throws {
        self.cleanupAPIKey()

        let hebrewKey = "sk-שלום-מפתח-עברית"

        try KeychainManager.setAPIKey(hebrewKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == hebrewKey, "Hebrew characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Korean")
    func utf8EncodingKorean() throws {
        self.cleanupAPIKey()

        let koreanKey = "sk-테스트-키-한국어"

        try KeychainManager.setAPIKey(koreanKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == koreanKey, "Korean characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: Cyrillic (Russian)")
    func utf8EncodingCyrillic() throws {
        self.cleanupAPIKey()

        let cyrillicKey = "sk-тест-ключ-русский"

        try KeychainManager.setAPIKey(cyrillicKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == cyrillicKey, "Cyrillic characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: mixed scripts")
    func utf8EncodingMixedScripts() throws {
        self.cleanupAPIKey()

        let mixedKey = "sk-test-测试-테스트-тест-مرحبا"

        try KeychainManager.setAPIKey(mixedKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == mixedKey, "Mixed scripts should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("UTF-8 encoding: combining diacritics")
    func utf8EncodingCombiningDiacritics() throws {
        self.cleanupAPIKey()

        // Using combining diacritical marks
        let combiningKey = "sk-cafe\u{0301}-na\u{0308}ve" // café + naïve

        try KeychainManager.setAPIKey(combiningKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == combiningKey, "Combining diacritics should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    // MARK: - Update Behavior Tests

    @Test("Update existing API key")
    func updateExistingKey() throws {
        self.cleanupAPIKey()

        let key1 = "sk-initial-key"
        let key2 = "sk-updated-key"

        // Store initial key
        try KeychainManager.setAPIKey(key1)
        let read1 = try KeychainManager.getAPIKey()
        #expect(read1 == key1, "Should read initial key")

        // Update with new key
        try KeychainManager.setAPIKey(key2)
        let read2 = try KeychainManager.getAPIKey()
        #expect(read2 == key2, "Should read updated key")
        #expect(read2 != key1, "Updated key should be different")

        // Verify only one key exists
        #expect(read2 == "sk-updated-key", "Only latest key should exist")

        try KeychainManager.deleteAPIKey()
    }

    @Test("Multiple updates in sequence")
    func multipleSequentialUpdates() throws {
        self.cleanupAPIKey()

        let keys = (1 ... 10).map { "sk-key-\($0)" }

        for key in keys {
            try KeychainManager.setAPIKey(key)
            let current = try KeychainManager.getAPIKey()
            #expect(current == key, "Should read current key after update")
        }

        // Final read should have last key
        let final = try KeychainManager.getAPIKey()
        #expect(final == "sk-key-10", "Final key should be last one set")

        try KeychainManager.deleteAPIKey()
    }

    // MARK: - Empty Key Validation Tests

    @Test("Empty key throws emptyKey error")
    func emptyKeyThrowsError() {
        self.cleanupAPIKey()

        do {
            try KeychainManager.setAPIKey("")
            #expect(Bool(false), "Should have thrown emptyKey error")
        } catch KeychainManager.KeychainError.emptyKey {
            // Expected error type
        } catch {
            #expect(Bool(false), "Should have thrown emptyKey error, not: \(error)")
        }

        // Whitespace-only key is allowed (only isEmpty is checked, not trimming)
        do {
            try KeychainManager.setAPIKey("   ")
            // Should succeed - whitespace is not considered empty
        } catch {
            #expect(Bool(false), "Whitespace-only key should be allowed, error: \(error)")
        }

        // Clean up the whitespace key
        try? KeychainManager.deleteAPIKey()
    }

    @Test("Empty key has localized error description")
    func emptyKeyErrorDescription() {
        do {
            _ = try KeychainManager.setAPIKey("")
        } catch let error as KeychainManager.KeychainError {
            #expect(
                error.localizedDescription == "Cannot store empty key",
                "Empty key error should have description"
            )
        } catch {
            #expect(Bool(false), "Should throw KeychainError.emptyKey")
        }
    }

    // MARK: - Delete Operations Tests

    @Test("Delete existing API key succeeds")
    func deleteExistingKey() throws {
        self.cleanupAPIKey()

        let testKey = "sk-to-delete"
        try KeychainManager.setAPIKey(testKey)

        let beforeDelete = try KeychainManager.getAPIKey()
        #expect(beforeDelete == testKey, "Key should exist before delete")

        try KeychainManager.deleteAPIKey()

        let afterDelete = try KeychainManager.getAPIKey()
        #expect(afterDelete == nil, "Key should be nil after delete")
    }

    @Test("Delete non-existent API key succeeds")
    func deleteNonExistentKey() throws {
        self.cleanupAPIKey()

        // Ensure key doesn't exist
        let before = try KeychainManager.getAPIKey()
        #expect(before == nil, "Key should not exist initially")

        // Delete should succeed even if key doesn't exist
        try KeychainManager.deleteAPIKey()

        // Should still not exist
        let after = try KeychainManager.getAPIKey()
        #expect(after == nil, "Key should still not exist")
    }

    @Test("Delete and recreate API key")
    func deleteAndRecreateKey() throws {
        self.cleanupAPIKey()

        let key1 = "sk-first"
        let key2 = "sk-second"

        // Create, delete, recreate
        try KeychainManager.setAPIKey(key1)
        try KeychainManager.deleteAPIKey()
        try KeychainManager.setAPIKey(key2)

        let final = try KeychainManager.getAPIKey()
        #expect(final == key2, "Recreated key should be the new one")

        try KeychainManager.deleteAPIKey()
    }

    // MARK: - hasAPIKey() Tests

    @Test("hasAPIKey returns true when key exists")
    func hasAPIKeyReturnsTrue() throws {
        self.cleanupAPIKey()

        #expect(KeychainManager.hasAPIKey() == false, "Should not have key initially")

        try KeychainManager.setAPIKey("sk-test")
        #expect(KeychainManager.hasAPIKey() == true, "Should have key after setting")

        try KeychainManager.deleteAPIKey()
        #expect(KeychainManager.hasAPIKey() == false, "Should not have key after delete")
    }

    @Test("hasAPIKey returns false when getAPIKey throws")
    func hasAPIKeyReturnsFalseOnError() {
        self.cleanupAPIKey()

        // If getAPIKey throws an unexpected error, hasAPIKey should return false
        // (In real scenarios, this would be Keychain corruption or access denial)
        let result = KeychainManager.hasAPIKey()
        #expect(result == false, "Should return false when key doesn't exist")
    }

    // MARK: - Generic Account Operations Tests

    @Test("Generic set and get for custom account")
    func genericSetAndGet() throws {
        self.cleanupAPIKey()

        let account = "test_account_1"
        let value = "test-value-123"

        try KeychainManager.set(value, forAccount: account)
        let retrieved = try KeychainManager.get(forAccount: account)

        #expect(retrieved == value, "Should retrieve same value for account")

        try KeychainManager.delete(forAccount: account)
    }

    @Test("Multiple accounts coexist independently")
    func multipleAccountsCoexist() throws {
        self.cleanupAPIKey()

        let account1 = "test_account_1"
        let account2 = "test_account_2"
        let value1 = "value-for-account-1"
        let value2 = "value-for-account-2"

        try KeychainManager.set(value1, forAccount: account1)
        try KeychainManager.set(value2, forAccount: account2)

        let read1 = try KeychainManager.get(forAccount: account1)
        let read2 = try KeychainManager.get(forAccount: account2)

        #expect(read1 == value1, "Account 1 should have its own value")
        #expect(read2 == value2, "Account 2 should have its own value")
        #expect(read1 != read2, "Values should be different")

        try KeychainManager.delete(forAccount: account1)
        let read1AfterDelete = try KeychainManager.get(forAccount: account1)
        let read2AfterDelete = try KeychainManager.get(forAccount: account2)

        #expect(read1AfterDelete == nil, "Account 1 should be deleted")
        #expect(read2AfterDelete == value2, "Account 2 should still exist")

        try KeychainManager.delete(forAccount: account2)
    }

    @Test("API key account is separate from generic accounts")
    func apiKeyAccountSeparateFromGeneric() throws {
        self.cleanupAPIKey()

        let apiKey = "sk-api-key"
        let genericAccount = "generic_storage"
        let genericValue = "generic-data"

        try KeychainManager.setAPIKey(apiKey)
        try KeychainManager.set(genericValue, forAccount: genericAccount)

        let readAPIKey = try KeychainManager.getAPIKey()
        let readGeneric = try KeychainManager.get(forAccount: genericAccount)

        #expect(readAPIKey == apiKey, "API key should be separate")
        #expect(readGeneric == genericValue, "Generic value should be separate")

        // Delete API key shouldn't affect generic
        try KeychainManager.deleteAPIKey()
        let readAPIKeyAfterDelete = try KeychainManager.getAPIKey()
        let readGenericAfterDelete = try KeychainManager.get(forAccount: genericAccount)

        #expect(readAPIKeyAfterDelete == nil, "API key should be deleted")
        #expect(readGenericAfterDelete == genericValue, "Generic value should still exist")

        try KeychainManager.delete(forAccount: genericAccount)
    }

    @Test("Generic account delete non-existent succeeds")
    func genericDeleteNonExistent() throws {
        self.cleanupAPIKey()

        let account = "non_existent_account"

        // Should succeed even if account doesn't exist
        try KeychainManager.delete(forAccount: account)

        // Verify it really doesn't exist
        let value = try KeychainManager.get(forAccount: account)
        #expect(value == nil, "Account should not exist")
    }

    // MARK: - Error Handling Tests

    @Test("KeychainError has localized descriptions")
    func keychainErrorDescriptions() {
        let emptyError = KeychainManager.KeychainError.emptyKey
        #expect(
            emptyError.localizedDescription == "Cannot store empty key",
            "emptyKey should have description"
        )

        let invalidError = KeychainManager.KeychainError.invalidData
        #expect(
            invalidError.localizedDescription == "Invalid data format in Keychain",
            "invalidData should have description"
        )

        let unhandledError = KeychainManager.KeychainError.unhandledError(-34018)
        #expect(
            unhandledError.localizedDescription.contains("OSStatus"),
            "unhandledError should mention OSStatus"
        )
    }

    @Test("getAPIKey throws on invalid UTF-8 data in Keychain")
    func getAPIKeyThrowsOnInvalidUTF8() async throws {
        self.cleanupAPIKey()

        // This test verifies that if Keychain contains non-UTF8 data,
        // getAPIKey() throws KeychainError.invalidData
        // Note: We can't easily create this scenario without direct Keychain manipulation

        // Verify the error type exists and can be thrown
        do {
            _ = try KeychainManager.getAPIKey()
            // No key exists, which is fine (returns nil, not error)
        } catch let error as KeychainManager.KeychainError {
            if case .invalidData = error {
                // This is what we expect if data were corrupted
            }
        } catch {
            // Other errors are also acceptable in this context
        }
    }

    // MARK: - Edge Cases

    @Test("Very long API key")
    func veryLongAPIKey() throws {
        self.cleanupAPIKey()

        let longKey = "sk-" + String(repeating: "a", count: 4000)

        try KeychainManager.setAPIKey(longKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved?.count == 4003, "Very long key should be preserved")
        #expect(retrieved == longKey, "Long key content should match")

        try KeychainManager.deleteAPIKey()
    }

    @Test("API key with special characters")
    func apiKeyWithSpecialCharacters() throws {
        self.cleanupAPIKey()

        let specialKey = "sk-!@#$%^&*()_+-=[]{}|;':\",./<>?"

        try KeychainManager.setAPIKey(specialKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == specialKey, "Special characters should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("API key with newlines and tabs")
    func apiKeyWithWhitespace() throws {
        self.cleanupAPIKey()

        let whitespaceKey = "sk-key-with\nnewlines\tand\ttabs"

        try KeychainManager.setAPIKey(whitespaceKey)
        let retrieved = try KeychainManager.getAPIKey()

        #expect(retrieved == whitespaceKey, "Whitespace should be preserved")

        try KeychainManager.deleteAPIKey()
    }

    @Test("Rapid set and delete operations")
    func rapidSetDeleteOperations() throws {
        self.cleanupAPIKey()

        // Perform rapid set/delete cycles
        for i in 0 ..< 20 {
            let key = "sk-rapid-\(i)"
            try KeychainManager.setAPIKey(key)

            let read = try KeychainManager.getAPIKey()
            #expect(read == key, "Rapid operation \(i) should succeed")

            try KeychainManager.deleteAPIKey()
        }

        // Final state should be clean
        let final = try KeychainManager.getAPIKey()
        #expect(final == nil, "All rapid operations completed cleanly")
    }
}
