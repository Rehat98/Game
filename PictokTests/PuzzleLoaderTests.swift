import XCTest
@testable import Pictok

final class PuzzleLoaderTests: XCTestCase {

    func test_loadsFromFixture() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)
        XCTAssertEqual(loader.allPuzzles.count, 3)
    }

    func test_findsPuzzleForKnownDate() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)

        // 2026-05-19 12:00 UTC → "2026-05-19" in UTC
        let date = ISO8601DateFormatter().date(from: "2026-05-19T12:00:00Z")!
        let puzzle = loader.puzzle(for: date, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(puzzle?.answer, "TEENAGE MUTANT NINJA TURTLES")
    }

    func test_returnsNilForDateWithNoPuzzle() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)

        let date = ISO8601DateFormatter().date(from: "2030-01-01T12:00:00Z")!
        XCTAssertNil(loader.puzzle(for: date, timeZone: TimeZone(identifier: "UTC")!))
    }

    func test_dateStringHelper_returnsYYYYMMDDInTimeZone() {
        let date = ISO8601DateFormatter().date(from: "2026-05-18T23:30:00Z")!
        // In UTC the date string is "2026-05-18"
        XCTAssertEqual(PuzzleLoader.dateString(for: date, timeZone: TimeZone(identifier: "UTC")!),
                       "2026-05-18")
        // In Asia/Tokyo (+9) it's already "2026-05-19"
        XCTAssertEqual(PuzzleLoader.dateString(for: date, timeZone: TimeZone(identifier: "Asia/Tokyo")!),
                       "2026-05-19")
    }
}
