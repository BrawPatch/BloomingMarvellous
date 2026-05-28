import Foundation
import os.log

// MARK: - NetworkError
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "The URL was invalid."
        case .unauthorized:             return "Not signed in. Please log in again."
        case .httpError(let code):      return "HTTP error: \(code)."
        case .decodingError(let e):     return "Decoding failed: \(e.localizedDescription)"
        case .noData:                   return "No data received."
        case .unknown(let e):           return e.localizedDescription
        }
    }
}

// MARK: - NetworkServiceProtocol
// US-0020 / US-0022: All URLSession usage is behind this protocol — testable via MockNetworkService.
protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

// MARK: - Endpoint
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: Data?
    /// When true (default), `NetworkService` retrieves the Bearer token from
    /// Keychain and attaches it as `Authorization`. Set false for endpoints
    /// that issue a token (e.g. login) and therefore must travel unauthenticated.
    let requiresAuth: Bool

    init(path: String,
         method: HTTPMethod = .get,
         queryItems: [URLQueryItem]? = nil,
         body: Data? = nil,
         requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
    }

    func url(relativeTo base: URL) -> URL? {
        var components = URLComponents(url: base.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        return components?.url
    }
}

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
}

// MARK: - NetworkService (concrete implementation)
// US-0004 / US-0013: base URL always https:// (from AppConfig / Environment)
// US-0020 / US-0022: single URLSession wrapper — no direct URLSession.shared at call sites
final class NetworkService: NetworkServiceProtocol {

    private let session: URLSession
    private let baseURL: URL
    private let keychain: KeychainServiceProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "NetworkService")

    init(session: URLSession = .shared,
         baseURL: URL = AppConfig.current.baseURL,
         keychain: KeychainServiceProtocol = KeychainService()) {
        self.session = session
        self.baseURL = baseURL
        self.keychain = keychain
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let url = endpoint.url(relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: AppConfig.requestTimeoutSeconds) // US-0024
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // US-0008: attach Bearer token from Keychain for authenticated endpoints.
        // The login endpoint sets requiresAuth=false so it can issue the token.
        if endpoint.requiresAuth {
            do {
                let token = try keychain.retrieve(forKey: KeychainKey.authToken)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch KeychainError.itemNotFound {
                // No stored token → caller needs to sign in first. Don't fire an
                // unauthenticated request and let the server 401 us; surface the
                // condition immediately so the UI can route to the login flow.
                throw NetworkError.unauthorized
            } catch {
                throw NetworkError.unknown(error)
            }
        }

        logger.debug("→ \(endpoint.method.rawValue) \(url.path) auth=\(endpoint.requiresAuth)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        if http.statusCode == 401 {
            // Token rejected (likely expired or revoked server-side).
            logger.warning("401 on \(url.path) — clearing stored token.")
            try? keychain.delete(forKey: KeychainKey.authToken)
            throw NetworkError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            logger.warning("HTTP \(http.statusCode) for \(url.path)")
            throw NetworkError.httpError(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}

// MARK: - MockNetworkService (US-0020 / US-0022: injectable mock for tests)
final class MockNetworkService: NetworkServiceProtocol {
    var result: Result<Any, Error> = .failure(NetworkError.noData)

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        switch result {
        case .success(let value):
            guard let typed = value as? T else { throw NetworkError.noData }
            return typed
        case .failure(let error):
            throw error
        }
    }
}
