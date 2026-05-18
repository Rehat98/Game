import XCTest
@testable import Pictok

final class UserStateStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.pictok.state"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_freshStore_returnsDefaultState() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(store.state.lives, 5)
        XCTAssertEqual(store.state.currentStreak, 0)
    }

    func test_save_persistsAcrossInstances() {
        let store1 = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store1.state.currentStreak = 5
        store1.save()

        let store2 = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(store2.state.currentStreak, 5)
    }

    func test_refillLives_addsOneHeartPerFourHours() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 2
        store.state.livesLastRefilledAt = t0

        // 4 hours later → +1 heart
        store.refillLives(now: t0.addingTimeInterval(4 * 3600))
        XCTAssertEqual(store.state.lives, 3)

        // 12 hours later (3 refills) but capped at 5
        store.refillLives(now: t0.addingTimeInterval(12 * 3600 + 1))
        XCTAssertEqual(store.state.lives, 5)
    }

    func test_refillLives_doesNothingWhenAlreadyMaxed() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 5
        store.refillLives(now: t0.addingTimeInterval(100 * 3600))
        XCTAssertEqual(store.state.lives, 5)
    }

    func test_refillLives_advancesAnchorByExactRefillCount() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 0
        store.state.livesLastRefilledAt = t0

        // 5 hours later → 1 refill, anchor advances by exactly 4h (not 5h),
        // so the next refill will fire after another 3 hours.
        let now1 = t0.addingTimeInterval(5 * 3600)
        store.refillLives(now: now1)
        XCTAssertEqual(store.state.lives, 1)
        XCTAssertEqual(store.state.livesLastRefilledAt, t0.addingTimeInterval(4 * 3600))
    }
}
