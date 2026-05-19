import SwiftUI

struct BlanksView: View {
    let answer: String                   // "THE DARK KNIGHT"
    let correctGuesses: Set<Character>   // letters the player has correctly guessed
    let revealedLetter: Character?       // single letter revealed by the hint (applies to all words)

    var body: some View {
        let activeIdx = GameEngine.activeWordIndex(answer: answer, correctGuesses: correctGuesses)
        let words = answer.split(separator: " ", omittingEmptySubsequences: false)
        return VStack(spacing: 8) {
            ForEach(0..<words.count, id: \.self) { wIndex in
                HStack(spacing: 6) {
                    ForEach(Array(words[wIndex].enumerated()), id: \.offset) { (cIndex, ch) in
                        slot(for: ch,
                             absolutePosition: absolutePosition(wordIndex: wIndex,
                                                                charIndex: cIndex,
                                                                words: words),
                             activeWordIndex: activeIdx)
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Helpers

    /// Position of the character within `answer` (including spaces), as expected by
    /// `GameEngine.isPositionRevealed`.
    private func absolutePosition(wordIndex: Int,
                                  charIndex: Int,
                                  words: [Substring]) -> Int {
        var pos = 0
        for i in 0..<wordIndex {
            pos += words[i].count + 1  // +1 for the space delimiter
        }
        return pos + charIndex
    }

    private func isRevealed(ch: Character, position: Int, activeWordIndex: Int?) -> Bool {
        if GameEngine.isPositionRevealed(answer: answer,
                                         position: position,
                                         correctGuesses: correctGuesses,
                                         activeWordIndex: activeWordIndex) {
            return true
        }
        // Hint-revealed letter applies across the whole puzzle, not just the active word.
        if let r = revealedLetter, ch == r { return true }
        return false
    }

    @ViewBuilder
    private func slot(for ch: Character,
                      absolutePosition position: Int,
                      activeWordIndex: Int?) -> some View {
        if !ch.isLetter {
            // Punctuation, numerals — always shown.
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
        } else if isRevealed(ch: ch, position: position, activeWordIndex: activeWordIndex) {
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
        let activeIdx = GameEngine.activeWordIndex(answer: answer, correctGuesses: correctGuesses)
        let chars = Array(answer)
        let mapped = chars.enumerated().map { (position, ch) -> String in
            if !ch.isLetter { return String(ch) }
            return isRevealed(ch: ch, position: position, activeWordIndex: activeIdx) ? String(ch) : "blank"
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
