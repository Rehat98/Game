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

        guard let activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer,
                                                         correctGuesses: correctGuesses) else {
            // Already solved (shouldn't happen because of the isSolved guard, but safe).
            return
        }

        if GameEngine.isCorrect(letter: upper, inWord: activeIdx, of: puzzle.answer) {
            correctGuesses.insert(upper)
            if GameEngine.isSolvedByWord(answer: puzzle.answer, correctGuesses: correctGuesses) {
                isSolved = true
                recordSolve(id: puzzle.id)
            }
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
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
        guard let activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer,
                                                         correctGuesses: correctGuesses) else { return }
        let activeWord = GameEngine.wordBreakdown(answer: puzzle.answer).words[activeIdx]
        guard let toReveal = activeWord.first(where: { !correctGuesses.contains($0) }) else { return }
        correctGuesses.insert(toReveal)
        hintUsedThisPuzzle = true
        if GameEngine.isSolvedByWord(answer: puzzle.answer, correctGuesses: correctGuesses) {
            isSolved = true
            recordSolve(id: puzzle.id)
        }
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
