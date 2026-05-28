import Foundation
import Combine
import os.log

// MARK: - HomeViewModelProtocol (US-0018: injectable protocol)
@MainActor
public protocol HomeViewModelProtocol: AnyObject {
    var welcomeItemsPublisher: AnyPublisher<[String], Never> { get }
    var libraryItemsPublisher: AnyPublisher<[String], Never> { get }
    var errorPublisher:        AnyPublisher<String?, Never> { get }
    var isLoadingPublisher:    AnyPublisher<Bool, Never>    { get }

    func loadHomeData() async
    func loadLibraryData() async
    func loadAll() async
}

// MARK: - HomeViewModel
//
// Loads the two read-only endpoints exposed by the backend Lambda
// (`/v1/home` and `/v1/data`) and surfaces them as separate `@Published`
// arrays so a SwiftUI consumer can render the Welcome card and the
// Plant Library side-by-side. Each loader is independent so callers can
// refresh one without invalidating the other.
@MainActor
public final class HomeViewModel: HomeViewModelProtocol, ObservableObject {

    // MARK: - Published state
    @Published public private(set) var welcomeItems: [String] = []
    @Published public private(set) var libraryItems: [String] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isLoading: Bool = false

    // MARK: - Combine publishers (UIKit / non-@StateObject consumers)
    public var welcomeItemsPublisher: AnyPublisher<[String], Never> { $welcomeItems.eraseToAnyPublisher() }
    public var libraryItemsPublisher: AnyPublisher<[String], Never> { $libraryItems.eraseToAnyPublisher() }
    public var errorPublisher:        AnyPublisher<String?, Never> { $errorMessage.eraseToAnyPublisher() }
    public var isLoadingPublisher:    AnyPublisher<Bool, Never>    { $isLoading.eraseToAnyPublisher() }

    // MARK: - Dependencies (US-0018: injected, protocol-typed)
    private let network: NetworkServiceProtocol
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
        category: "HomeViewModel"
    )

    // MARK: - Constants (US-0032: magic numbers named)
    private enum Constants {
        static let maxItemCount: Int = 999
    }

    // MARK: - Init

    public init() {
        self.network = NetworkService()
    }

    public init(network: NetworkServiceProtocol) {
        self.network = network
    }

    // MARK: - Loaders
    //
    // Each call is self-contained: it toggles `isLoading`, clears the
    // relevant array on failure, and routes errors into `errorMessage`
    // so the UI binds to a single field.

    public func loadHomeData() async {
        await load(into: \.welcomeItems, from: Environment.Path.home, label: "home")
    }

    public func loadLibraryData() async {
        await load(into: \.libraryItems, from: Environment.Path.data, label: "data")
    }

    /// Convenience: fire both loaders in parallel and surface the first
    /// error if either fails. Used by the SwiftUI HomeView on appearance.
    public func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        // Capture errors locally so neither task overwrites the other's failure
        // before we've decided which one to surface.
        async let homeResult: Result<[String], Error> = fetch(Environment.Path.home)
        async let libResult:  Result<[String], Error> = fetch(Environment.Path.data)

        let (h, l) = await (homeResult, libResult)

        switch h {
        case .success(let items): welcomeItems = Array(items.prefix(Constants.maxItemCount))
        case .failure:            welcomeItems = []
        }
        switch l {
        case .success(let items): libraryItems = Array(items.prefix(Constants.maxItemCount))
        case .failure:            libraryItems = []
        }

        // Error precedence: surface the first failure (home), otherwise library's.
        switch (h, l) {
        case (.failure(let e), _), (_, .failure(let e)):
            errorMessage = e.localizedDescription
            logger.warning("Home load surfaced error: \(e.localizedDescription)")
        case (.success, .success):
            errorMessage = nil
        }
    }

    // MARK: - Private helpers

    private func load(into keyPath: ReferenceWritableKeyPath<HomeViewModel, [String]>,
                      from path: String,
                      label: String) async {
        isLoading = true
        defer { isLoading = false }

        switch await fetch(path) {
        case .success(let items):
            self[keyPath: keyPath] = Array(items.prefix(Constants.maxItemCount))
            errorMessage = nil
            logger.debug("\(label) loaded: \(items.count) items.")
        case .failure(let error):
            self[keyPath: keyPath] = []
            errorMessage = error.localizedDescription
            logger.warning("\(label) load failed: \(error.localizedDescription)")
        }
    }

    private func fetch(_ path: String) async -> Result<[String], Error> {
        do {
            let items: [String] = try await network.request(Endpoint(path: path))
            return .success(items)
        } catch {
            return .failure(error)
        }
    }
}
