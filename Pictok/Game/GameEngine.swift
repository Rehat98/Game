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

extension GameEngine {

    /// Common English stop/connector words that are auto-revealed at puzzle start
    /// so the player doesn't have to type them letter by letter.
    static let connectorWords: Set<String> = [
        "A", "AN", "AND", "AS", "AT", "BY", "FOR", "IN", "IS", "IT",
        "OF", "ON", "OR", "TO", "THE"
    ]

    struct WordBreakdown: Equatable {
        let words: [String]
        let connectorIndices: Set<Int>
    }

    /// Splits the answer into words and identifies which indices are connectors.
    static func wordBreakdown(answer: String) -> WordBreakdown {
        let words = answer.split(separator: " ").map(String.init)
        let candidateConnectors = Set(words.enumerated().compactMap { (idx, w) -> Int? in
            connectorWords.contains(w) ? idx : nil
        })
        // Defensive: if every word would be a connector (e.g., a puzzle whose answer
        // is exactly "IT" or "AS IT IS"), treat them all as content words instead so
        // the puzzle is actually playable.
        let connectors = (candidateConnectors.count == words.count) ? [] : candidateConnectors
        return WordBreakdown(words: words, connectorIndices: connectors)
    }

    /// Returns the index of the first non-connector word that isn't fully solved.
    /// Returns nil when every non-connector word's letters are all in correctGuesses.
    static func activeWordIndex(answer: String,
                                correctGuesses: Set<Character>) -> Int? {
        let bd = wordBreakdown(answer: answer)
        for (idx, word) in bd.words.enumerated() {
            if bd.connectorIndices.contains(idx) { continue }
            let neededLetters = Set(word.filter { $0.isLetter })
            if !neededLetters.isSubset(of: correctGuesses) {
                return idx
            }
        }
        return nil
    }

    /// Whether the given letter appears in the word at `wordIndex` of `answer`.
    static func isCorrect(letter: Character, inWord wordIndex: Int, of answer: String) -> Bool {
        let upper = Character(String(letter).uppercased())
        let bd = wordBreakdown(answer: answer)
        guard wordIndex < bd.words.count else { return false }
        return bd.words[wordIndex].contains(upper)
    }

    /// Word-by-word solve check: the puzzle is solved when every non-connector
    /// word's letters are all in correctGuesses.
    static func isSolvedByWord(answer: String, correctGuesses: Set<Character>) -> Bool {
        return activeWordIndex(answer: answer, correctGuesses: correctGuesses) == nil
    }

    /// Whether the character at `position` of `answer` should currently be visible.
    /// Connector-word positions are always revealed; positions in past/current
    /// words reveal if the letter is in correctGuesses; future-word positions stay hidden.
    static func isPositionRevealed(answer: String,
                                   position: Int,
                                   correctGuesses: Set<Character>,
                                   activeWordIndex: Int?) -> Bool {
        let chars = Array(answer)
        guard position < chars.count else { return false }
        let ch = chars[position]
        if !ch.isLetter { return true }  // spaces, punctuation always "revealed"

        // Determine which word index this position belongs to.
        let bd = wordBreakdown(answer: answer)
        var charCursor = 0
        for (idx, word) in bd.words.enumerated() {
            let wordRange = charCursor..<(charCursor + word.count)
            if wordRange.contains(position) {
                // Connectors always shown.
                if bd.connectorIndices.contains(idx) { return true }
                // Past + current word: reveal if letter guessed.
                let active = activeWordIndex ?? bd.words.count
                if idx <= active && correctGuesses.contains(ch) { return true }
                return false
            }
            charCursor += word.count + 1  // +1 for the space delimiter
        }
        return false
    }
}
