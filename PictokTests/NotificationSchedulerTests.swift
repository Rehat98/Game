import XCTest
@testable import Pictok

final class NotificationSchedulerTests: XCTestCase {

    final class MockCenter: NotificationCenterProtocol {
        var pending: [String] = []
        var added: [(id: String, components: DateComponents)] = []
        var removed: [String] = []

        func pendingIdentifiers() async -> [String] { pending }
        func add(identifier: String, components: DateComponents) async {
            pending.append(identifier)
            added.append((identifier, components))
        }
        func remove(identifier: String) async {
            pending.removeAll { $0 == identifier }
            removed.append(identifier)
        }
    }

    func test_schedulesTomorrow9amWhenNothingPending() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T15:30:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        XCTAssertEqual(mock.added.count, 1)
        let comps = mock.added.first!.components
        // The scheduled fire time is the next 9 AM in the device timezone (UTC here)
        // 2026-05-18T15:30 UTC → next 9 AM is 2026-05-19T09:00 UTC
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 19)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    func test_schedulesSameDay9amIfNotYetFired_andNotSolved() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        let comps = mock.added.first!.components
        XCTAssertEqual(comps.day, 18)  // today
        XCTAssertEqual(comps.hour, 9)
    }

    func test_skipsSchedulingForToday_ifAlreadySolved_andBefore9am() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: true)

        // Schedules tomorrow instead
        let comps = mock.added.first!.components
        XCTAssertEqual(comps.day, 19)
    }

    func test_doesNotDoubleSchedule_whenIdentifierAlreadyPending() async {
        let mock = MockCenter()
        mock.pending = [NotificationScheduler.dailyReminderIdentifier]
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        XCTAssertEqual(mock.added.count, 0)
    }

    func test_cancelTodaysReminder_removesPendingIdentifier() async {
        let mock = MockCenter()
        mock.pending = [NotificationScheduler.dailyReminderIdentifier]
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)

        await scheduler.cancelDailyReminder()

        XCTAssertEqual(mock.removed, [NotificationScheduler.dailyReminderIdentifier])
    }
}
