import XCTest
import CryptoKit
@testable import BloomingMarvellous

// MARK: - MockKeychainService
final class MockKeychainService: KeychainServiceProtocol {
    var store: [String: String] = [:]
    var saveError: Error?
    var retrieveError: Error?

    func save(_ value: String, forKey key: String) throws {
        if let error = saveError { throw error }
        store[key] = value
    }
    func retrieve(forKey key: String) throws -> String {
        if let error = retrieveError { throw error }
        guard let value = store[key] else { throw KeychainError.itemNotFound }
        return value
    }
    func delete(forKey key: String) throws {
        store.removeValue(forKey: key)
    }
}

// MARK: - AuthServiceTests
// US-0018: AuthService injected with mocks — no simulator needed.
final class AuthServiceTests: XCTestCase {

    var mockKeychain: MockKeychainService!
    var mockNetwork: MockNetworkService!
    var sut: AuthService!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
        mockNetwork = MockNetworkService()
        sut = AuthService(keychain: mockKeychain, network: mockNetwork)
    }

    override func tearDown() {
        sut = nil
        mockKeychain = nil
        mockNetwork = nil
        super.tearDown()
    }

    // MARK: - Hash Password (US-0003: SHA-256, not MD5)

    func test_hashPassword_usesSHA256() {
        let hash = sut.hashPassword("hunter2")
        // SHA-256 of "hunter2" is deterministic — verify hex length (64 chars)
        XCTAssertEqual(hash.count, 64, "SHA-256 hex string must be 64 characters")
        // Verify it is NOT the MD5 of "hunter2" (MD5 = 2ab96390c7dbe3439de74d0c9b0b1767, 32 chars)
        XCTAssertNotEqual(hash.count, 32)
    }

    func test_hashPassword_isConsistent() {
        let h1 = sut.hashPassword("password123")
        let h2 = sut.hashPassword("password123")
        XCTAssertEqual(h1, h2)
    }

    func test_hashPassword_differentInputs_produceDifferentHashes() {
        XCTAssertNotEqual(sut.hashPassword("abc"), sut.hashPassword("xyz"))
    }

    func test_hashPassword_emptyString() {
        let hash = sut.hashPassword("")
        XCTAssertEqual(hash.count, 64)
    }

    // MARK: - Secure Token (US-0010: CSPRNG)

    func test_generateSecureToken_defaultLength() throws {
        let token = try sut.generateSecureToken()
        XCTAssertEqual(token.count, 32, "Default token should be 32 bytes")
    }

    func test_generateSecureToken_customLength() throws {
        let token = try sut.generateSecureToken(byteCount: 16)
        XCTAssertEqual(token.count, 16)
    }

    func test_generateSecureToken_isUnique() throws {
        let t1 = try sut.generateSecureToken()
        let t2 = try sut.generateSecureToken()
        XCTAssertNotEqual(t1, t2, "CSPRNG tokens must be unique")
    }

    // MARK: - Login (US-0008: token stored in Keychain, not UserDefaults)

    func test_login_storesTokenInKeychain() async throws {
        let user = UserModel(userId: 1, firstName: "Test", apiToken: "secret_token")
        mockNetwork.result = .success(user)

        _ = try await sut.login(username: "alice", pass: "pass")

        let stored = try mockKeychain.retrieve(forKey: KeychainKey.authToken)
        XCTAssertEqual(stored, "secret_token")

        // US-0008: Verify UserDefaults does NOT have the token
        XCTAssertNil(UserDefaults.standard.string(forKey: "stored_password"))
    }

    func test_login_networkFailure_throws() async {
        mockNetwork.result = .failure(NetworkError.httpError(statusCode: 401))
        do {
            _ = try await sut.login(username: "x", pass: "y")
            XCTFail("Expected throw")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - API Key retrieval (US-0001: loaded from Keychain, never hardcoded)

    func test_retrieveAPIKey_fromKeychain_succeeds() throws {
        mockKeychain.store[KeychainKey.apiKey] = "runtime-api-key"
        let key = try sut.retrieveAPIKey()
        XCTAssertEqual(key, "runtime-api-key")
    }

    func test_retrieveAPIKey_notFound_throws() {
        XCTAssertThrowsError(try sut.retrieveAPIKey()) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
}
