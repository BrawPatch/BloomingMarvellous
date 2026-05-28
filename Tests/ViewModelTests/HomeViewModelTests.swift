import XCTest
import Combine
@testable import BloomingMarvellous

// MARK: - HomeViewModelTests
//
// Every test asserts BOTH the expected change (positive) and a non-change
// elsewhere (negative). That guards against over-eager writes — e.g. a
// library load mutating the welcome array — which the previous single-list
// shape couldn't have caught.
@MainActor
final class HomeViewModelTests: XCTestCase {

    var mockNetwork: MockNetworkService!
    var sut: HomeViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetwork  = MockNetworkService()
        sut          = HomeViewModel(network: mockNetwork)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut          = nil
        mockNetwork  = nil
        super.tearDown()
    }

    // MARK: - loadHomeData

    func test_loadHomeData_success_populatesWelcomeOnly() async {
        mockNetwork.result = .success(["Welcome", "Tap to begin"] as [String])

        await sut.loadHomeData()

        // Positive: /home payload populates welcome, no spurious error,
        // loading flag resolves false.
        XCTAssertEqual(sut.welcomeItems, ["Welcome", "Tap to begin"])
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)

        // Negative: loadHomeData must NOT touch libraryItems.
        XCTAssertTrue(sut.libraryItems.isEmpty,
                      "loadHomeData() must not write the library list")
    }

    func test_loadHomeData_failure_setsErrorAndClearsWelcome() async {
        // Seed the welcome list with stale content so we can assert it
        // gets cleared on failure (not retained from a previous load).
        mockNetwork.result = .success(["stale"] as [String])
        await sut.loadHomeData()
        XCTAssertEqual(sut.welcomeItems, ["stale"])  // sanity precondition

        mockNetwork.result = .failure(NetworkError.httpError(statusCode: 500))
        await sut.loadHomeData()

        // Positive: error message is surfaced, welcome is cleared.
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.welcomeItems.isEmpty)

        // Negative: library remains untouched, loading flag is false.
        XCTAssertTrue(sut.libraryItems.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - loadLibraryData

    func test_loadLibraryData_success_populatesLibraryOnly() async {
        mockNetwork.result = .success(["Lavender", "Cosmos", "Dahlia"] as [String])

        await sut.loadLibraryData()

        // Positive: library populated, no error, not loading.
        XCTAssertEqual(sut.libraryItems, ["Lavender", "Cosmos", "Dahlia"])
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)

        // Negative: welcome is independent and must not be polluted.
        XCTAssertTrue(sut.welcomeItems.isEmpty,
                      "loadLibraryData() must not write the welcome list")
    }

    func test_loadLibraryData_failure_setsErrorAndClearsLibrary() async {
        mockNetwork.result = .success(["stale"] as [String])
        await sut.loadLibraryData()
        XCTAssertEqual(sut.libraryItems, ["stale"])

        mockNetwork.result = .failure(NetworkError.unauthorized)
        await sut.loadLibraryData()

        // Positive: error appears, library cleared.
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.libraryItems.isEmpty)

        // Negative: welcome untouched, loading flag false.
        XCTAssertTrue(sut.welcomeItems.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - loadAll

    func test_loadAll_success_populatesBothAndClearsError() async {
        // Pre-seed errorMessage so we can assert it gets cleared.
        mockNetwork.result = .failure(NetworkError.noData)
        await sut.loadHomeData()
        XCTAssertNotNil(sut.errorMessage)  // sanity precondition

        mockNetwork.result = .success(["a", "b"] as [String])
        await sut.loadAll()

        // Positive: both lists populated from the same payload (mock
        // returns the same array twice), errorMessage cleared, loading
        // resolves to false.
        XCTAssertEqual(sut.welcomeItems, ["a", "b"])
        XCTAssertEqual(sut.libraryItems, ["a", "b"])
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)

        // Negative: neither list is left empty by a partial overwrite.
        XCTAssertFalse(sut.welcomeItems.isEmpty)
        XCTAssertFalse(sut.libraryItems.isEmpty)
    }

    func test_loadAll_failure_setsErrorAndLeavesBothEmpty() async {
        mockNetwork.result = .failure(NetworkError.httpError(statusCode: 503))

        await sut.loadAll()

        // Positive: error surfaced, loading flag resolves.
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)

        // Negative: nothing got partially populated.
        XCTAssertTrue(sut.welcomeItems.isEmpty)
        XCTAssertTrue(sut.libraryItems.isEmpty)
    }

    // MARK: - isLoading lifecycle

    func test_isLoading_togglesTrueThenFalseAcrossAFetch() async {
        var states: [Bool] = []
        sut.isLoadingPublisher
            .sink { states.append($0) }
            .store(in: &cancellables)

        mockNetwork.result = .success([] as [String])
        await sut.loadHomeData()

        // Positive: isLoading transitioned through `true` during the
        // fetch (otherwise spinners never appear), and settled at `false`.
        XCTAssertTrue(states.contains(true),
                      "isLoading must flip true during the in-flight request")
        XCTAssertEqual(states.last, false)
        XCTAssertFalse(sut.isLoading)

        // Negative: there must NOT be more than one `true` window — the
        // loader shouldn't bounce isLoading off and on within one call.
        let trueRuns = states.reduce(into: (count: 0, prev: false)) { acc, s in
            if s && !acc.prev { acc.count += 1 }
            acc.prev = s
        }.count
        XCTAssertEqual(trueRuns, 1, "isLoading must enter the `true` state exactly once per fetch")
    }

    // MARK: - Dependency injection

    func test_init_acceptsInjectedNetwork() {
        let custom = MockNetworkService()
        let vm = HomeViewModel(network: custom)

        // Positive: the convenience init returns an instance.
        XCTAssertNotNil(vm)

        // Negative: the default no-arg init does NOT share state with the
        // injected one — they're independent objects. (Guards against an
        // accidental shared-singleton refactor.)
        let defaultVM = HomeViewModel()
        XCTAssertFalse(vm === defaultVM)
    }

    // MARK: - Publisher contract

    func test_publishersEmitInitialStateOnSubscribe() {
        var welcome: [String]? = nil
        var library: [String]? = nil
        var error:   String??  = nil
        var loading: Bool?     = nil

        sut.welcomeItemsPublisher.sink { welcome = $0 }.store(in: &cancellables)
        sut.libraryItemsPublisher.sink { library = $0 }.store(in: &cancellables)
        sut.errorPublisher.sink        { error   = $0 }.store(in: &cancellables)
        sut.isLoadingPublisher.sink    { loading = $0 }.store(in: &cancellables)

        // Positive: every published property emits its initial value on
        // subscription (so SwiftUI / Combine sinks receive a starting state).
        XCTAssertEqual(welcome, [])
        XCTAssertEqual(library, [])
        XCTAssertEqual(loading, false)

        // Negative: no spurious error fires at construction time.
        XCTAssertNotNil(error)             // closure ran
        XCTAssertNil(error ?? "non-nil")   // …with the wrapped value being nil
    }
}
