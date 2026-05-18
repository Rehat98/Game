import Foundation
import UserNotifications

protocol NotificationCenterProtocol {
    func pendingIdentifiers() async -> [String]
    func add(identifier: String, components: DateComponents) async
    func remove(identifier: String) async
}

/// Real UNUserNotificationCenter adapter.
struct UNNotificationCenterAdapter: NotificationCenterProtocol {
    let title = "Your puzzle is ready 📌"
    let body  = "Keep your streak going 🔥 — today's emoji decode awaits."

    func pendingIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }

    func add(identifier: String, components: DateComponents) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func remove(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }
}

struct NotificationScheduler {
    static let dailyReminderIdentifier = "pictok.daily-reminder"
    private static let fireHour = 9

    let center: NotificationCenterProtocol
    let calendar: Calendar
    let timeZone: TimeZone

    init(center: NotificationCenterProtocol = UNNotificationCenterAdapter(),
         calendar: Calendar = Calendar(identifier: .gregorian),
         timeZone: TimeZone = .current) {
        self.center = center
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }

    /// Schedule the next 9 AM reminder. If `alreadySolvedToday` is true, skip
    /// today's notification and schedule tomorrow's.
    func scheduleDailyReminderIfNeeded(now: Date, alreadySolvedToday: Bool) async {
        let pending = await center.pendingIdentifiers()
        guard !pending.contains(Self.dailyReminderIdentifier) else { return }

        let fireDate = nextFireDate(after: now, skipTodayBecauseSolved: alreadySolvedToday)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                            from: fireDate)
        await center.add(identifier: Self.dailyReminderIdentifier, components: comps)
    }

    func cancelDailyReminder() async {
        await center.remove(identifier: Self.dailyReminderIdentifier)
    }

    /// Returns the next 9 AM moment that should fire. If today's 9 AM is still
    /// in the future AND the user hasn't already solved, fire today; otherwise tomorrow.
    private func nextFireDate(after now: Date, skipTodayBecauseSolved: Bool) -> Date {
        let todayAt9 = calendar.date(bySettingHour: Self.fireHour, minute: 0, second: 0, of: now)!
        if !skipTodayBecauseSolved && now < todayAt9 {
            return todayAt9
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAt9)!
    }
}
