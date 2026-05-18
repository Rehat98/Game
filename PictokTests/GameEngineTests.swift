import XCTest
@testable import Pictok

final class GameEngineTests: XCTestCase {

    func makeSamplePuzzle() -> Puzzle {
        Puzzle(id: "t-1", date: "2026-05-18",
               emoji: "🌃🦇🤡", answer: "THE DARK KNIGHT",
               category: .movie, subcategory: "Action · 2008",
               difficulty: .hard)
    }

    // MARK: Letter classification

    func test_isLetterCorrect_trueWhenLetterInAnswer() {
        let p = makeSamplePuzzle()
        XCTAssertTrue(GameEngine.isCorrect(letter: "T", in: p))
        XCTAssertTrue(GameEngine.isCorrect(letter: "K", in: p))
    }

    func test_isLetterCorrect_falseWhenLetterNotInAnswer() {
        let p = makeSamplePuzzle()
        XCTAssertFalse(GameEngine.isCorrect(letter: "Z", in: p))
        XCTAssertFalse(GameEngine.isCorrect(letter: "B", in: p))
    }

    func test_isLetterCorrect_caseInsensitive() {
        let p = makeSamplePuzzle()
        XCTAssertTrue(GameEngine.isCorrect(letter: "t", in: p))
    }

    // MARK: Win/fail

    func test_isSolved_falseWithMissingLetters() {
        let p = makeSamplePuzzle()
        let guessed: Set<Character> = ["T", "H", "E"]
        XCTAssertFalse(GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: nil))
    }

    func test_isSolved_trueWhenAllLettersGuessed() {
        let p = makeSamplePuzzle()
        let allLetters = Set("THE DARK KNIGHT".filter { $0.isLetter })
        XCTAssertTrue(GameEngine.isSolved(answer: p.answer, correctGuesses: allLetters, revealedLetter: nil))
    }

    func test_isSolved_trueWhenAllLettersIncludingRevealedHint() {
        let p = makeSamplePuzzle()
        // All letters except T → solved only when revealedLetter is T
        var guessed = Set("THE DARK KNIGHT".filter { $0.isLetter })
        guessed.remove("T")
        XCTAssertFalse(GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: nil))
        XCTAssertTrue (GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: "T"))
    }

    func test_isFailed_whenLivesAtZero() {
        XCTAssertTrue(GameEngine.isFailed(lives: 0))
        XCTAssertFalse(GameEngine.isFailed(lives: 1))
    }

    // MARK: Hints

    func test_hintCost_categoryCostsOneHeart() {
        XCTAssertEqual(GameEngine.heartCost(for: .category), 1)
    }

    func test_hintCost_letterCostsTwoHearts() {
        XCTAssertEqual(GameEngine.heartCost(for: .letter), 2)
    }

    func test_letterHint_returnsFirstUnguessedLetterFromAnswer() {
        let p = makeSamplePuzzle()
        let revealed = GameEngine.letterToReveal(for: p, correctGuesses: [])
        XCTAssertNotNil(revealed)
        XCTAssertTrue("THE DARK KNIGHT".contains(revealed!))
    }

    func test_letterHint_skipsAlreadyGuessedLetters() {
        let p = makeSamplePuzzle()
        let already: Set<Character> = ["T", "H", "E"]
        let revealed = GameEngine.letterToReveal(for: p, correctGuesses: already)
        XCTAssertNotNil(revealed)
        XCTAssertFalse(already.contains(revealed!))
        XCTAssertTrue("DARKNIGHT".contains(revealed!))
    }

    func test_letterHint_returnsNilWhenAllLettersAlreadyGuessed() {
        let p = makeSamplePuzzle()
        let all = Set("THE DARK KNIGHT".filter { $0.isLetter })
        XCTAssertNil(GameEngine.letterToReveal(for: p, correctGuesses: all))
    }

    // MARK: Streak transitions

    func test_streakAfterSolve_incrementsWhenYesterdayWasSolved() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-18",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 0
        )
        XCTAssertEqual(next.streak, 8)
        XCTAssertEqual(next.freezesAvailable, 0)
    }

    func test_streakAfterSolve_setsToOneWhenLastSolveIsNil() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-18",
            lastSolvedDate: nil,
            currentStreak: 0,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 1)
    }

    func test_streakAfterSolve_setsToOneWhenLastSolveIsTwoOrMoreDaysAgo_andNoFreeze() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-20",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 0
        )
        XCTAssertEqual(next.streak, 1)
    }

    func test_streakAfterSolve_consumesFreezeForExactlyOneMissedDay() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-19",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 8)
        XCTAssertEqual(next.freezesAvailable, 0)
    }

    func test_streakAfterSolve_doesNotConsumeFreezeForMoreThanOneMissedDay() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-20",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 1)
        XCTAssertEqual(next.freezesAvailable, 1)
    }

    func test_streakAfterFail_resetsToZero() {
        XCTAssertEqual(GameEngine.streakAfterFail(currentStreak: 23), 0)
    }
}
