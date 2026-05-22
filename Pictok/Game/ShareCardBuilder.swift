import Foundation

/// Builds the share-card text shown when a player taps Share after solving (or
/// failing) the Daily puzzle. Output is plain text designed to read well in
/// iMessage / Twitter / group chats.
///
/// Performance is communicated visually via a 5-wide hearts strip (❤️ remaining,
/// 🖤 lost), with a 💡 suffix when a hint was used. The strip is the viral hook —
/// instantly scannable, no varying English-language phrasing required.
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
        // puzzleNumber / category / difficulty are kept in the signature for
        // caller compatibility; receivers don't care about the internal index
        // and "today's Pictok" framing is identifier enough.
        _ = puzzleNumber
        _ = category
        _ = difficulty
        let hearts = heartsLine(heartsRemaining: heartsRemaining, hintUsed: hintUsed)
        return """
        I solved today's Pictok!
        \(hearts)
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
        _ = category
        _ = difficulty
        return """
        Today's Pictok beat me.
        🖤🖤🖤🖤🖤
        Streak: \(previousStreak) → 0

        \(failBold)
        → \(url)
        """
    }

    private static func heartsLine(heartsRemaining: Int, hintUsed: Bool) -> String {
        let safe = max(0, min(5, heartsRemaining))
        let strip = String(repeating: "❤️", count: safe)
                  + String(repeating: "🖤", count: 5 - safe)
        return hintUsed ? "\(strip) 💡" : strip
    }
}
