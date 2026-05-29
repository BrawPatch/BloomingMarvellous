#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantPickerMonthView
//
// Wireframe: Plant Picker — Month. User picks a target bloom month and
// optional filters (sun / soil / height), then drills into the gallery.

public struct PlantPickerMonthView: View {

    @State private var month: Int = Calendar.current.component(.month, from: Date())
    @State private var sunFilter: Sunlight?
    @State private var soilFilter: SoilType?
    @State private var minHeightCm: Int = 0

    public init() {}

    public var body: some View {
        ZStack {
            Color.bmBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    targetMonthSection
                    filtersSection
                    NavigationLink {
                        PlantPickerGalleryView(month: month,
                                               sunFilter: sunFilter,
                                               soilFilter: soilFilter,
                                               minHeightCm: minHeightCm)
                    } label: {
                        Text("View plants")
                            .font(.custom("Fredoka-SemiBold", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.bmGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.bmGreen.opacity(0.25), radius: 6, y: 2)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Plant picker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetMonthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Select target bloom month", icon: "🌸")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    Button {
                        month = m
                    } label: {
                        Text(Self.monthName(m))
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundStyle(month == m ? .white : Color.bmText2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(month == m ? Color.bmGreen : Color.bmBgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(month == m ? Color.bmGreen : Color.bmBorder, lineWidth: 1.5))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Optional filters", icon: "🔎")

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

    private static func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.shortMonthSymbols[m - 1]
    }
}

// MARK: - PlantPickerGalleryView
//
// Wireframe: Plant Picker — Gallery. 2-col grid of plants matching the
// filters, with type/color/height chips. Tap → Plant modal.

struct PlantPickerGalleryView: View {

    let month: Int
    let sunFilter: Sunlight?
    let soilFilter: SoilType?
    let minHeightCm: Int

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    private var matches: [Plant] {
        library.plants.filter { plant in
            guard plant.blooms(in: month) else { return false }
            if let sun = sunFilter, !plant.preferredSunlight.contains(sun) { return false }
            if let soil = soilFilter, !plant.preferredSoil.contains(soil) { return false }
            if let h = plant.heightCm, h < minHeightCm { return false }
            return true
        }
    }

    var body: some View {
        ZStack {
            Color.bmBg.ignoresSafeArea()
            ScrollView {
                if case .failed(let msg) = library.status {
                    offlineBanner(msg)
                }
                if matches.isEmpty {
                    Text("No plants match these filters.\nTry relaxing one.")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(Color.bmText2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                              spacing: 12) {
                        ForEach(matches) { p in
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
                    .padding(20)
                }
            }
        }
        .navigationTitle("\(PlantPickerMonthView_monthName(month)) bloom")
        .navigationBarTitleDisplayMode(.inline)
        .task { await library.loadIfNeeded() }
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
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: p.colorHex ?? "#c4eeda").opacity(0.45))
                    .frame(height: 96)
                Text(emoji(for: p.type))
                    .font(.system(size: 36))
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

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Nunito-Bold", size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func emoji(for t: PlantType) -> String {
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
}

// MARK: - PlantDetailView
//
// Wireframe: Plant modal (full screen). Hero, details, growers' tips, buy
// link, Add to plan.

struct PlantDetailView: View {

    let plantId: String

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var picked = false

    private var plant: Plant? { library.plant(id: plantId) }

    var body: some View {
        ZStack {
            Color.bmBg.ignoresSafeArea()
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
        .navigationTitle(plant?.name ?? "Plant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ p: Plant) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: p.colorHex ?? "#c4eeda").opacity(0.4))
                .frame(height: 180)
            VStack(spacing: 6) {
                Text("🌸").font(.system(size: 56))
                Text(p.latin)
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
                    .italic()
            }
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

    private func addToPlanSection(_ p: Plant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Add to plan", icon: "🗓")
            Picker("Bloom month", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(PlantPickerMonthView_monthName(m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.bmGreen)

            Button {
                store.togglePick(plantId: p.id, month: selectedMonth)
                picked = true
            } label: {
                Text(picked ? "Added ✓" : "Add to bloom schedule")
                    .font(.custom("Fredoka-SemiBold", size: 14))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(picked ? Color.bmGreenMid : Color.bmGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }
}

// File-local copy so the gallery title can reuse the formatter without
// piercing PlantPickerMonthView's static.
private func PlantPickerMonthView_monthName(_ m: Int) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.shortMonthSymbols[m - 1]
}
#endif
