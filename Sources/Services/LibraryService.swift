import Foundation
import os.log

// MARK: - LibraryServiceProtocol
//
// Fetches the tier-filtered plant library from the backend. The bundled
// `PlantLibrary.all` is the offline fallback — used before the first
// successful fetch and whenever the network call fails.

public protocol LibraryServiceProtocol {
    func fetchLibrary() async throws -> [Plant]
}

// MARK: - LibraryService

public final class LibraryService: LibraryServiceProtocol {

    private let network: NetworkServiceProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "LibraryService")

    public init(network: NetworkServiceProtocol = NetworkService()) {
        self.network = network
    }

    public func fetchLibrary() async throws -> [Plant] {
        let endpoint = Endpoint(path: "library", method: .get, requiresAuth: true)
        let plants: [Plant] = try await network.request(endpoint)
        logger.debug("Fetched \(plants.count) plants from /v1/library")
        return plants
    }
}
