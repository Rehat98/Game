import XCTest
@testable import Pictok

final class EndlessSelectorTests: XCTestCase {

    // Helper: build a deterministic puzzle set with given dates.
    private func makePuzzles(_ specs: [(id: String, date: String)]) -> [Puzzle] {
        specs.map { spec in
            Puzzle(
                id: spec.id,
                date: spec.date,
                emoji: "🐝",
                answer: "BEE",
                category: .brand,
                subcategory: "test",
                difficulty: .medium
            )
        }
    }

    func test_priority1_picksUnseenSafePuzzle_excludingTodaysDaily() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily — must be excluded
            ("p2", "2026-05-20"),  // <7 days, skip in tier 1
            ("p3", "2026-05-28"),  // ≥7 days, eligible
            ("p4", "2026-06-15"),  // ≥7 days, eligible
        ])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p3", "p4"].contains(pick?.id),
                      "Expected p3 or p4 (tier-1 eligible), got \(pick?.id ?? "nil")")
    }

    func test_priority2_fallsBackToNearFutureWhenSafePoolEmpty() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily
            ("p2", "2026-05-20"),  // <7 days
            ("p3", "2026-05-22"),  // <7 days
        ])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p2", "p3"].contains(pick?.id),
                      "Expected p2 or p3 (tier-2), got \(pick?.id ?? "nil")")
    }

    func test_priority3_replayRotation_avoidsRecentEndlessIds() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily, excluded
            ("p2", "2026-05-20"),
            ("p3", "2026-05-22"),
            ("p4", "2026-05-28"),
            ("p5", "2026-06-01"),
            ("p6", "2026-06-02"),
        ])
        var state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        // Everything seen.
        state.solvedPuzzleIds = ["p2", "p3", "p4", "p5", "p6"]
        // p2 and p3 are in the recent buffer — should be skipped in tier 3.
        state.recentEndlessIds = ["p2", "p3"]
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p4", "p5", "p6"].contains(pick?.id),
                      "Expected p4/p5/p6 (not in recent buffer), got \(pick?.id ?? "nil")")
    }

    func test_returnsNilWhenOnlyTodaysDailyExists() {
        let puzzles = makePuzzles([("p1", "2026-05-19")])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertNil(pick)
    }
}
