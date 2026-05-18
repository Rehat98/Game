import Foundation

enum ShareCardBuilder {

    static func successCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            heartsRemaining: Int,
                            hintUsed: Bool,
                            currentStreak: Int,
                            url: String) -> String {
        let hearts = heartsBar(remaining: heartsRemaining)
        let hint = hintUsed ? " · 💡" : ""
        return """
        Pictok #\(puzzleNumber) 📌
        \(category.icon) \(difficulty.displayName)
        \(hearts)\(hint) · 🔥 \(currentStreak)

        \(url)
        """
    }

    static func failureCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            previousStreak: Int,
                            url: String) -> String {
        return """
        Pictok #\(puzzleNumber) 📌
        \(category.icon) \(difficulty.displayName) · today got me 🥲
        🔥 \(previousStreak) → 0

        \(url)
        """
    }

    private static func heartsBar(remaining: Int) -> String {
        let r = max(0, min(5, remaining))
        return String(repeating: "❤️", count: r) + String(repeating: "🖤", count: 5 - r)
    }
}
