#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PickerMode
//
// Three top-level tabs on the picker:
//   • .matched — pre-filters the catalogue against the active bed (Pro)
//                or garden (Free) — soil, sunlight, wetness, acidity,
//                plus the regional growing season from the postcode.
//   • .all     — no auto-context. The gardener picks soil/sun/moisture/
//                pH manually as additional filter chips.
//   • .browse  — hierarchical drill-down (Group → Genus → Species →
//                Cultivars) so the gardener can navigate the catalogue
//                taxonomically without scrolling through 6,000 thumbnails.

public enum PickerMode: String, CaseIterable, Identifiable {
    case matched, all, browse
    public var id: String { rawValue }
}

// MARK: - HeightBand
//
// User-friendly grouping of mature heights so a gardener can ask for
// "just dwarf bedding" or "only climbers". Bands map to heightCm ranges
// derived from the library's heightCm field plus a few special-case
// rules for shrubs and climbers (which are tagged by type).

public enum HeightBand: String, CaseIterable, Identifiable {
    case dwarf      // < 30 cm — alpines, low edging
    case medium     // 30–80 cm — most bedding + perennials
    case tall       // 80–180 cm — back-of-border
    case shrub      // anything tagged type==shrub
    case climber    // ≥ 180 cm OR climber families (Clematis, Wisteria, Lonicera, Passiflora, Hedera, Humulus, Vitis)

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .dwarf:   return "Dwarf"
        case .medium:  return "Medium"
        case .tall:    return "Tall"
        case .shrub:   return "Shrub"
        case .climber: return "Climber"
        }
    }
    public var emoji: String {
        switch self {
        case .dwarf:   return "🌱"
        case .medium:  return "🌼"
        case .tall:    return "🌻"
        case .shrub:   return "🪴"
        case .climber: return "🪜"
        }
    }
    fileprivate func matches(_ p: Plant) -> Bool {
        switch self {
        case .shrub:   return p.type == .shrub
        case .climber:
            let climberGenera: Set<String> = [
                "Clematis","Wisteria","Lonicera","Passiflora","Hedera",
                "Humulus","Vitis","Jasminum","Akebia","Lathyrus","Cobaea",
                "Ipomoea","Thunbergia","Pyrostegia","Bougainvillea",
            ]
            let genus = p.latin.split(separator: " ").first.map(String.init) ?? ""
            if climberGenera.contains(genus) { return true }
            return (p.heightCm ?? 0) >= 180 && p.type != .shrub
        case .dwarf:   return (p.heightCm ?? 0) > 0 && (p.heightCm ?? 0) < 30 && p.type != .shrub
        case .medium:  return (p.heightCm ?? 0) >= 30 && (p.heightCm ?? 0) < 80 && p.type != .shrub
        case .tall:    return (p.heightCm ?? 0) >= 80 && (p.heightCm ?? 0) < 180 && p.type != .shrub
        }
    }
}

// MARK: - LifecycleFilter
//
// Annual / Perennial / All. Maps loosely onto PlantType — biennials count
// as perennials for filter purposes (more useful to a gardener than
// surfacing the rare biennial-only chip).

public enum LifecycleFilter: String, CaseIterable, Identifiable {
    case perennial, annual, all
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .perennial: return "Perennials"
        case .annual:    return "Annuals"
        case .all:       return "All"
        }
    }
    fileprivate func matches(_ p: Plant) -> Bool {
        switch self {
        case .all: return true
        case .annual:
            return p.type == .annual
        case .perennial:
            return p.type == .perennial || p.type == .biennial
                || p.type == .bulb || p.type == .shrub
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
    @State private var filtersExpanded: Bool = true

    // Manual refinements — only relevant when `mode == .all`.
    @State private var sunFilter: Sunlight?
    @State private var soilFilter: SoilType?
    @State private var wetFilter: Wetness?
    @State private var acidityFilter: SoilAcidity?

    // Cross-mode filters
    /// Empty set means "any colour" — the filter is inert.
    @State private var colorFilter:   Set<BloomColor> = []
    @State private var typeFilter:    PlantGroup?
    @State private var heightBand:    HeightBand?
    @State private var lifecycle:     LifecycleFilter = .all

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                tabBar
                    .padding(.horizontal, 16)
                if mode == .matched {
                    matchedContextCard
                        .padding(.horizontal, 16)
                }
                if mode != .browse {
                    filtersCard
                        .padding(.horizontal, 16)
                    if mode == .all {
                        manualFiltersSection
                            .padding(.horizontal, 16)
                    }
                    inlineGallery
                        .padding(.top, 4)
                } else {
                    PlantBrowseView()
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 14)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Plant picker", icon: "🌷")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .plantPicker)
            }
        }
    }

    // MARK: - Tab bar
    //
    // Two top-level tabs (Matched / All Plants). Replaces the old "Matched
    // to garden" segmented control. Label flips between "Matched to my Bed"
    // (Pro with a bed selected) and "Matched to my Garden" otherwise.

    private var tabBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                tabButton(.matched, label: matchedTabLabel)
                tabButton(.all,     label: "All Plants")
                tabButton(.browse,  label: "Browse")
            }
            .padding(4)
            .background(Color.bmBgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.bmBorder, lineWidth: 1.5))
            HStack(spacing: 6) {
                Tooltip(tabHelpText)
                Text(tabSubLabel)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private func tabButton(_ m: PickerMode, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { mode = m }
        } label: {
            Text(label)
                .font(.custom("Fredoka-SemiBold", size: 13))
                .foregroundStyle(mode == m ? .white : Color.bmText2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(mode == m ? Color.bmGreen : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var matchedTabLabel: String {
        if store.user.tier == .pro, store.selectedBed != nil {
            return "Matched to my Bed"
        }
        return "Matched to my Garden"
    }

    private var tabHelpText: String {
        switch mode {
        case .matched:
            return "Matched plays it safe — only plants happy in your selected bed or garden's soil, sunlight, moisture and pH, AND in your regional growing season."
        case .all:
            return "All Plants drops the bed/garden auto-filter so you can browse the whole catalogue. Use the Refine card below to pick conditions manually."
        case .browse:
            return "Browse drills down by botany — pick a category, then a genus, then a species, then a cultivar. Avoids the 6,000-thumbnail wall."
        }
    }

    private var tabSubLabel: String {
        switch mode {
        case .matched: return "Plants suited to your conditions"
        case .all:     return "The whole catalogue, refined manually"
        case .browse:  return "Drill down: Group → Genus → Species → Cultivars"
        }
    }

    // MARK: - Filters card (months + colour + type + height + lifecycle)

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $filtersExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    targetMonthsSection
                    Divider().padding(.vertical, 2)
                    bloomColourStrip
                    typeFilterStrip
                    heightFilterStrip
                    lifecycleFilterStrip
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    SectionLabel("Filters", icon: "🎛️")
                    Spacer()
                    if filtersExpanded { EmptyView() } else { activeFiltersSummary }
                }
            }
            .tint(Color.bmText2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var activeFiltersSummary: some View {
        let parts: [String] = [
            months.isEmpty ? nil : "\(months.count) month\(months.count == 1 ? "" : "s")",
            colorFilter.isEmpty ? nil : "\(colorFilter.count) colour\(colorFilter.count == 1 ? "" : "s")",
            typeFilter?.label,
            heightBand?.label,
            lifecycle == .all ? nil : lifecycle.label,
        ].compactMap { $0 }
        return Text(parts.isEmpty ? "No filters" : parts.joined(separator: " · "))
            .font(.custom("Nunito-SemiBold", size: 11))
            .foregroundStyle(Color.bmText3)
            .lineLimit(1)
    }

    // MARK: - Bloom colour strip (multi-select, with "Any colour")

    private var bloomColourStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Colour")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Multi-select. Tap several colours to build a palette, or tap 'Any colour' to clear. Plants are matched to their nearest three colour bands so pink-purple cultivars surface in both.")
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    smallChip(label: "Any colour", isActive: colorFilter.isEmpty) {
                        colorFilter.removeAll()
                    }
                    ForEach(BloomColor.allCases) { c in
                        Button {
                            if colorFilter.contains(c) { colorFilter.remove(c) }
                            else                      { colorFilter.insert(c) }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(c.swatch)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                Text(c.label)
                                    .font(.custom("Nunito-Bold", size: 11))
                                    .foregroundStyle(colorFilter.contains(c) ? .white : Color.bmText2)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(colorFilter.contains(c) ? Color.bmGreen : Color.bmBgCard)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(
                                colorFilter.contains(c) ? Color.bmGreen : Color.bmBorder,
                                lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Type strip

    private var typeFilterStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Type")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Group by Flower / Vegetable / Herb / Fruit. Fruit-pack plants land in Fruit regardless of their botanical type so you can find your blackcurrant.")
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    smallChip(label: "Any", isActive: typeFilter == nil) { typeFilter = nil }
                    ForEach(PlantGroup.allCases) { g in
                        smallChip(label: "\(g.emoji) \(g.label)",
                                  isActive: typeFilter == g) {
                            typeFilter = (typeFilter == g) ? nil : g
                        }
                    }
                }
            }
        }
    }

    // MARK: - Height strip

    private var heightFilterStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Height")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Dwarf is under 30 cm, Medium 30-80 cm, Tall 80-180 cm. Shrubs and Climbers are flagged by type and genus too — a Clematis counts as a climber regardless of height.")
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    smallChip(label: "Any", isActive: heightBand == nil) { heightBand = nil }
                    ForEach(HeightBand.allCases) { b in
                        smallChip(label: "\(b.emoji) \(b.label)",
                                  isActive: heightBand == b) {
                            heightBand = (heightBand == b) ? nil : b
                        }
                    }
                }
            }
        }
    }

    // MARK: - Lifecycle strip

    private var lifecycleFilterStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Lifecycle")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Annuals flower for one season and need replanting next year. Perennials (plus biennials, bulbs and shrubs) come back. Tap 'All' to mix both.")
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(LifecycleFilter.allCases) { f in
                    smallChip(label: f.label, isActive: lifecycle == f) {
                        lifecycle = f
                    }
                }
            }
        }
    }

    private func smallChip(label: String,
                           isActive: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Nunito-Bold", size: 11))
                .foregroundStyle(isActive ? .white : Color.bmText2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(isActive ? Color.bmGreen : Color.bmBgCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(
                    isActive ? Color.bmGreen : Color.bmBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline gallery

    private var inlineGallery: some View {
        PlantPickerGalleryView(months: Array(months).sorted(),
                               mode: mode,
                               manualSun: sunFilter,
                               manualSoil: soilFilter,
                               manualWet: wetFilter,
                               colorFilter: colorFilter,
                               typeFilter: typeFilter,
                               heightBand: heightBand,
                               lifecycle: lifecycle,
                               acidityOverride: acidityFilter)
    }

    // MARK: - Matched context

    private var matchedContextCard: some View {
        let climate = store.climate
        let isPro   = store.user.tier == .pro
        let bed     = isPro ? store.selectedBed : nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel("Filtering for", icon: "🎯")
                Tooltip("Tap the chips to switch which bed or garden the Matched results are filtered against.")
                Spacer()
            }

            // Garden + Bed selectors. Replaces the previous read-only chip
            // strip so the gardener can switch context without leaving
            // the picker — fixes the original gap where you'd have to
            // back out to BedDetail or Settings to swap.
            HStack(spacing: 8) {
                gardenSelector
                if isPro {
                    bedSelector
                }
                Spacer()
            }

            if let bed, let g = store.selectedGarden {
                let soil = bed.effectiveSoil(garden: g)
                let sun  = bed.effectiveSunlight(garden: g)
                let wet  = bed.effectiveWetness(garden: g)
                let acid = bed.effectiveAcidity(garden: g)
                HStack(spacing: 6) {
                    miniChip(soil.label, color: .bmGreen)
                    miniChip(sun.shortLabel, color: .bmAmber)
                    miniChip(wet.shortLabel, color: .bmSky)
                    if let a = acid {
                        miniChip(a.shortLabel, color: .bmLilac)
                    }
                }
            } else if let g = store.selectedGarden {
                HStack(spacing: 6) {
                    miniChip(g.soilType.label, color: .bmGreen)
                    miniChip(g.sunlight.shortLabel, color: .bmAmber)
                    miniChip(g.wetness.shortLabel, color: .bmSky)
                    if let a = g.acidity {
                        miniChip(a.shortLabel, color: .bmLilac)
                    }
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

    // MARK: - Selectors

    @ViewBuilder
    private var gardenSelector: some View {
        let isPro = store.user.tier == .pro
        if !isPro || store.gardens.count <= 1 {
            // Free tier or single garden — just a read-only label.
            selectorChip(icon: "🌷",
                         text: store.selectedGarden?.name ?? "Garden",
                         disabled: true)
        } else {
            Menu {
                ForEach(store.gardens) { g in
                    Button {
                        store.selectedGardenId = g.id
                        // Keep the bed selection consistent: drop into the
                        // first bed of the newly chosen garden so the
                        // Matched filter doesn't fall back to a bed in the
                        // other garden.
                        store.selectedBedId = store.beds(in: g.id).first?.id
                    } label: {
                        HStack {
                            Text(g.name)
                            if store.selectedGardenId == g.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                selectorChip(icon: "🌷",
                             text: store.selectedGarden?.name ?? "Pick a garden",
                             disabled: false)
            }
        }
    }

    @ViewBuilder
    private var bedSelector: some View {
        let beds = store.selectedGarden.map { store.beds(in: $0.id) } ?? []
        if beds.isEmpty {
            selectorChip(icon: "🌿",
                         text: "No beds",
                         disabled: true)
        } else if beds.count == 1, let only = beds.first {
            selectorChip(icon: "🌿", text: only.name, disabled: true)
        } else {
            Menu {
                Button {
                    store.selectedBedId = nil
                } label: {
                    HStack {
                        Text("Whole garden")
                        if store.selectedBedId == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
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
                selectorChip(icon: "🌿",
                             text: store.selectedBed?.name ?? "Whole garden",
                             disabled: false)
            }
        }
    }

    private func selectorChip(icon: String, text: String, disabled: Bool) -> some View {
        HStack(spacing: 5) {
            Text(icon).font(.system(size: 12))
            Text(text)
                .font(.custom("Fredoka-SemiBold", size: 12))
                .foregroundStyle(Color.bmText1)
            if !disabled {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.bmText3)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.bmBgSoft)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.bmBorder, lineWidth: 1))
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
    //
    // Embedded inside the Filters disclosure now — drop the outer card
    // chrome so it inherits the disclosure's padding.

    private var targetMonthsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bloom months")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Tap one or more months when you'd like flowers. Picking June + September gives a staggered show. Off-season months in Matched mode dim out.")
                Spacer()
                if months.count > 1 {
                    Text("\(months.count) selected")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    monthChip(m)
                }
            }
            HStack(spacing: 10) {
                Button("Clear")    { months = [] }
                    .font(.custom("Fredoka-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
                Button("All year")  { months = Set(1...12) }
                    .font(.custom("Fredoka-SemiBold", size: 11))
                    .foregroundStyle(Color.bmGreen)
                if mode == .matched {
                    Button("Growing season only") {
                        months = store.climate.growingSeason
                    }
                    .font(.custom("Fredoka-SemiBold", size: 11))
                    .foregroundStyle(Color.bmLilac)
                }
                Spacer()
            }
        }
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
    //
    // Soil / Sun / Moisture / Acidity chip rows. Replace the old min-height
    // slider with the new HeightBand strip (it lives in the main Filters
    // card alongside Colour and Type).

    private var manualFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Refine (All Plants)", icon: "🔎")

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
                Text("Moisture")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PillButton("Any", isActive: wetFilter == nil, color: .bmSky) { wetFilter = nil }
                        ForEach(Wetness.allCases) { w in
                            PillButton(w.shortLabel, isActive: wetFilter == w, color: .bmSky) {
                                wetFilter = (wetFilter == w) ? nil : w
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Acidity (pH)")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PillButton("Any", isActive: acidityFilter == nil, color: .bmLilac) { acidityFilter = nil }
                        ForEach(SoilAcidity.allCases) { a in
                            PillButton(a.shortLabel, isActive: acidityFilter == a, color: .bmLilac) {
                                acidityFilter = (acidityFilter == a) ? nil : a
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

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
    let manualWet: Wetness?
    let colorFilter: Set<BloomColor>
    let typeFilter: PlantGroup?
    let heightBand: HeightBand?
    let lifecycle: LifecycleFilter
    /// Explicit acidity filter applied in addition to the matched filter
    /// (e.g. when the user wants to override the garden default for this
    /// one search). nil = don't apply an extra constraint.
    let acidityOverride: SoilAcidity?

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    /// Free-text search applied across common + Latin names. Persists
    /// for the lifetime of this gallery view.
    @State private var search: String = ""

    var body: some View {
        VStack(spacing: 12) {
            if case .failed(let msg) = library.status {
                offlineBanner(msg)
            }
            PlantSearchBar(text: $search)
                .padding(.horizontal, 16)

            if grouped.allSatisfy({ $0.plants.isEmpty }) {
                emptyState
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(grouped, id: \.month) { group in
                        section(for: group)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
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
        // Matched-tab context: prefer bed-level effective conditions (Pro
        // with a bed selected), otherwise the garden's defaults.
        let bedEff: (soil: SoilType, sun: Sunlight, wet: Wetness, acid: SoilAcidity?)? = {
            guard store.user.tier == .pro,
                  let bed = store.selectedBed,
                  let g   = store.selectedGarden else { return nil }
            return (bed.effectiveSoil(garden: g),
                    bed.effectiveSunlight(garden: g),
                    bed.effectiveWetness(garden: g),
                    bed.effectiveAcidity(garden: g))
        }()

        func suitsContext(_ p: Plant) -> Bool {
            let soil:  SoilType?
            let sun:   Sunlight?
            let wet:   Wetness?
            let acid:  SoilAcidity?
            if let e = bedEff {
                soil = e.soil; sun = e.sun; wet = e.wet; acid = e.acid
            } else if let g = store.selectedGarden {
                soil = g.soilType; sun = g.sunlight; wet = g.wetness; acid = g.acidity
            } else {
                return true
            }
            let soilOk = soil.map { p.preferredSoil.isEmpty || p.preferredSoil.contains($0) } ?? true
            let sunOk  = sun.map { sunlightCompatible(garden: $0, plantPrefers: p.preferredSunlight) } ?? true
            let acidOk = acid.map { acidityCompatible(garden: $0, plantPrefers: p.preferredAcidity ?? []) } ?? true
            let wetOk: Bool = {
                guard let w = wet, let prefs = p.preferredWetness, !prefs.isEmpty else { return true }
                return prefs.contains(w)
            }()
            return soilOk && sunOk && acidOk && wetOk
        }

        func suitsColor(_ p: Plant) -> Bool {
            guard !colorFilter.isEmpty else { return true }
            // Match against the primary swatch AND any additional cultivar
            // palette colours, so a "white" search legitimately surfaces a
            // primarily-pink Wax Begonia 'Cocktail' series that also comes
            // in white.
            var allBands = BloomColor.nearestBands(forHex: p.colorHex)
            for hex in p.availableColours ?? [] {
                allBands.formUnion(BloomColor.nearestBands(forHex: hex))
            }
            return !colorFilter.isDisjoint(with: allBands)
        }
        func suitsType(_ p: Plant) -> Bool {
            guard let want = typeFilter else { return true }
            return PlantGroup.group(for: p) == want
        }
        func suitsHeight(_ p: Plant) -> Bool {
            guard let band = heightBand else { return true }
            return band.matches(p)
        }
        func suitsLifecycle(_ p: Plant) -> Bool {
            lifecycle.matches(p)
        }

        return months.map { m in
            let plants = entitled.filter { p in
                guard p.blooms(in: m) else { return false }
                guard suitsColor(p)     else { return false }
                guard suitsType(p)      else { return false }
                guard suitsHeight(p)    else { return false }
                guard suitsLifecycle(p) else { return false }
                if let a = acidityOverride,
                   let acids = p.preferredAcidity, !acids.isEmpty,
                   !acids.contains(a) {
                    return false
                }
                switch mode {
                case .matched:
                    guard suitsContext(p) else { return false }
                    guard climate.suits(p) else { return false }
                    return true
                case .all:
                    if let s = manualSun,  !p.preferredSunlight.contains(s) { return false }
                    if let s = manualSoil, !p.preferredSoil.contains(s)     { return false }
                    if let w = manualWet,
                       let prefs = p.preferredWetness, !prefs.isEmpty,
                       !prefs.contains(w) { return false }
                    return true
                case .browse:
                    // Gallery isn't rendered in browse mode (the parent
                    // swaps to PlantBrowseView); fall through accepting
                    // everything so this code path is harmless if reached.
                    return true
                }
            }
            let searched = PlantSectioning.filter(plants, search: search)
            return MonthGroup(month: m, plants: searched)
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
                // Sub-group by PlantGroup (Flower / Veg / Herb / Fruit)
                // so the gallery reads as a tidy catalog instead of a
                // jumble of types.
                ForEach(PlantSectioning.sections(for: group.plants)) { sec in
                    typeSubsection(sec)
                }
            }
        }
    }

    @ViewBuilder
    private func typeSubsection(_ section: PlantSection) -> some View {
        // Within each PlantGroup (Flowers / Vegetables / Herbs / Fruit)
        // sub-group plants by series — every "French Marigold" cultivar
        // lands under one "French Marigolds (N)" header, every Petunia
        // under "Petunias (N)", etc. Plants with no cultivar siblings
        // render inline without a header so single entries don't waste
        // a line.
        let buckets = seriesBuckets(plants: section.plants)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(section.group.emoji)
                Text(section.group.label.uppercased())
                    .font(.custom("Fredoka-SemiBold", size: 10))
                    .foregroundStyle(Color.bmText2)
                    .kerning(0.6)
                Spacer()
                Text("\(section.plants.count)")
                    .font(.custom("Nunito-Bold", size: 10))
                    .foregroundStyle(Color.bmText3)
            }
            .padding(.top, 4)
            ForEach(buckets, id: \.label) { bucket in
                seriesBucketView(bucket)
            }
        }
    }

    private struct SeriesBucket {
        let label: String
        let plants: [Plant]
    }

    /// Group plants by series (the part of `plant.name` before the
    /// cultivar epithet). Single-cultivar buckets are merged into a
    /// catch-all "Other" bucket at the end so the gallery still groups
    /// runs of related plants without floating 1-of-each rows.
    private func seriesBuckets(plants: [Plant]) -> [SeriesBucket] {
        let bySeries = Dictionary(grouping: plants) { Self.seriesLabel(plant: $0) }
        var multi: [SeriesBucket] = []
        var loners: [Plant] = []
        for (series, list) in bySeries {
            if list.count >= 2 {
                multi.append(SeriesBucket(label: series, plants: list.sorted { $0.name < $1.name }))
            } else {
                loners.append(contentsOf: list)
            }
        }
        multi.sort { (a, b) in
            if a.plants.count != b.plants.count { return a.plants.count > b.plants.count }
            return a.label.localizedCompare(b.label) == .orderedAscending
        }
        if !loners.isEmpty {
            multi.append(SeriesBucket(label: "Other",
                                      plants: loners.sorted { $0.name < $1.name }))
        }
        return multi
    }

    /// "French Marigold 'Boy Spry'" → "French Marigold". "Petunia
    /// 'Surfinia Purple'" → "Petunia". A species without a cultivar
    /// suffix returns its full common name.
    static func seriesLabel(plant: Plant) -> String {
        let name = plant.name
        if let r = name.range(of: " '") ?? name.range(of: " ‘") {
            return String(name[..<r.lowerBound])
        }
        return name
    }

    private func pluralise(_ singular: String) -> String {
        let lower = singular.lowercased()
        if lower.hasSuffix("s") || lower.hasSuffix("y")
            || lower.hasSuffix("ies") || lower.hasSuffix("z") { return singular }
        return singular + "s"
    }

    private func seriesBucketView(_ bucket: SeriesBucket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if bucket.label != "Other" {
                HStack(spacing: 6) {
                    Text(pluralise(bucket.label))
                        .font(.custom("Fredoka-SemiBold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text("·")
                        .foregroundStyle(Color.bmText3)
                    Text("\(bucket.plants.count) cultivar\(bucket.plants.count == 1 ? "" : "s")")
                        .font(.custom("Nunito-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                    Spacer()
                }
                .padding(.top, 2)
            } else if bucket.plants.count > 1 {
                Text("Other")
                    .font(.custom("Fredoka-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
                    .padding(.top, 2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                      spacing: 12) {
                ForEach(bucket.plants) { p in
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
            ZStack(alignment: .topTrailing) {
                plantImage(p, height: 96, cornerRadius: 12)
                if let acid = primaryAcidity(p) {
                    Text(acid.shortLabel)
                        .font(.custom("Fredoka-SemiBold", size: 9))
                        .foregroundStyle(.white)
                        .kerning(0.3)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(acidityBadgeColor(acid))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                        .padding(6)
                        .accessibilityLabel("Prefers \(acid.label) soil")
                }
                if store.isPickedInSelectedScope(plantId: p.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white, Color.bmGreen)
                        .padding(6)
                        .accessibilityLabel("Already in your plan")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
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

    private func primaryAcidity(_ p: Plant) -> SoilAcidity? {
        // If the plant carries an explicit acidity preference, surface the
        // mid-band value as the indicator. Otherwise no badge.
        guard let acids = p.preferredAcidity, !acids.isEmpty else { return nil }
        return acids.sorted { $0.rawValue < $1.rawValue }[acids.count / 2]
    }

    private func acidityBadgeColor(_ a: SoilAcidity) -> Color {
        switch a {
        case .veryAcidic, .mildlyAcidic: return .bmRed
        case .neutral:                   return .bmGreen
        case .mildlyAlkaline, .veryAlkaline: return .bmSky
        }
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

struct BMPlantImage: View {
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

// MARK: - BloomColor (named bands for the colour filter)
//
// Maps a plant's `colorHex` swatch to the nearest named bloom colour band.
// Used by the picker to filter results and by the swatch chips in the
// filter row.

public enum BloomColor: String, CaseIterable, Identifiable {
    case white, yellow, orange, red, pink, purple, blue, green

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }

    public var swatch: Color {
        switch self {
        case .white:  return Color(hex: "#f5f5f5")
        case .yellow: return Color(hex: "#f0d860")
        case .orange: return Color(hex: "#f0a060")
        case .red:    return Color(hex: "#d85050")
        case .pink:   return Color(hex: "#f0a8c0")
        case .purple: return Color(hex: "#b890d0")
        case .blue:   return Color(hex: "#7090d0")
        case .green:  return Color(hex: "#80b890")
        }
    }

    /// Reference (R, G, B) for each band, used for nearest-band assignment.
    fileprivate var referenceRGB: (Double, Double, Double) {
        let h = swatch.cgColor?.components ?? [1, 1, 1, 1]
        return (Double(h[0]), Double(h[1]), Double(h[2]))
    }

    /// Pick the closest band to a given hex (Euclidean RGB distance).
    public static func band(forHex hex: String?) -> BloomColor? {
        guard let hex else { return nil }
        let c = Color(hex: hex).cgColor?.components ?? [1, 1, 1, 1]
        let r = Double(c[0]), g = Double(c[1]), b = Double(c[2])
        var bestBand: BloomColor = .white
        var bestDist: Double = .infinity
        for band in BloomColor.allCases {
            let (rr, gg, bb) = band.referenceRGB
            let d = (r-rr)*(r-rr) + (g-gg)*(g-gg) + (b-bb)*(b-bb)
            if d < bestDist { bestDist = d; bestBand = band }
        }
        return bestBand
    }

    /// Top-N nearest bands. Used by the picker's colour filter — the
    /// library only carries 8 distinct hex values from the ingest
    /// defaults (no yellow, no white, etc.), so a strict single-band
    /// match returns zero plants for half of the chips. Letting a
    /// plant register against its three closest bands lifts every chip
    /// out of the empty state while still keeping pink/red/purple
    /// queries useful.
    public static func nearestBands(forHex hex: String?, count: Int = 3) -> Set<BloomColor> {
        guard let hex else { return Set(BloomColor.allCases) }
        let c = Color(hex: hex).cgColor?.components ?? [1, 1, 1, 1]
        let r = Double(c[0]), g = Double(c[1]), b = Double(c[2])
        let ranked = BloomColor.allCases
            .map { band -> (BloomColor, Double) in
                let (rr, gg, bb) = band.referenceRGB
                return (band, (r-rr)*(r-rr) + (g-gg)*(g-gg) + (b-bb)*(b-bb))
            }
            .sorted { $0.1 < $1.1 }
        return Set(ranked.prefix(count).map { $0.0 })
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

    // Local "pending" picks. The chips toggle in this set without touching
    // the store; the explicit Save button commits the diff so the gardener
    // sees a clear submit step.
    @State private var pending: Set<Int> = []
    @State private var didSeed = false
    @State private var savedToast: String?

    private var plant: Plant? { library.plant(id: plantId) }

    var body: some View {
        Group {
            if let p = plant {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero(p)
                        availableColoursSection(p)
                        descriptionSection(p)
                        details(p)
                        suitableForSection(p)
                        growersTipsSection(p)
                        sowingDetailsSection(p)
                        addToPlanSection(p)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .onAppear { syncPendingFromStore(p) }
                .onChange(of: store.selectedBedId) { _ in syncPendingFromStore(p) }
            } else {
                Text("Plant not found.")
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .foregroundStyle(Color.bmText2)
            }
        }
        .bmFloralBackdrop()
        .bmNavTitle(plant?.name ?? "Plant", icon: "🌼")
        .overlay(alignment: .top) {
            if let toast = savedToast {
                Text(toast)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.bmGreenMid, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func hero(_ p: Plant) -> some View {
        VStack(spacing: 4) {
            BMPlantImage(plant: p, height: 180, cornerRadius: 18)
            Text(p.name)
                .font(.custom("Fredoka-SemiBold", size: 18))
                .foregroundStyle(Color.bmText1)
                .padding(.top, 4)
            Text(p.latin)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
                .italic()
        }
    }

    @ViewBuilder
    private func availableColoursSection(_ p: Plant) -> some View {
        let palette = ([p.colorHex].compactMap { $0 } + (p.availableColours ?? []))
            // Deduplicate case-insensitively while preserving the primary
            // colour at the front.
            .reduce(into: [String]()) { acc, hex in
                let norm = hex.lowercased()
                if !acc.contains(where: { $0.lowercased() == norm }) { acc.append(hex) }
            }
        if palette.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    SectionLabel("Available colours", icon: "🎨")
                    Tooltip("Cultivars in this series are sold in several colours. Searching for any of them surfaces this plant — that's why a 'white' search might land on a primarily-pink series.")
                    Spacer()
                }
                HStack(spacing: 8) {
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .overlay(Circle().stroke(Color.bmBorder.opacity(0.6), lineWidth: 0.5))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
        }
    }

    @ViewBuilder
    private func descriptionSection(_ p: Plant) -> some View {
        if let desc = p.description, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Description", icon: "📖")
                Text(desc)
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
        }
    }

    // MARK: - Suitable for
    //
    // Shows which of the user's gardens / beds this plant will be happy
    // in, based on the same soft-match rules the picker uses (soil +
    // sunlight + acidity + wetness). When the list is empty we tell
    // the gardener what would have to change to make it work.

    @ViewBuilder
    private func suitableForSection(_ p: Plant) -> some View {
        let matches = suitableMatches(for: p)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Suitable for", icon: "✅")
            if matches.isEmpty {
                Text("Doesn't quite match the conditions of any of your gardens or beds. The Plant Picker will still let you add it, but it might need a sheltered spot or amended soil.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
            } else {
                ForEach(matches, id: \.id) { match in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.bmGreen)
                            .font(.system(size: 13, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.title)
                                .font(.custom("Nunito-Bold", size: 13))
                                .foregroundStyle(Color.bmText1)
                            Text(match.subtitle)
                                .font(.custom("Nunito-SemiBold", size: 11))
                                .foregroundStyle(Color.bmText3)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private struct SuitableMatch {
        let id: String
        let title: String
        let subtitle: String
    }

    private func suitableMatches(for p: Plant) -> [SuitableMatch] {
        var out: [SuitableMatch] = []
        for garden in store.gardens {
            let gardenSuits = matches(plant: p,
                                      soil: garden.soilType,
                                      sun:  garden.sunlight,
                                      wet:  garden.wetness,
                                      acid: garden.acidity)
            if gardenSuits {
                out.append(.init(
                    id: "g-\(garden.id.uuidString)",
                    title: garden.name,
                    subtitle: "Garden defaults match: \(garden.soilType.label), \(garden.sunlight.shortLabel), \(garden.wetness.shortLabel)"
                ))
            }
            for bed in store.beds(in: garden.id) {
                let bSoil = bed.effectiveSoil(garden: garden)
                let bSun  = bed.effectiveSunlight(garden: garden)
                let bWet  = bed.effectiveWetness(garden: garden)
                let bAcid = bed.effectiveAcidity(garden: garden)
                let bedSuits = matches(plant: p, soil: bSoil, sun: bSun, wet: bWet, acid: bAcid)
                if bedSuits {
                    out.append(.init(
                        id: "b-\(bed.id.uuidString)",
                        title: "\(garden.name) · \(bed.name)",
                        subtitle: "Bed conditions match: \(bSoil.label), \(bSun.shortLabel), \(bWet.shortLabel)"
                    ))
                }
            }
        }
        return out
    }

    private func matches(plant p: Plant,
                         soil: SoilType,
                         sun: Sunlight,
                         wet: Wetness,
                         acid: SoilAcidity?) -> Bool {
        let soilOk = p.preferredSoil.isEmpty || p.preferredSoil.contains(soil)
        let sunOk = sunlightCompatible(garden: sun, plantPrefers: p.preferredSunlight)
        let wetOk: Bool
        if let w = p.preferredWetness, !w.isEmpty { wetOk = w.contains(wet) } else { wetOk = true }
        let acidOk: Bool
        if let g = acid {
            acidOk = acidityCompatible(garden: g, plantPrefers: p.preferredAcidity ?? [])
        } else {
            acidOk = true
        }
        return soilOk && sunOk && wetOk && acidOk
    }

    @ViewBuilder
    private func growersTipsSection(_ p: Plant) -> some View {
        if !p.growersTips.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Grower's tips", icon: "💡")
                let bullets = p.growersTips
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.custom("Nunito-Bold", size: 13))
                            .foregroundStyle(Color.bmGreen)
                        Text(bullet)
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundStyle(Color.bmText1)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
        }
    }

    private func syncPendingFromStore(_ p: Plant) {
        pending = Set((1...12).filter { store.isPicked(plantId: p.id, month: $0) })
        didSeed = true
    }

    private func details(_ p: Plant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Details", icon: "📖")
            row("Type", p.type.label)
            if let h = p.heightCm { row("Height", "\(h) cm") }
            row("Preferred soil",     p.preferredSoil.map(\.label).joined(separator: ", "))
            row("Preferred sunlight", p.preferredSunlight.map(\.label).joined(separator: ", "))
            if let wet = p.preferredWetness, !wet.isEmpty {
                row("Preferred moisture", wet.map(\.label).joined(separator: ", "))
            }
            if let acid = p.preferredAcidity, !acid.isEmpty {
                row("Preferred pH",   acid.map(\.label).joined(separator: ", "))
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

    private func sowingDetailsSection(_ p: Plant) -> some View {
        // Always render the card — when data is sparse we surface a
        // rule-of-thumb derived from bloom months + plant type so the
        // gardener still has actionable guidance.
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Sowing details", icon: "🌱")

            if !p.bloomMonths.isEmpty {
                row("Target bloom", monthList(p.bloomMonths))
            }
            if let d = p.seedDepthMm        { row("Seed depth", "\(d) mm") }
            if let t = p.germinationTempC   { row("Temperature", "\(t) °C") }
            if let days = p.germinationDays { row("Days to germinate", days) }
            if let light = p.lightForGermination {
                row("Light at germination", light)
            }
            if !p.sowIndoorMonths.isEmpty {
                row("Sow indoors", monthList(p.sowIndoorMonths))
            }
            if !p.sowDirectMonths.isEmpty {
                row("Sow direct",  monthList(p.sowDirectMonths))
            }
            if !p.transplantMonths.isEmpty {
                row("Transplant",  monthList(p.transplantMonths))
            }
            if !p.harvestMonths.isEmpty {
                row("Harvest",     monthList(p.harvestMonths))
            }
            if !p.germinationRequirements.isEmpty {
                paragraph("Germination requirements", p.germinationRequirements)
            }
            if !hasSpecificSowingDetail(p) {
                Text(sowingRuleOfThumb(p))
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func hasSpecificSowingDetail(_ p: Plant) -> Bool {
        p.seedDepthMm != nil
        || p.germinationTempC != nil
        || p.germinationDays != nil
        || p.lightForGermination != nil
        || !p.sowIndoorMonths.isEmpty
        || !p.sowDirectMonths.isEmpty
        || !p.transplantMonths.isEmpty
        || !p.harvestMonths.isEmpty
        || !p.germinationRequirements.isEmpty
    }

    /// Plain-English fallback derived from bloom month + plant type. Mirrors
    /// the same "12 weeks before bloom" rule the planting schedule uses.
    private func sowingRuleOfThumb(_ p: Plant) -> String {
        let firstBloom = p.bloomMonths.sorted().first ?? 6
        let bloomName = PlantPickerMonthView.monthName(firstBloom)
        switch p.type {
        case .annual, .biennial:
            return "Detailed sowing data isn't recorded yet. Rule of thumb for a \(bloomName)-blooming \(p.type.label.lowercased()): start indoors 8–12 weeks before bloom, prick out into pots, harden off, and plant out after the last frost."
        case .perennial:
            return "Detailed sowing data isn't recorded yet. Most \(p.type.label.lowercased())s prefer autumn sowing or division — buy potted in spring for a \(bloomName) first bloom."
        case .bulb:
            return "Detailed sowing data isn't recorded yet. For \(bloomName) flowers plant bulbs in autumn at a depth of about 3× the bulb's height; spring-flowering bulbs go in Sep–Nov, summer ones in Apr–May."
        case .shrub:
            return "Detailed sowing data isn't recorded yet. \(p.type.label) — plant bare-root from late autumn to early spring; container-grown any frost-free month."
        case .herb:
            return "Detailed sowing data isn't recorded yet. Sow indoors 6–8 weeks before last frost or direct outdoors once soil is warm; pinch tips often to keep leafy."
        case .vegetable:
            return "Detailed sowing data isn't recorded yet. Start indoors 6–8 weeks before last frost, transplant after the frost, harvest from \(bloomName) onwards."
        }
    }

    private func monthList(_ months: [Int]) -> String {
        months.sorted().map { PlantPickerMonthView.monthName($0) }.joined(separator: ", ")
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

            if isPro && store.gardens.count > 1 {
                Text("Garden")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Menu {
                    ForEach(store.gardens) { g in
                        Button {
                            store.selectedGardenId = g.id
                            // Bounce the bed selection to a bed inside the new
                            // garden so the bed picker below stays consistent.
                            store.selectedBedId = store.beds(in: g.id).first?.id
                        } label: {
                            HStack {
                                Text(g.name)
                                if store.selectedGardenId == g.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Color.bmGreen)
                        Text(store.selectedGarden?.name ?? "Pick a garden")
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

            HStack(spacing: 6) {
                Text("Bloom months — tap to stagger across the season")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Tooltip("Only this plant's actual bloom window is shown here — plus any months you've already saved. Pick several to stagger the show across the season.")
                Spacer()
            }

            // Limit the month grid to this plant's actual bloom window so
            // a June-July rose doesn't offer January as a choice. Already-
            // committed picks outside the window are still surfaced so an
            // existing schedule doesn't silently disappear, and a plant
            // without recorded bloomMonths falls back to the full year.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(availableMonths(for: p), id: \.self) { m in
                    monthPickChip(month: m)
                }
            }

            if !pending.isEmpty {
                Text("Selected \(pending.count) month\(pending.count == 1 ? "" : "s") — tap Save below to add them to your bloom schedule.")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }

            savePickButton(plant: p)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func availableMonths(for p: Plant) -> [Int] {
        let bloomSet: Set<Int> = p.bloomMonths.isEmpty
            ? Set(1...12)
            : Set(p.bloomMonths)
        let pickedSet: Set<Int> = Set((1...12).filter { store.isPicked(plantId: p.id, month: $0) })
        return bloomSet.union(pickedSet).sorted()
    }

    private func monthPickChip(month m: Int) -> some View {
        let selected = pending.contains(m)
        return Button {
            if selected { pending.remove(m) } else { pending.insert(m) }
        } label: {
            VStack(spacing: 2) {
                Text(PlantPickerMonthView.monthName(m))
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(selected ? .white : Color.bmText1)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.bmGreen : Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Color.bmGreen : Color.bmBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func savePickButton(plant p: Plant) -> some View {
        let committed = Set((1...12).filter { store.isPicked(plantId: p.id, month: $0) })
        let hasDiff = pending != committed
        Button {
            commitPicks(plant: p, committed: committed)
        } label: {
            Text(savePickButtonLabel(committed: committed))
                .font(.custom("Fredoka-SemiBold", size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(hasDiff ? Color.bmGreen : Color.bmGreenMid)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: hasDiff ? Color.bmGreen.opacity(0.25) : .clear, radius: 5, y: 2)
        }
        .disabled(!hasDiff)
        .padding(.top, 4)
    }

    private func savePickButtonLabel(committed: Set<Int>) -> String {
        if pending.isEmpty && committed.isEmpty { return "Pick a month" }
        if pending == committed { return "Saved ✓" }
        if pending.isEmpty       { return "Remove from schedule" }
        if committed.isEmpty     { return "Add \(pending.count) to bloom schedule" }
        return "Update bloom schedule (\(pending.count))"
    }

    private func commitPicks(plant p: Plant, committed: Set<Int>) {
        let toAdd    = pending.subtracting(committed)
        let toRemove = committed.subtracting(pending)
        for m in toAdd    { store.togglePick(plantId: p.id, month: m) }
        for m in toRemove { store.togglePick(plantId: p.id, month: m) }
        let count = pending.count
        let summary: String
        if count == 0 {
            summary = "Removed from schedule"
        } else if count == 1 {
            summary = "Added to 1 month ✓"
        } else {
            summary = "Added to \(count) months ✓"
        }
        withAnimation(.spring(response: 0.3)) { savedToast = summary }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation { savedToast = nil }
        }
    }
}

// MARK: - Matched-filter compatibility helpers
//
// The original strict-membership check turned into a UX dead end: a
// `sunny_am` garden excluded every plant whose preferred set was
// `[sunny_always]` (the majority of the ingested library), and a
// `mildly_alkaline` garden excluded every plant tagged `[neutral]`. The
// helpers below relax both axes:
//
//   • Sunlight: partial-sun (am / pm) gardens accept plants happy in any
//     sunny band; full-sun gardens also accept partial-sun plants;
//     shaded gardens stay strict so we don't surface sun-lovers.
//   • Acidity: a garden suits any plant whose preferred bands sit within
//     one step of the garden's pH band — neutral plants pass for mildly
//     acidic / mildly alkaline gardens, and so on.

private func sunlightCompatible(garden: Sunlight, plantPrefers: [Sunlight]) -> Bool {
    if plantPrefers.isEmpty { return true }
    if plantPrefers.contains(garden) { return true }
    switch garden {
    case .sunnyAlways:
        // Full sun garden still suits plants happy in partial sun.
        return plantPrefers.contains(.sunnyAM) || plantPrefers.contains(.sunnyPM)
    case .sunnyAM, .sunnyPM:
        // Partial-sun garden tolerates any sunny preference (the morning /
        // afternoon distinction is finer than what the library encodes).
        return plantPrefers.contains(.sunnyAlways)
            || plantPrefers.contains(.sunnyAM)
            || plantPrefers.contains(.sunnyPM)
    case .shadedAlways:
        return false
    }
}

private func acidityCompatible(garden: SoilAcidity, plantPrefers: [SoilAcidity]) -> Bool {
    if plantPrefers.isEmpty { return true }
    if plantPrefers.contains(garden) { return true }
    let bandIndex: (SoilAcidity) -> Int = {
        switch $0 {
        case .veryAcidic:     return 0
        case .mildlyAcidic:   return 1
        case .neutral:        return 2
        case .mildlyAlkaline: return 3
        case .veryAlkaline:   return 4
        }
    }
    let g = bandIndex(garden)
    return plantPrefers.contains { abs(bandIndex($0) - g) <= 1 }
}
#endif
