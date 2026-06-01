#if canImport(StoreKit)
import Foundation
import StoreKit

// MARK: - StoreManager
//
// Phase D wiring for StoreKit 2 — Pro subscription + two non-consumable
// content packs. Reads the products listed in `StoreProductID`, watches
// `Transaction.updates` for renewals / refunds / family-sharing changes,
// and exposes the result to SwiftUI via @Published properties.
//
// On a successful purchase the manager publishes the new entitlement set
// via the `entitlementsChanged` async stream; UI layers (SplashView,
// SettingsView, HomeView) subscribe and route the result back into the
// active `UserModel` so the rest of the app sees the tier flip
// immediately.
//
// The real billing happens via the App Store; this client just verifies
// the JWS Transaction returned by StoreKit and trusts it for entitlement
// state. A future server-side hook (POST /v1/users/me/entitlements with
// the JWS payload) can move the source of truth onto the backend.

@MainActor
public final class StoreManager: ObservableObject {

    public static let shared = StoreManager()

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var ownedProductIds: Set<String> = []
    @Published public private(set) var purchaseInFlight: StoreProductID?
    @Published public private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Listen for transaction updates the whole time the app is alive.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Load

    public func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        do {
            let ids = StoreProductID.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { $0.displayName < $1.displayName }
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Purchase

    public func purchase(_ id: StoreProductID) async {
        guard let product = products.first(where: { $0.id == id.rawValue }) else {
            lastError = "Product not loaded yet — try again in a moment."
            return
        }
        purchaseInFlight = id
        defer { purchaseInFlight = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    ownedProductIds.insert(transaction.productID)
                    await transaction.finish()
                } else {
                    lastError = "App Store returned an unverified receipt."
                }
            case .userCancelled:
                break
            case .pending:
                // Ask-to-buy / SCA — handled when Transaction.updates fires.
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    public func owns(_ id: StoreProductID) -> Bool {
        ownedProductIds.contains(id.rawValue)
    }

    private func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIds = owned
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = transactionResult {
            if transaction.revocationDate == nil {
                ownedProductIds.insert(transaction.productID)
            } else {
                ownedProductIds.remove(transaction.productID)
            }
            await transaction.finish()
        }
    }

    // MARK: - Helpers

    public func product(for id: StoreProductID) -> Product? {
        products.first(where: { $0.id == id.rawValue })
    }

    public func priceLabel(for id: StoreProductID) -> String {
        product(for: id)?.displayPrice ?? "—"
    }
}
#endif
