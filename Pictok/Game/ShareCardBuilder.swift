import Foundation

/// Builds the share-card text shown when a player taps Share after solving (or
/// failing) the Daily puzzle. Output is plain text designed to read well in
/// iMessage / Twitter / group chats — no kid-emoji aesthetics, framed as a
/// social challenge ("Can you beat me?") rather than a result dump.
enum ShareCardBuilder {

    static func successCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            heartsRemaining: Int,
                            hintUsed: Bool,
                            currentStreak: Int,
                            url: String) -> String {
        let heartsLost = max(0, min(5, 5 - heartsRemaining))
        let firstLine = challengeLine(hintUsed: hintUsed, heartsLost: heartsLost)
        return """
        \(firstLine)
        Streak: \(currentStreak) · Pictok #\(puzzleNumber)
        Can you beat me? → \(url)
        """
    }

    static func failureCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            previousStreak: Int,
                            url: String) -> String {
        return """
        Today's Pictok beat me. Pictok #\(puzzleNumber).
        Streak: \(previousStreak) → 0
        Want to take a swing? → \(url)
        """
    }

    /// First-line copy varies by performance:
    /// - No hint, no wrong guesses → "perfect run" framing
    /// - Hint used → call out the hint
    /// - Wrong guesses but no hint → call out the cleaner challenge
    /// - Hint used AND wrong guesses → call out both
    private static func challengeLine(hintUsed: Bool, heartsLost: Int) -> String {
        switch (hintUsed, heartsLost) {
        case (false, 0):
            return "I solved today's Pictok with no hints — perfect run."
        case (true, 0):
            return "I solved today's Pictok using 1 hint."
        case (false, let lost):
            return "I solved today's Pictok (\(lost) wrong \(lost == 1 ? "guess" : "guesses"))."
        case (true, let lost):
            return "I solved today's Pictok with 1 hint and \(lost) wrong \(lost == 1 ? "guess" : "guesses")."
        }
    }
}
