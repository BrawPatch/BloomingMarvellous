#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - HomeView (dashboard)

public struct HomeView: View {

    private let user: UserModel
    private let onLogout: () -> Void
    private let onSelectTab: (AppTab) -> Void
    /// Bumped by MainTabView when the Home tab is tapped (including
    /// re-taps). HomeView watches this and dismisses every open
    /// sheet/popover and pops every pushed destination so the gardener
    /// always lands on a clean dashboard.
    private let resetToken: Int

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @State private var showingGardenPicker = false
    @State private var showingCreateGarden = false
    @State private var showingManageGardens = false
    @State private var showingSettings = false
    @State private var showingTasks = false
    @State private var showingBeds = false
    @State private var showingMyBeds = false
    @State private var showingPlantingMap = false
    @State private var showingBloomSchedule = false
    @State private var showingPlantPicker = false
    @State private var showingPlantingSchedule = false
    @State private var showingStore = false
    @State private var toast: ToastBanner.Message?

    public init(user: UserModel,
                onLogout: @escaping () -> Void,
                onSelectTab: @escaping (AppTab) -> Void = { _ in },
                resetToken: Int = 0) {
        self.user = user
        self.onLogout = onLogout
        self.onSelectTab = onSelectTab
        self.resetToken = resetToken
    }

    /// Close every sheet + pop every pushed destination. Called whenever
    /// the gardener taps the Home tab.
    private func resetAllPresentations() {
        showingGardenPicker     = false
        showingCreateGarden     = false
        showingManageGardens    = false
        showingSettings         = false
        showingTasks            = false
        showingBeds             = false
        showingMyBeds           = false
        showingPlantingMap      = false
        showingBloomSchedule    = false
        showingPlantPicker      = false
        showingPlantingSchedule = false
        showingStore            = false
    }

    public var body: some View {
        ZStack(alignment: .top) {
            floralWallpaper

            ScrollView {
                VStack(spacing: 18) {
                    GardenTopBar(
                        user: user,
                        store: store,
                        storeManager: StoreManager.shared,
                        onSwitchGarden: { showingGardenPicker = true },
                        onAddGarden:    { showingCreateGarden = true },
                        onUpgrade:      { showingStore = true },
                        onLogout: onLogout
                    )

                    tileGrid

                    todaysTasksCard
                        .padding(.horizontal, 20)

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
            SettingsView(user: user, onLogout: onLogout)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingStore) {
            StoreSheet()
        }
        .sheet(isPresented: $showingTasks) {
            TaskListView()
        }
        .navigationDestination(isPresented: $showingBeds) {
            GardenBedsView()
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $showingPlantingMap) {
            PlantingMapView()
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $showingMyBeds) {
            MyBedsView()
                .environmentObject(store)
                .environmentObject(library)
        }
        .navigationDestination(isPresented: $showingBloomSchedule) {
            BloomScheduleView()
                .environmentObject(store)
                .environmentObject(library)
        }
        .navigationDestination(isPresented: $showingPlantPicker) {
            PlantPickerMonthView()
                .environmentObject(store)
                .environmentObject(library)
        }
        .navigationDestination(isPresented: $showingPlantingSchedule) {
            PlantingScheduleView()
                .environmentObject(store)
                .environmentObject(library)
        }
        .onChange(of: resetToken) { _ in
            // Home tab was tapped — close anything the gardener had open.
            resetAllPresentations()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                ContextualHelpButton(topic: .home)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.75)))
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
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

    // MARK: - Floral wallpaper backdrop
    //
    // Replaces the flat mint behind the tile grid with a softly-tiled
    // floral pattern so the home dashboard feels more like a garden and
    // less like a UIKit list view. Decorations sit at low alpha so the
    // white tile cards still pop.

    private var floralWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#e8f8ef"), Color(hex: "#d8f5e8"), Color(hex: "#caf0e2")],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Group {
                    FlowerView(size: 70, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                        .rotationEffect(.degrees(-18))
                        .position(x: 30, y: h * 0.18)
                        .opacity(0.32)
                    FlowerView(size: 90, petalColor: .bmLilac, centerColor: .bmPeach)
                        .rotationEffect(.degrees(22))
                        .position(x: w - 40, y: h * 0.28)
                        .opacity(0.28)
                    LeafView(size: 60, color: .bmLeafSage)
                        .rotationEffect(.degrees(40))
                        .position(x: w * 0.12, y: h * 0.46)
                        .opacity(0.32)
                    FlowerView(size: 55, petalColor: .bmPeach, centerColor: .bmAmber)
                        .rotationEffect(.degrees(-25))
                        .position(x: w * 0.85, y: h * 0.5)
                        .opacity(0.3)
                    LeafView(size: 50, color: .bmGreen)
                        .rotationEffect(.degrees(-30))
                        .position(x: w - 36, y: h * 0.68)
                        .opacity(0.3)
                    FlowerView(size: 80, petalColor: .bmFlowerLilac, centerColor: .bmFlowerPink)
                        .rotationEffect(.degrees(12))
                        .position(x: 38, y: h * 0.78)
                        .opacity(0.32)
                    FlowerView(size: 60, petalColor: .bmLilac, centerColor: .bmAmber)
                        .rotationEffect(.degrees(-8))
                        .position(x: w * 0.78, y: h * 0.92)
                        .opacity(0.28)
                    LeafView(size: 55, color: .bmLeafSage)
                        .rotationEffect(.degrees(60))
                        .position(x: w * 0.5, y: h - 30)
                        .opacity(0.28)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Tile grid
    //
    // Four primary entry points: Pick your plants → catalogue + picker;
    // Bloom Schedule → seasonal planner; Planting Schedule → sow /
    // transplant / harvest calendar; Bedding Map Tool → bed layouts and
    // drag-to-arrange editor. Pick + Planting still swap to their bottom
    // tabs; Bloom + Bedding Map push (their tabs no longer exist).

    private var tileGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            tile(title: "Pick your plants",
                 subtitle: "Browse + match to your beds",
                 icon: "🌷",
                 tint: .bmPeach) { showingPlantPicker = true }

            tile(title: "Bloom Schedule",
                 subtitle: "Plan your seasonal colour",
                 icon: "🌸",
                 tint: .bmLilac) { showingBloomSchedule = true }

            tile(title: "Planting Schedule",
                 subtitle: "Sow · Transplant · Harvest",
                 icon: "📅",
                 tint: .bmSky) { showingPlantingSchedule = true }

            tile(title: "My Beds",
                 subtitle: "Edit a bed or open its map",
                 icon: "🪴",
                 tint: .bmLeafSage) { showingMyBeds = true }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Today's Tasks card
    //
    // Surfaces outstanding planting tasks scheduled for the current
    // calendar month — sow / transplant / harvest jobs derived from the
    // gardener's bloom picks. Tapping the checkbox toggles task
    // completion via `GardenStore.markTaskDone`, which the Planting
    // Schedule tab also reads, so the two stay in lockstep.

    @ViewBuilder
    private var todaysTasksCard: some View {
        let month = Calendar.current.component(.month, from: Date())
        let outstanding = TaskScheduler.outstandingEvents(
            forMonth: month,
            store: store,
            plantLookup: { library.plant(id: $0) }
        )
        let shown = Array(outstanding.prefix(6))
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel("Today's tasks", icon: "✅")
                Tooltip("Outstanding sow, transplant and harvest jobs for the current month. Ticking one here also ticks it off in the Planting Schedule.")
                Spacer()
                if outstanding.count > shown.count {
                    Text("\(outstanding.count) outstanding")
                        .font(.custom("Nunito-Bold", size: 10))
                        .foregroundStyle(Color.bmText3)
                }
            }
            if outstanding.isEmpty {
                Text("Nothing scheduled for this month. Pop some bloom picks into the Plant Picker and they'll appear here.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
            } else {
                ForEach(shown) { event in
                    todaysTaskRow(event: event)
                }
                if outstanding.count > shown.count {
                    Button {
                        onSelectTab(.planting)
                    } label: {
                        HStack(spacing: 4) {
                            Text("View all in Planting Schedule")
                                .font(.custom("Fredoka-SemiBold", size: 12))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.bmGreen)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func todaysTaskRow(event: TaskScheduler.Event) -> some View {
        let done = store.isTaskDone(id: event.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if done { store.markTaskNotDone(id: event.id) }
                else    { store.markTaskDone(id: event.id) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(done ? Color.bmGreen : Color.bmText3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(event.kind.emoji)
                            .font(.system(size: 13))
                        Text(event.kind.label)
                            .font(.custom("Fredoka-SemiBold", size: 11))
                            .foregroundStyle(Color.bmText2)
                            .kerning(0.4)
                        Spacer()
                    }
                    Text(event.plantName)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(done ? Color.bmText3 : Color.bmText1)
                        .strikethrough(done, color: Color.bmText3)
                    Text(event.bedName.map { "\(event.gardenName) · \($0)" } ?? event.gardenName)
                        .font(.custom("Nunito-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func tile(title: String,
                      subtitle: String,
                      icon: String,
                      tint: Color,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
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
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
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
    @ObservedObject var storeManager: StoreManager
    let onSwitchGarden: () -> Void
    let onAddGarden: () -> Void
    let onUpgrade: () -> Void
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
                    HStack(spacing: 8) {
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

                        // Subtle Pro upsell pill — opens the StoreSheet
                        // so Free users can subscribe without digging
                        // through Settings → Account.
                        Button(action: onUpgrade) {
                            HStack(spacing: 4) {
                                Text("✨")
                                    .font(.system(size: 11))
                                Text(proPillTitle)
                                    .font(.custom("Fredoka-SemiBold", size: 11))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                LinearGradient(colors: [Color.bmLilac, Color.bmFlowerPink],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.bmLilac.opacity(0.35), radius: 3, y: 1)
                        }
                        .buttonStyle(.plain)
                        .task { await storeManager.loadProductsIfNeeded() }
                    }
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

    private var proPillTitle: String {
        let price = storeManager.priceLabel(for: .proSubscription)
        if price == "—" { return "Try Pro" }
        return "Try Pro · \(price)/mo"
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
