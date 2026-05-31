#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantingScheduleView
//
// Wireframe: Planting Schedule (Calendar). Month grid with event markers
// derived deterministically from the user's bloom picks. The contract is:
//
//   • Sow event = (bloom month – 12 weeks), day 1. The 12 weeks is the
//     *earliest* end of an 8–12 week sowing window, per product brief —
//     gardeners want the marker at the **start** of the window so they
//     don't miss it.
//   • Transplant event = earliest month in the plant's `transplantMonths`,
//     day 1. Skipped if the plant has no transplant guidance.
//   • Harvest event = earliest month in the plant's `harvestMonths`,
//     day 1. Skipped if the plant has no harvest guidance (e.g. ornamentals).
//
// Manual "Add to calendar" was removed — schedule events are always derived
// from picks, working backwards from the bloom date.

public struct PlantingScheduleView: View {

    @EnvironmentObject private var store: GardenStore

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var showSow: Bool = true
    @State private var showTransplant: Bool = true
    @State private var showHarvest: Bool = true

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                filters
                monthGrid
                legend
                let evs = eventsInDisplayedMonth
                if evs.isEmpty {
                    emptyHint
                } else {
                    eventList(evs)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Planting schedule", icon: "🗓")
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text("🌱").font(.system(size: 32))
            Text("No events this month")
                .font(.custom("Fredoka-SemiBold", size: 14))
                .foregroundStyle(Color.bmText1)
            Text("Pick plants in the Plant Picker — sow, transplant, and harvest events will appear here, scheduled back from each bloom month.")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .bmCard()
    }

    private var eventsInDisplayedMonth: [ScheduledEvent] {
        let m = Calendar.current.component(.month, from: displayedMonth)
        return generatedEvents
            .filter { $0.month == m && isVisible($0.kind) }
            .sorted { ($0.day, $0.plantName) < ($1.day, $1.plantName) }
    }

    private func isVisible(_ kind: EventKind) -> Bool {
        switch kind {
        case .sow:        return showSow
        case .transplant: return showTransplant
        case .harvest:    return showHarvest
        }
    }

    private func eventList(_ events: [ScheduledEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Activities this month", icon: "📌")
            ForEach(events) { event in
                eventRow(event)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private func eventRow(_ event: ScheduledEvent) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(event.kind.color.opacity(0.2)).frame(width: 32, height: 32)
                Text(event.kind.emoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(event.kind.label) \(event.plantName)")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Text("For \(Self.monthName(event.bloomMonth)) bloom · start \(Self.dayLabel(month: event.month, day: event.day))")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static func dayLabel(month: Int, day: Int) -> String {
        "\(day) \(monthName(month))"
    }

    private static func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.shortMonthSymbols[m - 1]
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.bmText2)
                    .padding(8)
                    .background(Circle().fill(Color.white))
            }
            Spacer()
            Text(Self.monthYear(displayedMonth))
                .font(.custom("Fredoka-SemiBold", size: 18))
                .foregroundStyle(Color.bmText1)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.bmText2)
                    .padding(8)
                    .background(Circle().fill(Color.white))
            }
        }
        .padding(.horizontal, 8)
    }

    private var filters: some View {
        HStack(spacing: 8) {
            PillButton("🌱 Sow", isActive: showSow, color: .bmGreen) { showSow.toggle() }
            PillButton("🪴 Transplant", isActive: showTransplant, color: .bmLilac) { showTransplant.toggle() }
            PillButton("🧺 Harvest", isActive: showHarvest, color: .bmPeach) { showHarvest.toggle() }
            Spacer()
            Button("Today") { displayedMonth = Calendar.current.startOfMonth(for: Date()) }
                .font(.custom("Fredoka-SemiBold", size: 12))
                .foregroundStyle(Color.bmGreen)
        }
        .padding(.horizontal, 8)
    }

    private var monthGrid: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d)
                        .font(.custom("Fredoka-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                        .frame(maxWidth: .infinity)
                }
            }
            let cal = Calendar.current
            let days = cal.daysInGrid(forMonthStarting: displayedMonth)
            let m = cal.component(.month, from: displayedMonth)
            let eventsByDay = bucketedEvents(month: m)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dayCell(day: day, monthMatch: cal.component(.month, from: day) == m,
                            events: eventsByDay[cal.component(.day, from: day)] ?? [])
                }
            }
        }
        .padding(12)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    private func dayCell(day: Date, monthMatch: Bool, events: [EventKind]) -> some View {
        let dayNum = Calendar.current.component(.day, from: day)
        return VStack(spacing: 2) {
            Text("\(dayNum)")
                .font(.custom("Nunito-Bold", size: 11))
                .foregroundStyle(monthMatch ? Color.bmText1 : Color.bmText3)
            HStack(spacing: 2) {
                ForEach(events.prefix(3), id: \.self) { e in
                    Circle().fill(e.color).frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(monthMatch ? Color.bmBgSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendChip(color: .bmGreen,  label: "Sow")
            legendChip(color: .bmLilac,  label: "Transplant")
            legendChip(color: .bmPeach,  label: "Harvest")
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.custom("Nunito-Bold", size: 11))
                .foregroundStyle(Color.bmText2)
        }
    }

    // MARK: - Event derivation
    //
    // Events are derived from the user's bloom picks. For each (plant, bloom
    // month) pick we generate up to three events — sow / transplant / harvest —
    // pinning each to day 1 of the earliest applicable month. The sow date
    // works backwards from bloom by 12 weeks (≈ 3 months); transplant and
    // harvest use the plant's own earliest-month windows when present.

    fileprivate enum EventKind: Hashable {
        case sow, transplant, harvest
        var color: Color {
            switch self {
            case .sow:        return .bmGreen
            case .transplant: return .bmLilac
            case .harvest:    return .bmPeach
            }
        }
        var label: String {
            switch self {
            case .sow:        return "Sow"
            case .transplant: return "Transplant"
            case .harvest:    return "Harvest"
            }
        }
        var emoji: String {
            switch self {
            case .sow:        return "🌱"
            case .transplant: return "🪴"
            case .harvest:    return "🧺"
            }
        }
    }

    fileprivate struct ScheduledEvent: Identifiable, Hashable {
        let id: String          // deterministic so SwiftUI diffing stays stable
        let kind: EventKind
        let month: Int          // 1-12
        let day: Int            // 1 = start of window
        let plantId: String
        let plantName: String
        let bloomMonth: Int
    }

    fileprivate var generatedEvents: [ScheduledEvent] {
        var out: [ScheduledEvent] = []
        for bloomMonth in 1...12 {
            for plantId in store.picks(month: bloomMonth) {
                guard let plant = PlantLibrary.plant(id: plantId) else { continue }
                // Sow start: 12 weeks (~3 months) before bloom, wrapped 1...12.
                let sowMonth = ((bloomMonth - 3 - 1) % 12 + 12) % 12 + 1
                out.append(ScheduledEvent(
                    id: "sow|\(plantId)|\(bloomMonth)",
                    kind: .sow, month: sowMonth, day: 1,
                    plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth))
                if let t = plant.transplantMonths.min() {
                    out.append(ScheduledEvent(
                        id: "trans|\(plantId)|\(bloomMonth)",
                        kind: .transplant, month: t, day: 1,
                        plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth))
                }
                if let h = plant.harvestMonths.min() {
                    out.append(ScheduledEvent(
                        id: "harv|\(plantId)|\(bloomMonth)",
                        kind: .harvest, month: h, day: 1,
                        plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth))
                }
            }
        }
        return out
    }

    fileprivate func bucketedEvents(month: Int) -> [Int: [EventKind]] {
        var byDay: [Int: [EventKind]] = [:]
        for e in generatedEvents where e.month == month && isVisible(e.kind) {
            byDay[e.day, default: []].append(e.kind)
        }
        return byDay
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = Calendar.current.startOfMonth(for: d)
        }
    }

    private static func monthYear(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }
}

// MARK: - Calendar helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    /// 6 × 7 grid of Mondays-first days spanning the calendar month that
    /// `startOfMonth` belongs to.
    func daysInGrid(forMonthStarting startOfMonth: Date) -> [Date] {
        var cal = self
        cal.firstWeekday = 2 // Monday
        let weekday = cal.component(.weekday, from: startOfMonth) // 1=Sun, 2=Mon, ...
        let offset = ((weekday - cal.firstWeekday) + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -offset, to: startOfMonth) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
}
#endif
