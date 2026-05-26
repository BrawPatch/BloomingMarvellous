import Foundation
import Combine
import os.log

// MARK: - HomeViewModelProtocol (US-0018: injectable protocol)
@MainActor
public protocol HomeViewModelProtocol: AnyObject {
    var itemsPublisher: AnyPublisher<[String], Never> { get }
    var errorPublisher: AnyPublisher<String?, Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    func loadHomeData() async
    func loadData() async
}

// MARK: - HomeViewModel
// US-0011 / US-0014 / US-0015: All URLSession + CoreData calls extracted from
//   HomeViewController into this ViewModel (MVVM, Single Responsibility).
// US-0018: Dependencies injected via init — no `let service = UserService()` inside class body.
// US-0019 / US-0021: URLs resolved via AppConfig / Environment — no raw string literals.
@MainActor
public final class HomeViewModel: HomeViewModelProtocol, ObservableObject {

    // MARK: - Published state
    @Published private(set) var items: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    // Combine publishers for UIKit bindings
    public var itemsPublisher: AnyPublisher<[String], Never> {
        $items.eraseToAnyPublisher()
    }
    public var errorPublisher: AnyPublisher<String?, Never> {
        $errorMessage.eraseToAnyPublisher()
    }
    public var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    // MARK: - Dependencies (US-0018: injected, protocol-typed)
    private let network: NetworkServiceProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "HomeViewModel")

    // MARK: - Constants (US-0032 / US-0034: magic numbers named)
    private enum Constants {
        static let maxItemCount: Int  = 999  // US-0032
        static let processingLimit: Int = 50 // US-0034
    }

    // MARK: - Init
    public init() {
        self.network = NetworkService()
    }

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    // MARK: - Load Home Data
    // US-0013: URL uses https:// via Environment.Path (no hardcoded http://)
    // US-0020: Routed through NetworkService, not URLSession.shared directly
    public func loadHomeData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // US-0019: Endpoint path from config — no hardcoded URL string here
            let endpoint = Endpoint(path: Environment.Path.home)
            let result: [String] = try await network.request(endpoint)
            items = result
            logger.debug("Home data loaded: \(result.count) items.")
        } catch {
            errorMessage = error.localizedDescription
            logger.warning("Home data load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Data
    // US-0015 / US-0021 / US-0022: Extracted from ViewController, uses config URL
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // US-0021: No raw "https://api.myapp.com/data" — resolved via Environment.Path
            let endpoint = Endpoint(path: Environment.Path.data)
            let result: [String] = try await network.request(endpoint)
            // US-0033: Logger replaces print("Loaded \(result.count) items") — no sensitive data
            logger.debug("Data loaded: \(result.count) items.")
            items = Array(result.prefix(Constants.maxItemCount)) // US-0032
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Process Data
    // US-0034: magic number 50 replaced with Constants.processingLimit
    func processData(input: String) -> String {
        var output = input
        for i in 0..<Constants.processingLimit {
            output += String(i)
        }
        return output
    }
}
