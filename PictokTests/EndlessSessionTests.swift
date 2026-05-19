import XCTest
@testable import Pictok

final class EndlessSessionTests: XCTestCase {

    private func makePuzzles() -> [Puzzle] {
        [
            Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "BEE",
                   category: .brand, subcategory: "t", difficulty: .medium),
            Puzzle(id: "p2", date: "2026-05-28", emoji: "🐶", answer: "DOG",
                   category: .brand, subcategory: "t", difficulty: .medium),
            Puzzle(id: "p3", date: "2026-05-29", emoji: "🐱", answer: "CAT",
                   category: .brand, subcategory: "t", difficulty: .medium),
        ]
    }

    private func makeStore(state: UserState = UserState.fresh(at: Date(timeIntervalSince1970: 0))) -> UserStateStore {
        // Use a fresh in-memory UserDefaults suite so tests don't leak.
        let suiteName = "test.endless.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserStateStore(defaults: defaults)
        store.state = state
        return store
    }

    func test_freshSession_startsWith5Hearts_andFirstPuzzle() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        XCTAssertEqual(session.hearts, 5)
        XCTAssertNotNil(session.currentPuzzle)
        XCTAssertNotEqual(session.currentPuzzle?.id, "p1")  // today's daily excluded
    }

    func test_correctGuess_keepsHearts_butLetterIsTracked() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let correctLetter = session.currentPuzzle!.answer.first { $0.isLetter }!
        session.guess(letter: correctLetter)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertTrue(session.correctGuesses.contains(correctLetter))
    }

    func test_wrongGuess_decrementsHearts() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        // pick a letter guaranteed not in the answer
        let allAnswerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
        let wrongLetter: Character = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first { !allAnswerLetters.contains($0) }!
        session.guess(letter: wrongLetter)
        XCTAssertEqual(session.hearts, 4)
    }

    func test_solving_addsToSolvedSet_incrementsLifetime_andDoesNotChangeStreak() {
        let store = makeStore()
        let startStreak = store.state.currentStreak
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let solvedId = session.currentPuzzle!.id
        // Guess every unique letter of the answer.
        for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        XCTAssertTrue(session.isSolved)
        XCTAssertTrue(store.state.solvedPuzzleIds.contains(solvedId))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
        XCTAssertEqual(store.state.currentStreak, startStreak,
                       "Endless solve must NOT change the Daily-only streak.")
    }

    func test_failing_addsToFailedSet_andDoesNotIncrementLifetime() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let failedId = session.currentPuzzle!.id
        // Force-fail by burning all 5 hearts on wrong letters.
        let allAnswerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
        let wrongPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".filter { !allAnswerLetters.contains($0) }
        for ch in wrongPool.prefix(5) {
            session.guess(letter: ch)
        }
        XCTAssertTrue(session.isFailed)
        XCTAssertTrue(store.state.failedPuzzleIds.contains(failedId))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 0)
    }

    func test_advance_resetsHeartsTo5_andSwitchesPuzzle() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let firstId = session.currentPuzzle!.id
        // Solve the first puzzle.
        for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        session.advance()
        XCTAssertEqual(session.hearts, 5)
        XCTAssertNotEqual(session.currentPuzzle?.id, firstId)
    }

    func test_wrongGuessInCurrentWord_evenIfLetterInLaterWord_decrementsHearts() {
        // Create a puzzle with multi-word answer where letters in word 2 are NOT in word 1.
        let multiPuzzle = Puzzle(id: "p_multi", date: "2026-05-28", emoji: "🐝🦴",
                                 answer: "BEE BONE",
                                 category: .brand, subcategory: "t", difficulty: .medium)
        let allPuzzles = [
            Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "X",
                   category: .brand, subcategory: "t", difficulty: .medium),
            multiPuzzle
        ]
        let store = makeStore()
        let session = EndlessSession(allPuzzles: allPuzzles,
                                     store: store,
                                     today: "2026-05-19")
        // Force the session onto the multi-word puzzle.
        XCTAssertEqual(session.currentPuzzle?.id, "p_multi")

        // 'O' is in BONE (word 1) but NOT in BEE (word 0, active). Should cost a heart.
        session.guess(letter: "O")
        XCTAssertEqual(session.hearts, 4, "O is not in active word BEE — must cost a heart")
    }

    func test_advance_addsPreviousIdToRecentEndlessIds_ringBufferAt5() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let firstId = session.currentPuzzle!.id
        session.advance()
        XCTAssertEqual(store.state.recentEndlessIds.last, firstId)
        XCTAssertLessThanOrEqual(store.state.recentEndlessIds.count, 5)
    }
}
