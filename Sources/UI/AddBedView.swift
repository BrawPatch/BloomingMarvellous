#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - AddBedView
//
// Wireframe: Add Bed — name + garden picker (Pro: multi) + width/length +
// status + optional sunlight/soil overrides.

public struct AddBedView: View {

    @EnvironmentObject private var store: GardenStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var gardenId: UUID?
    @State private var widthCm: Int = 100
    @State private var lengthCm: Int = 200
    @State private var status: BedStatus = .planned
    @State private var overrideSunlight: Bool = false
    @State private var sunlightOverride: Sunlight = .sunnyAlways
    @State private var overrideSoil: Bool = false
    @State private var soilOverride: SoilType = .loam
    @State private var wetnessOverride: Wetness = .normalWell

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nameField
                    gardenPicker
                    sizeFields
                    statusPicker
                    overridesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .bmSheetBackdrop()
            .bmNavTitle("Add bed", icon: "🪴")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { create() }
                        .disabled(!canCreate)
                        .foregroundStyle(canCreate ? Color.bmGreen : Color.bmText3)
                }
            }
            .onAppear {
                if gardenId == nil { gardenId = store.selectedGardenId ?? store.gardens.first?.id }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Bed name", icon: "🪴")
            TextField("e.g. Veg bed 1", text: $name)
                .font(.custom("Nunito-SemiBold", size: 15))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.bmBgSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.bmBorder, lineWidth: 1.5))
        }
    }

    @ViewBuilder
    private var gardenPicker: some View {
        if store.gardens.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Garden", icon: "🌿")
                Picker("Garden", selection: Binding(
                    get: { gardenId ?? store.gardens.first?.id ?? UUID() },
                    set: { gardenId = $0 })) {
                    ForEach(store.gardens) { g in
                        Text(g.name).tag(g.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.bmBgSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.bmBorder, lineWidth: 1))
            }
        }
    }

    private var sizeFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Size (cm)", icon: "📏")
            HStack(spacing: 12) {
                stepperField("Width", value: $widthCm)
                stepperField("Length", value: $lengthCm)
            }
        }
    }

    private func stepperField(_ label: String, value: Binding<Int>) -> some View {
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

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Status", icon: "📌")
            HStack(spacing: 10) {
                ForEach(BedStatus.allCases) { s in
                    PillButton(s.label, isActive: status == s, color: s == .active ? .bmGreen : .bmAmber) {
                        status = s
                    }
                }
            }
        }
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Optional overrides", icon: "✨")

            Toggle(isOn: $overrideSunlight) {
                Text("Override sunlight")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            .tint(Color.bmGreen)

            if overrideSunlight {
                Picker("Sunlight", selection: $sunlightOverride) {
                    ForEach(Sunlight.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)
            }

            Toggle(isOn: $overrideSoil) {
                Text("Override soil / wetness")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            .tint(Color.bmGreen)

            if overrideSoil {
                Picker("Soil", selection: $soilOverride) {
                    ForEach(SoilType.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)

                Picker("Wetness", selection: $wetnessOverride) {
                    ForEach(Wetness.allCases) { w in Text(w.label).tag(w) }
                }
                .pickerStyle(.menu)
                .tint(Color.bmGreen)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && gardenId != nil
    }

    private func create() {
        guard let gid = gardenId else { return }
        let bed = Bed(gardenId: gid,
                      name: name.trimmingCharacters(in: .whitespaces),
                      widthCm: widthCm,
                      lengthCm: lengthCm,
                      status: status,
                      soilTypeOverride: overrideSoil ? soilOverride : nil,
                      wetnessOverride: overrideSoil ? wetnessOverride : nil,
                      sunlightOverride: overrideSunlight ? sunlightOverride : nil)
        store.addBed(bed)
        dismiss()
    }
}
#endif
