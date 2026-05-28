import XCTest
@testable import BloomingMarvellous

// MARK: - NetworkServiceTests
// US-0020 / US-0022: NetworkServiceProtocol is injectable; MockNetworkService used here.
final class NetworkServiceTests: XCTestCase {

    // MARK: - MockNetworkService (US-0020: protocol mock)

    func test_mockNetworkService_successPath() async throws {
        let mock = MockNetworkService()
        mock.result = .success(["a", "b"] as [String])

        let endpoint = Endpoint(path: "/test")
        let result: [String] = try await mock.request(endpoint)
        XCTAssertEqual(result, ["a", "b"])
    }

    func test_mockNetworkService_failurePath() async {
        let mock = MockNetworkService()
        mock.result = .failure(NetworkError.httpError(statusCode: 404))

        let endpoint = Endpoint(path: "/missing")
        do {
            let _: [String] = try await mock.request(endpoint)
            XCTFail("Expected throw")
        } catch NetworkError.httpError(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Endpoint URL construction

    func test_endpoint_buildsURLCorrectly() {
        let base = URL(string: "https://api.example.com/v1")!
        let endpoint = Endpoint(path: "/users",
                                queryItems: [URLQueryItem(name: "page", value: "1")])
        let url = endpoint.url(relativeTo: base)

        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("users") == true)
        XCTAssertTrue(url?.absoluteString.contains("page=1") == true)
    }

    func test_endpoint_defaultMethod_isGET() {
        let endpoint = Endpoint(path: "/health")
        XCTAssertEqual(endpoint.method, .get)
    }

    // MARK: - Auth wiring (US-0008 follow-up: Bearer attach)

    func test_endpoint_requiresAuth_defaultsToTrue() {
        let endpoint = Endpoint(path: "/home")
        XCTAssertTrue(endpoint.requiresAuth,
                      "Endpoints must default to authenticated — only login opts out.")
    }

    func test_endpoint_requiresAuth_canBeOptedOut() {
        let endpoint = Endpoint(path: "/auth/login", method: .post, requiresAuth: false)
        XCTAssertFalse(endpoint.requiresAuth)
    }

    func test_networkService_throwsUnauthorized_whenTokenMissing() async {
        // Use a keychain mock that reports no stored token. The session should
        // not be touched at all — NetworkService must short-circuit before any
        // HTTP request is made.
        final class EmptyKeychain: KeychainServiceProtocol {
            func save(_: String, forKey _: String) throws {}
            func retrieve(forKey _: String) throws -> String { throw KeychainError.itemNotFound }
            func delete(forKey _: String) throws {}
        }

        let service = NetworkService(session: .shared,
                                     baseURL: URL(string: "https://example.invalid/v1")!,
                                     keychain: EmptyKeychain())
        do {
            let _: [String] = try await service.request(Endpoint(path: "/home"))
            XCTFail("Expected NetworkError.unauthorized")
        } catch NetworkError.unauthorized {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_networkError_unauthorized_hasDescription() {
        XCTAssertFalse(NetworkError.unauthorized.localizedDescription.isEmpty)
    }

    // MARK: - NetworkError localised descriptions

    func test_networkError_invalidURL_hasDescription() {
        let err = NetworkError.invalidURL
        XCTAssertFalse(err.localizedDescription.isEmpty)
    }

    func test_networkError_httpError_includesStatusCode() {
        let err = NetworkError.httpError(statusCode: 503)
        XCTAssertTrue(err.localizedDescription.contains("503"))
    }

    // MARK: - Centralised error mapping (US-0020 / US-0022)

    func test_allNetworkErrorCases_haveDescriptions() {
        let errors: [NetworkError] = [
            .invalidURL,
            .httpError(statusCode: 400),
            .noData,
            .unknown(NSError(domain: "test", code: -1))
        ]
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                           "Error \(error) has no description")
        }
    }
}
