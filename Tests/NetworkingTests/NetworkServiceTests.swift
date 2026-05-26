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
