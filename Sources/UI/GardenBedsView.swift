#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - GardenBedsView

public struct GardenBedsView: View {

    @EnvironmentObject private var store: GardenStore
    @State private var search: String = ""
    @State private var statusFilter: BedStatus?
    @State private var sunFilter: Sunlight?
    @State private var soilFilter: SoilType?
    @State private var showingAddBed = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            searchAndFilters
            bedsList
        }
        .padding(.top, 12)
        .bmFloralBackdrop()
        .bmNavTitle("Garden beds", icon: "🪴")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBed = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.bmGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddBed) {
            AddBedView()
                .environmentObject(store)
        }
    }

    // MARK: - Search + filters

    private var searchAndFilters: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.bmText3)
                TextField("Search beds", text: $search)
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.bmBorder, lineWidth: 1.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PillButton("All", isActive: statusFilter == nil, color: .bmGreen) { statusFilter = nil }
                    ForEach(BedStatus.allCases) { s in
                        PillButton(s.label, isActive: statusFilter == s, color: tint(for: s)) {
                            statusFilter = (statusFilter == s) ? nil : s
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Sun")
                        .font(.custom("Fredoka-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                    ForEach(Sunlight.allCases) { s in
                        PillButton(s.shortLabel, isActive: sunFilter == s, color: .bmAmber) {
                            sunFilter = (sunFilter == s) ? nil : s
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Soil")
                        .font(.custom("Fredoka-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                    ForEach(SoilType.allCases) { s in
                        PillButton(s.label, isActive: soilFilter == s, color: .bmGreen) {
                            soilFilter = (soilFilter == s) ? nil : s
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - List

    @ViewBuilder
    private var bedsList: some View {
        let beds = filteredBeds
        ScrollView {
            VStack(spacing: 10) {
                if beds.isEmpty {
                    emptyState
                } else {
                    ForEach(beds) { b in
                        NavigationLink {
                            BedDetailView(bedId: b.id)
                                .environmentObject(store)
                        } label: {
                            bedRow(b)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🪴").font(.system(size: 38))
            Text("No beds yet")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("Add your first bed to start planning.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
            Button {
                showingAddBed = true
            } label: {
                Text("Add bed")
                    .font(.custom("Fredoka-SemiBold", size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .bmCard()
    }

    private func bedRow(_ b: Bed) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(b.name)
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                statusChip(b.status)
            }

            Text(b.dimensionLabel)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)

            HStack(spacing: 6) {
                if let (soil, wet, _, sun) = store.effectiveConditions(forBed: b) {
                    miniBadge(sun.shortLabel, color: .bmAmber)
                    miniBadge(soil.label,    color: .bmGreen)
                    miniBadge(wet.shortLabel, color: .bmSky)
                }
                Spacer()
                if b.overridesGarden {
                    HStack(spacing: 3) {
                        Image(systemName: "info.circle.fill").font(.system(size: 10))
                        Text("Overrides garden")
                    }
                    .font(.custom("Nunito-Bold", size: 10))
                    .foregroundStyle(Color.bmLilac)
                }
            }
        }
        .padding(14)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.bmBorder, lineWidth: 1.5))
        .shadow(color: Color.bmGreen.opacity(0.06), radius: 4, y: 1)
    }

    private func statusChip(_ s: BedStatus) -> some View {
        Text(s.label.uppercased())
            .font(.custom("Fredoka-SemiBold", size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint(for: s))
            .clipShape(Capsule())
    }

    private func miniBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Nunito-Bold", size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func tint(for s: BedStatus) -> Color {
        switch s {
        case .planned: return .bmAmber
        case .active:  return .bmGreen
        }
    }

    private var filteredBeds: [Bed] {
        var list = store.bedsInSelectedGarden
        if let s = statusFilter { list = list.filter { $0.status == s } }
        if let sun = sunFilter {
            list = list.filter { b in
                store.effectiveConditions(forBed: b)?.3 == sun
            }
        }
        if let soil = soilFilter {
            list = list.filter { b in
                store.effectiveConditions(forBed: b)?.0 == soil
            }
        }
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            list = list.filter { $0.name.lowercased().contains(needle) }
        }
        return list
    }
}
#endif
