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
        // Kick off the initial fetch immediately so it doesn't depend on
        // any single view's lifetime. SwiftUI's `.task` modifier cancels
        // its child task when the host view dismisses, which previously
        // killed the URLSessionTask mid-flight and stuck us on the
        // bundled fallback. This Task lives at the store's lifetime.
        Task { await self.loadIfNeeded() }
    }

    /// Loads the server library. Safe to call repeatedly — only one fetch
    /// runs at a time. On failure, `plants` is left pointing at the
    /// bundled fallback so the UI keeps working. The actual network call
    /// runs in a detached task so SwiftUI `.task` cancellation cannot
    /// abort it (the caller's structured concurrency scope ends when the
    /// view disappears, but the fetch keeps going).
    public func loadIfNeeded() async {
        if status == .loading || status == .loaded { return }
        status = .loading
        do {
            let server = try await Task.detached(priority: .userInitiated) { [service] in
                try await service.fetchLibrary()
            }.value
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
