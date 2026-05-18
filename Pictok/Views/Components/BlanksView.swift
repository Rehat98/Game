import SwiftUI

struct BlanksView: View {
    let answer: String                   // "THE DARK KNIGHT"
    let revealedLetters: Set<Character>  // correct guesses ∪ revealed-by-hint

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

    @ViewBuilder
    private func slot(for ch: Character) -> some View {
        if !ch.isLetter {
            // Punctuation, numerals — always shown.
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
        } else if revealedLetters.contains(ch) {
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
            return revealedLetters.contains(ch) ? String(ch) : "blank"
        }
        return mapped.joined(separator: " ")
    }
}

#Preview {
    VStack(spacing: 20) {
        BlanksView(answer: "THE DARK KNIGHT", revealedLetters: ["E"])
        BlanksView(answer: "BILLIE JEAN", revealedLetters: ["L", "E"])
    }
    .padding()
    .background(Color.pkPaper)
}
