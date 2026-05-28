import Foundation
import Security
import os.log

// MARK: - KeychainError
public enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .duplicateItem:        return "Keychain item already exists."
        case .itemNotFound:         return "Keychain item not found."
        case .unexpectedStatus(let s): return "Unexpected Keychain OSStatus: \(s)."
        }
    }
}

// MARK: - KeychainServiceProtocol (US-0018: injectable via protocol)
public protocol KeychainServiceProtocol {
    func save(_ value: String, forKey key: String) throws
    func retrieve(forKey key: String) throws -> String
    func delete(forKey key: String) throws
}

// MARK: - KeychainService
// US-0001 / US-0002: Replaces hardcoded apiKey / password literals.
// US-0008: Replaces UserDefaults storage of sensitive data.
// kSecAttrAccessible set to kSecAttrAccessibleWhenUnlockedThisDeviceOnly per OWASP M2.
public final class KeychainService: KeychainServiceProtocol {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "KeychainService")

    public init() {}

    // MARK: - Save
    public func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }

        let query: [CFString: Any] = [
            kSecClass:               kSecClassGenericPassword,
            kSecAttrAccount:         key,
            kSecValueData:           data,
            kSecAttrAccessible:      kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Remove any existing item first (upsert pattern)
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for key '\(key, privacy: .private)': \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
        logger.debug("Keychain save succeeded for key category (value redacted).")
    }

    // MARK: - Retrieve
    public func retrieve(forKey key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:               kSecClassGenericPassword,
            kSecAttrAccount:         key,
            kSecReturnData:          true,
            kSecMatchLimit:          kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }
        return value
    }

    // MARK: - Delete
    public func delete(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - Keychain Keys Namespace
public enum KeychainKey {
    public static let apiKey    = "com.bloomingmarvellous.apiKey"    // US-0001
    public static let password  = "com.bloomingmarvellous.password"  // US-0002
    public static let authToken = "com.bloomingmarvellous.authToken" // US-0008
}
