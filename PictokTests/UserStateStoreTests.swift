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

    // MARK: - recordArchiveOutcome

    func test_recordArchiveOutcome_solved_updatesLifetimeFields() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.state.currentStreak = 3
        store.state.longestStreak = 5
        store.state.lastSolvedDate = "2026-05-15"
        store.state.streakFreezesAvailable = 1

        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: true,
                                   wrongGuesses: 2,
                                   hintUsed: false,
                                   date: "2026-05-10")

        XCTAssertTrue(store.state.solvedPuzzleIds.contains("puzzle-010"))
        XCTAssertEqual(store.state.totalSolved, 1)
        XCTAssertEqual(store.state.totalPlayed, 1)
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
        XCTAssertEqual(store.state.guessDistribution[2], 1)
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-10" && $0.result == .solved
        }))
    }

    func test_recordArchiveOutcome_perfectRun_recordsAsPerfect() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.recordArchiveOutcome(puzzleId: "puzzle-011",
                                   solved: true,
                                   wrongGuesses: 0,
                                   hintUsed: false,
                                   date: "2026-05-11")
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-11" && $0.result == .perfect
        }))
    }

    func test_recordArchiveOutcome_solvedWithHint_recordsAsSolvedNotPerfect() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.recordArchiveOutcome(puzzleId: "puzzle-012",
                                   solved: true,
                                   wrongGuesses: 0,
                                   hintUsed: true,
                                   date: "2026-05-12")
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-12" && $0.result == .solved
        }))
    }

    func test_recordArchiveOutcome_failed_updatesFailedSetAndHistory() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.recordArchiveOutcome(puzzleId: "puzzle-013",
                                   solved: false,
                                   wrongGuesses: 5,
                                   hintUsed: false,
                                   date: "2026-05-13")

        XCTAssertTrue(store.state.failedPuzzleIds.contains("puzzle-013"))
        XCTAssertEqual(store.state.totalPlayed, 1)
        XCTAssertEqual(store.state.totalSolved, 0)
        XCTAssertEqual(store.state.lifetimeSolvedCount, 0)
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-13" && $0.result == .failed
        }))
    }

    func test_recordArchiveOutcome_neverChangesStreakFields() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.state.currentStreak = 7
        store.state.longestStreak = 12
        store.state.lastSolvedDate = "2026-05-21"
        store.state.streakFreezesAvailable = 1
        let beforeStreak = store.state.currentStreak
        let beforeLongest = store.state.longestStreak
        let beforeLast = store.state.lastSolvedDate
        let beforeFreezes = store.state.streakFreezesAvailable

        store.recordArchiveOutcome(puzzleId: "puzzle-009",
                                   solved: true,
                                   wrongGuesses: 1,
                                   hintUsed: false,
                                   date: "2026-05-09")
        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: false,
                                   wrongGuesses: 5,
                                   hintUsed: true,
                                   date: "2026-05-10")

        XCTAssertEqual(store.state.currentStreak, beforeStreak)
        XCTAssertEqual(store.state.longestStreak, beforeLongest)
        XCTAssertEqual(store.state.lastSolvedDate, beforeLast)
        XCTAssertEqual(store.state.streakFreezesAvailable, beforeFreezes)
    }

    func test_recordArchiveOutcome_replacesAnyExistingHistoryEntryForDate() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.state.solveHistory = [SolveRecord(date: "2026-05-10", result: .failed)]

        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: true,
                                   wrongGuesses: 0,
                                   hintUsed: false,
                                   date: "2026-05-10")

        let matches = store.state.solveHistory.filter { $0.date == "2026-05-10" }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.result, .perfect)
    }

    func test_recordArchiveOutcome_idempotentForSamePuzzleId() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })

        // First solve — counters go up by 1.
        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: true,
                                   wrongGuesses: 1,
                                   hintUsed: false,
                                   date: "2026-05-10")
        XCTAssertEqual(store.state.totalPlayed, 1)
        XCTAssertEqual(store.state.totalSolved, 1)
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
        XCTAssertEqual(store.state.guessDistribution[1], 1)

        // Second call for the same puzzleId — no counter changes.
        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: true,
                                   wrongGuesses: 1,
                                   hintUsed: false,
                                   date: "2026-05-10")
        XCTAssertEqual(store.state.totalPlayed, 1,
                       "totalPlayed must not double on repeat recording of same puzzleId")
        XCTAssertEqual(store.state.totalSolved, 1)
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
        XCTAssertEqual(store.state.guessDistribution[1], 1)
    }

    func test_recordArchiveOutcome_idempotentForPreviouslyFailedPuzzle() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })

        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: false,
                                   wrongGuesses: 5,
                                   hintUsed: false,
                                   date: "2026-05-10")
        XCTAssertEqual(store.state.totalPlayed, 1)
        XCTAssertTrue(store.state.failedPuzzleIds.contains("puzzle-010"))

        // Repeat call — no changes, even with a "solved=true" follow-up
        // (cell would be locked in the UI; this is defense in depth).
        store.recordArchiveOutcome(puzzleId: "puzzle-010",
                                   solved: true,
                                   wrongGuesses: 0,
                                   hintUsed: false,
                                   date: "2026-05-10")
        XCTAssertEqual(store.state.totalPlayed, 1, "totalPlayed must not bump on repeat")
        XCTAssertEqual(store.state.totalSolved, 0)
        XCTAssertFalse(store.state.solvedPuzzleIds.contains("puzzle-010"),
                       "Puzzle that's been recorded as failed cannot be retroactively solved")
    }
}
