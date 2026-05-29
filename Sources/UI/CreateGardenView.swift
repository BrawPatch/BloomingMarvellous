#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - CreateGardenView (modal)
//
// Wireframe: Create Garden modal — name + default soil/wetness/exposure/sunlight.

public struct CreateGardenView: View {

    private let onCreate: (Garden) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var soilType: SoilType = .loam
    @State private var wetness: Wetness = .normalWell
    @State private var exposure: WeatherExposure = .normal
    @State private var sunlight: Sunlight = .sunnyAlways

    public init(onCreate: @escaping (Garden) -> Void) {
        self.onCreate = onCreate
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.bmBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        nameField
                        defaultsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Create garden")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Garden name", icon: "🌱")
            TextField("e.g. Back garden", text: $name)
                .font(.custom("Nunito-SemiBold", size: 15))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.bmBgSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.bmBorder, lineWidth: 1.5))
        }
    }

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Default settings", icon: "🪴")

            picker(title: "Soil type", selection: $soilType, options: SoilType.allCases) { $0.label }
            picker(title: "Wetness / drainage", selection: $wetness, options: Wetness.allCases) { $0.label }
            picker(title: "Weather exposure", selection: $exposure, options: WeatherExposure.allCases) { $0.label }
            picker(title: "Sunlight", selection: $sunlight, options: Sunlight.allCases) { $0.label }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

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
                ForEach(options) { o in
                    Text(label(o)).tag(o)
                }
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

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func create() {
        let garden = Garden(name: name.trimmingCharacters(in: .whitespaces),
                            soilType: soilType,
                            wetness: wetness,
                            exposure: exposure,
                            sunlight: sunlight)
        onCreate(garden)
        dismiss()
    }
}
#endif
