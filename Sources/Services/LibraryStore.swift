import Foundation

// MARK: - LibraryStore
//
// Observable wrapper around LibraryService. Loads /v1/library once per
// session and exposes the result to the UI. Falls back to the bundled
// PlantLibrary when offline or before the first successful fetch.

@MainActor
public final class LibraryStore: ObservableObject {

    public enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published public private(set) var plants: [Plant] = PlantLibrary.all
    @Published public private(set) var status: Status = .idle

    private let service: LibraryServiceProtocol

    public init(service: LibraryServiceProtocol = LibraryService()) {
        self.service = service
    }

    /// Loads the server library. Safe to call repeatedly — only one fetch
    /// runs at a time. On failure, `plants` is left pointing at the
    /// bundled fallback so the UI keeps working.
    public func loadIfNeeded() async {
        if status == .loading || status == .loaded { return }
        status = .loading
        do {
            let server = try await service.fetchLibrary()
            plants = server.isEmpty ? PlantLibrary.all : server
            status = .loaded
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    public func plant(id: String) -> Plant? {
        plants.first(where: { $0.id == id }) ?? PlantLibrary.plant(id: id)
    }
}
