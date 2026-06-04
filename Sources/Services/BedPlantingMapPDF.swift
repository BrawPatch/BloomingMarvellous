#if canImport(UIKit)
import Foundation
import UIKit

// MARK: - BedPlantingMapPDF
//
// Renders a single bed's planting map to a one-page A4 PDF. The page is
// laid out as:
//
//   ┌─ Margin (36 pt) ──────────────────────────────────┐
//   │  Title:  <Bed name>                               │
//   │  Sub:    <W × L> · <Garden name>                  │
//   │                                                   │
//   │  ┌──────── bed canvas (aspect = widthCm:lengthCm) │
//   │  │                                                │
//   │  │  back row: tallest species, footprints by      │
//   │  │  spreadCm, sorted by heightCm desc             │
//   │  │                                                │
//   │  │  front row: shortest species                   │
//   │  └────────────────────────────────────────────────│
//   │                                                   │
//   │  Legend:                                          │
//   │  ● Lavender   ×3 · 40 cm spread · 60 cm tall      │
//   │  ● Cosmos     ×2 · 45 cm spread · 90 cm tall      │
//   └───────────────────────────────────────────────────┘
//
// All drawing is vector — Core Graphics calls into the PDF context — so
// the output prints cleanly on paper. UIGraphicsPDFRenderer writes to a
// caller-provided URL (typically a temp file the share sheet picks up).

public enum BedPlantingMapPDF {

    /// Render to `destination`. Returns the URL on success.
    @discardableResult
    public static func render(bed: Bed,
                              gardenName: String,
                              plants: [String: Plant],
                              to destination: URL) throws -> URL {
        // A4 portrait in points (72 dpi).
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Blooming Marvellous",
            kCGPDFContextTitle   as String: "\(bed.name) — planting map",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try renderer.writePDF(to: destination) { ctx in
            ctx.beginPage()
            drawPage(in: ctx.cgContext,
                     pageRect: pageRect,
                     bed: bed,
                     gardenName: gardenName,
                     plants: plants)
        }
        return destination
    }

    // MARK: - Page composition

    private static func drawPage(in cg: CGContext,
                                 pageRect: CGRect,
                                 bed: Bed,
                                 gardenName: String,
                                 plants: [String: Plant]) {
        let margin: CGFloat = 36
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)

        // Title block
        let titleHeight: CGFloat = 60
        let titleRect = CGRect(x: contentRect.minX,
                               y: contentRect.minY,
                               width: contentRect.width,
                               height: titleHeight)
        drawTitle(bed: bed, gardenName: gardenName, in: titleRect)

        // Legend block at the bottom (height grows with species count, capped)
        let entries = orderedEntries(bed: bed, plants: plants)
        let legendLineHeight: CGFloat = 20
        let legendHeight = max(40, CGFloat(entries.count) * legendLineHeight + 24)
        let legendRect = CGRect(x: contentRect.minX,
                                y: contentRect.maxY - legendHeight,
                                width: contentRect.width,
                                height: legendHeight)

        // Bed canvas in between
        let canvasRect = CGRect(x: contentRect.minX,
                                y: titleRect.maxY + 16,
                                width: contentRect.width,
                                height: legendRect.minY - titleRect.maxY - 32)

        drawBedCanvas(bed: bed, entries: entries, in: canvasRect, ctx: cg)
        drawLegend(entries: entries, in: legendRect)
    }

    private static func drawTitle(bed: Bed, gardenName: String, in rect: CGRect) {
        let title = bed.name
        let sub = "\(bed.widthCm) × \(bed.lengthCm) cm · \(gardenName)"

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.black,
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.darkGray,
        ]

        (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                                 withAttributes: titleAttrs)
        (sub as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY + 30),
                               withAttributes: subAttrs)
    }

    private static func drawBedCanvas(bed: Bed,
                                      entries: [LayoutEntry],
                                      in rect: CGRect,
                                      ctx: CGContext) {
        // Fit bed widthCm × lengthCm into `rect` while preserving aspect.
        let bedW = max(1, CGFloat(bed.widthCm))
        let bedL = max(1, CGFloat(bed.lengthCm))
        let scale = min(rect.width / bedW, rect.height / bedL)
        let canvasW = bedW * scale
        let canvasH = bedL * scale
        let origin = CGPoint(x: rect.minX + (rect.width - canvasW) / 2,
                             y: rect.minY + (rect.height - canvasH) / 2)
        let canvasRect = CGRect(origin: origin,
                                size: CGSize(width: canvasW, height: canvasH))

        // Bed background
        ctx.saveGState()
        let bg = UIBezierPath(roundedRect: canvasRect, cornerRadius: 8)
        UIColor(white: 0.96, alpha: 1).setFill()
        bg.fill()
        UIColor(white: 0.4, alpha: 1).setStroke()
        bg.lineWidth = 1
        bg.stroke()
        ctx.restoreGState()

        // Two paths depending on whether the gardener has arranged the bed
        // by hand in the Planting Map editor: explicit placements → draw
        // each at its exact (xCm, yCm); empty placements → fall through to
        // the legacy greedy row-pack so old beds still print sensibly.
        if !bed.placements.isEmpty {
            drawPlacements(bed: bed, entries: entries,
                           canvasRect: canvasRect, scale: scale)
        } else {
            drawGreedyPack(entries: entries,
                           canvasRect: canvasRect, scale: scale)
        }

        // "Front of bed" caption
        let caption = "Front of bed"
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.darkGray,
        ]
        let captionSize = (caption as NSString).size(withAttributes: captionAttrs)
        (caption as NSString).draw(at: CGPoint(x: canvasRect.midX - captionSize.width / 2,
                                               y: canvasRect.maxY + 4),
                                   withAttributes: captionAttrs)

        drawScaleBar(in: canvasRect, scale: scale, ctx: ctx)
    }

    private static func drawPlacements(bed: Bed,
                                       entries: [LayoutEntry],
                                       canvasRect: CGRect,
                                       scale: CGFloat) {
        // Index palette + letter + plant by plant id so each placement can
        // pick up its rendering context in O(1).
        var paletteByPid: [String: (color: UIColor, letter: String, plant: Plant)] = [:]
        for entry in entries {
            paletteByPid[entry.plant.id] = (entry.uiColor, entry.letter, entry.plant)
        }
        let glyphColor = UIColor(white: 0.1, alpha: 1)
        for placement in bed.placements {
            guard let info = paletteByPid[placement.plantId] else { continue }
            let spreadCm = CGFloat(info.plant.spreadCm ?? 30)
            let diameter = max(14, spreadCm * scale)
            let cx = canvasRect.minX + CGFloat(placement.xCm) * scale
            let cy = canvasRect.minY + CGFloat(placement.yCm) * scale
            let r = CGRect(x: cx - diameter / 2,
                           y: cy - diameter / 2,
                           width: diameter, height: diameter)
            info.color.setFill()
            glyphColor.setStroke()
            let path = UIBezierPath(ovalIn: r)
            path.fill()
            path.lineWidth = 0.9
            path.stroke()
            let glyphPt = max(7, min(12, diameter * 0.55))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: glyphPt, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let letterSize = (info.letter as NSString).size(withAttributes: attrs)
            (info.letter as NSString).draw(at: CGPoint(x: r.midX - letterSize.width / 2,
                                                       y: r.midY - letterSize.height / 2),
                                            withAttributes: attrs)
        }
    }

    private static func drawGreedyPack(entries: [LayoutEntry],
                                       canvasRect: CGRect,
                                       scale: CGFloat) {
        var cursorX: CGFloat = canvasRect.minX + 4
        var cursorY: CGFloat = canvasRect.minY + 4
        var rowH: CGFloat = 0
        let glyphColor = UIColor(white: 0.1, alpha: 1)

        for entry in entries {
            let spreadCm = CGFloat(entry.plant.spreadCm ?? 30)
            let circleSize = max(14, spreadCm * scale)
            let color = entry.uiColor

            for _ in 0..<entry.count {
                if cursorX + circleSize > canvasRect.maxX - 4 {
                    cursorX = canvasRect.minX + 4
                    cursorY += rowH + 2
                    rowH = 0
                }
                if cursorY + circleSize > canvasRect.maxY - 4 {
                    return
                }
                let r = CGRect(x: cursorX, y: cursorY,
                               width: circleSize, height: circleSize)
                color.setFill()
                glyphColor.setStroke()
                let path = UIBezierPath(ovalIn: r)
                path.fill()
                path.lineWidth = 0.9
                path.stroke()

                let glyphPt = max(7, min(12, circleSize * 0.55))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: glyphPt, weight: .bold),
                    .foregroundColor: UIColor.white,
                ]
                let letterSize = (entry.letter as NSString).size(withAttributes: attrs)
                let letterPt = CGPoint(x: r.midX - letterSize.width / 2,
                                       y: r.midY - letterSize.height / 2)
                (entry.letter as NSString).draw(at: letterPt, withAttributes: attrs)

                cursorX += circleSize + 2
                rowH = max(rowH, circleSize)
            }
            cursorX = canvasRect.minX + 4
            cursorY += rowH + 2
            rowH = 0
        }
    }

    private static func drawScaleBar(in canvasRect: CGRect,
                                     scale: CGFloat,
                                     ctx: CGContext) {
        let candidates: [CGFloat] = [10, 25, 50, 100, 200, 500]
        let cm = candidates.first { $0 * scale >= 40 && $0 * scale <= 120 } ?? 50
        let pxLen = cm * scale
        let pad: CGFloat = 8
        let y = canvasRect.maxY - pad - 14
        let x0 = canvasRect.maxX - pad - pxLen
        let x1 = canvasRect.maxX - pad

        let bar = UIBezierPath()
        bar.move(to: CGPoint(x: x0, y: y))
        bar.addLine(to: CGPoint(x: x1, y: y))
        bar.move(to: CGPoint(x: x0, y: y - 3))
        bar.addLine(to: CGPoint(x: x0, y: y + 3))
        bar.move(to: CGPoint(x: x1, y: y - 3))
        bar.addLine(to: CGPoint(x: x1, y: y + 3))
        UIColor.darkGray.setStroke()
        bar.lineWidth = 1
        bar.stroke()

        let label = scaleLabel(cm: cm)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: UIColor.darkGray,
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(at: CGPoint(x: (x0 + x1) / 2 - size.width / 2,
                                             y: y - size.height - 2),
                                 withAttributes: attrs)
    }

    private static func scaleLabel(cm: CGFloat) -> String {
        if cm >= 100 {
            let m = cm / 100
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(m)) m"
                : String(format: "%.1f m", m)
        }
        return "\(Int(cm)) cm"
    }

    private static func drawLegend(entries: [LayoutEntry], in rect: CGRect) {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray,
        ]
        let letterAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.white,
        ]
        ("Key" as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                                 withAttributes: headerAttrs)

        var y = rect.minY + 20
        for entry in entries {
            let dot = CGRect(x: rect.minX, y: y, width: 14, height: 14)
            entry.uiColor.setFill()
            UIBezierPath(ovalIn: dot).fill()
            UIColor.black.setStroke()
            let outline = UIBezierPath(ovalIn: dot)
            outline.lineWidth = 0.9
            outline.stroke()

            let lSize = (entry.letter as NSString).size(withAttributes: letterAttrs)
            (entry.letter as NSString).draw(at: CGPoint(
                x: dot.midX - lSize.width / 2,
                y: dot.midY - lSize.height / 2),
                withAttributes: letterAttrs)

            let text = legendLine(entry)
            (text as NSString).draw(at: CGPoint(x: rect.minX + 20, y: y + 1),
                                    withAttributes: rowAttrs)
            y += 20
            if y > rect.maxY - 4 { break }
        }
    }

    private static func legendLine(_ entry: LayoutEntry) -> String {
        var parts: [String] = ["\(entry.plant.name) ×\(entry.count)"]
        if let s = entry.plant.spreadCm { parts.append("\(s) cm spread") }
        if let h = entry.plant.heightCm { parts.append("\(h) cm tall") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Layout entries

    private struct LayoutEntry {
        let letter: String
        let plant: Plant
        let count: Int
        let paletteHex: String
        var uiColor: UIColor {
            UIColor(hex: paletteHex) ?? UIColor.systemGreen
        }
    }

    private static func orderedEntries(bed: Bed,
                                       plants: [String: Plant]) -> [LayoutEntry] {
        BedLayoutKey.entries(bed: bed, plants: plants).map { key in
            LayoutEntry(letter: key.letter,
                        plant: key.plant,
                        count: key.count,
                        paletteHex: key.paletteHex)
        }
    }
}

// MARK: - UIColor(hex:) helper (PDF-only, mirrors the SwiftUI Color(hex:))

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xff) / 255
        let g = CGFloat((v >>  8) & 0xff) / 255
        let b = CGFloat( v        & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
