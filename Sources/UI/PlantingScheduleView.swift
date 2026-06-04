#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantingScheduleView
//
// Phase 6: the schedule now spans every garden and bed by default. The
// filter bar (ScheduleFilterBar) lets the gardener narrow by task kind,
// garden, or bed, all multi-select. Empty selections mean "everything".
//
// Event derivation rules (unchanged from the original brief):
//   • Sow event = (bloom month – 12 weeks), day 1. Marker sits at the
//     START of the 8–12 week sowing window so gardeners don't miss it.
//   • Transplant event = earliest month in the plant's transplantMonths,
//     day 1. Skipped when the plant has no transplant guidance.
//   • Harvest event = earliest month in the plant's harvestMonths,
//     day 1. Skipped when the plant has no harvest guidance.

public struct PlantingScheduleView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var filters = ScheduleFilters()
    @State private var selectedDay: DayPickToken?

    fileprivate struct DayPickToken: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    @AppStorage("bm.notif.pushOn")          private var pushNotificationsOn: Bool = false
    @AppStorage("bm.notif.icalOn")          private var icalCalendarOn: Bool = false
    @AppStorage("bm.settings.reminderTime") private var reminderTimeRaw: Double = 0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                ScheduleFilterBar(filters: $filters,
                                  gardens: store.gardens,
                                  beds: store.beds,
                                  showKinds: true)
                    .padding(.horizontal, 4)
                HStack {
                    if pushNotificationsOn || icalCalendarOn {
                        Button {
                            Task { await syncAll() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Sync reminders")
                                    .font(.custom("Fredoka-SemiBold", size: 12))
                            }
                            .foregroundStyle(Color.bmGreen)
                        }
                    }
                    Spacer()
                    Button("Today") { displayedMonth = Calendar.current.startOfMonth(for: Date()) }
                        .font(.custom("Fredoka-SemiBold", size: 12))
                        .foregroundStyle(Color.bmGreen)
                }
                .padding(.horizontal, 4)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .plantingSchedule)
            }
        }
        .sheet(item: $selectedDay) { token in
            DayDetailSheet(day: token.date,
                           events: events(on: token.date),
                           reminders: store.customReminders.filter {
                               Calendar.current.isDate($0.date, inSameDayAs: token.date)
                           })
                .environmentObject(store)
                .environmentObject(library)
        }
    }

    fileprivate func events(on day: Date) -> [ScheduledEvent] {
        let cal = Calendar.current
        let m = cal.component(.month, from: day)
        let d = cal.component(.day, from: day)
        return generatedEvents.filter {
            $0.month == m && $0.day == d && passes($0)
        }
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
            .filter { $0.month == m && passes($0) }
            .sorted { ($0.day, $0.plantName) < ($1.day, $1.plantName) }
    }

    private func passes(_ event: ScheduledEvent) -> Bool {
        filters.includes(kind: event.kind)
            && filters.includes(gardenId: event.gardenId)
            && filters.includes(bedId: event.bedId)
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
        let done = store.isTaskDone(id: event.id)
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(event.kind.color.opacity(done ? 0.08 : 0.2))
                    .frame(width: 32, height: 32)
                Text(event.kind.emoji)
                    .font(.system(size: 16))
                    .opacity(done ? 0.4 : 1)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(event.kind.label) \(event.plantName)")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(done ? Color.bmText3 : Color.bmText1)
                    .strikethrough(done)
                Text("For \(Self.monthName(event.bloomMonth)) bloom · start \(Self.dayLabel(month: event.month, day: event.day))")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
                Text(scopeLabel(event))
                    .font(.custom("Nunito-SemiBold", size: 10))
                    .foregroundStyle(Color.bmText3)
            }
            Spacer()
            Button {
                toggleDone(event)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(done ? Color.bmGreen : Color.bmText3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark not done" : "Mark done")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toggleDone(_ event: ScheduledEvent) {
        if store.isTaskDone(id: event.id) {
            store.markTaskNotDone(id: event.id)
            // Re-schedule push for this one when push is on.
            if pushNotificationsOn {
                Task { await syncAll() }
            }
        } else {
            store.markTaskDone(id: event.id)
            if pushNotificationsOn {
                NotificationScheduler.shared.cancel(taskId: event.id)
            }
        }
    }

    private func scopeLabel(_ event: ScheduledEvent) -> String {
        if let bed = event.bedName {
            return "\(event.gardenName) · \(bed)"
        }
        return event.gardenName
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
                    Button {
                        selectedDay = DayPickToken(date: day)
                    } label: {
                        dayCell(day: day, monthMatch: cal.component(.month, from: day) == m,
                                events: eventsByDay[cal.component(.day, from: day)] ?? [])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    private func dayCell(day: Date, monthMatch: Bool, events: [ScheduleTaskKind]) -> some View {
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
    // Events span every garden and every bed. On Free tier the picks live
    // at the garden level (`bloomPicks`); on Pro they live per-bed
    // (`bedPicks`). The struct carries gardenId / bedId so the filter
    // bar can scope freely.

    struct ScheduledEvent: Identifiable, Hashable {
        let id: String
        let kind: ScheduleTaskKind
        let month: Int          // 1-12
        let day: Int            // 1 = start of window
        let plantId: String
        let plantName: String
        let bloomMonth: Int
        let gardenId: UUID
        let gardenName: String
        let bedId: UUID?        // nil on Free tier
        let bedName: String?
    }

    fileprivate var generatedEvents: [ScheduledEvent] {
        switch store.user.tier {
        case .free: return freeTierEvents()
        case .pro:  return proTierEvents()
        }
    }

    private func freeTierEvents() -> [ScheduledEvent] {
        var out: [ScheduledEvent] = []
        for garden in store.gardens {
            for bloomMonth in 1...12 {
                for plantId in store.picks(month: bloomMonth, gardenId: garden.id) {
                    out.append(contentsOf: events(forPlant: plantId,
                                                  bloomMonth: bloomMonth,
                                                  garden: garden,
                                                  bed: nil))
                }
            }
        }
        return out
    }

    private func proTierEvents() -> [ScheduledEvent] {
        var out: [ScheduledEvent] = []
        for bed in store.beds {
            guard let garden = store.garden(id: bed.gardenId) else { continue }
            for bloomMonth in 1...12 {
                for plantId in store.picks(month: bloomMonth, bedId: bed.id) {
                    out.append(contentsOf: events(forPlant: plantId,
                                                  bloomMonth: bloomMonth,
                                                  garden: garden,
                                                  bed: bed))
                }
            }
        }
        return out
    }

    private func events(forPlant plantId: String,
                        bloomMonth: Int,
                        garden: Garden,
                        bed: Bed?) -> [ScheduledEvent] {
        guard let plant = library.plant(id: plantId) else { return [] }
        let scopeId = bed?.id.uuidString ?? garden.id.uuidString
        var out: [ScheduledEvent] = []

        let sowMonth = ((bloomMonth - 3 - 1) % 12 + 12) % 12 + 1
        out.append(ScheduledEvent(
            id: "sow|\(plantId)|\(bloomMonth)|\(scopeId)",
            kind: .sow, month: sowMonth, day: 1,
            plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
            gardenId: garden.id, gardenName: garden.name,
            bedId: bed?.id, bedName: bed?.name))

        if let t = plant.transplantMonths.min() {
            out.append(ScheduledEvent(
                id: "trans|\(plantId)|\(bloomMonth)|\(scopeId)",
                kind: .transplant, month: t, day: 1,
                plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
                gardenId: garden.id, gardenName: garden.name,
                bedId: bed?.id, bedName: bed?.name))
        }
        if let h = plant.harvestMonths.min() {
            out.append(ScheduledEvent(
                id: "harv|\(plantId)|\(bloomMonth)|\(scopeId)",
                kind: .harvest, month: h, day: 1,
                plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
                gardenId: garden.id, gardenName: garden.name,
                bedId: bed?.id, bedName: bed?.name))
        }
        return out
    }

    fileprivate func bucketedEvents(month: Int) -> [Int: [ScheduleTaskKind]] {
        var byDay: [Int: [ScheduleTaskKind]] = [:]
        for e in generatedEvents where e.month == month && passes(e) {
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

    // MARK: - Phase 7: sync helpers

    private func tasksForSync() -> [ScheduleTask] {
        generatedEvents.map { event in
            ScheduleTask(
                id: event.id,
                title: "\(event.kind.label) \(event.plantName)",
                body: "For \(Self.monthName(event.bloomMonth)) bloom — \(scopeLabel(event))",
                month: event.month,
                day: event.day)
        }
    }

    private func reminderHourMinute() -> (Int, Int) {
        let date = reminderTimeRaw > 0
            ? Date(timeIntervalSince1970: reminderTimeRaw)
            : Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 8, comps.minute ?? 0)
    }

    @MainActor
    private func syncAll() async {
        let tasks = tasksForSync()
        let completed = store.completedTaskIds
        let (h, m) = reminderHourMinute()
        if pushNotificationsOn {
            await NotificationScheduler.shared.sync(tasks: tasks,
                                                    completedIds: completed,
                                                    reminderHour: h,
                                                    reminderMinute: m)
        }
        if icalCalendarOn {
            await CalendarSyncService.shared.sync(tasks: tasks,
                                                  completedIds: completed)
        }
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

// MARK: - DayDetailSheet
//
// Opened by tapping a day cell on the Planting Schedule calendar. Lists
// the day's auto-generated sow/transplant/harvest tasks alongside any
// custom reminders the gardener has set for that date, and offers a "+
// Add reminder" button that pre-fills the date in AddReminderSheet so
// the gardener doesn't have to re-pick it.

struct DayDetailSheet: View {
    let day: Date
    let events: [PlantingScheduleView.ScheduledEvent]
    let reminders: [CustomReminder]

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var showingAddReminder: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if events.isEmpty && reminders.isEmpty {
                        emptyState
                    } else {
                        if !reminders.isEmpty {
                            remindersSection
                        }
                        if !events.isEmpty {
                            eventsSection
                        }
                    }
                    addReminderButton
                }
                .padding(20)
            }
            .bmSheetBackdrop()
            .bmNavTitle(headerTitle, icon: "🗓")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderSheet(editingReminderId: nil, initialDate: day)
                    .environmentObject(store)
            }
        }
    }

    private var headerTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: day)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerTitle)
                .font(.custom("Fredoka-SemiBold", size: 18))
                .foregroundStyle(Color.bmText1)
            Text(eventsSummary)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText3)
        }
    }

    private var eventsSummary: String {
        let total = events.count + reminders.count
        if total == 0 { return "No tasks scheduled. Add one below." }
        if total == 1 { return "1 task on this day." }
        return "\(total) tasks on this day."
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing scheduled for this day yet.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
            Text("Tap +Add reminder below to drop one on this date.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("My reminders", icon: "🔔")
            ForEach(reminders) { reminder in
                reminderRow(reminder: reminder)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func reminderRow(reminder: CustomReminder) -> some View {
        let done = store.isTaskDone(id: reminder.taskId)
        return HStack(spacing: 10) {
            Button {
                if done { store.markTaskNotDone(id: reminder.taskId) }
                else    { store.markTaskDone(id: reminder.taskId) }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(done ? Color.bmGreen : Color.bmText3)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(done ? Color.bmText3 : Color.bmText1)
                    .strikethrough(done, color: Color.bmText3)
                if let bedId = reminder.bedId,
                   let bed = store.bed(id: bedId),
                   let garden = store.garden(id: bed.gardenId) {
                    Text("\(garden.name) · \(bed.name)")
                        .font(.custom("Nunito-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                }
            }
            Spacer()
            Button {
                store.deleteReminder(id: reminder.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bmRed)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Scheduled tasks", icon: "🌱")
            ForEach(events) { event in
                eventRow(event: event)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func eventRow(event: PlantingScheduleView.ScheduledEvent) -> some View {
        let done = store.isTaskDone(id: event.id)
        return Button {
            if done { store.markTaskNotDone(id: event.id) }
            else    { store.markTaskDone(id: event.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(done ? Color.bmGreen : Color.bmText3)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(event.kind.emoji)
                        Text(event.kind.label.uppercased())
                            .font(.custom("Fredoka-SemiBold", size: 10))
                            .foregroundStyle(Color.bmText2)
                            .kerning(0.4)
                    }
                    Text(event.plantName)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(done ? Color.bmText3 : Color.bmText1)
                        .strikethrough(done, color: Color.bmText3)
                    Text(event.bedName.map { "\(event.gardenName) · \($0)" } ?? event.gardenName)
                        .font(.custom("Nunito-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var addReminderButton: some View {
        Button {
            showingAddReminder = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Add reminder for this day")
                    .font(.custom("Fredoka-SemiBold", size: 14))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.bmGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
#endif
