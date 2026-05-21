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
        session.submit()  // <-- new step; required after the revert
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
        session.submit()
        session.advance()
        XCTAssertEqual(session.hearts, 5)
        XCTAssertNotEqual(session.currentPuzzle?.id, firstId)
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

    func test_useHint_revealsFirstUnguessedLetterOfActiveWord() {
        let store = makeStore()
        let multiPuzzle = Puzzle(id: "p_multi", date: "2026-05-28", emoji: "🐝🦴",
                                 answer: "BEE BONE",
                                 category: .brand, subcategory: "t", difficulty: .medium)
        let allPuzzles = [
            Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "X",
                   category: .brand, subcategory: "t", difficulty: .medium),
            multiPuzzle
        ]
        let session = EndlessSession(allPuzzles: allPuzzles, store: store, today: "2026-05-19")
        XCTAssertEqual(session.currentPuzzle?.id, "p_multi")

        session.useHint()
        // BEE's first unguessed letter is "B" — that should be revealed.
        XCTAssertTrue(session.correctGuesses.contains("B"))
    }

    func test_useHint_marksUsed_andSubsequentCallsAreNoOp() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        XCTAssertFalse(session.hintUsedThisPuzzle)

        session.useHint()
        XCTAssertTrue(session.hintUsedThisPuzzle)
        let countAfterFirst = session.correctGuesses.count

        session.useHint()  // should be no-op
        XCTAssertEqual(session.correctGuesses.count, countAfterFirst)
    }

    func test_useHint_doesNotCostHearts() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        XCTAssertEqual(session.hearts, 5)

        session.useHint()
        XCTAssertEqual(session.hearts, 5, "Hint must be free (no heart cost)")
    }

    func test_advance_resetsHintAvailability() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")

        session.useHint()
        XCTAssertTrue(session.hintUsedThisPuzzle)

        // Force the puzzle to a state where advance() picks a different one.
        // (Solve it via remaining guesses, then advance.)
        if let answer = session.currentPuzzle?.answer {
            for ch in Set(answer.filter { $0.isLetter }) {
                session.guess(letter: ch)
            }
        }
        session.advance()
        XCTAssertFalse(session.hintUsedThisPuzzle, "advance() must reset hint availability")
    }

    func test_useHint_solvesPuzzle_whenItRevealsLastNeededLetter() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        let answer = session.currentPuzzle!.answer

        let allLetters = Set(answer.filter { $0.isLetter })
        let firstLetter = answer.first(where: { $0.isLetter })!
        for ch in allLetters where ch != firstLetter {
            session.guess(letter: ch)
        }
        XCTAssertFalse(session.isSolved)

        session.useHint()
        XCTAssertTrue(session.needsSubmit, "Hint revealing the last letter triggers Submit")
        XCTAssertFalse(session.isSolved, "Submit must still be tapped")

        session.submit()
        XCTAssertTrue(session.isSolved)
    }

    func test_solvingDoesNotSetIsSolved_butSetsNeedsSubmit() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        let answer = session.currentPuzzle!.answer
        // Guess every unique letter of the answer.
        for ch in Set(answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        XCTAssertFalse(session.isSolved,
                       "guess() must not auto-solve; player must tap Submit first")
        XCTAssertTrue(session.needsSubmit,
                      "all letters revealed → needsSubmit must be true")
    }

    func test_submit_flipsIsSolved_andRecordsSolve() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        let solvedId = session.currentPuzzle!.id
        for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        XCTAssertTrue(session.needsSubmit)

        session.submit()
        XCTAssertTrue(session.isSolved)
        XCTAssertTrue(store.state.solvedPuzzleIds.contains(solvedId))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
    }

    func test_oneChanceWarning_firesOnceWhenHeartsHitOne() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
        let answerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
        // Burn 4 wrong guesses → hearts go 5→4→3→2→1.
        let wrongLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".filter { !answerLetters.contains($0) }
        for ch in wrongLetters.prefix(4) {
            session.guess(letter: ch)
        }
        XCTAssertEqual(session.hearts, 1)
        XCTAssertTrue(session.hasShownOneChanceWarning,
                      "Transitioning into hearts == 1 should mark hasShownOneChanceWarning")

        // Advance to next puzzle → flag should reset.
        session.advance()
        XCTAssertFalse(session.hasShownOneChanceWarning,
                       "advance() must reset hasShownOneChanceWarning")
    }
}
