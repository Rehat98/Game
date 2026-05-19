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
}
