#if canImport(EventKit)
import Foundation
import EventKit

// MARK: - CalendarSyncService
//
// Phase 7's iCal half. The brief is "one event per task, written to the
// user's default calendar; no daily repeat (only push repeats)". We
// keep a local @AppStorage-backed map of `taskId → EKEvent.eventIdentifier`
// so re-syncing the same task doesn't spawn duplicates — the existing
// event is updated in place.

public final class CalendarSyncService {

    public static let shared = CalendarSyncService()
    private init() {}

    private let store = EKEventStore()
    private let mapKey = "bm.cal.syncedTaskMap"

    /// Request write-only access on iOS 17+. Older iOS uses the legacy
    /// `requestAccess(to:)`. Returns whether access is granted.
    @discardableResult
    public func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await store.requestWriteOnlyAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    public func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Add or update one event per pending task in the calendar. Tasks
    /// the user has marked done are pulled back out of the calendar.
    public func sync(tasks: [ScheduleTask],
                     completedIds: Set<String>,
                     calendarTitle: String = "Blooming Marvellous") async {
        guard isAuthorizedForWrite() else { return }
        var map = loadMap()
        let calendar = ensureCalendar(named: calendarTitle)

        for task in tasks {
            if completedIds.contains(task.id) {
                removeEvent(taskId: task.id, map: &map)
                continue
            }
            upsertEvent(task: task, calendar: calendar, map: &map)
        }

        // Tasks that no longer exist but are still in our map → remove.
        let currentIds = Set(tasks.map(\.id))
        for taskId in map.keys where !currentIds.contains(taskId) {
            removeEvent(taskId: taskId, map: &map)
        }

        saveMap(map)
    }

    public func cancelAll() {
        var map = loadMap()
        for (taskId, _) in map { removeEvent(taskId: taskId, map: &map) }
        saveMap(map)
    }

    // MARK: - Private

    private func isAuthorizedForWrite() -> Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus() == .writeOnly || authorizationStatus() == .fullAccess
        }
        return authorizationStatus() == .authorized
    }

    private func ensureCalendar(named title: String) -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == title }) {
            return existing
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = title
        cal.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first
        do { try store.saveCalendar(cal, commit: true) } catch { /* fall through */ }
        return cal
    }

    private func upsertEvent(task: ScheduleTask,
                             calendar: EKCalendar,
                             map: inout [String: String]) {
        let (start, end) = dateRange(for: task)
        let event: EKEvent
        if let existingId = map[task.id], let found = store.event(withIdentifier: existingId) {
            event = found
        } else {
            event = EKEvent(eventStore: store)
        }
        event.title = task.title
        event.notes = task.body
        event.startDate = start
        event.endDate = end
        event.isAllDay = true
        event.calendar = calendar
        do {
            try store.save(event, span: .thisEvent, commit: true)
            map[task.id] = event.eventIdentifier
        } catch {
            // Silent — the Settings toggle stays on, but the sync attempt
            // failed (likely because the user revoked access).
        }
    }

    private func removeEvent(taskId: String, map: inout [String: String]) {
        guard let eventId = map[taskId],
              let event = store.event(withIdentifier: eventId) else {
            map.removeValue(forKey: taskId)
            return
        }
        try? store.remove(event, span: .thisEvent, commit: true)
        map.removeValue(forKey: taskId)
    }

    /// First occurrence of the task in the user's calendar — current
    /// year if the month is still ahead, next year otherwise.
    private func dateRange(for task: ScheduleTask) -> (Date, Date) {
        var cal = Calendar.current
        cal.timeZone = .current
        let now = Date()
        let nowComps = cal.dateComponents([.year, .month], from: now)
        let year: Int = {
            let currentYear = nowComps.year ?? 2026
            let currentMonth = nowComps.month ?? 1
            if task.month < currentMonth { return currentYear + 1 }
            return currentYear
        }()

        var startComps = DateComponents()
        startComps.year = year
        startComps.month = task.month
        startComps.day = task.day
        let start = cal.date(from: startComps) ?? now
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    // MARK: - Persisted task→event map

    private func loadMap() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: mapKey),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    private func saveMap(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: mapKey)
    }
}
#endif
