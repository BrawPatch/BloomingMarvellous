#if canImport(UIKit)
import SwiftUI
import StoreKit
import BloomingMarvellous

// MARK: - StoreSheet
//
// Phase D presentation layer for the StoreManager. Friendlier voice and
// floral chrome to match the rest of the app — every card is its own
// little planted patch, with the price shown right next to the CTA so
// nobody clicks "Subscribe" wondering what it'll cost.

public struct StoreSheet: View {

    @StateObject private var store = StoreManager.shared
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                petalBackdrop
                ScrollView {
                    VStack(spacing: 16) {
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
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .bmNavTitle("Grow your garden", icon: "🌸")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
        }
        .task { await store.loadProductsIfNeeded() }
    }

    // MARK: - Backdrop

    private var petalBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#e8f8ef"), Color(hex: "#d8f5e8")],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geo in
                FlowerView(size: 80, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-12))
                    .position(x: 32, y: 40)
                    .opacity(0.35)
                FlowerView(size: 100, petalColor: .bmLilac, centerColor: .bmPeach)
                    .rotationEffect(.degrees(20))
                    .position(x: geo.size.width - 40, y: 90)
                    .opacity(0.3)
                LeafView(size: 60, color: .bmLeafSage)
                    .rotationEffect(.degrees(40))
                    .position(x: 30, y: geo.size.height - 100)
                    .opacity(0.35)
                FlowerView(size: 70, petalColor: .bmPeach, centerColor: .bmAmber)
                    .rotationEffect(.degrees(-25))
                    .position(x: geo.size.width - 50, y: geo.size.height - 60)
                    .opacity(0.32)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("🌷")
                Text("Pick your perfect plot")
                    .font(.custom("Fredoka-SemiBold", size: 18))
                    .foregroundStyle(Color.bmText1)
                Text("🌷")
            }
            Text("More plants, smarter planning, and a little extra magic for your gardening adventure.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .stickerCard(radius: 18)
    }

    private func productCard(_ id: StoreProductID) -> some View {
        let owned = store.owns(id)
        let inFlight = store.purchaseInFlight == id
        let priceLabel = store.priceLabel(for: id)
        let isSub = id.isSubscription
        let accent = cardAccent(id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Text(id.emoji)
                        .font(.system(size: 28))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(id.displayName)
                        .font(.custom("Fredoka-SemiBold", size: 17))
                        .foregroundStyle(Color.bmText1)
                    Text(id.shortPitch)
                        .font(.custom("Nunito-Bold", size: 12))
                        .foregroundStyle(accent)
                }
                Spacer(minLength: 0)
                if !owned, priceLabel != "—" {
                    Text(priceLabel + (isSub ? " /mo" : ""))
                        .font(.custom("Fredoka-SemiBold", size: 15))
                        .foregroundStyle(Color.bmText1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.6), lineWidth: 1.4))
                }
            }

            Text(id.blurb)
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
                .lineSpacing(2)

            if owned {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                    Text(isSub ? "You're a Pro — happy planting!" : "Unlocked — enjoy 🌿")
                        .font(.custom("Fredoka-SemiBold", size: 13))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.bmGreen)
                .clipShape(Capsule())
            } else {
                Button {
                    Task { await store.purchase(id) }
                } label: {
                    HStack(spacing: 8) {
                        if inFlight { ProgressView().tint(.white) }
                        Text(ctaTitle(id, price: priceLabel))
                            .font(.custom("Fredoka-SemiBold", size: 14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [accent, accent.opacity(0.85)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Capsule())
                    .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                }
                .disabled(inFlight)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accent.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: accent.opacity(0.12), radius: 8, y: 3)
    }

    private func ctaTitle(_ id: StoreProductID, price: String) -> String {
        if id.isSubscription {
            return price == "—" ? "Become a Pro Gardener" : "Become a Pro · \(price)/mo"
        } else {
            return price == "—" ? "Add to my garden" : "Add to my garden · \(price)"
        }
    }

    private func cardAccent(_ id: StoreProductID) -> Color {
        switch id {
        case .proSubscription: return .bmLilac
        case .packExotic:      return .bmPeach
        case .packEdible:      return .bmGreen
        }
    }

    private var restoreRow: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                Text("Restore previous purchases")
                    .font(.custom("Fredoka-SemiBold", size: 12))
            }
            .foregroundStyle(Color.bmLilac)
        }
        .padding(.top, 4)
    }
}
#endif
