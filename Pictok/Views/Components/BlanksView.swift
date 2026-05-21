import SwiftUI

struct BlanksView: View {
    let answer: String                   // "THE DARK KNIGHT"
    let correctGuesses: Set<Character>   // letters the player has correctly guessed
    let revealedLetter: Character?       // single letter revealed by the hint (applies to all words)

    var body: some View {
        let words = answer.split(separator: " ", omittingEmptySubsequences: false)
        return VStack(spacing: 8) {
            ForEach(0..<words.count, id: \.self) { wIndex in
                HStack(spacing: 6) {
                    ForEach(Array(words[wIndex].enumerated()), id: \.offset) { (_, ch) in
                        slot(for: ch)
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Helpers

    /// Classic hangman reveal: a letter shows if the player has guessed it
    /// or if it matches the hint-revealed letter.
    private func isRevealed(_ ch: Character) -> Bool {
        correctGuesses.contains(ch) || ch == revealedLetter
    }

    @ViewBuilder
    private func slot(for ch: Character) -> some View {
        if !ch.isLetter {
            // Punctuation, numerals — always shown.
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
        } else if isRevealed(ch) {
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
                .frame(width: 22)
                .overlay(Rectangle().fill(Color.pkInk).frame(height: 3).offset(y: 14))
        } else {
            Text(" ")
                .font(.pkBlank)
                .frame(width: 22)
                .overlay(Rectangle().fill(Color.pkInk).frame(height: 3).offset(y: 14))
        }
    }

    private var accessibilityText: String {
        let mapped = answer.map { ch -> String in
            if !ch.isLetter { return String(ch) }
            return isRevealed(ch) ? String(ch) : "blank"
        }
        return mapped.joined(separator: " ")
    }
}

#Preview {
    VStack(spacing: 20) {
        BlanksView(answer: "THE DARK KNIGHT",
                   correctGuesses: ["T", "H", "E"],
                   revealedLetter: nil)
        BlanksView(answer: "BILLIE JEAN",
                   correctGuesses: ["B", "I", "L", "E"],
                   revealedLetter: "J")
    }
    .padding()
    .background(Color.pkPaper)
}
