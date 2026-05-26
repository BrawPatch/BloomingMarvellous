import Foundation
import CryptoKit
import Security
import os.log

// MARK: - AuthServiceProtocol (US-0018: injectable)
protocol AuthServiceProtocol {
    func login(username: String, pass: String) async throws -> UserModel
    func hashPassword(_ pw: String) -> String
    func generateSecureToken(byteCount: Int) throws -> Data
}

// MARK: - AuthService
// US-0029: Renamed `authService` → `AuthService` (PascalCase)
// US-0001: `apiKey` hardcoded literal REMOVED — loaded from Keychain at runtime.
// US-0002: `password` hardcoded literal REMOVED — loaded from Keychain at runtime.
final class AuthService: AuthServiceProtocol {

    // US-0030: Logger replaces print() / NSLog for all non-sensitive diagnostic output
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "AuthService")

    private let keychain: KeychainServiceProtocol
    private let network: NetworkServiceProtocol

    // MARK: - Init (US-0018: constructor injection)
    init(keychain: KeychainServiceProtocol = KeychainService(),
         network: NetworkServiceProtocol = NetworkService()) {
        self.keychain = keychain
        self.network = network
    }

    // MARK: - Login
    // US-0008: Password no longer written to UserDefaults — token stored in Keychain.
    // US-0009: Sensitive values (pass, token) never appear in log output.
    func login(username: String, pass: String) async throws -> UserModel {
        // US-0009: Do NOT log `pass` or any token value — log only metadata.
        logger.debug("Login attempt initiated for username category (value redacted).")

        // Build login request body — passwords travel over HTTPS only (US-0004)
        let body = try JSONEncoder().encode(["username": username, "password": pass])
        let endpoint = Endpoint(path: Environment.Path.login, method: .post, body: body)

        let user: UserModel = try await network.request(endpoint)

        // US-0008: Store auth token in Keychain, NOT UserDefaults.
        try keychain.save(user.apiToken, forKey: KeychainKey.authToken)

        logger.debug("Login succeeded — token stored in Keychain (value redacted).")
        return user
    }

    // MARK: - Hash Password
    // US-0003: MD5 (CC_MD5) REMOVED. SHA-256 via CryptoKit (OWASP M5).
    // US-0010: arc4random() REMOVED — not a CSPRNG. SHA-256 of UTF-8 bytes used here.
    func hashPassword(_ pw: String) -> String {
        guard let data = pw.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Secure Token Generation
    // US-0010: CSPRNG via SecRandomCopyBytes (replaces arc4random / rand)
    func generateSecureToken(byteCount: Int = 32) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return Data(bytes)
    }

    // MARK: - Retrieve API Key at runtime (US-0001)
    /// Returns the API key from Keychain. Never stored in source code.
    func retrieveAPIKey() throws -> String {
        return try keychain.retrieve(forKey: KeychainKey.apiKey)
    }
}
