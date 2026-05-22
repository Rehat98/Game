import Foundation
import Observation

/// Single-puzzle game session pinned to one past Daily puzzle, used by the
/// Archive feature. Mirrors EndlessSession in shape but never advances and
/// records its outcome via `UserStateStore.recordArchiveOutcome` (which is
/// streak-neutral by design).
@Observable
final class ArchiveSession {
    let puzzle: Puzzle
    private let store: UserStateStore

    private(set) var hearts: Int = 5
    private(set) var correctGuesses: Set<Character> = []
    private(set) var wrongGuesses: Set<Character> = []
    private(set) var isSolved: Bool = false
    private(set) var isFailed: Bool = false
    private(set) var hintUsedThisPuzzle: Bool = false
    private(set) var hasShownOneChanceWarning: Bool = false

    init(puzzle: Puzzle, store: UserStateStore) {
        self.puzzle = puzzle
        self.store = store
    }

    var needsSubmit: Bool {
        guard !isSolved, !isFailed else { return false }
        return GameEngine.isSolved(answer: puzzle.answer,
                                   correctGuesses: correctGuesses,
                                   revealedLetter: nil)
    }

    func guess(letter: Character) {
        guard !isSolved, !isFailed else { return }
        let upper = Character(String(letter).uppercased())
        guard !correctGuesses.contains(upper), !wrongGuesses.contains(upper) else { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle) {
            correctGuesses.insert(upper)
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
            if hearts == 1 && !hasShownOneChanceWarning {
                hasShownOneChanceWarning = true
            }
            if GameEngine.isFailed(lives: hearts) {
                isFailed = true
                recordOutcome(solved: false)
            }
        }
    }

    func submit() {
        guard needsSubmit else { return }
        isSolved = true
        recordOutcome(solved: true)
    }

    func useHint() {
        guard !hintUsedThisPuzzle, !isSolved, !isFailed else { return }
        guard let letter = GameEngine.letterToReveal(for: puzzle, correctGuesses: correctGuesses) else { return }
        correctGuesses.insert(letter)
        hintUsedThisPuzzle = true
    }

    private func recordOutcome(solved: Bool) {
        store.recordArchiveOutcome(
            puzzleId: puzzle.id,
            solved: solved,
            wrongGuesses: wrongGuesses.count,
            hintUsed: hintUsedThisPuzzle,
            date: puzzle.date
        )
    }
}
