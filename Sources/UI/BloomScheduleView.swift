#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BloomScheduleView
//
// Two-year bloom calendar (current year from "today onward" + the whole of
// next year, so plants that need autumn sowing for spring bloom show up).
// Each month is a tappable chip; tapping opens a per-garden / per-bed sheet
// listing every pick for that month with a tap-through to PlantDetailView so
// the gardener can flip the pick state back off.

public struct BloomScheduleView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    @State private var sheetMonth: ScheduleMonth?
    @State private var showingAddReminder: Bool = false
    @State private var editingReminderId: UUID?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                remindersCard
                let cal = Calendar.current
                let now = Date()
                let thisYear = cal.component(.year, from: now)
                let thisMonth = cal.component(.month, from: now)
                yearSection(year: thisYear, startMonth: thisMonth)
                yearSection(year: thisYear + 1, startMonth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Bloom schedule", icon: "🌺")
        .sheet(item: $sheetMonth) { m in
            BloomMonthSheet(year: m.year, month: m.month)
                .environmentObject(store)
                .environmentObject(library)
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet(editingReminderId: nil)
                .environmentObject(store)
        }
        .sheet(item: Binding(
            get: { editingReminderId.map(ReminderIdHolder.init) },
            set: { editingReminderId = $0?.id })) { holder in
            AddReminderSheet(editingReminderId: holder.id)
                .environmentObject(store)
        }
    }

    // MARK: - Reminders card

    private var remindersCard: some View {
        let upcoming = store.customReminders
            .sorted { $0.date < $1.date }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel("My reminders", icon: "🔔")
                Tooltip("Reminders you've added here show up in the matching month below AND on the Home screen's Today's Tasks panel, so you can tick them off from either place.")
                Spacer()
                Button {
                    showingAddReminder = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add")
                            .font(.custom("Fredoka-SemiBold", size: 12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if upcoming.isEmpty {
                Text("No reminders yet. Tap + Add to drop one on the calendar.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
            } else {
                ForEach(upcoming) { reminder in
                    reminderRow(reminder: reminder)
                }
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
            Button {
                editingReminderId = reminder.id
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(done ? Color.bmText3 : Color.bmText1)
                        .strikethrough(done, color: Color.bmText3)
                    Text(reminder.date, style: .date)
                        .font(.custom("Nunito-SemiBold", size: 10))
                        .foregroundStyle(Color.bmText3)
                }
            }
            .buttonStyle(.plain)
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

    fileprivate struct ReminderIdHolder: Identifiable, Hashable { let id: UUID }

    // MARK: - Year section

    private func yearSection(year: Int, startMonth: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(year))
                .font(.custom("Fredoka-SemiBold", size: 20))
                .foregroundStyle(Color.bmText1)
                .padding(.leading, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(startMonth...12, id: \.self) { m in
                    monthChip(year: year, month: m)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func monthChip(year: Int, month: Int) -> some View {
        let count = monthPickCount(month: month)
        return Button {
            sheetMonth = ScheduleMonth(year: year, month: month)
        } label: {
            VStack(spacing: 4) {
                Text(Self.shortMonth(month))
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Text(count == 0 ? "—" : "\(count) plant\(count == 1 ? "" : "s")")
                    .font(.custom("Nunito-SemiBold", size: 10))
                    .foregroundStyle(count == 0 ? Color.bmText3 : Color.bmGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(count == 0 ? Color.bmBgSoft : Color.bmGreenLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(count == 0 ? Color.bmBorder : Color.bmGreen.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// Counts unique plants picked in a calendar month, resolved via the
    /// server library (with bundled fallback) so Wikipedia-ingested plants
    /// don't silently disappear.
    private func monthPickCount(month: Int) -> Int {
        store.picks(month: month).compactMap(library.plant(id:)).count
    }

    static func shortMonth(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.shortMonthSymbols[m - 1]
    }
}

// MARK: - ScheduleMonth identifier

public struct ScheduleMonth: Identifiable, Hashable {
    public let year: Int
    public let month: Int
    public var id: String { "\(year)-\(month)" }
}

// MARK: - BloomMonthSheet
//
// Per-month sheet: for Pro, list picks grouped by bed in the selected
// garden; for Free, a single garden-scoped list. Each pick taps through to
// PlantDetailView so the user can toggle the pick state back off.

struct BloomMonthSheet: View {
    let year: Int
    let month: Int

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.user.tier == .pro {
                        proSections
                    } else {
                        freeSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .bmSheetBackdrop()
            .bmNavTitle("\(monthName(month)) \(year)", icon: "🌺")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
        }
    }

    // MARK: - Pro: per-bed grouping

    @ViewBuilder
    private var proSections: some View {
        let beds = store.bedsInSelectedGarden
        if beds.isEmpty {
            emptyState
        } else {
            ForEach(beds) { bed in
                let plants = store.picks(month: month, bedId: bed.id).compactMap(library.plant(id:))
                bedSection(bed: bed, plants: plants)
            }
            if beds.allSatisfy({ store.picks(month: month, bedId: $0.id).isEmpty }) {
                emptyState
            }
        }
    }

    private func bedSection(bed: Bed, plants: [Plant]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(Color.bmGreen)
                Text(bed.name)
                    .font(.custom("Fredoka-SemiBold", size: 15))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text("\(plants.count)")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
                NavigationLink {
                    BedDetailView(bedId: bed.id)
                        .environmentObject(store)
                        .environmentObject(library)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Edit bed")
                            .font(.custom("Fredoka-SemiBold", size: 11))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                // Stash the bloom-month context so when the gardener
                // drills Edit Bed → Add Plant → Plant Detail, the
                // Add-to-Plan card pre-fills with this month. The user
                // can save straight away without re-picking months.
                .simultaneousGesture(TapGesture().onEnded {
                    store.contextBloomMonths = [month]
                })
            }
            if plants.isEmpty {
                Text("No picks for this bed in \(monthName(month)).")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
            } else {
                ForEach(plants) { p in
                    pickRow(p)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    // MARK: - Free: single garden list

    @ViewBuilder
    private var freeSection: some View {
        let plants = store.picks(month: month).compactMap(library.plant(id:))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.bmGreen)
                Text(store.selectedGarden?.name ?? "Garden")
                    .font(.custom("Fredoka-SemiBold", size: 15))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text("\(plants.count)")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            if plants.isEmpty {
                emptyState
            } else {
                ForEach(plants) { p in
                    pickRow(p)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func pickRow(_ plant: Plant) -> some View {
        NavigationLink {
            PlantDetailView(plantId: plant.id)
                .environmentObject(store)
                .environmentObject(library)
        } label: {
            HStack(spacing: 10) {
                BMPlantImage(plant: plant, height: 44, cornerRadius: 10)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 1) {
                    Text(plant.name)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text(plant.latin)
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .italic()
                        .foregroundStyle(Color.bmText2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bmText3)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bmBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🌱").font(.system(size: 28))
            Text("No picks yet for \(monthName(month))")
                .font(.custom("Fredoka-SemiBold", size: 14))
                .foregroundStyle(Color.bmText1)
            Text("Open Plant Picker, choose a plant, and tap \(monthName(month)) on its detail screen to add it here.")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText2)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .bmCard()
    }

    private func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.monthSymbols[m - 1]
    }
}

// MARK: - AddReminderSheet
//
// Compact form for adding or editing a gardener-authored reminder.
// Reminders are stored on GardenStore.customReminders and surfaced on
// Home's Today's Tasks card (current-month only) plus the Bloom Planner
// (always).

struct AddReminderSheet: View {
    let editingReminderId: UUID?
    /// Optional date to pre-fill — used by PlantingScheduleView's
    /// DayDetailSheet so tapping a calendar day and then "Add reminder"
    /// drops the gardener straight on that date instead of "today".
    let initialDate: Date?

    @EnvironmentObject private var store: GardenStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var bedScope: BedScope = .anyGarden

    init(editingReminderId: UUID?, initialDate: Date? = nil) {
        self.editingReminderId = editingReminderId
        self.initialDate = initialDate
    }

    enum BedScope: Hashable {
        case anyGarden
        case bed(UUID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's the reminder?")
                            .font(.custom("Nunito-Bold", size: 13))
                            .foregroundStyle(Color.bmText1)
                        TextField("Net the brassicas", text: $title)
                            .font(.custom("Nunito-SemiBold", size: 14))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.bmBgSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.bmBorder, lineWidth: 1))
                    }

                    DatePicker("When", selection: $date,
                               displayedComponents: .date)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                        .tint(Color.bmGreen)

                    if !store.beds.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pin to a bed (optional)")
                                .font(.custom("Nunito-Bold", size: 13))
                                .foregroundStyle(Color.bmText1)
                            Picker("Bed", selection: $bedScope) {
                                Text("All gardens").tag(BedScope.anyGarden)
                                ForEach(store.beds) { bed in
                                    Text("\(bed.name) (\(store.garden(id: bed.gardenId)?.name ?? ""))")
                                        .tag(BedScope.bed(bed.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.bmGreen)
                        }
                    }

                    Button {
                        save()
                    } label: {
                        Text(editingReminderId == nil ? "Add reminder" : "Save changes")
                            .font(.custom("Fredoka-SemiBold", size: 14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(canSave ? Color.bmGreen : Color.bmGreenMid)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .bmSheetBackdrop()
            .bmNavTitle(editingReminderId == nil ? "New reminder" : "Edit reminder", icon: "🔔")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
            .onAppear { loadIfEditing() }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadIfEditing() {
        if let id = editingReminderId,
           let existing = store.customReminders.first(where: { $0.id == id }) {
            title = existing.title
            date = existing.date
            bedScope = existing.bedId.map(BedScope.bed) ?? .anyGarden
        } else if let seed = initialDate {
            // Fresh-create with a pre-filled date (DayDetailSheet path).
            date = seed
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bedId: UUID? = {
            if case .bed(let id) = bedScope { return id }
            return nil
        }()
        if let id = editingReminderId,
           let existing = store.customReminders.first(where: { $0.id == id }) {
            var updated = existing
            updated.title = trimmed
            updated.date = date
            updated.bedId = bedId
            store.updateReminder(updated)
        } else {
            store.addReminder(CustomReminder(
                title: trimmed,
                date: date,
                bedId: bedId
            ))
        }
        dismiss()
    }
}
#endif
