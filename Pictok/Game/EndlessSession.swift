import Foundation
import Observation

@Observable
final class EndlessSession {
    private static let maxHearts = 5
    private static let recentIdsBufferSize = 5

    private let allPuzzles: [Puzzle]
    private let store: UserStateStore
    private let today: String
    private let selector: EndlessSelector

    private(set) var currentPuzzle: Puzzle?
    private(set) var hearts: Int = maxHearts
    private(set) var correctGuesses: Set<Character> = []
    private(set) var wrongGuesses: Set<Character> = []
    private(set) var isSolved: Bool = false
    private(set) var isFailed: Bool = false
    private(set) var hintUsedThisPuzzle: Bool = false
    private(set) var hasShownOneChanceWarning: Bool = false

    /// True when every letter in the answer has been correctly guessed (or revealed
    /// via hint), but the player has not yet tapped Submit. Win celebration is gated
    /// on the player tapping Submit, which calls `submit()`.
    var needsSubmit: Bool {
        guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return false }
        return GameEngine.isSolved(answer: puzzle.answer,
                                   correctGuesses: correctGuesses,
                                   revealedLetter: nil)
    }

    init(allPuzzles: [Puzzle], store: UserStateStore, today: String,
         selector: EndlessSelector = EndlessSelector()) {
        self.allPuzzles = allPuzzles
        self.store = store
        self.today = today
        self.selector = selector
        self.currentPuzzle = selector.nextPuzzle(allPuzzles: allPuzzles,
                                                 state: store.state,
                                                 today: today)
    }

    func guess(letter: Character) {
        guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return }
        let upper = Character(String(letter).uppercased())
        if correctGuesses.contains(upper) || wrongGuesses.contains(upper) { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle) {
            correctGuesses.insert(upper)
            // NOTE: do not flip isSolved here. The player must tap Submit;
            // that path runs in submit().
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
            if hearts == 1 && !hasShownOneChanceWarning {
                hasShownOneChanceWarning = true
            }
            if GameEngine.isFailed(lives: hearts) {
                isFailed = true
                recordFail(id: puzzle.id)
            }
        }
    }

    func useHint() {
        guard !hintUsedThisPuzzle,
              let puzzle = currentPuzzle,
              !isSolved, !isFailed else { return }
        // Pick the first unguessed letter in the answer, left to right.
        guard let toReveal = puzzle.answer.first(where: {
            $0.isLetter && !correctGuesses.contains($0)
        }) else { return }
        correctGuesses.insert(toReveal)
        hintUsedThisPuzzle = true
        // Like guess(): do not auto-solve. needsSubmit becomes true via its
        // computed getter, and the view shows the Submit button.
    }

    /// Player-tap finisher: flips isSolved and records the solve. Only does work
    /// if the puzzle is currently `needsSubmit` (all letters revealed but not yet
    /// celebrated). Safe to call redundantly.
    func submit() {
        guard needsSubmit, let puzzle = currentPuzzle else { return }
        isSolved = true
        recordSolve(id: puzzle.id)
    }

    func advance() {
        if let prevId = currentPuzzle?.id {
            var buffer = store.state.recentEndlessIds
            buffer.append(prevId)
            if buffer.count > Self.recentIdsBufferSize {
                buffer.removeFirst(buffer.count - Self.recentIdsBufferSize)
            }
            store.state.recentEndlessIds = buffer
            store.save()
        }
        hearts = Self.maxHearts
        correctGuesses = []
        wrongGuesses = []
        isSolved = false
        isFailed = false
        hintUsedThisPuzzle = false
        hasShownOneChanceWarning = false
        currentPuzzle = selector.nextPuzzle(allPuzzles: allPuzzles,
                                            state: store.state,
                                            today: today)
    }

    private func recordSolve(id: String) {
        store.state.solvedPuzzleIds.insert(id)
        store.state.lifetimeSolvedCount += 1
        store.save()
    }

    private func recordFail(id: String) {
        store.state.failedPuzzleIds.insert(id)
        store.save()
    }
}
