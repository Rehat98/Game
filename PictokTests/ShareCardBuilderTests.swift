import XCTest
@testable import Pictok

final class ShareCardBuilderTests: XCTestCase {

    func test_successCard_basicFormat() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 3,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        let expected = """
        Pictok #142 📌
        🎬 Hard
        ❤️❤️❤️🖤🖤 · 🔥 7

        pictok.app
        """
        XCTAssertEqual(card, expected)
    }

    func test_successCard_withHint_appendsBulbAfterHearts() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 3,
            hintUsed: true,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️🖤🖤 · 💡 · 🔥 7"))
    }

    func test_failureCard_format() {
        let card = ShareCardBuilder.failureCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            previousStreak: 7,
            url: "pictok.app"
        )
        let expected = """
        Pictok #142 📌
        🎬 Hard · today got me 🥲
        🔥 7 → 0

        pictok.app
        """
        XCTAssertEqual(card, expected)
    }

    func test_successCard_fullHearts_zeroLost() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 1,
            category: .song,
            difficulty: .easy,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️❤️❤️ · 🔥 1"))
    }

    func test_successCard_zeroHearts_allLost_butStillSolved() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 50,
            category: .book,
            difficulty: .medium,
            heartsRemaining: 0,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("🖤🖤🖤🖤🖤 · 🔥 1"))
    }
}
