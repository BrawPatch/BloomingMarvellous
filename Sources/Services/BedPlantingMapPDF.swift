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
        UIColor(white: 0.6, alpha: 1).setStroke()
        bg.lineWidth = 1
        bg.stroke()
        ctx.restoreGState()

        // Plant circles — tallest at the back (top of page = back of bed),
        // wrap rows; new species starts a new row.
        var cursorX: CGFloat = canvasRect.minX + 4
        var cursorY: CGFloat = canvasRect.minY + 4
        var rowH: CGFloat = 0

        for entry in entries {
            let spreadCm = CGFloat(entry.plant.spreadCm ?? 30)
            let circleSize = max(10, spreadCm * scale)
            let color = entry.uiColor

            for _ in 0..<entry.count {
                if cursorX + circleSize > canvasRect.maxX - 4 {
                    cursorX = canvasRect.minX + 4
                    cursorY += rowH + 2
                    rowH = 0
                }
                if cursorY + circleSize > canvasRect.maxY - 4 {
                    // Out of room — stop drawing further plants.
                    return
                }
                let r = CGRect(x: cursorX, y: cursorY,
                               width: circleSize, height: circleSize)
                color.withAlphaComponent(0.55).setFill()
                color.setStroke()
                let path = UIBezierPath(ovalIn: r)
                path.fill()
                path.lineWidth = 0.8
                path.stroke()
                cursorX += circleSize + 2
                rowH = max(rowH, circleSize)
            }
            // New species → new row, so height tiers stay grouped.
            cursorX = canvasRect.minX + 4
            cursorY += rowH + 2
            rowH = 0
        }

        // "Front of bed" caption
        let caption = "Front of bed"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.darkGray,
        ]
        let size = (caption as NSString).size(withAttributes: attrs)
        (caption as NSString).draw(at: CGPoint(x: canvasRect.midX - size.width / 2,
                                               y: canvasRect.maxY + 4),
                                   withAttributes: attrs)
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
        ("Legend" as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                                    withAttributes: headerAttrs)

        var y = rect.minY + 20
        for entry in entries {
            let dot = CGRect(x: rect.minX, y: y + 2, width: 10, height: 10)
            entry.uiColor.withAlphaComponent(0.7).setFill()
            UIBezierPath(ovalIn: dot).fill()
            entry.uiColor.setStroke()
            let line = UIBezierPath(ovalIn: dot)
            line.lineWidth = 0.6
            line.stroke()

            let text = legendLine(entry)
            (text as NSString).draw(at: CGPoint(x: rect.minX + 16, y: y),
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
        let plant: Plant
        let count: Int
        var uiColor: UIColor {
            if let hex = plant.colorHex, let c = UIColor(hex: hex) { return c }
            return UIColor.systemGreen
        }
    }

    private static func orderedEntries(bed: Bed,
                                       plants: [String: Plant]) -> [LayoutEntry] {
        bed.plantCounts
            .compactMap { (pid, count) -> LayoutEntry? in
                guard count > 0, let p = plants[pid] else { return nil }
                return LayoutEntry(plant: p, count: count)
            }
            .sorted { ($0.plant.heightCm ?? 0) > ($1.plant.heightCm ?? 0) }
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
