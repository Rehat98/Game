import Foundation
import Observation

@Observable
final class UserStateStore {
    static let defaultsKey = "pictok.state.v1"

    private let defaults: UserDefaults
    private let now: () -> Date

    var state: UserState

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.defaultsKey),
           let restored = try? JSONDecoder().decode(UserState.self, from: data) {
            self.state = restored
        } else {
            self.state = UserState.fresh(at: now())
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Records the outcome of an archive (catch-up) play. Updates lifetime fields
    /// and `solveHistory`, but **never** touches `currentStreak`, `longestStreak`,
    /// `lastSolvedDate`, or `streakFreezesAvailable` — archive plays are
    /// streak-neutral by design.
    func recordArchiveOutcome(puzzleId: String,
                              solved: Bool,
                              wrongGuesses: Int,
                              hintUsed: Bool,
                              date: String) {
        // Idempotent: if this puzzle was already recorded (cell-tap routing
        // should prevent repeats, but the defense costs nothing), do nothing.
        if state.solvedPuzzleIds.contains(puzzleId) || state.failedPuzzleIds.contains(puzzleId) {
            return
        }
        state.totalPlayed += 1
        if solved {
            state.solvedPuzzleIds.insert(puzzleId)
            state.totalSolved += 1
            state.lifetimeSolvedCount += 1
            state.guessDistribution[wrongGuesses, default: 0] += 1
        } else {
            state.failedPuzzleIds.insert(puzzleId)
        }
        let result: SolveResult = solved
            ? (wrongGuesses == 0 && !hintUsed ? .perfect : .solved)
            : .failed
        var history = state.solveHistory.filter { $0.date != date }
        history.append(SolveRecord(date: date, result: result))
        state.solveHistory = history
        save()
    }
}
