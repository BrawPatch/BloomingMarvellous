#if canImport(UserNotifications)
import Foundation
import UserNotifications

// MARK: - NotificationScheduler
//
// Phase 7 wiring for daily-repeating local notifications. Per the
// product brief: every planting-schedule entry gets a notification that
// fires daily at the user's preferred time and only stops when the user
// ticks the task done in-app (the `completedTaskIds` set on
// GardenStore). No APNs, no server — pure on-device `UNCalendarNotification`.
//
// The scheduler is intentionally `final class` (not actor) because all
// of its methods either await UN's own concurrency-safe APIs or simply
// call them; concurrent calls from the same call site are not expected.

public final class NotificationScheduler {

    public static let shared = NotificationScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Request alerts + sound + badge. Returns the granted state. The
    /// caller should reflect a false result back into the Settings
    /// toggle so the user knows the OS denied the prompt.
    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Returns the current authorization status without prompting.
    public func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            center.getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// Sync every task into the OS: schedule daily-repeating
    /// notifications for the tasks still pending, cancel anything that
    /// belongs to a completed task. Idempotent — re-running with the
    /// same input replaces previous registrations using the deterministic
    /// task id as the request identifier.
    public func sync(tasks: [ScheduleTask],
                     completedIds: Set<String>,
                     reminderHour: Int,
                     reminderMinute: Int) async {
        // Pull the current set of pending IDs so we can prune anything
        // the user has since deleted or marked done.
        let pendingIds = await pendingIdentifiers()
        var keep: Set<String> = []

        for task in tasks where !completedIds.contains(task.id) {
            keep.insert(task.id)
            scheduleDaily(task: task, hour: reminderHour, minute: reminderMinute)
        }

        let toCancel = pendingIds.subtracting(keep)
            .union(completedIds.intersection(pendingIds))
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
            center.removeDeliveredNotifications(withIdentifiers: Array(toCancel))
        }
    }

    public func cancel(taskId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId])
        center.removeDeliveredNotifications(withIdentifiers: [taskId])
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private

    private func scheduleDaily(task: ScheduleTask, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.body
        content.sound = .default

        // Daily repeat in the user's preferred reminder window. UN doesn't
        // expose "daily until I tell you to stop" directly — we use
        // `repeats: true` + cancel-on-done to model it.
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: task.id,
                                            content: content,
                                            trigger: trigger)
        center.add(request) { _ in /* silent — UI surfaces failure via authorization status */ }
    }

    private func pendingIdentifiers() async -> Set<String> {
        await withCheckedContinuation { cont in
            center.getPendingNotificationRequests { reqs in
                cont.resume(returning: Set(reqs.map(\.identifier)))
            }
        }
    }
}
#endif
