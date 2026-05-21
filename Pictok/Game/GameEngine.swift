import Foundation

enum GameEngine {

    static func isCorrect(letter: Character, in puzzle: Puzzle) -> Bool {
        let upper = Character(String(letter).uppercased())
        return puzzle.answer.contains(upper)
    }

    static func isSolved(answer: String,
                         correctGuesses: Set<Character>,
                         revealedLetter: Character?) -> Bool {
        let answerLetters = Set(answer.filter { $0.isLetter })
        var known = correctGuesses
        if let r = revealedLetter { known.insert(r) }
        return answerLetters.isSubset(of: known)
    }

    static func isFailed(lives: Int) -> Bool {
        lives <= 0
    }
}

extension GameEngine {

    static func heartCost(for hint: HintType) -> Int {
        switch hint {
        case .category: return 1
        case .letter:   return 2
        }
    }

    /// Returns a deterministic "best" letter to reveal: the first letter in the answer
    /// (left-to-right) that the player hasn't already guessed. Returns nil if all
    /// letters are already known.
    static func letterToReveal(for puzzle: Puzzle, correctGuesses: Set<Character>) -> Character? {
        for ch in puzzle.answer where ch.isLetter {
            if !correctGuesses.contains(ch) { return ch }
        }
        return nil
    }
}

extension GameEngine {

    struct StreakResult: Equatable {
        let streak: Int
        let freezesAvailable: Int
    }

    static func streakAfterSolve(today: String,
                                 lastSolvedDate: String?,
                                 currentStreak: Int,
                                 streakFreezesAvailable: Int) -> StreakResult {
        guard let last = lastSolvedDate else {
            return StreakResult(streak: 1, freezesAvailable: streakFreezesAvailable)
        }
        let daysApart = daysBetween(last, today)
        switch daysApart {
        case 1:
            // Solved consecutive day — straight increment.
            return StreakResult(streak: currentStreak + 1,
                                freezesAvailable: streakFreezesAvailable)
        case 2 where streakFreezesAvailable > 0:
            // Missed exactly one day, freeze rescues the streak.
            return StreakResult(streak: currentStreak + 1,
                                freezesAvailable: streakFreezesAvailable - 1)
        default:
            // 0 (same day — shouldn't happen during a real solve), or >1 missed days.
            return StreakResult(streak: 1, freezesAvailable: streakFreezesAvailable)
        }
    }

    static func streakAfterFail(currentStreak: Int) -> Int { 0 }

    private static func daysBetween(_ a: String, _ b: String) -> Int {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let da = f.date(from: a), let db = f.date(from: b) else { return Int.max }
        let comps = Calendar(identifier: .gregorian).dateComponents([.day], from: da, to: db)
        return comps.day ?? Int.max
    }
}
