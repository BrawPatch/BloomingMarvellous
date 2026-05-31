#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SetupView
//
// First-run wizard shown immediately after server sign-in when the user has
// no local garden persisted yet. Captures:
//   • Address (postcode + country) — used by ClimateProfile to bias the
//     Plant Picker.
//   • Default garden conditions — soil, wetness, exposure, sunlight.
//   • A first planting bed — name + size + status.
//
// Everything is stored locally in GardenStore (UserDefaults-backed). The
// server has no /v1/gardens endpoints yet, so this is local state only.

public struct SetupView: View {

    @EnvironmentObject private var store: GardenStore
    @State private var page: Int = 0

    // Address
    @State private var postcode: String = ""
    @State private var country:  String = "GB"

    // Garden
    @State private var gardenName: String = "My Garden"
    @State private var soilType: SoilType = .loam
    @State private var wetness: Wetness = .normalWell
    @State private var exposure: WeatherExposure = .normal
    @State private var sunlight: Sunlight = .sunnyAlways

    // Bed
    @State private var bedName: String = "Bed 1"
    @State private var bedWidth: Int = 100
    @State private var bedLength: Int = 200
    @State private var bedStatus: BedStatus = .planned

    public init() {}

    public var body: some View {
        ZStack {
            Color.bmBg.ignoresSafeArea()
            decorations

            VStack(spacing: 18) {
                titleCard
                progressDots

                TabView(selection: $page) {
                    addressPage.tag(0)
                    gardenPage.tag(1)
                    bedPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                navRow
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Title

    private var titleCard: some View {
        VStack(spacing: 2) {
            Text("Let's set up your garden")
                .font(.custom("Fredoka-SemiBold", size: 18))
                .foregroundStyle(Color.bmText1)
            Text(stepHint)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .stickerCard(radius: 16)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private var stepHint: String {
        switch page {
        case 0:  return "Step 1 of 3 — Address"
        case 1:  return "Step 2 of 3 — Garden defaults"
        default: return "Step 3 of 3 — First bed"
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == page ? Color.bmGreen : Color.bmBorder)
                    .frame(width: i == page ? 10 : 8, height: i == page ? 10 : 8)
            }
        }
    }

    // MARK: - Pages

    private var addressPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Where is your garden?", icon: "📍")

                Text("Postcode (UK)")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                TextField("e.g. EH3 9XX", text: $postcode)
                    .font(.custom("Nunito-SemiBold", size: 15))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.bmBorder, lineWidth: 1.5))

                Text("Country")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                Picker("Country", selection: $country) {
                    Text("United Kingdom").tag("GB")
                    Text("Ireland").tag("IE")
                    Text("Other").tag("XX")
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)

                if !postcode.isEmpty {
                    let climate = ClimateProfile.lookup(postcode: postcode)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Region detected")
                            .font(.custom("Fredoka-SemiBold", size: 11))
                            .foregroundStyle(Color.bmText3)
                            .kerning(0.5)
                        HStack(spacing: 8) {
                            Text(climate.regionLabel)
                                .font(.custom("Nunito-Bold", size: 13))
                                .foregroundStyle(Color.bmText1)
                            Text(climate.hardinessLabel)
                                .font(.custom("Nunito-SemiBold", size: 11))
                                .foregroundStyle(Color.bmText2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.bmBgSoft)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
    }

    private var gardenPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Tell us about your garden", icon: "🌿")

                Text("Garden name")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                TextField("e.g. Back garden", text: $gardenName)
                    .font(.custom("Nunito-SemiBold", size: 15))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.bmBorder, lineWidth: 1.5))

                picker(title: "Soil type",          selection: $soilType, options: SoilType.allCases)        { $0.label }
                picker(title: "Wetness / drainage", selection: $wetness,  options: Wetness.allCases)         { $0.label }
                picker(title: "Weather exposure",   selection: $exposure, options: WeatherExposure.allCases) { $0.label }
                picker(title: "Sunlight",           selection: $sunlight, options: Sunlight.allCases)        { $0.label }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
    }

    private var bedPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Your first bed", icon: "🪴")

                Text("Bed name")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                TextField("e.g. Veg bed", text: $bedName)
                    .font(.custom("Nunito-SemiBold", size: 15))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.bmBgSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.bmBorder, lineWidth: 1.5))

                HStack(spacing: 12) {
                    sizeStepper("Width",  value: $bedWidth)
                    sizeStepper("Length", value: $bedLength)
                }

                Text("Status")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundStyle(Color.bmText2)
                HStack(spacing: 10) {
                    ForEach(BedStatus.allCases) { s in
                        PillButton(s.label, isActive: bedStatus == s, color: s == .active ? .bmGreen : .bmAmber) {
                            bedStatus = s
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
    }

    // MARK: - Field helpers

    @ViewBuilder
    private func picker<T: Hashable & Identifiable>(title: String,
                                                   selection: Binding<T>,
                                                   options: [T],
                                                   label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)
            Picker(title, selection: selection) {
                ForEach(options) { o in Text(label(o)).tag(o) }
            }
            .pickerStyle(.menu)
            .tint(Color.bmGreen)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bmBorder, lineWidth: 1))
        }
    }

    private func sizeStepper(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText2)
            Stepper(value: value, in: 10...1000, step: 10) {
                Text("\(value.wrappedValue) cm")
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
            }
            .tint(Color.bmGreen)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bmBorder, lineWidth: 1))
        }
    }

    // MARK: - Nav row

    private var navRow: some View {
        HStack {
            if page > 0 {
                Button("Back") { withAnimation { page -= 1 } }
                    .font(.custom("Fredoka-SemiBold", size: 14))
                    .foregroundStyle(Color.bmText2)
            }
            Spacer()
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page == 2 ? "Finish" : "Next")
                    .font(.custom("Fredoka-SemiBold", size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(canAdvance ? Color.bmGreen : Color.bmGreenMid)
                    .clipShape(Capsule())
            }
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 24)
    }

    private var canAdvance: Bool {
        switch page {
        case 0:  return !postcode.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:  return !gardenName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return !bedName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Finish

    private func finish() {
        store.postcode = postcode.trimmingCharacters(in: .whitespaces)
        store.country  = country
        let garden = Garden(name: gardenName.trimmingCharacters(in: .whitespaces),
                            soilType: soilType,
                            wetness: wetness,
                            exposure: exposure,
                            sunlight: sunlight)
        store.addGarden(garden)
        store.selectedGardenId = garden.id
        let bed = Bed(gardenId: garden.id,
                      name: bedName.trimmingCharacters(in: .whitespaces),
                      widthCm: bedWidth,
                      lengthCm: bedLength,
                      status: bedStatus)
        store.addBed(bed)
    }

    // MARK: - Decorations

    private var decorations: some View {
        GeometryReader { geo in
            Group {
                FlowerView(size: 48, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-12))
                    .position(x: 40, y: 90)
                    .opacity(0.5)
                FlowerView(size: 32, petalColor: .bmLilac, centerColor: .bmAmber)
                    .rotationEffect(.degrees(18))
                    .position(x: geo.size.width - 38, y: 110)
                    .opacity(0.45)
                LeafView(size: 26, color: .bmLeafSage)
                    .rotationEffect(.degrees(20))
                    .position(x: 30, y: geo.size.height - 90)
                    .opacity(0.35)
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
