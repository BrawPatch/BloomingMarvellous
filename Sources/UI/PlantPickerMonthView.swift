#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PickerMode
//
// Drives the default vs. unfiltered behaviour described in the latest
// product brief:
//   • .matched   — filter by the selected garden's defaults (soil, wetness,
//                   exposure, sunlight) AND the regional growing season
//                   derived from the postcode.
//   • .all       — show every plant the user is entitled to. Manual
//                   Sun/Soil/Height refinements are available in this mode.

public enum PickerMode: String, CaseIterable, Identifiable {
    case matched, all
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .matched: return "Matched to garden"
        case .all:     return "All plants"
        }
    }
}

// MARK: - PlantPickerMonthView
//
// User picks one or more target bloom months and a filter mode, then drills
// into a per-month gallery.

public struct PlantPickerMonthView: View {

    @EnvironmentObject private var store: GardenStore

    @State private var months: Set<Int> = [Calendar.current.component(.month, from: Date())]
    @State private var mode: PickerMode = .matched

    // Manual refinements — only relevant when `mode == .all`.
    @State private var sunFilter: Sunlight?
    @State private var soilFilter: SoilType?
    @State private var minHeightCm: Int = 0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modeToggle
                if mode == .matched { matchedContextCard }
                targetMonthsSection
                if mode == .all { manualFiltersSection }
                viewPlantsButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Plant picker", icon: "🌷")
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(PickerMode.allCases) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                } label: {
                    Text(m.label)
                        .font(.custom("Fredoka-SemiBold", size: 13))
                        .foregroundStyle(mode == m ? .white : Color.bmText2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode == m ? Color.bmGreen : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    // MARK: - Matched context

    private var matchedContextCard: some View {
        let climate = store.climate
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Filtering for", icon: "🎯")

            if let g = store.selectedGarden {
                HStack(spacing: 6) {
                    miniChip(g.name, color: .bmText2)
                    miniChip(g.soilType.label, color: .bmGreen)
                    miniChip(g.sunlight.shortLabel, color: .bmAmber)
                    miniChip(g.wetness.shortLabel, color: .bmSky)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "location.fill").font(.system(size: 11)).foregroundStyle(Color.bmLilac)
                Text(climate.regionLabel)
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText1)
                Text("·").foregroundStyle(Color.bmText3)
                Text(climate.hardinessLabel)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func miniChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Nunito-Bold", size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Target months (multi-select)

    private var targetMonthsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Target bloom months", icon: "🌸")
                Spacer()
                if months.count > 1 {
                    Text("\(months.count) selected")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    monthChip(m)
                }
            }
            HStack(spacing: 12) {
                Button("Clear")    { months = [] }
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Button("All year")  { months = Set(1...12) }
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmGreen)
                if mode == .matched {
                    Button("Growing season only") {
                        months = store.climate.growingSeason
                    }
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmLilac)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private func monthChip(_ m: Int) -> some View {
        let selected = months.contains(m)
        let inSeason = mode == .matched && store.climate.growingSeason.contains(m)
        Button {
            if selected { months.remove(m) } else { months.insert(m) }
        } label: {
            VStack(spacing: 2) {
                Text(Self.monthName(m))
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(selected ? .white : Color.bmText2)
                if mode == .matched && !inSeason {
                    Text("off-season")
                        .font(.custom("Nunito-Bold", size: 8))
                        .foregroundStyle(Color.bmText3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.bmGreen : Color.bmBgCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Color.bmGreen : Color.bmBorder, lineWidth: 1.5))
            .opacity(mode == .matched && !inSeason ? 0.55 : 1)
        }
    }

    // MARK: - Manual filters (only in .all mode)

    private var manualFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Refine", icon: "🔎")

            VStack(alignment: .leading, spacing: 6) {
                Text("Sun")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PillButton("Any", isActive: sunFilter == nil, color: .bmAmber) { sunFilter = nil }
                        ForEach(Sunlight.allCases) { s in
                            PillButton(s.shortLabel, isActive: sunFilter == s, color: .bmAmber) {
                                sunFilter = (sunFilter == s) ? nil : s
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Soil")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PillButton("Any", isActive: soilFilter == nil, color: .bmGreen) { soilFilter = nil }
                        ForEach(SoilType.allCases) { s in
                            PillButton(s.label, isActive: soilFilter == s, color: .bmGreen) {
                                soilFilter = (soilFilter == s) ? nil : s
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Minimum height: \(minHeightCm) cm")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Slider(value: Binding(get: { Double(minHeightCm) },
                                      set: { minHeightCm = Int($0) }),
                       in: 0...200, step: 10)
                    .tint(Color.bmGreen)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    // MARK: - View plants

    private var viewPlantsButton: some View {
        NavigationLink {
            PlantPickerGalleryView(months: Array(months).sorted(),
                                   mode: mode,
                                   manualSun: sunFilter,
                                   manualSoil: soilFilter,
                                   minHeightCm: minHeightCm)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .bold))
                Text("View plants")
                    .font(.custom("Fredoka-SemiBold", size: 16))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.bmGreen : Color.bmGreenMid)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.bmGreen.opacity(0.25), radius: 6, y: 2)
        }
        .disabled(!canSubmit)
        .padding(.top, 4)
    }

    private var canSubmit: Bool { !months.isEmpty }

    static func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.shortMonthSymbols[m - 1]
    }
}

// MARK: - PlantPickerGalleryView
//
// Grouped results: one section per selected month. Plants that bloom in
// multiple selected months appear in each matching section (duplicated by
// design, per the brief).

struct PlantPickerGalleryView: View {

    let months: [Int]
    let mode: PickerMode
    let manualSun: Sunlight?
    let manualSoil: SoilType?
    let minHeightCm: Int

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ScrollView {
            if case .failed(let msg) = library.status {
                offlineBanner(msg)
            }
            if grouped.allSatisfy({ $0.plants.isEmpty }) {
                emptyState
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(grouped, id: \.month) { group in
                        section(for: group)
                    }
                }
                .padding(20)
            }
        }
        .bmFloralBackdrop()
        .bmNavTitle(months.count == 1
                    ? "\(PlantPickerMonthView.monthName(months[0])) bloom"
                    : "\(months.count)-month bloom",
                    icon: "🌸")
        .task { await library.loadIfNeeded() }
    }

    // MARK: - Filter pipeline

    private struct MonthGroup {
        let month: Int
        let plants: [Plant]
    }

    private var grouped: [MonthGroup] {
        let entitled = library.plants
        let climate = store.climate

        // Pre-compute the garden-condition filter once.
        func suitsGarden(_ p: Plant) -> Bool {
            guard let g = store.selectedGarden else { return true }
            let soilOk = p.preferredSoil.isEmpty || p.preferredSoil.contains(g.soilType)
            let sunOk  = p.preferredSunlight.isEmpty || p.preferredSunlight.contains(g.sunlight)
            return soilOk && sunOk
        }

        return months.map { m in
            let plants = entitled.filter { p in
                guard p.blooms(in: m) else { return false }
                switch mode {
                case .matched:
                    guard suitsGarden(p) else { return false }
                    guard climate.suits(p) else { return false }
                    return true
                case .all:
                    if let s = manualSun, !p.preferredSunlight.contains(s)  { return false }
                    if let s = manualSoil, !p.preferredSoil.contains(s)     { return false }
                    if let h = p.heightCm, h < minHeightCm                  { return false }
                    return true
                }
            }
            return MonthGroup(month: m, plants: plants)
        }
    }

    // MARK: - Section + tile

    @ViewBuilder
    private func section(for group: MonthGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(PlantPickerMonthView.monthName(group.month))
                    .font(.custom("Fredoka-SemiBold", size: 16))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text("\(group.plants.count) plant\(group.plants.count == 1 ? "" : "s")")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }

            if group.plants.isEmpty {
                Text(mode == .matched
                     ? "Nothing in your garden suits this month. Try All plants."
                     : "No matches.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
                    .padding(.vertical, 6)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                          spacing: 12) {
                    ForEach(group.plants) { p in
                        NavigationLink {
                            PlantDetailView(plantId: p.id)
                                .environmentObject(store)
                                .environmentObject(library)
                        } label: {
                            tile(p)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌱").font(.system(size: 38))
            Text(mode == .matched ? "No matches for your garden" : "No plants found")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text(mode == .matched
                 ? "Try toggling to All plants, or pick different bloom months."
                 : "Try different filters.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .bmCard()
        .padding(20)
    }

    private func offlineBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color.bmAmber)
            Text("Showing bundled library — \(message)")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText2)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.bmBorder, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func tile(_ p: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            plantImage(p, height: 96, cornerRadius: 12)
            Text(p.name)
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundStyle(Color.bmText1)
                .lineLimit(1)
            HStack(spacing: 4) {
                chip(p.type.label, color: .bmLilac)
                if let hex = p.colorHex {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
                if let h = p.heightCm { chip("\(h) cm", color: .bmSky) }
            }
        }
        .padding(10)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Nunito-Bold", size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func plantImage(_ p: Plant, height: CGFloat, cornerRadius: CGFloat) -> some View {
        BMPlantImage(plant: p, height: height, cornerRadius: cornerRadius)
    }
}

// MARK: - Shared plant image
//
// AsyncImage with a colour-card placeholder + emoji fallback. Used by both
// the picker tile (96 px) and the detail hero (180 px). The Wikimedia Commons
// URLs come pre-thumbnailed at width=800 by the ingest pipeline.

fileprivate struct BMPlantImage: View {
    let plant: Plant
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(hex: plant.colorHex ?? "#c4eeda").opacity(0.45))
                .frame(height: height)
            if let url = plant.imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: height)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    case .empty:
                        ProgressView().tint(Color.bmGreen)
                    case .failure:
                        emojiFallback
                    @unknown default:
                        emojiFallback
                    }
                }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                emojiFallback
            }
        }
    }

    private var emojiFallback: some View {
        Text(emojiFor(plant.type)).font(.system(size: height * 0.38))
    }
}

fileprivate func emojiFor(_ t: PlantType) -> String {
    switch t {
    case .annual:    return "🌸"
    case .perennial: return "🌷"
    case .biennial:  return "🌼"
    case .bulb:      return "🌹"
    case .shrub:     return "🪴"
    case .herb:      return "🌿"
    case .vegetable: return "🥕"
    }
}

// MARK: - PlantDetailView (unchanged from previous iteration)

struct PlantDetailView: View {

    let plantId: String

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    private var plant: Plant? { library.plant(id: plantId) }

    var body: some View {
        Group {
            if let p = plant {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero(p)
                        details(p)
                        addToPlanSection(p)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            } else {
                Text("Plant not found.")
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .foregroundStyle(Color.bmText2)
            }
        }
        .bmFloralBackdrop()
        .bmNavTitle(plant?.name ?? "Plant", icon: "🌼")
    }

    private func hero(_ p: Plant) -> some View {
        VStack(spacing: 8) {
            BMPlantImage(plant: p, height: 180, cornerRadius: 18)
            Text(p.latin)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
                .italic()
        }
    }

    private func details(_ p: Plant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Details", icon: "📖")
            row("Type", p.type.label)
            if let h = p.heightCm { row("Height", "\(h) cm") }
            row("Preferred soil",     p.preferredSoil.map(\.label).joined(separator: ", "))
            row("Preferred sunlight", p.preferredSunlight.map(\.label).joined(separator: ", "))

            if !p.germinationRequirements.isEmpty {
                paragraph("Germination requirements", p.germinationRequirements)
            }
            if !p.growersTips.isEmpty {
                paragraph("Growers' tips", p.growersTips)
            }

            if let link = p.buyLink {
                Link(destination: link) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                        Text("Buy seeds")
                    }
                    .font(.custom("Fredoka-SemiBold", size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.bmPeach)
                    .clipShape(Capsule())
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText1)
        }
    }

    private func paragraph(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)
            Text(body)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText1)
        }
    }

    @ViewBuilder
    private func addToPlanSection(_ p: Plant) -> some View {
        let isPro = store.user.tier == .pro
        let beds = store.bedsInSelectedGarden
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Add to plan", icon: "🗓")

            if isPro && !beds.isEmpty {
                Text("Bed")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Menu {
                    ForEach(beds) { b in
                        Button {
                            store.selectedBedId = b.id
                        } label: {
                            HStack {
                                Text(b.name)
                                if store.selectedBedId == b.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .foregroundStyle(Color.bmGreen)
                        Text(store.selectedBed?.name ?? beds.first?.name ?? "Pick a bed")
                            .font(.custom("Nunito-Bold", size: 13))
                            .foregroundStyle(Color.bmText1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.bmText3)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.bmBorder, lineWidth: 1))
                }
            }

            Text("Bloom months — tap to stagger across the season")
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    monthPickChip(plant: p, month: m)
                }
            }

            let total = (1...12).filter { store.isPicked(plantId: p.id, month: $0) }.count
            if total > 0 {
                Text("Picked for \(total) month\(total == 1 ? "" : "s") — one schedule entry per pick.")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func monthPickChip(plant p: Plant, month m: Int) -> some View {
        let picked = store.isPicked(plantId: p.id, month: m)
        return Button {
            store.togglePick(plantId: p.id, month: m)
        } label: {
            VStack(spacing: 2) {
                Text(PlantPickerMonthView.monthName(m))
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(picked ? .white : Color.bmText1)
                if picked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(picked ? Color.bmGreen : Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(picked ? Color.bmGreen : Color.bmBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
#endif
