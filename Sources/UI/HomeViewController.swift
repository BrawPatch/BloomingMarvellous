#if canImport(UIKit)
import UIKit
import Combine
import os.log
import BloomingMarvellous
// CoreData import REMOVED from ViewController — persistence belongs in Repository layer (US-0011)

// MARK: - HomeViewController
// US-0011 / US-0014 / US-0015: ViewController contains NO direct URLSession or CoreData calls.
//   All data operations are delegated to HomeViewModel (MVVM).
// US-0035: TODO replaced with JIRA ticket reference → See: BM-101 (MVVM migration tracked).
public class HomeViewController: UIViewController {

    // MARK: - Constants (US-0032: magic number 999 → named constant)
    private enum Constants {
        static let maxDisplayCount: Int = 999
    }

    // MARK: - Properties
    // US-0031: `user_name` → `userName` (camelCase)
    public var userName: String = ""

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
    public init() {
        self.viewModel = HomeViewModel()
        super.init(nibName: nil, bundle: nil)
    }

    public init(viewModel: HomeViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        self.viewModel = HomeViewModel()
        super.init(coder: coder)
    }

    // MARK: - Lifecycle
    public override func viewDidLoad() {
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
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // US-0032: Uses named constant instead of magic literal 999
        return min(dataItems.count, Constants.maxDisplayCount)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = dataItems[indexPath.row]
        return cell
    }
}
#elseif canImport(AppKit)
import AppKit
import Combine
import os.log
import BloomingMarvellous

// MARK: - HomeViewController
// macOS placeholder that mirrors the UIKit table/loading/error surface with AppKit controls.
@MainActor
public class HomeViewController: NSViewController {

    private enum Constants {
        static let maxDisplayCount: Int = 999
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 20
        static let headerSpacing: CGFloat = 8
        static let tableHeight: CGFloat = 320
    }

    public var userName: String = ""

    private var viewModel: HomeViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bloomingmarvellous",
                                category: "MacHomeViewController")

    private let titleLabel = NSTextField(labelWithString: "Blooming Marvellous")
    private let subtitleLabel = NSTextField(labelWithString: "Home data will appear here when the macOS experience is ready.")
    private let statusLabel = NSTextField(labelWithString: "")
    private let loadingIndicator = NSProgressIndicator()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var dataItems: [String] = []

    public init() {
        self.viewModel = HomeViewModel()
        super.init(nibName: nil, bundle: nil)
    }

    public init(viewModel: HomeViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        self.viewModel = HomeViewModel()
        super.init(coder: coder)
    }

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        setupPlaceholderUI()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        Task { await viewModel.loadData() }
    }

    private func setupPlaceholderUI() {
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.textColor = .labelColor

        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2

        statusLabel.font = .preferredFont(forTextStyle: .callout)
        statusLabel.textColor = .secondaryLabelColor

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("homeItem"))
        column.title = "Items"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = Constants.headerSpacing

        let statusStack = NSStackView(views: [loadingIndicator, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = Constants.headerSpacing

        let contentStack = NSStackView(views: [headerStack, statusStack, scrollView])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = Constants.verticalPadding
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalPadding),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: Constants.verticalPadding),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -Constants.verticalPadding),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Constants.tableHeight)
        ])
    }

    private func bindViewModel() {
        viewModel.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                dataItems = Array(items.prefix(Constants.maxDisplayCount))
                statusLabel.stringValue = dataItems.isEmpty ? "No items loaded yet." : "\(dataItems.count) items loaded."
                tableView.reloadData()
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
                loading ? self?.showLoading() : self?.hideLoading()
            }
            .store(in: &cancellables)
    }

    private func showLoading() {
        statusLabel.stringValue = "Loading..."
        loadingIndicator.startAnimation(nil)
    }

    private func hideLoading() {
        loadingIndicator.stopAnimation(nil)
    }

    private func showError(_ message: String) {
        logger.warning("Displaying macOS placeholder error (non-sensitive): \(message)")
        statusLabel.stringValue = message
    }
}

extension HomeViewController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return dataItems.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("HomeItemCell")
        let textField: NSTextField

        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            textField = existing
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.lineBreakMode = .byTruncatingTail
        }

        textField.stringValue = dataItems[row]
        return textField
    }
}
#endif
