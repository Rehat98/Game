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
        I solved today's Pictok with no hints — perfect run.
        Streak: 7 · Pictok #142
        Can you beat me? → pictok.app
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
        XCTAssertTrue(card.contains("I solved today's Pictok using 1 hint."),
                      "Expected hint framing, got: \(card)")
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
        XCTAssertTrue(card.contains("(1 wrong guess)"),
                      "Expected singular 'guess', got: \(card)")
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
        XCTAssertTrue(card.contains("(3 wrong guesses)"),
                      "Expected plural 'guesses', got: \(card)")
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
        XCTAssertTrue(card.contains("with 1 hint and 2 wrong guesses"),
                      "Expected combo framing, got: \(card)")
    }

    func test_successCard_includesStreakAndPuzzleNumber() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("Streak: 7 · Pictok #142"))
    }

    func test_successCard_includesChallengeUrl() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 1,
            category: .brand,
            difficulty: .medium,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("Can you beat me? → pictok.app"))
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
        Today's Pictok beat me. Pictok #142.
        Streak: 7 → 0
        Want to take a swing? → pictok.app
        """
        XCTAssertEqual(card, expected)
    }
}
