import XCTest
@testable import Pictok

final class UserStateCodableTests: XCTestCase {

    func test_freshState_roundTripsThroughJSON() throws {
        let original = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(UserState.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func test_freshState_hasExpectedDefaults() {
        let s = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertNil(s.lastSolvedDate)
        XCTAssertEqual(s.streakFreezesAvailable, 1)
        XCTAssertEqual(s.totalSolved, 0)
        XCTAssertEqual(s.totalPlayed, 0)
        XCTAssertEqual(s.guessDistribution, [:])
        XCTAssertEqual(s.lives, 5)
        XCTAssertFalse(s.todaySolved)
        XCTAssertFalse(s.todayFailed)
        XCTAssertNil(s.todayPuzzleId)
        XCTAssertEqual(s.todayWrongGuesses, [])
        XCTAssertEqual(s.todayCorrectGuesses, [])
        XCTAssertNil(s.todayHintUsed)
        XCTAssertNil(s.todayRevealedLetter)
    }

    func test_populatedState_roundTrips() throws {
        var s = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        s.currentStreak = 7
        s.longestStreak = 10
        s.lastSolvedDate = "2026-05-17"
        s.streakFreezesAvailable = 0
        s.totalSolved = 23
        s.totalPlayed = 25
        s.guessDistribution = [0: 5, 1: 7, 2: 6, 3: 5]
        s.lives = 3
        s.todayPuzzleId = "2026-05-18"
        s.todayWrongGuesses = ["X", "Z"]
        s.todayCorrectGuesses = ["E", "I"]
        s.todayHintUsed = .category
        s.todayRevealedLetter = nil

        let data = try JSONEncoder().encode(s)
        let restored = try JSONDecoder().decode(UserState.self, from: data)
        XCTAssertEqual(s, restored)
    }

    func test_hintType_codableViaRawValue() throws {
        let cat = try JSONEncoder().encode(HintType.category)
        XCTAssertEqual(String(data: cat, encoding: .utf8), "\"category\"")

        let letter = try JSONEncoder().encode(HintType.letter)
        XCTAssertEqual(String(data: letter, encoding: .utf8), "\"letter\"")
    }
}
