#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - HomeView
//
// SwiftUI home screen that replaces the legacy UIKit HomeViewController.
// Visual language is ported from the BMFinal design (mint background,
// Fredoka title, Nunito body, sticker-card header, BMCard rows).

public struct HomeView: View {

    private let user: UserModel
    private let onLogout: () -> Void

    @StateObject private var viewModel: HomeViewModel
    @State private var selectedFilter: ContentFilter = .all

    @MainActor
    public init(user: UserModel, onLogout: @escaping () -> Void) {
        self.user = user
        self._viewModel = StateObject(wrappedValue: HomeViewModel())
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.bmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    BMAppHeader(user: user, onLogout: onLogout)

                    filterRow

                    welcomeSection

                    librarySection
                }
                .padding(.bottom, 32)
            }
        }
        .task { await viewModel.loadAll() }
    }

    // MARK: - Filter pills

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ContentFilter.allCases) { f in
                    PillButton(f.label,
                               isActive: selectedFilter == f,
                               color: f.tint) {
                        selectedFilter = f
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - "Welcome" section (server /home items)

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Welcome back, \(user.firstName)", icon: "🌿")
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading && viewModel.welcomeItems.isEmpty {
                    placeholder
                } else if viewModel.welcomeItems.isEmpty {
                    Text("No welcome content yet.")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(Color.bmText2)
                } else {
                    ForEach(viewModel.welcomeItems, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 10) {
                            FlowerView(size: 18,
                                       petalColor: .bmFlowerPink,
                                       centerColor: .bmLilac)
                            Text(msg)
                                .font(.custom("Nunito-SemiBold", size: 14))
                                .foregroundStyle(Color.bmText1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - "Plant library" section (server /data items)

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Plant library", icon: "🌸")
                Spacer()
                Text("\(filteredItems.count) items")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if viewModel.isLoading && viewModel.libraryItems.isEmpty {
                    placeholder
                } else if filteredItems.isEmpty {
                    Text("No plants in this filter.")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(Color.bmText2)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .bmCard()
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.offset) { idx, item in
                        plantRow(item, tint: tintFor(index: idx))
                    }
                }
            }
            .padding(.horizontal, 20)

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmRed)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func plantRow(_ item: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            // Coloured circular badge with a leaf
            ZStack {
                Circle().fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                LeafView(size: 18, color: tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(14)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.bmBorder, lineWidth: 1.5))
        .shadow(color: Color.bmGreen.opacity(0.06), radius: 4, y: 1)
    }

    private var placeholder: some View {
        HStack {
            ProgressView().tint(.bmGreen)
            Text("Loading…")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
        }
    }

    // MARK: - Helpers

    private var filteredItems: [String] {
        let items = viewModel.libraryItems
        // Server already filtered by tier/packs; the pills here are a
        // simple visual cue — we just shorten the list to give a sense of
        // categorisation. A real implementation would tag items server-side.
        switch selectedFilter {
        case .all:   return items
        case .pro:   return user.tier == .pro ? items : []
        case .packs: return user.purchasedPacks.isEmpty ? [] : items
        }
    }

    private func tintFor(index: Int) -> Color {
        let palette: [Color] = [.bmGreen, .bmLilac, .bmPeach, .bmAmber, .bmSky, .bmLeafSage]
        return palette[index % palette.count]
    }
}

// MARK: - ContentFilter

private enum ContentFilter: String, CaseIterable, Identifiable {
    case all, pro, packs
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:   return "All"
        case .pro:   return "Pro"
        case .packs: return "Packs"
        }
    }
    var tint: Color {
        switch self {
        case .all:   return .bmGreen
        case .pro:   return .bmAmber
        case .packs: return .bmLilac
        }
    }
}

// MARK: - BMAppHeader
//
// Trimmed port of BMFinal's AppHeader — the multi-coloured "Blooming
// Marvellous" sticker card on a mint gradient with a tier badge and a
// logout button.

private struct BMAppHeader: View {
    let user: UserModel
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#c4eeda"), Color(hex: "#caf0e2"), Color(hex: "#b8e8d4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            decorations

            VStack(spacing: 8) {
                VStack(spacing: 1) {
                    HStack(spacing: 0) {
                        Text("Blooming ")
                            .font(.custom("Fredoka-Bold", size: 24))
                            .foregroundStyle(Color.bmLilac)
                        Text("Marvellous")
                            .font(.custom("Fredoka-Bold", size: 24))
                            .foregroundStyle(Color.bmPeach)
                    }
                    Text("Bloom-based Garden Planner")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText2)
                        .kerning(0.3)
                }
                .stickerCard(radius: 16)

                tierBadge
            }
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onLogout) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.bmLilac)
                }
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            }
            .padding(.trailing, 12)
            .padding(.top, 8)
            .accessibilityLabel("Sign out")
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bmBorder).frame(height: 2)
        }
    }

    @ViewBuilder
    private var tierBadge: some View {
        HStack(spacing: 6) {
            Text("🌱")
            Text("\(user.firstName) · \(user.tier == .pro ? "PRO" : "FREE")")
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText1)
            if user.tier == .pro {
                Text("PRO")
                    .font(.custom("Fredoka-SemiBold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.bmAmber)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(Color.white.opacity(0.7))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }

    private var decorations: some View {
        GeometryReader { geo in
            Group {
                FlowerView(size: 32, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-20))
                    .position(x: 20, y: 14)
                    .opacity(0.55)
                FlowerView(size: 24, petalColor: .bmLilac, centerColor: .bmPeach)
                    .rotationEffect(.degrees(15))
                    .position(x: geo.size.width - 18, y: 12)
                    .opacity(0.55)
                LeafView(size: 22, color: .bmLeafSage)
                    .rotationEffect(.degrees(10))
                    .position(x: 32, y: geo.size.height - 8)
                    .opacity(0.4)
                LeafView(size: 18, color: .bmLeafSage)
                    .rotationEffect(.degrees(-25))
                    .position(x: geo.size.width - 30, y: geo.size.height - 10)
                    .opacity(0.4)
            }
        }
    }
}

#Preview {
    HomeView(user: UserModel(userId: 1,
                             firstName: "Chance",
                             apiToken: "preview",
                             tier: .pro,
                             purchasedPacks: [.exotic, .edible])) { }
}
#endif
