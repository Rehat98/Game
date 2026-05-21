import Foundation

/// Builds the share-card text shown when a player taps Share after solving (or
/// failing) the Daily puzzle. Output is plain text designed to read well in
/// iMessage / Twitter / group chats — no kid-emoji aesthetics, framed as a
/// social challenge ("Can you beat me?") rather than a result dump.
///
/// The challenge line uses Unicode "Mathematical Sans-Serif Bold" codepoints
/// (U+1D5D4 – U+1D607) so the text renders as bold in every plain-text
/// receiver without relying on Markdown/HTML formatting that would get
/// stripped. Combined with emoji bracketing for color/attention.
enum ShareCardBuilder {

    static let challengeBold = "🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯"
    static let failBold     = "🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯"

    static func successCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            heartsRemaining: Int,
                            hintUsed: Bool,
                            currentStreak: Int,
                            url: String) -> String {
        // `puzzleNumber` is kept in the signature for caller compatibility but
        // is no longer surfaced in the text — receivers don't care about the
        // internal index. The "today's Pictok" framing is identifier enough.
        _ = puzzleNumber
        let heartsLost = max(0, min(5, 5 - heartsRemaining))
        let firstLine = challengeLine(hintUsed: hintUsed, heartsLost: heartsLost)
        return """
        \(firstLine)
        Streak: \(currentStreak)

        \(challengeBold)
        → \(url)
        """
    }

    static func failureCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            previousStreak: Int,
                            url: String) -> String {
        _ = puzzleNumber
        return """
        Today's Pictok beat me.
        Streak: \(previousStreak) → 0

        \(failBold)
        → \(url)
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
