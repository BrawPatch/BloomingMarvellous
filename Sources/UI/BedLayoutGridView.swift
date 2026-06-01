#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedLayoutGridView
//
// Stylised top-down view of a bed showing the planted species as circles
// sized by `spreadCm` and laid out tallest-at-the-back (top of the view),
// shortest-at-the-front. The bed's aspect ratio matches widthCm:lengthCm
// so the canvas keeps a sense of physical scale.
//
// Layout is greedy row-packing: iterate plants in descending height,
// each species contributes `count` circles; when the row would overflow
// the bed width we wrap to a new row immediately below. This is a
// visualisation, not a true planting planner — Phase 4's PDF export
// will re-use the same canvas at A4 scale.

struct BedLayoutGridView: View {

    let bed: Bed
    let plants: [String: Plant]

    var body: some View {
        GeometryReader { geo in
            let bedW = max(1, Double(bed.widthCm))
            let bedL = max(1, Double(bed.lengthCm))
            let scale = min(geo.size.width / bedW, geo.size.height / bedL)
            let canvasW = bedW * scale
            let canvasH = bedL * scale

            ZStack(alignment: .topLeading) {
                // Bed background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.bmBgSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.bmBorder, lineWidth: 1.5)
                    )
                    .frame(width: canvasW, height: canvasH)

                Canvas { ctx, _ in
                    var cursorX: Double = 4
                    var cursorY: Double = 4
                    var rowHeight: Double = 0

                    for entry in orderedEntries {
                        let plant = entry.plant
                        let count = entry.count
                        let spread = Double(plant.spreadCm ?? 30)
                        let circleSize = max(8, spread * scale)
                        let tint = plant.tintColor

                        for _ in 0..<count {
                            if cursorX + circleSize > canvasW - 4 {
                                cursorX = 4
                                cursorY += rowHeight + 2
                                rowHeight = 0
                            }
                            if cursorY + circleSize > canvasH - 4 {
                                return
                            }
                            let rect = CGRect(x: cursorX, y: cursorY,
                                              width: circleSize, height: circleSize)
                            ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.6)))
                            ctx.stroke(Path(ellipseIn: rect),
                                       with: .color(tint),
                                       lineWidth: 1)
                            cursorX += circleSize + 2
                            rowHeight = max(rowHeight, circleSize)
                        }
                        // New species starts a new row so height tiers stay grouped
                        // (tallest back row, shorter species in front rows).
                        cursorX = 4
                        cursorY += rowHeight + 2
                        rowHeight = 0
                    }
                }
                .frame(width: canvasW, height: canvasH)

                VStack {
                    Spacer()
                    Text("Front of bed")
                        .font(.custom("Nunito-Bold", size: 9))
                        .foregroundStyle(Color.bmText3)
                        .padding(.bottom, 4)
                        .frame(maxWidth: canvasW)
                }
                .frame(width: canvasW, height: canvasH)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .frame(height: 160)
    }

    private var orderedEntries: [(plant: Plant, count: Int)] {
        bed.plantCounts.compactMap { (pid, count) -> (Plant, Int)? in
            guard count > 0, let p = plants[pid] else { return nil }
            return (p, count)
        }
        .sorted { ($0.0.heightCm ?? 0) > ($1.0.heightCm ?? 0) }
    }
}

private extension Plant {
    /// Best-effort tint pulled from the plant's `colorHex`, with a green
    /// fallback so unknown species still render.
    var tintColor: Color {
        guard let hex = colorHex, !hex.isEmpty else { return Color.bmGreen }
        return Color(hex: hex)
    }
}
#endif
