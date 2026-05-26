import UIKit
import Combine
import os.log
// CoreData import REMOVED from ViewController — persistence belongs in Repository layer (US-0011)

// MARK: - HomeViewController
// US-0011 / US-0014 / US-0015: ViewController contains NO direct URLSession or CoreData calls.
//   All data operations are delegated to HomeViewModel (MVVM).
// US-0035: TODO replaced with JIRA ticket reference → See: BM-101 (MVVM migration tracked).
class HomeViewController: UIViewController {

    // MARK: - Constants (US-0032: magic number 999 → named constant)
    private enum Constants {
        static let maxDisplayCount: Int = 999
    }

    // MARK: - Properties
    // US-0031: `user_name` → `userName` (camelCase)
    var userName: String = ""

    // US-0018: Dependency injected — no `let service = UserService()` inside class body.
    // See: BM-102 — wire via DI container (Swinject) in AppDelegate/Coordinator.
    private var viewModel: HomeViewModelProtocol

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "HomeViewController")

    // MARK: - UI
    private let tableView = UITableView()
    private var dataItems: [String] = []

    // MARK: - Init (US-0018: constructor injection)
    init(viewModel: HomeViewModelProtocol = HomeViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.viewModel = HomeViewModel()
        super.init(coder: coder)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        bindViewModel()

        // US-0012: `DispatchQueue.main.sync` REMOVED — replaced with Task + @MainActor.
        // Heavy work dispatched to async context; @MainActor in ViewModel ensures UI safety.
        Task { await viewModel.loadData() }
    }

    // MARK: - Bindings (US-0011: data flows from ViewModel via Combine publishers)
    private func bindViewModel() {
        viewModel.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.dataItems = items
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.errorPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showError(message)
            }
            .store(in: &cancellables)

        viewModel.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                // Show/hide activity indicator
                loading ? self?.showLoading() : self?.hideLoading()
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Setup
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func showLoading() {
        // TODO: replace with proper loading indicator — See: BM-103
    }

    private func hideLoading() { }

    private func showError(_ message: String) {
        logger.warning("Displaying error to user (non-sensitive): \(message)")
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // US-0032: Uses named constant instead of magic literal 999
        return min(dataItems.count, Constants.maxDisplayCount)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = dataItems[indexPath.row]
        return cell
    }
}
