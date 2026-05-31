#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BloomScheduleView
//
// Wireframe: Bloom Schedule (List). Months Jan–Dec; each month lists the
// plants the user has picked for that bloom window. Picks come from the
// PlantDetailView "Add to bloom schedule" action.

public struct BloomScheduleView: View {

    @EnvironmentObject private var store: GardenStore

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(1...12, id: \.self) { m in
                    monthCard(month: m)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Bloom schedule", icon: "🌺")
    }

    @ViewBuilder
    private func monthCard(month: Int) -> some View {
        let picks = store.picks(month: month).compactMap(PlantLibrary.plant(id:))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Self.monthName(month))
                    .font(.custom("Fredoka-SemiBold", size: 16))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text("\(picks.count) plant\(picks.count == 1 ? "" : "s")")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }

            if picks.isEmpty {
                Text("No picks yet — add from Plant Picker.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
            } else {
                VStack(spacing: 6) {
                    ForEach(picks) { plant in
                        pickRow(plant, month: month)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func pickRow(_ plant: Plant, month: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: plant.colorHex ?? "#c4eeda"))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(plant.name)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Text(plant.type.label)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
            }
            Spacer()
            Button {
                store.removePick(plantId: plant.id, month: month)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.bmRed)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.monthSymbols[m - 1]
    }
}
#endif
