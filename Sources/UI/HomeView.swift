#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - HomeView (dashboard)

public struct HomeView: View {

    private let user: UserModel
    private let onLogout: () -> Void

    @EnvironmentObject private var store: GardenStore
    @State private var showingGardenPicker = false
    @State private var showingCreateGarden = false
    @State private var showingManageGardens = false
    @State private var showingSettings = false
    @State private var showingTasks = false
    @State private var showingBeds = false
    @State private var toast: ToastBanner.Message?

    public init(user: UserModel, onLogout: @escaping () -> Void) {
        self.user = user
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.bmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    GardenTopBar(
                        user: user,
                        store: store,
                        onSwitchGarden: { showingGardenPicker = true },
                        onAddGarden:    { showingCreateGarden = true },
                        onLogout: onLogout
                    )

                    if let garden = store.selectedGarden {
                        gardenSummary(garden)
                        shortcutCards(garden)
                    }

                    Spacer(minLength: 12)
                }
                .padding(.bottom, 32)
            }

            ToastBanner(message: $toast)
        }
        .navigationBarHidden(true)
        .confirmationDialog("Select garden",
                            isPresented: $showingGardenPicker,
                            titleVisibility: .visible) {
            ForEach(store.gardens) { g in
                Button(g.name) { store.selectedGardenId = g.id }
            }
            if store.canManageGardens {
                Button("Manage gardens…") { showingManageGardens = true }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCreateGarden) {
            CreateGardenView { newGarden in
                store.addGarden(newGarden)
                toast = .init(text: "Garden created", icon: "🌱")
            }
        }
        .sheet(isPresented: $showingManageGardens) {
            ManageGardensView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: user)
        }
        .sheet(isPresented: $showingTasks) {
            TaskListView()
        }
        .navigationDestination(isPresented: $showingBeds) {
            GardenBedsView()
                .environmentObject(store)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.bmText2)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.75)))
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
                .padding(.trailing, 14)
            }
            .padding(.top, 6)
            .background(Color.clear)
        }
    }

    // MARK: - Garden summary card

    @ViewBuilder
    private func gardenSummary(_ garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Garden defaults", icon: "🌿")
            HStack(spacing: 10) {
                badge("Soil", garden.soilType.label, .bmGreen)
                badge("Wet",  garden.wetness.shortLabel, .bmSky)
                badge("Sun",  garden.sunlight.shortLabel, .bmAmber)
            }
            HStack(spacing: 10) {
                badge("Exposure", garden.exposure.label, .bmLeafSage)
                Spacer(minLength: 0)
                Text("\(store.beds(in: garden.id).count) beds")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
        .padding(.horizontal, 20)
    }

    private func badge(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.custom("Fredoka-SemiBold", size: 9))
                .foregroundStyle(Color.bmText3)
                .kerning(0.5)
            Text(value)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Shortcut cards

    @ViewBuilder
    private func shortcutCards(_ garden: Garden) -> some View {
        VStack(spacing: 12) {
            shortcut(title: "Garden beds",
                     subtitle: "\(store.beds(in: garden.id).count) bed\(store.beds(in: garden.id).count == 1 ? "" : "s")",
                     icon: "🪴",
                     tint: .bmGreen) { showingBeds = true }
            shortcut(title: "This week's tasks",
                     subtitle: "Sow · Transplant · Harvest",
                     icon: "✅",
                     tint: .bmSky) { showingTasks = true }
            shortcut(title: "Add to schedule",
                     subtitle: "Plan plant + event",
                     icon: "🌸",
                     tint: .bmPeach) { /* will link into Picker in a future turn */ }
        }
        .padding(.horizontal, 20)
    }

    private func shortcut(title: String,
                          subtitle: String,
                          icon: String,
                          tint: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Text(icon).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Nunito-Bold", size: 15))
                        .foregroundStyle(Color.bmText1)
                    Text(subtitle)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText2)
                }
                Spacer()
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
        .buttonStyle(.plain)
    }
}

// MARK: - GardenTopBar
//
// The mint-gradient sticker header from BMFinal, with a Free or Pro
// garden picker integrated. Free → static label. Pro → tappable dropdown
// with + Add garden affordance.

private struct GardenTopBar: View {
    let user: UserModel
    let store: GardenStore
    let onSwitchGarden: () -> Void
    let onAddGarden: () -> Void
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
                HStack(spacing: 0) {
                    Text("Blooming ")
                        .font(.custom("Fredoka-Bold", size: 22))
                        .foregroundStyle(Color.bmLilac)
                    Text("Marvellous")
                        .font(.custom("Fredoka-Bold", size: 22))
                        .foregroundStyle(Color.bmPeach)
                }
                .stickerCard(radius: 14)

                if user.tier == .pro {
                    HStack(spacing: 8) {
                        Button(action: onSwitchGarden) {
                            HStack(spacing: 4) {
                                Text(store.selectedGarden?.name ?? "Select garden")
                                    .font(.custom("Nunito-Bold", size: 12))
                                    .foregroundStyle(Color.bmText1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.bmText2)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.white.opacity(0.75))
                            .clipShape(Capsule())
                        }
                        Button(action: onAddGarden) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(Circle().fill(Color.bmGreen))
                        }
                        .disabled(!store.canAddGarden)
                        .opacity(store.canAddGarden ? 1 : 0.35)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("🌱")
                        Text(store.selectedGarden?.name ?? "My Garden")
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundStyle(Color.bmText1)
                        Text("FREE")
                            .font(.custom("Fredoka-SemiBold", size: 9))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.bmLeafSage)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.bmLilac)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.75)))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            }
            .padding(.trailing, 50)
            .padding(.top, 8)
            .accessibilityLabel("Sign out")
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bmBorder).frame(height: 2)
        }
    }

    private var decorations: some View {
        GeometryReader { geo in
            Group {
                FlowerView(size: 28, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-20))
                    .position(x: 22, y: 16)
                    .opacity(0.5)
                FlowerView(size: 22, petalColor: .bmLilac, centerColor: .bmPeach)
                    .rotationEffect(.degrees(15))
                    .position(x: geo.size.width - 22, y: 18)
                    .opacity(0.5)
                LeafView(size: 20, color: .bmLeafSage)
                    .rotationEffect(.degrees(10))
                    .position(x: 32, y: geo.size.height - 10)
                    .opacity(0.4)
            }
        }
    }
}

// MARK: - Toast banner

public struct ToastBanner: View {

    public struct Message: Equatable {
        public let text: String
        public let icon: String
        public init(text: String, icon: String = "✓") {
            self.text = text; self.icon = icon
        }
    }

    @Binding public var message: Message?

    public init(message: Binding<Message?>) { self._message = message }

    public var body: some View {
        if let m = message {
            HStack(spacing: 8) {
                Text(m.icon)
                Text(m.text)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.bmBorder, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: m) {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation { message = nil }
            }
        }
    }
}
#endif
