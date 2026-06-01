import Foundation

// MARK: - ScheduleTask
//
// Storage-shaped value carried between the schedule view, the
// NotificationScheduler, and the CalendarSyncService. `id` is the same
// identifier used by `GardenStore.completedTaskIds`, so toggling a task
// done cleanly cancels the matching push reminder and prevents a
// duplicate calendar event.
//
// Months are 1-indexed; `day` defaults to 1 (start of window) to match
// the original Planting Schedule contract.

public struct ScheduleTask: Hashable, Identifiable {
    public let id: String
    public let title: String        // notification title — usually "Sow Lavender"
    public let body: String         // longer copy used by both push + calendar
    public let month: Int           // 1...12
    public let day: Int             // 1 = start of window

    public init(id: String, title: String, body: String, month: Int, day: Int = 1) {
        self.id = id
        self.title = title
        self.body = body
        self.month = month
        self.day = day
    }
}
