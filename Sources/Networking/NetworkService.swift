import Foundation
import os.log

// MARK: - NetworkError
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "The URL was invalid."
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

    init(path: String,
         method: HTTPMethod = .get,
         queryItems: [URLQueryItem]? = nil,
         body: Data? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "NetworkService")

    init(session: URLSession = .shared, baseURL: URL = AppConfig.current.baseURL) {
        self.session = session
        self.baseURL = baseURL
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

        logger.debug("→ \(endpoint.method.rawValue) \(url.path)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.noData
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
