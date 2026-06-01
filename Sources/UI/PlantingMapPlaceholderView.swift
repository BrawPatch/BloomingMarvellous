#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantingMapPlaceholderView
//
// Phase 2 stub. The real Planting Map (Phase 4) renders a bed-by-bed
// gallery with PDF/A4 print; until then this screen tells the user the
// surface is reserved and links into the existing per-bed layout so the
// tile isn't a dead end.

struct PlantingMapPlaceholderView: View {

    @EnvironmentObject private var store: GardenStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                bedsPreview
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Planting Map", icon: "🗺️")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming in Phase 4")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("A bed-by-bed layout gallery with an A4 PDF you can print and take into the garden. Each bed shows plant footprints (height tier at the back, shortest at the front) drawn from the Bed Planting Map.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private var bedsPreview: some View {
        let beds = store.beds
        if !beds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Your beds (\(beds.count))", icon: "🪴")
                ForEach(beds) { b in
                    HStack(spacing: 10) {
                        Text("🪴").font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.name)
                                .font(.custom("Nunito-Bold", size: 13))
                                .foregroundStyle(Color.bmText1)
                            Text("\(b.plantCounts.values.reduce(0, +)) plants placed")
                                .font(.custom("Nunito-SemiBold", size: 11))
                                .foregroundStyle(Color.bmText3)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard()
        }
    }
}
#endif
