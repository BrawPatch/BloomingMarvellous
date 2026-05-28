import Foundation
import CryptoKit
import Security
import os.log

// MARK: - AuthServiceProtocol (US-0018: injectable)
public protocol AuthServiceProtocol {
    func login(username: String, pass: String) async throws -> UserModel
    func hashPassword(_ pw: String) -> String
    func generateSecureToken(byteCount: Int) throws -> Data
    func hasStoredToken() -> Bool
    func logout() throws
}

// MARK: - AuthService
// US-0029: Renamed `authService` → `AuthService` (PascalCase)
// US-0001: `apiKey` hardcoded literal REMOVED — loaded from Keychain at runtime.
// US-0002: `password` hardcoded literal REMOVED — loaded from Keychain at runtime.
public final class AuthService: AuthServiceProtocol {

    // US-0030: Logger replaces print() / NSLog for all non-sensitive diagnostic output
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "AuthService")

    private let keychain: KeychainServiceProtocol
    private let network: NetworkServiceProtocol

    // MARK: - Init (US-0018: constructor injection)
    public init(keychain: KeychainServiceProtocol = KeychainService(),
                network: NetworkServiceProtocol = NetworkService()) {
        self.keychain = keychain
        self.network = network
    }

    // MARK: - Login
    // US-0008: Password no longer written to UserDefaults — token stored in Keychain.
    // US-0009: Sensitive values (pass, token) never appear in log output.
    public func login(username: String, pass: String) async throws -> UserModel {
        // US-0009: Do NOT log `pass` or any token value — log only metadata.
        logger.debug("Login attempt initiated for username category (value redacted).")

        // Build login request body — passwords travel over HTTPS only (US-0004)
        let body = try JSONEncoder().encode(["username": username, "password": pass])
        // requiresAuth=false: login is the endpoint that *issues* the token, so it
        // must travel without a Bearer header (otherwise NetworkService would throw
        // NetworkError.unauthorized on the first-ever login when no token exists).
        let endpoint = Endpoint(path: Environment.Path.login,
                                method: .post,
                                body: body,
                                requiresAuth: false)

        let user: UserModel = try await network.request(endpoint)

        // US-0008: Store auth token in Keychain, NOT UserDefaults.
        try keychain.save(user.apiToken, forKey: KeychainKey.authToken)

        logger.debug("Login succeeded — token stored in Keychain (value redacted).")
        return user
    }

    // MARK: - Hash Password
    // US-0003: MD5 (CC_MD5) REMOVED. SHA-256 via CryptoKit (OWASP M5).
    // US-0010: arc4random() REMOVED — not a CSPRNG. SHA-256 of UTF-8 bytes used here.
    public func hashPassword(_ pw: String) -> String {
        guard let data = pw.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Secure Token Generation
    // US-0010: CSPRNG via SecRandomCopyBytes (replaces arc4random / rand)
    public func generateSecureToken(byteCount: Int = 32) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return Data(bytes)
    }

    // MARK: - Session helpers (used by SwiftUI app entry point)

    /// True when a previously-issued auth token is present in Keychain.
    /// Cheap, synchronous — safe to call from app launch to decide
    /// between LoginView and HomeView. Does NOT validate the token with
    /// the server; a stale token will be invalidated by NetworkService
    /// the first time it gets a 401.
    public func hasStoredToken() -> Bool {
        do {
            _ = try keychain.retrieve(forKey: KeychainKey.authToken)
            return true
        } catch {
            return false
        }
    }

    /// Clears the stored auth token. Server-side session is left in place;
    /// it expires naturally via DynamoDB TTL. Safe to call when no token
    /// is stored.
    public func logout() throws {
        do {
            try keychain.delete(forKey: KeychainKey.authToken)
        } catch KeychainError.itemNotFound {
            // already signed out — not an error
        }
    }

    // MARK: - Retrieve API Key at runtime (US-0001)
    /// Returns the API key from Keychain. Never stored in source code.
    public func retrieveAPIKey() throws -> String {
        return try keychain.retrieve(forKey: KeychainKey.apiKey)
    }
}
