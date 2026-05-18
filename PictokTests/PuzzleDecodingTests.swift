import XCTest
@testable import Pictok

final class PuzzleDecodingTests: XCTestCase {

    func test_decodesAllPuzzlesFromFixture() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let puzzles = try JSONDecoder().decode([Puzzle].self, from: data)

        XCTAssertEqual(puzzles.count, 3)
        XCTAssertEqual(puzzles[0].id, "2026-05-18")
        XCTAssertEqual(puzzles[0].emoji, "🌃🦇🤡")
        XCTAssertEqual(puzzles[0].answer, "THE DARK KNIGHT")
        XCTAssertEqual(puzzles[0].category, .movie)
        XCTAssertEqual(puzzles[0].difficulty, .hard)
        XCTAssertEqual(puzzles[2].category, .song)
        XCTAssertEqual(puzzles[2].difficulty, .easy)
    }

    func test_categoryEmojiIcon_matchesSpec() {
        XCTAssertEqual(Category.movie.icon, "🎬")
        XCTAssertEqual(Category.song.icon, "🎵")
        XCTAssertEqual(Category.book.icon, "📚")
        XCTAssertEqual(Category.brand.icon, "🏷️")
        XCTAssertEqual(Category.celeb.icon, "🎤")
    }

    func test_difficultyDisplayName() {
        XCTAssertEqual(Difficulty.easy.displayName, "Easy")
        XCTAssertEqual(Difficulty.medium.displayName, "Medium")
        XCTAssertEqual(Difficulty.hard.displayName, "Hard")
    }
}
