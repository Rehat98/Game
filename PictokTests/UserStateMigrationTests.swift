import XCTest
@testable import Pictok

final class UserStateMigrationTests: XCTestCase {

    // A legacy JSON payload that includes `livesLastRefilledAt` (now removed)
    // and lacks the new endless-mode fields. Must decode without throwing,
    // with new fields defaulting to empty/zero.
    func test_decodesLegacyPayload_withDefaultsForNewFields() throws {
        let legacy = """
        {
          "currentStreak": 3,
          "longestStreak": 5,
          "lastSolvedDate": "2026-05-17",
          "streakFreezesAvailable": 1,
          "totalSolved": 7,
          "totalPlayed": 9,
          "guessDistribution": {"0": 2, "1": 4, "2": 1},
          "lives": 4,
          "livesLastRefilledAt": "2026-05-18T08:00:00Z",
          "todayPuzzleId": "puzzle-002",
          "todayWrongGuesses": ["B"],
          "todayCorrectGuesses": ["R", "O"],
          "todaySolved": false,
          "todayFailed": false,
          "hasEverSolved": true,
          "hasAskedForNotificationPermission": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(UserState.self, from: legacy)

        XCTAssertEqual(decoded.currentStreak, 3)
        XCTAssertEqual(decoded.lives, 4)
        XCTAssertEqual(decoded.solvedPuzzleIds, [])
        XCTAssertEqual(decoded.failedPuzzleIds, [])
        XCTAssertEqual(decoded.lifetimeSolvedCount, 7,
                       "lifetimeSolvedCount backfills from totalSolved on legacy payloads")
        XCTAssertEqual(decoded.recentEndlessIds, [])
    }

    func test_legacyPayloadLacksAmbassadorActive_defaultsFalse() throws {
        // An existing user upgrading to the ambassador-fix build must NOT suddenly
        // see puzzle-001 as their next puzzle. The legacy payload lacks the new
        // `ambassadorActive` key; decode must default it to false.
        let legacy = """
        {
          "currentStreak": 2, "longestStreak": 3, "streakFreezesAvailable": 1,
          "totalSolved": 4, "totalPlayed": 5,
          "guessDistribution": {},
          "lives": 5,
          "todayWrongGuesses": [], "todayCorrectGuesses": [],
          "todaySolved": false, "todayFailed": false,
          "hasEverSolved": true, "hasAskedForNotificationPermission": true,
          "solvedPuzzleIds": ["puzzle-001"], "failedPuzzleIds": [],
          "lifetimeSolvedCount": 4, "recentEndlessIds": [], "solveHistory": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserState.self, from: legacy)
        XCTAssertFalse(decoded.ambassadorActive,
                       "Legacy payload (no ambassadorActive key) must decode to false.")
    }

    func test_freshState_hasAmbassadorActiveTrue() {
        // A truly fresh user (state created via UserState.fresh) must see the
        // ambassador on their first launch.
        let fresh = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(fresh.ambassadorActive,
                      "UserState.fresh() arms the ambassador for first-launch users.")
    }

    func test_decodesNewPayload_doesNotBackfill_whenLifetimeFieldPresent() throws {
        let payload = """
        {
          "currentStreak": 0, "longestStreak": 0, "streakFreezesAvailable": 1,
          "totalSolved": 7, "totalPlayed": 9,
          "guessDistribution": {},
          "lives": 5, "livesLastRefilledAt": 0,
          "todayWrongGuesses": [], "todayCorrectGuesses": [],
          "todaySolved": false, "todayFailed": false,
          "hasEverSolved": true, "hasAskedForNotificationPermission": true,
          "solvedPuzzleIds": [], "failedPuzzleIds": [],
          "lifetimeSolvedCount": 3,
          "recentEndlessIds": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserState.self, from: payload)
        XCTAssertEqual(decoded.lifetimeSolvedCount, 3,
                       "When the field is explicitly present, it must NOT be overridden by totalSolved")
    }

    // Fresh state must encode and decode losslessly, including the new fields.
    func test_freshState_encodesAndDecodes_withNewFields() throws {
        var fresh = UserState.fresh(at: Date(timeIntervalSince1970: 1747569600))
        fresh.solvedPuzzleIds = ["puzzle-001", "puzzle-005"]
        fresh.failedPuzzleIds = ["puzzle-010"]
        fresh.lifetimeSolvedCount = 2
        fresh.recentEndlessIds = ["puzzle-005", "puzzle-001"]

        let data = try JSONEncoder().encode(fresh)
        let roundTripped = try JSONDecoder().decode(UserState.self, from: data)

        XCTAssertEqual(roundTripped.solvedPuzzleIds, ["puzzle-001", "puzzle-005"])
        XCTAssertEqual(roundTripped.failedPuzzleIds, ["puzzle-010"])
        XCTAssertEqual(roundTripped.lifetimeSolvedCount, 2)
        XCTAssertEqual(roundTripped.recentEndlessIds, ["puzzle-005", "puzzle-001"])
    }
}
