import XCTest
@testable import Pictok

final class ShareCardBuilderTests: XCTestCase {

    func test_successCard_perfectRun_noHintNoWrong() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        let expected = """
        I solved today's Pictok!
        ❤️❤️❤️❤️❤️
        Streak: 7

        🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯
        → pictok.app
        """
        XCTAssertEqual(card, expected)
    }

    func test_successCard_withHint_noWrong() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 5,
            hintUsed: true,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️❤️❤️ 💡"),
                      "Expected full hearts with hint marker, got: \(card)")
    }

    func test_successCard_oneWrongGuess_noHint() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 4,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️❤️🖤"),
                      "Expected 4❤️ + 1🖤, got: \(card)")
        XCTAssertFalse(card.contains("💡"))
    }

    func test_successCard_multipleWrongGuesses_noHint() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 2,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️🖤🖤🖤"),
                      "Expected 2❤️ + 3🖤, got: \(card)")
    }

    func test_successCard_hintAndWrongGuesses() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 3,
            hintUsed: true,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️🖤🖤 💡"),
                      "Expected 3❤️ + 2🖤 + hint marker, got: \(card)")
    }

    func test_successCard_includesStreakWithoutPuzzleNumber() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("Streak: 7"))
        XCTAssertFalse(card.contains("#"), "Internal puzzle number should not surface in the share text")
    }

    func test_successCard_includesBoldChallengeLine() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 1,
            category: .brand,
            difficulty: .medium,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯"))
        XCTAssertTrue(card.contains("→ pictok.app"))
    }

    func test_successCard_clampsHeartsRemainingToZeroFive() {
        let over = ShareCardBuilder.successCard(
            puzzleNumber: 1, category: .movie, difficulty: .hard,
            heartsRemaining: 99, hintUsed: false, currentStreak: 1, url: "p"
        )
        XCTAssertTrue(over.contains("❤️❤️❤️❤️❤️"))
        let under = ShareCardBuilder.successCard(
            puzzleNumber: 1, category: .movie, difficulty: .hard,
            heartsRemaining: -3, hintUsed: false, currentStreak: 1, url: "p"
        )
        XCTAssertTrue(under.contains("🖤🖤🖤🖤🖤"))
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
        Today's Pictok beat me.
        🖤🖤🖤🖤🖤
        Streak: 7 → 0

        🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯
        → pictok.app
        """
        XCTAssertEqual(card, expected)
    }
}
