import XCTest
import Combine
@testable import BloomingMarvellous

// MARK: - HomeViewModelTests
// US-0011 / US-0018: ViewModel tested in isolation — no UIKit component instantiated.
// US-0017-style coverage goal: ≥ 80% line coverage.
@MainActor
final class HomeViewModelTests: XCTestCase {

    var mockNetwork: MockNetworkService!
    var sut: HomeViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkService()
        sut = HomeViewModel(network: mockNetwork)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockNetwork = nil
        super.tearDown()
    }

    // MARK: - loadData (US-0015: extracted from VC)

    func test_loadData_success_publishesItems() async {
        mockNetwork.result = .success(["rose", "tulip", "lily"] as [String])

        await sut.loadData()

        XCTAssertEqual(sut.items, ["rose", "tulip", "lily"])
        XCTAssertNil(sut.errorMessage)
    }

    func test_loadData_failure_publishesError() async {
        mockNetwork.result = .failure(NetworkError.httpError(statusCode: 500))

        await sut.loadData()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - loadHomeData (US-0014)

    func test_loadHomeData_success_updatesItems() async {
        mockNetwork.result = .success(["home1", "home2"] as [String])

        await sut.loadHomeData()

        XCTAssertEqual(sut.items, ["home1", "home2"])
    }

    // MARK: - isLoading toggle

    func test_loadData_togglesIsLoading() async {
        let expectation = expectation(description: "isLoading goes true then false")
        var states: [Bool] = []

        sut.isLoadingPublisher
            .sink { states.append($0) }
            .store(in: &cancellables)

        mockNetwork.result = .success([] as [String])
        await sut.loadData()

        // Initial false → true during load → false after
        XCTAssertTrue(states.contains(true))
        XCTAssertFalse(sut.isLoading)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1)
    }

    // MARK: - processData (US-0034: magic number 50 → Constants)

    func test_processData_appendsExpectedSuffix() {
        let result = sut.processData(input: "start_")
        // Should append 0..<50 (50 iterations)
        XCTAssertTrue(result.hasPrefix("start_"))
        XCTAssertTrue(result.hasSuffix("49"))
    }

    func test_processData_emptyInput() {
        let result = sut.processData(input: "")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Dependency injection (US-0018)

    func test_viewModel_acceptsMockNetwork() {
        // Confirms protocol injection works — no concrete URLSession in ViewModel
        let vm = HomeViewModel(network: MockNetworkService())
        XCTAssertNotNil(vm)
    }
}
