#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SoilView
//
// Tab 1. Lets the user edit the soil-related settings either for the
// selected garden (default scope) or, when launched from a Bed Detail,
// as an override on a specific bed.

public struct SoilView: View {

    public enum Scope: Hashable {
        case garden
        case bed(UUID)
    }

    @EnvironmentObject private var store: GardenStore
    @State private var scope: Scope = .garden
    @State private var soilType: SoilType   = .loam
    @State private var wetness: Wetness     = .normalWell
    @State private var exposure: WeatherExposure = .normal
    @State private var sunlight: Sunlight   = .sunnyAlways
    @State private var didLoad = false
    @State private var toast: ToastBanner.Message?

    private let initialScope: Scope?

    public init(scope: Scope? = nil) { self.initialScope = scope }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.bmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    scopePicker
                    soilTypeSection
                    wetnessSection
                    exposureSection
                    sunlightSection
                    saveButton
                    Spacer(minLength: 12)
                }
                .padding(20)
                .padding(.top, 20)
            }
            ToastBanner(message: $toast)
        }
        .navigationTitle("Soil & Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Sections

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Scope", icon: "🎯")
            Picker("Scope", selection: $scope) {
                Text("Garden defaults").tag(Scope.garden)
                ForEach(store.bedsInSelectedGarden) { b in
                    Text("Bed override · \(b.name)").tag(Scope.bed(b.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Color.bmGreen)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.bmBorder, lineWidth: 1.5))

            Text(scopeHelp)
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText2)
        }
        .onChange(of: scope) { _ in reloadFromStore() }
    }

    private var scopeHelp: String {
        switch scope {
        case .garden:
            return "Applies to every bed unless that bed sets its own override."
        case .bed:
            return "Overrides the garden defaults for this bed only."
        }
    }

    private var soilTypeSection: some View {
        sectionCard(label: "Soil type", icon: "🌍") {
            chipsRow(options: SoilType.allCases, selection: $soilType) { $0.label }
        }
    }

    private var wetnessSection: some View {
        sectionCard(label: "Wetness / drainage", icon: "💧") {
            chipsRow(options: Wetness.allCases, selection: $wetness) { $0.label }
        }
    }

    private var exposureSection: some View {
        sectionCard(label: "Weather exposure", icon: "🌬") {
            chipsRow(options: WeatherExposure.allCases, selection: $exposure) { $0.label }
        }
    }

    private var sunlightSection: some View {
        sectionCard(label: "Sunlight", icon: "☀️") {
            chipsRow(options: Sunlight.allCases, selection: $sunlight) { $0.label }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(scope == .garden ? "Save garden defaults" : "Save bed override")
                .font(.custom("Fredoka-SemiBold", size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bmGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.bmGreen.opacity(0.25), radius: 6, y: 2)
        }
    }

    // MARK: - Reusable bits

    private func sectionCard<Content: View>(label: String,
                                            icon: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(label, icon: icon)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func chipsRow<O: Hashable & Identifiable>(
        options: [O],
        selection: Binding<O>,
        label: @escaping (O) -> String
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { o in
                    PillButton(label(o),
                               isActive: selection.wrappedValue == o,
                               color: .bmGreen) {
                        selection.wrappedValue = o
                    }
                }
            }
        }
    }

    // MARK: - Load + save

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let initial = initialScope { scope = initial }
        reloadFromStore()
    }

    private func reloadFromStore() {
        switch scope {
        case .garden:
            guard let g = store.selectedGarden else { return }
            soilType = g.soilType
            wetness  = g.wetness
            exposure = g.exposure
            sunlight = g.sunlight
        case .bed(let id):
            guard let bed = store.bed(id: id),
                  let g = store.garden(id: bed.gardenId) else { return }
            soilType = bed.effectiveSoil(garden: g)
            wetness  = bed.effectiveWetness(garden: g)
            exposure = bed.effectiveExposure(garden: g)
            sunlight = bed.effectiveSunlight(garden: g)
        }
    }

    private func save() {
        switch scope {
        case .garden:
            guard var g = store.selectedGarden else { return }
            g.soilType = soilType
            g.wetness  = wetness
            g.exposure = exposure
            g.sunlight = sunlight
            store.updateGarden(g)
            toast = .init(text: "Garden defaults saved", icon: "🌱")
        case .bed(let id):
            guard var b = store.bed(id: id),
                  let g = store.garden(id: b.gardenId) else { return }
            // Only set overrides for values that diverge from the garden.
            b.soilTypeOverride = (soilType != g.soilType) ? soilType : nil
            b.wetnessOverride  = (wetness  != g.wetness)  ? wetness  : nil
            b.exposureOverride = (exposure != g.exposure) ? exposure : nil
            b.sunlightOverride = (sunlight != g.sunlight) ? sunlight : nil
            store.updateBed(b)
            toast = .init(text: "Bed override saved", icon: "✓")
        }
    }
}

#endif
