#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedMapEditorView
//
// Drag-to-arrange Planting Map editor. Replaces the read-only greedy
// row-pack canvas with an interactive surface:
//   • Tap any plant chip in the tray (bottom) to drop a new placement at
//     the first non-overlapping spot in the bed.
//   • Drag any placement to reposition it. The colour saturates while
//     a drag is in progress; on commit, if the new position overlaps
//     another placement's spread zone, the circle snaps back.
//   • Long-press a placement to remove it.
//   • Save commits the whole arrangement back into `Bed.placements`
//     via `GardenStore.setPlacements`.
//
// Placements are addressed in bed-local centimetres (origin top-left,
// x right, y down). The canvas re-projects to view pixels every render
// so a wide bed packs the available width and a long bed scrolls
// vertically as needed.

public struct BedMapEditorView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public let bedId: UUID

    @State private var draftPlacements: [PlantPlacement] = []
    @State private var draggingId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var didSeed: Bool = false
    @State private var lastSaved: Date?

    public init(bedId: UUID) { self.bedId = bedId }

    public var body: some View {
        Group {
            if let bed = store.bed(id: bedId) {
                content(bed: bed)
            } else {
                Text("Bed not found.")
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundStyle(Color.bmText2)
            }
        }
        .bmFloralBackdrop()
        .bmNavTitle("Edit map", icon: "✏️")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .plantingMap)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(bed: Bed) -> some View {
        let plants = resolvedPlants(bed: bed)
        let palette = paletteByPlant(bed: bed, plants: plants)
        ScrollView {
            VStack(spacing: 14) {
                helpCard
                bedCanvas(bed: bed, plants: plants, palette: palette)
                trayCard(bed: bed, plants: plants, palette: palette)
                keyCard(plants: plants, palette: palette)
                saveButton(bed: bed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .onAppear { seedDraftIfNeeded(bed: bed) }
    }

    private var helpCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.bmGreen)
            Text("Tap a plant below to drop it in, drag to arrange, long-press to remove.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.leading)
            Spacer()
            Tooltip("Each circle is the plant's spread zone (radius = spread/2). The editor snaps a placement back if you drop it overlapping a neighbour. Mark a species perennial to keep its layout across seasons.")
        }
        .padding(12)
        .bmCard()
    }

    // MARK: - Bed canvas with drag gestures

    @ViewBuilder
    private func bedCanvas(bed: Bed,
                           plants: [String: Plant],
                           palette: [String: String]) -> some View {
        // Project bed-cm to view-pixels: fit the bed within available
        // width, then derive height proportionally.
        GeometryReader { geo in
            let scale = geo.size.width / CGFloat(bed.widthCm)
            let viewHeight = CGFloat(bed.lengthCm) * scale
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.bmBgSoft)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.bmGreenMid, lineWidth: 1.5)
                gridOverlay(scale: scale)
                ForEach(draftPlacements) { placement in
                    placementCircle(placement,
                                    bed: bed,
                                    plants: plants,
                                    palette: palette,
                                    scale: scale)
                }
                Text("Front of bed →")
                    .font(.custom("Nunito-Bold", size: 9))
                    .foregroundStyle(Color.bmText3)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
                    .padding(6)
            }
            .frame(width: geo.size.width, height: viewHeight)
        }
        .frame(height: bedCanvasHeight(bed: bed))
    }

    private func bedCanvasHeight(bed: Bed) -> CGFloat {
        // The GeometryReader pins width; we need to forward-declare a
        // height so the parent ScrollView allocates the right space.
        // Approximate using a typical width assumption (UIScreen) — the
        // canvas itself will lay out correctly via scale once measured.
        let width = UIScreen.main.bounds.width - 32 - 32
        let scale = width / CGFloat(bed.widthCm)
        return max(220, CGFloat(bed.lengthCm) * scale)
    }

    private func gridOverlay(scale: CGFloat) -> some View {
        Canvas { context, size in
            // 10 cm grid lines, very subtle.
            let step: CGFloat = 10 * scale
            var x: CGFloat = step
            while x < size.width {
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(Color.bmBorder.opacity(0.3)),
                    lineWidth: 0.5)
                x += step
            }
            var y: CGFloat = step
            while y < size.height {
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(Color.bmBorder.opacity(0.3)),
                    lineWidth: 0.5)
                y += step
            }
        }
    }

    @ViewBuilder
    private func placementCircle(_ placement: PlantPlacement,
                                 bed: Bed,
                                 plants: [String: Plant],
                                 palette: [String: String],
                                 scale: CGFloat) -> some View {
        if let plant = plants[placement.plantId] {
            let spreadCm = Double(plant.spreadCm ?? 30)
            let diameter = CGFloat(spreadCm) * scale
            let dragging = (draggingId == placement.id)
            let baseX = CGFloat(placement.xCm) * scale
            let baseY = CGFloat(placement.yCm) * scale
            let dx = dragging ? dragOffset.width  : 0
            let dy = dragging ? dragOffset.height : 0
            let letter = letterForPlant(plant.id, plants: plants, bed: bed)
            let colour = Color(hex: palette[plant.id] ?? "#88aa88")
            ZStack {
                Circle()
                    .fill(colour.opacity(dragging ? 0.85 : 0.55))
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                Text(letter)
                    .font(.custom("Fredoka-SemiBold", size: 11))
                    .foregroundStyle(.white)
            }
            .frame(width: diameter, height: diameter)
            .position(x: baseX + dx, y: baseY + dy)
            .accessibilityLabel("\(plant.name) at \(Int(placement.xCm)), \(Int(placement.yCm))")
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if draggingId != placement.id { draggingId = placement.id }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let newXCm = placement.xCm + Double(value.translation.width / scale)
                        let newYCm = placement.yCm + Double(value.translation.height / scale)
                        commitDrag(placementId: placement.id,
                                   to: CGPoint(x: newXCm, y: newYCm),
                                   bed: bed,
                                   plants: plants)
                        draggingId = nil
                        dragOffset = .zero
                    }
            )
            .onLongPressGesture(minimumDuration: 0.45) {
                draftPlacements.removeAll { $0.id == placement.id }
            }
        }
    }

    // MARK: - Tray of placeable plants

    @ViewBuilder
    private func trayCard(bed: Bed,
                          plants: [String: Plant],
                          palette: [String: String]) -> some View {
        // For each species in plantCounts, show how many more can be
        // dropped (count - already-placed). Tapping the tile drops one
        // at the first free slot inside the bed.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SectionLabel("Plants to place", icon: "🌱")
                Tooltip("Each chip shows how many of that species still need a spot. Tap to drop one in — it lands at the first free position in the bed.")
                Spacer()
            }
            let remainings = bed.plantCounts.compactMap { (pid, total) -> (Plant, Int)? in
                guard let p = plants[pid] else { return nil }
                let placed = draftPlacements.filter { $0.plantId == pid }.count
                let remain = max(0, total - placed)
                return remain > 0 ? (p, remain) : nil
            }.sorted { ($0.0.heightCm ?? 0) > ($1.0.heightCm ?? 0) }
            if remainings.isEmpty {
                Text("Everything's placed. Drag to fine-tune, long-press to remove.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(remainings.enumerated()), id: \.element.0.id) { _, pair in
                            let (plant, remain) = pair
                            trayChip(plant: plant,
                                     remaining: remain,
                                     colour: Color(hex: palette[plant.id] ?? "#88aa88"),
                                     letter: letterForPlant(plant.id, plants: plants, bed: bed),
                                     bed: bed,
                                     plants: plants)
                        }
                    }
                }
            }
        }
        .padding(14)
        .bmCard()
    }

    private func trayChip(plant: Plant,
                          remaining: Int,
                          colour: Color,
                          letter: String,
                          bed: Bed,
                          plants: [String: Plant]) -> some View {
        Button {
            placeOne(plant: plant, bed: bed, plants: plants)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(colour.opacity(0.85))
                        .frame(width: 28, height: 28)
                    Text(letter)
                        .font(.custom("Fredoka-SemiBold", size: 12))
                        .foregroundStyle(.white)
                }
                Text(plant.name)
                    .font(.custom("Nunito-Bold", size: 10))
                    .foregroundStyle(Color.bmText1)
                    .lineLimit(1)
                    .frame(maxWidth: 90)
                Text("×\(remaining) left")
                    .font(.custom("Nunito-Bold", size: 9))
                    .foregroundStyle(Color.bmGreen)
            }
            .padding(8)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bmBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key (symbol legend)

    @ViewBuilder
    private func keyCard(plants: [String: Plant],
                         palette: [String: String]) -> some View {
        let entries = sortedPlants(in: plants)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SectionLabel("Key", icon: "🔑")
                Tooltip("Same colours and letters as your bed list on the Plants In Bed card and the printable PDF.")
                Spacer()
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, plant in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: palette[plant.id] ?? "#88aa88"))
                            .frame(width: 20, height: 20)
                        Text(BedLayoutKey.letter(forIndex: idx))
                            .font(.custom("Fredoka-SemiBold", size: 10))
                            .foregroundStyle(.white)
                    }
                    Text(plant.name)
                        .font(.custom("Nunito-Bold", size: 12))
                        .foregroundStyle(Color.bmText1)
                    Spacer()
                    if let s = plant.spreadCm {
                        Text("\(s) cm spread")
                            .font(.custom("Nunito-SemiBold", size: 10))
                            .foregroundStyle(Color.bmText3)
                    }
                }
            }
        }
        .padding(14)
        .bmCard()
    }

    // MARK: - Save

    private func saveButton(bed: Bed) -> some View {
        VStack(spacing: 6) {
            Button {
                store.setPlacements(draftPlacements, in: bed.id)
                lastSaved = Date()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Save layout")
                        .font(.custom("Fredoka-SemiBold", size: 15))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.bmGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            if let lastSaved {
                Text("Saved \(savedAgo(lastSaved))")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
        }
    }

    private func savedAgo(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Drag commit + collision

    private func commitDrag(placementId: UUID,
                            to position: CGPoint,
                            bed: Bed,
                            plants: [String: Plant]) {
        guard let idx = draftPlacements.firstIndex(where: { $0.id == placementId }) else { return }
        guard let plant = plants[draftPlacements[idx].plantId] else { return }

        let spreadCm = Double(plant.spreadCm ?? 30)
        let r = spreadCm / 2.0

        // Clamp to bed interior so the gardener can't park a plant
        // half-outside the bed.
        let clampedX = max(r, min(Double(bed.widthCm) - r, Double(position.x)))
        let clampedY = max(r, min(Double(bed.lengthCm) - r, Double(position.y)))
        let candidate = CGPoint(x: clampedX, y: clampedY)

        if overlapsSomething(plantId: plant.id,
                             placementId: placementId,
                             at: candidate,
                             radiusCm: r,
                             plants: plants) {
            // Snap back — don't update position.
            return
        }
        draftPlacements[idx].xCm = clampedX
        draftPlacements[idx].yCm = clampedY
    }

    private func overlapsSomething(plantId: String,
                                   placementId: UUID,
                                   at candidate: CGPoint,
                                   radiusCm: Double,
                                   plants: [String: Plant]) -> Bool {
        for other in draftPlacements where other.id != placementId {
            guard let otherPlant = plants[other.plantId] else { continue }
            let otherR = Double(otherPlant.spreadCm ?? 30) / 2.0
            let dx = Double(candidate.x) - other.xCm
            let dy = Double(candidate.y) - other.yCm
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < (radiusCm + otherR) { return true }
        }
        return false
    }

    // MARK: - Tap-to-place

    private func placeOne(plant: Plant,
                          bed: Bed,
                          plants: [String: Plant]) {
        let spreadCm = Double(plant.spreadCm ?? 30)
        let r = spreadCm / 2.0
        // Scan the bed in 10cm steps for the first non-overlapping slot.
        let step = 10.0
        var bestPos: CGPoint?
        var y = r
        while y <= Double(bed.lengthCm) - r {
            var x = r
            while x <= Double(bed.widthCm) - r {
                let candidate = CGPoint(x: x, y: y)
                if !overlapsSomething(plantId: plant.id,
                                      placementId: UUID(), // never matches existing ids
                                      at: candidate,
                                      radiusCm: r,
                                      plants: plants) {
                    bestPos = candidate
                    break
                }
                x += step
            }
            if bestPos != nil { break }
            y += step
        }
        let pos = bestPos ?? CGPoint(x: Double(bed.widthCm) / 2.0, y: Double(bed.lengthCm) / 2.0)
        let isPerennial = bed.perennials.contains(plant.id)
        let placement = PlantPlacement(plantId: plant.id,
                                       xCm: Double(pos.x),
                                       yCm: Double(pos.y),
                                       isPerennial: isPerennial)
        draftPlacements.append(placement)
    }

    // MARK: - Helpers

    private func resolvedPlants(bed: Bed) -> [String: Plant] {
        var out: [String: Plant] = [:]
        for pid in bed.plantCounts.keys {
            if let p = library.plant(id: pid) { out[pid] = p }
        }
        for placement in draftPlacements where out[placement.plantId] == nil {
            if let p = library.plant(id: placement.plantId) { out[placement.plantId] = p }
        }
        return out
    }

    private func sortedPlants(in dict: [String: Plant]) -> [Plant] {
        Array(dict.values).sorted { lhs, rhs in
            let lh = lhs.heightCm ?? 0
            let rh = rhs.heightCm ?? 0
            if lh != rh { return lh > rh }
            return lhs.name < rhs.name
        }
    }

    private func paletteByPlant(bed: Bed, plants: [String: Plant]) -> [String: String] {
        let ordered = sortedPlants(in: plants)
        var out: [String: String] = [:]
        for (idx, plant) in ordered.enumerated() {
            out[plant.id] = BedLayoutKey.palette[idx % BedLayoutKey.palette.count]
        }
        return out
    }

    private func letterForPlant(_ pid: String,
                                plants: [String: Plant],
                                bed: Bed) -> String {
        let ordered = sortedPlants(in: plants)
        guard let idx = ordered.firstIndex(where: { $0.id == pid }) else { return "?" }
        return BedLayoutKey.letter(forIndex: idx)
    }

    private func seedDraftIfNeeded(bed: Bed) {
        guard !didSeed else { return }
        // Seed from saved placements if any; otherwise drop one circle per
        // counted plant at a sensible starting position (greedy row pack)
        // so the gardener can drag-refine instead of starting blank.
        if !bed.placements.isEmpty {
            draftPlacements = bed.placements
        } else if !bed.plantCounts.isEmpty {
            draftPlacements = seedFromCounts(bed: bed)
        }
        didSeed = true
    }

    private func seedFromCounts(bed: Bed) -> [PlantPlacement] {
        let plants = resolvedPlants(bed: bed)
        let entries = BedLayoutKey.entries(bed: bed, plants: plants)
        var out: [PlantPlacement] = []
        var cursorX: Double = 0
        var cursorY: Double = 0
        var rowMaxR: Double = 0
        for entry in entries {
            let spread = Double(entry.plant.spreadCm ?? 30)
            let r = spread / 2.0
            for _ in 0..<entry.count {
                if cursorX + spread > Double(bed.widthCm) {
                    cursorX = 0
                    cursorY += rowMaxR * 2
                    rowMaxR = 0
                }
                let x = cursorX + r
                let y = cursorY + r
                if y + r > Double(bed.lengthCm) { return out } // ran out of space
                out.append(PlantPlacement(
                    plantId: entry.plant.id,
                    xCm: x,
                    yCm: y,
                    isPerennial: bed.perennials.contains(entry.plant.id)
                ))
                cursorX += spread
                if r > rowMaxR { rowMaxR = r }
            }
        }
        return out
    }
}
#endif
