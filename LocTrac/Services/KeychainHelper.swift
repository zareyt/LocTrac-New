//
//  KeychainHelper.swift
//  LocTrac
//
//  Generic Keychain wrapper using the Security framework.
//  All auth credentials (passwords, tokens, TOTP secrets) are stored here.
//
//  Service identifier: com.loctrac.auth
//

import Foundation
import Security

struct KeychainHelper {

    // MARK: - Configuration

    private static let service = "com.loctrac.auth"

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case dataConversionError

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "An item with this key already exists in the Keychain."
            case .itemNotFound:
                return "No item found in the Keychain for this key."
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            case .dataConversionError:
                return "Failed to convert data to/from Keychain format."
            }
        }
    }

    // MARK: - Data Operations

    /// Saves raw data to the Keychain for a given key.
    /// Overwrites any existing value for the same key.
    static func save(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Reads raw data from the Keychain for a given key.
    /// Returns nil if no item exists for the key.
    static func read(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Checks if an item exists in the Keychain for a given key.
    static func exists(forKey key: String) -> Bool {
        return read(forKey: key) != nil
    }

    /// Deletes an item from the Keychain for a given key.
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Deletes all items for the LocTrac auth service.
    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - String Convenience

    /// Saves a string value to the Keychain.
    static func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try save(data: data, forKey: key)
    }

    /// Reads a string value from the Keychain.
    static func readString(forKey key: String) -> String? {
        guard let data = read(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Codable Convenience

    /// Saves a Codable value to the Keychain.
    static func saveCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try save(data: data, forKey: key)
    }

    /// Reads a Codable value from the Keychain.
    static func readCodable<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        guard let data = read(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
