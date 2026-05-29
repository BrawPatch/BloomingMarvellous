#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantingScheduleView
//
// Wireframe: Planting Schedule (Calendar). Month grid with event markers
// derived from the picked plants' sow / transplant / harvest windows.
// A future /v1/gardens/{id}/events endpoint will replace the derivation
// with real persisted events.

public struct PlantingScheduleView: View {

    @EnvironmentObject private var store: GardenStore

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var showSow: Bool = true
    @State private var showTransplant: Bool = true
    @State private var showHarvest: Bool = true
    @State private var events: [GardenEvent] = []
    @State private var showingAddEvent: Bool = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bmBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    filters
                    monthGrid
                    legend
                    if !eventsInDisplayedMonth.isEmpty {
                        eventList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, 80)
            }

            fab
        }
        .navigationTitle("Planting schedule")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddEvent) {
            AddEventView { newEvent in
                events.append(newEvent)
                displayedMonth = Calendar.current.startOfMonth(for: newEvent.date)
            }
        }
    }

    private var fab: some View {
        Button {
            showingAddEvent = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add to calendar")
                    .font(.custom("Fredoka-SemiBold", size: 14))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Color.bmGreen)
            .clipShape(Capsule())
            .shadow(color: Color.bmGreen.opacity(0.35), radius: 8, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private var eventsInDisplayedMonth: [GardenEvent] {
        let cal = Calendar.current
        return events
            .filter { cal.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
            .sorted { $0.date < $1.date }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Scheduled events", icon: "📌")
            ForEach(eventsInDisplayedMonth) { event in
                eventRow(event)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private func eventRow(_ event: GardenEvent) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(event.kind.color.opacity(0.2)).frame(width: 32, height: 32)
                Text(event.kind.emoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(event.kind.label)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    if let bedId = event.bedId, let bed = store.bed(id: bedId) {
                        Text("· \(bed.name)")
                            .font(.custom("Nunito-SemiBold", size: 11))
                            .foregroundStyle(Color.bmText2)
                    }
                }
                Text(Self.dayLabel(event.date))
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
            }
            Spacer()
            Button {
                events.removeAll { $0.id == event.id }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.bmRed)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM"
        return f.string(from: d)
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
    // Until the backend exposes /v1/gardens/{id}/events, we synthesise
    // markers by reading the picked plants' sow / transplant / harvest
    // windows: any day in the displayed month that belongs to one of
    // those windows surfaces a coloured dot. The day number itself is
    // arbitrary — the picker view will land first; an Add Event flow
    // can later choose real dates.

    private enum EventKind: Hashable {
        case sow, transplant, harvest
        var color: Color {
            switch self {
            case .sow:        return .bmGreen
            case .transplant: return .bmLilac
            case .harvest:    return .bmPeach
            }
        }
    }

    private func bucketedEvents(month: Int) -> [Int: [EventKind]] {
        var byDay: [Int: [EventKind]] = [:]
        let plants = (1...12).flatMap { store.picks(month: $0).compactMap(PlantLibrary.plant(id:)) }
        // De-dup by id to avoid double counting picks across multiple bloom months.
        let unique = Array(Set(plants.map(\.id))).compactMap(PlantLibrary.plant(id:))

        for plant in unique {
            if showSow {
                if plant.sowIndoorMonths.contains(month) { byDay[5, default: []].append(.sow) }
                if plant.sowDirectMonths.contains(month) { byDay[12, default: []].append(.sow) }
            }
            if showTransplant, plant.transplantMonths.contains(month) {
                byDay[20, default: []].append(.transplant)
            }
            if showHarvest, plant.harvestMonths.contains(month) {
                byDay[26, default: []].append(.harvest)
            }
        }

        // Overlay user-added events on their actual day.
        let cal = Calendar.current
        for event in events where cal.component(.month, from: event.date) == month
            && cal.component(.year, from: event.date) == cal.component(.year, from: displayedMonth) {
            let day = cal.component(.day, from: event.date)
            let kind: EventKind?
            switch event.kind {
            case .sow:        kind = showSow        ? .sow        : nil
            case .transplant: kind = showTransplant ? .transplant : nil
            case .harvest:    kind = showHarvest    ? .harvest    : nil
            case .water, .fertilise: kind = nil // legend doesn't cover these dots — surfaced in event list below
            }
            if let k = kind { byDay[day, default: []].append(k) }
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
