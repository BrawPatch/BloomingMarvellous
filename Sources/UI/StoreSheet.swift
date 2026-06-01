#if canImport(UIKit)
import SwiftUI
import StoreKit
import BloomingMarvellous

// MARK: - StoreSheet
//
// Phase D presentation layer for the StoreManager. Shown from Settings
// → Account → "Upgrade to Pro" / "Buy <pack>", the Home top-bar "Go Pro"
// pill, and the Splash CTAs. The sheet always loads every product so a
// Pro user can also pick up content packs in the same flow.
//
// Real billing requires the product IDs in `StoreProductID` to exist in
// App Store Connect; a local `BloomingMarvellous.storekit` configuration
// is sufficient for simulator testing.

public struct StoreSheet: View {

    @StateObject private var store = StoreManager.shared
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    ForEach(StoreProductID.allCases, id: \.rawValue) { id in
                        productCard(id)
                    }
                    restoreRow
                    if let err = store.lastError {
                        Text(err)
                            .font(.custom("Nunito-SemiBold", size: 11))
                            .foregroundStyle(Color.bmRed)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .bmSheetBackdrop()
            .bmNavTitle("Pro & content packs", icon: "✨")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
        }
        .task { await store.loadProductsIfNeeded() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Unlock more of your garden")
                .font(.custom("Fredoka-SemiBold", size: 17))
                .foregroundStyle(Color.bmText1)
            Text("Pro adds multi-garden planning, the bed planting map, A4 PDF printing, push reminders, and Plant Management. Content packs add curated plant collections to the Picker.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func productCard(_ id: StoreProductID) -> some View {
        let owned = store.owns(id)
        let inFlight = store.purchaseInFlight == id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(id.displayName)
                    .font(.custom("Fredoka-SemiBold", size: 15))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text(store.priceLabel(for: id))
                    .font(.custom("Fredoka-SemiBold", size: 13))
                    .foregroundStyle(Color.bmGreen)
            }
            Text(id.blurb)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)

            if owned {
                Text(id.isSubscription ? "Active" : "Purchased")
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
            } else {
                Button {
                    Task { await store.purchase(id) }
                } label: {
                    HStack(spacing: 6) {
                        if inFlight { ProgressView().tint(.white) }
                        Text(id.isSubscription ? "Subscribe" : "Buy")
                            .font(.custom("Fredoka-SemiBold", size: 13))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.bmGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(inFlight)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var restoreRow: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore purchases")
                .font(.custom("Fredoka-SemiBold", size: 12))
                .foregroundStyle(Color.bmLilac)
        }
        .padding(.top, 6)
    }
}
#endif
