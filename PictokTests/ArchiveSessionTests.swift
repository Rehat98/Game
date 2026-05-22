import XCTest
@testable import Pictok

final class ArchiveSessionTests: XCTestCase {

    private func makePuzzle(answer: String = "CAT") -> Puzzle {
        Puzzle(id: "puzzle-010", date: "2026-05-10", emoji: "🐱", answer: answer,
               category: .movie, subcategory: "t", difficulty: .medium)
    }

    private func makeStore(state: UserState = UserState.fresh(at: Date(timeIntervalSince1970: 0))) -> UserStateStore {
        let suiteName = "test.archive.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserStateStore(defaults: defaults)
        store.state = state
        return store
    }

    func test_init_pinsPuzzle_5Hearts_noGuesses() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertEqual(session.puzzle.id, "puzzle-010")
        XCTAssertTrue(session.correctGuesses.isEmpty)
        XCTAssertTrue(session.wrongGuesses.isEmpty)
        XCTAssertFalse(session.isSolved)
        XCTAssertFalse(session.isFailed)
    }

    func test_correctGuess_addsLetter_keepsHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.guess(letter: "C")
        XCTAssertTrue(session.correctGuesses.contains("C"))
        XCTAssertEqual(session.hearts, 5)
    }

    func test_wrongGuess_addsLetter_decrementsHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.guess(letter: "Z")
        XCTAssertTrue(session.wrongGuesses.contains("Z"))
        XCTAssertEqual(session.hearts, 4)
    }

    func test_submitWhenAllLettersRevealed_solvesAndRecordsOutcome() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        XCTAssertTrue(session.needsSubmit)
        session.submit()
        XCTAssertTrue(session.isSolved)
        XCTAssertTrue(store.state.solvedPuzzleIds.contains("puzzle-010"))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
    }

    func test_perfectRun_recordsAsPerfect() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        session.submit()
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-10" && $0.result == .perfect
        }))
    }

    func test_5WrongGuesses_failsAndRecordsOutcome() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["B", "D", "E", "F", "G"] { session.guess(letter: Character(letter)) }
        XCTAssertTrue(session.isFailed)
        XCTAssertEqual(session.hearts, 0)
        XCTAssertTrue(store.state.failedPuzzleIds.contains("puzzle-010"))
    }

    func test_solve_neverChangesStreak() {
        let store = makeStore()
        store.state.currentStreak = 4
        store.state.longestStreak = 9
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        session.submit()
        XCTAssertEqual(store.state.currentStreak, 4)
        XCTAssertEqual(store.state.longestStreak, 9)
    }

    func test_useHint_revealsOneLetter_butStaysAtFiveHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.useHint()
        XCTAssertTrue(session.hintUsedThisPuzzle)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertFalse(session.correctGuesses.isEmpty,
                       "Hint should reveal at least one letter")
    }

    func test_oneChanceWarningFiresAt2to1Transition() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(answer: "AAA"), store: store)
        for letter in ["B", "C", "D"] { session.guess(letter: Character(letter)) }
        XCTAssertEqual(session.hearts, 2)
        XCTAssertFalse(session.hasShownOneChanceWarning)
        session.guess(letter: "E")
        XCTAssertEqual(session.hearts, 1)
        XCTAssertTrue(session.hasShownOneChanceWarning)
    }
}
