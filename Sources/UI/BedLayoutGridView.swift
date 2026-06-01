#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedLayoutGridView
//
// Stylised top-down view of a bed showing the planted species as
// labelled circles sized by `spreadCm` and laid out tallest-at-the-back
// (top of the view), shortest-at-the-front. Each circle carries the
// letter assigned by `BedLayoutKey` so a glance at the legend explains
// every dot.
//
// Layout is greedy row-packing: iterate species in descending height,
// each species contributes `count` circles; when the row would overflow
// the bed width we wrap to a new row immediately below. A scale bar in
// the bottom-right gives the gardener a rough sense of size.

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.bmBgSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.bmBorder, lineWidth: 1.5)
                    )
                    .frame(width: canvasW, height: canvasH)

                Canvas { ctx, _ in
                    drawPlants(ctx: ctx, canvasW: canvasW, canvasH: canvasH, scale: scale)
                    drawScaleBar(ctx: ctx, canvasW: canvasW, canvasH: canvasH, scale: scale)
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

    // MARK: - Drawing

    private func drawPlants(ctx: GraphicsContext,
                            canvasW: Double,
                            canvasH: Double,
                            scale: Double) {
        var cursorX: Double = 4
        var cursorY: Double = 4
        var rowHeight: Double = 0

        for entry in BedLayoutKey.entries(bed: bed, plants: plants) {
            let spread = Double(entry.plant.spreadCm ?? 30)
            let circleSize = max(14, spread * scale)
            let fill = entry.plant.canvasFill
            let stroke = Color.bmText1

            for _ in 0..<entry.count {
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
                ctx.fill(Path(ellipseIn: rect), with: .color(fill))
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(stroke),
                           lineWidth: 1.4)

                // Letter glyph, sized to fit even small footprints.
                let glyphSize = max(8, min(14, circleSize * 0.55))
                let letter = Text(entry.letter)
                    .font(.system(size: glyphSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color.bmText1)
                ctx.draw(letter,
                         at: CGPoint(x: rect.midX, y: rect.midY),
                         anchor: .center)

                cursorX += circleSize + 2
                rowHeight = max(rowHeight, circleSize)
            }
            cursorX = 4
            cursorY += rowHeight + 2
            rowHeight = 0
        }
    }

    private func drawScaleBar(ctx: GraphicsContext,
                              canvasW: Double,
                              canvasH: Double,
                              scale: Double) {
        // Pick a round number of cm whose drawn length sits between
        // 30 and 90 px so the bar is always legible regardless of bed size.
        let candidates = [10.0, 25.0, 50.0, 100.0, 200.0]
        let cm = candidates.first { $0 * scale >= 30 && $0 * scale <= 90 } ?? 50.0
        let pxLen = cm * scale
        let pad: Double = 8
        let y = canvasH - pad - 12
        let x0 = canvasW - pad - pxLen
        let x1 = canvasW - pad

        var bar = Path()
        bar.move(to: CGPoint(x: x0, y: y))
        bar.addLine(to: CGPoint(x: x1, y: y))
        bar.move(to: CGPoint(x: x0, y: y - 3))
        bar.addLine(to: CGPoint(x: x0, y: y + 3))
        bar.move(to: CGPoint(x: x1, y: y - 3))
        bar.addLine(to: CGPoint(x: x1, y: y + 3))
        ctx.stroke(bar, with: .color(Color.bmText2), lineWidth: 1.2)

        let label = Text(scaleLabel(cm: cm))
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(Color.bmText2)
        ctx.draw(label,
                 at: CGPoint(x: (x0 + x1) / 2, y: y - 9),
                 anchor: .center)
    }

    private func scaleLabel(cm: Double) -> String {
        if cm >= 100 {
            let m = cm / 100
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(m)) m"
                : String(format: "%.1f m", m)
        }
        return "\(Int(cm)) cm"
    }
}

private extension Plant {
    /// Visible fill for the canvas. The original tint pulled from
    /// `colorHex` was sometimes lighter than the mint background and
    /// vanished; we blend it 70% towards a richer green so every dot
    /// has at least a visible weight, and we never go below alpha 0.55.
    var canvasFill: Color {
        let base: Color
        if let hex = colorHex, !hex.isEmpty {
            base = Color(hex: hex)
        } else {
            base = Color.bmGreen
        }
        return base.opacity(0.7)
    }
}
#endif
