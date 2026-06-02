#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SplashView
//
// First impression after sign-in: branded loading screen with a
// progress shimmer until the LibraryStore has fetched /v1/library,
// then a tier-aware call-to-action.
//
//   • Free users  → "Upgrade to Pro" (routes through StoreKit once
//                   Phase D is wired up).
//   • Pro users without all content packs → "Add the Exotic / Edible
//                   pack" buttons surfaced inline.
//   • Pro users with every pack → no CTA; the splash dismisses
//                   automatically as soon as the library finishes
//                   loading.

public struct SplashView: View {

    private let user: UserModel
    private let onContinue: () -> Void
    private let onUpgrade: () -> Void
    private let onBuyPack: (ContentPack) -> Void

    @EnvironmentObject private var library: LibraryStore

    public init(user: UserModel,
                onContinue: @escaping () -> Void,
                onUpgrade: @escaping () -> Void = {},
                onBuyPack: @escaping (ContentPack) -> Void = { _ in }) {
        self.user = user
        self.onContinue = onContinue
        self.onUpgrade = onUpgrade
        self.onBuyPack = onBuyPack
    }

    public var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 22) {
                Spacer()
                brandCard
                loadingPill
                if showCTAs {
                    ctaStack
                }
                Spacer()
                continueButton
                    .opacity(canContinue ? 1 : 0.45)
                    .disabled(!canContinue)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Sections

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#d8f5e8"), Color(hex: "#caf0e2"), Color(hex: "#b8e8d4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                Group {
                    FlowerView(size: 70, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                        .rotationEffect(.degrees(-18))
                        .position(x: 50, y: 90)
                        .opacity(0.55)
                    FlowerView(size: 90, petalColor: .bmLilac, centerColor: .bmPeach)
                        .rotationEffect(.degrees(22))
                        .position(x: geo.size.width - 60, y: 140)
                        .opacity(0.45)
                    LeafView(size: 60, color: .bmLeafSage)
                        .rotationEffect(.degrees(35))
                        .position(x: 40, y: geo.size.height - 80)
                        .opacity(0.5)
                    FlowerView(size: 60, petalColor: .bmPeach, centerColor: .bmLilac)
                        .rotationEffect(.degrees(-30))
                        .position(x: geo.size.width - 80, y: geo.size.height - 100)
                        .opacity(0.45)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var brandCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("Blooming ")
                    .font(.custom("Fredoka-Bold", size: 30))
                    .foregroundStyle(Color.bmLilac)
                Text("Marvellous")
                    .font(.custom("Fredoka-Bold", size: 30))
                    .foregroundStyle(Color.bmPeach)
            }
            Text("Plant something marvellous, \(user.firstName.isEmpty ? "gardener" : user.firstName).")
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
        }
        .stickerCard(radius: 18)
    }

    @ViewBuilder
    private var loadingPill: some View {
        switch library.status {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Color.bmGreen)
                Text("Loading your plant library…")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText2)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
        case .loaded:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.bmGreen)
                Text("Ready — \(library.plants.count) plants available")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(0.85))
            .clipShape(Capsule())
        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.bmAmber)
                Text("Offline — using bundled plants. (\(message))")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var ctaStack: some View {
        VStack(spacing: 12) {
            if user.tier == .free {
                proUpgradeCard
            } else {
                ForEach(missingPacks, id: \.self) { pack in
                    packCard(pack)
                }
            }
        }
    }

    private var proUpgradeCard: some View {
        Button(action: onUpgrade) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.bmLilac.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Text("✨")
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Try Pro & let your garden run wild")
                            .font(.custom("Fredoka-SemiBold", size: 15))
                            .foregroundStyle(Color.bmText1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.bmText2)
                    }
                    Text("1,000+ more plants to fall in love with, plus the bed planting map, daily reminders, and the all-plants summary.")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.white, Color.bmLilac.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.bmLilac, lineWidth: 1.5))
            .shadow(color: Color.bmLilac.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func packCard(_ pack: ContentPack) -> some View {
        let info = packCopy(pack)
        return Button {
            onBuyPack(pack)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(info.accent.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Text(info.emoji)
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.custom("Fredoka-SemiBold", size: 14))
                        .foregroundStyle(Color.bmText1)
                    Text(info.subtitle)
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(info.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.white, info.accent.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(info.accent.opacity(0.55), lineWidth: 1.5))
            .shadow(color: info.accent.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(canContinue ? "Enter the garden" : "Just a moment…")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bmGreen)
                .clipShape(Capsule())
        }
    }

    // MARK: - Logic

    private var canContinue: Bool {
        switch library.status {
        case .loaded, .failed: return true
        case .idle, .loading:  return false
        }
    }

    private var showCTAs: Bool {
        if user.tier == .free { return true }
        return !missingPacks.isEmpty
    }

    private var missingPacks: [ContentPack] {
        ContentPack.allCases.filter { !user.purchasedPacks.contains($0) }
    }

    private func packCopy(_ pack: ContentPack) -> (emoji: String, title: String, subtitle: String, accent: Color) {
        switch pack {
        case .exotic:
            return ("🌺", "Exotic Pack",
                    "1,000+ tropical & conservatory beauties for indoor and sheltered planting.",
                    Color.bmPeach)
        case .edible:
            return ("🥕", "Edible Pack",
                    "750+ veg, herbs & kitchen-garden favourites with sow & harvest dates for your area.",
                    Color.bmGreen)
        }
    }
}
#endif
