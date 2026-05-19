import SwiftUI

struct KeyboardView: View {
    let correctGuesses: Set<Character>
    let wrongGuesses: Set<Character>
    let onGuess: (Character) -> Void

    @State private var flashingLetter: Character? = nil
    @State private var flashIsCorrect: Bool = false
    @State private var shakeOffset: CGFloat = 0

    private static let rows: [[Character]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<Self.rows.count, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(Self.rows[r], id: \.self) { letter in
                        key(letter)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func key(_ letter: Character) -> some View {
        let isCorrect = correctGuesses.contains(letter)
        let isWrong = wrongGuesses.contains(letter)
        let isGuessed = isCorrect || isWrong
        let isFlashing = (flashingLetter == letter)
        let baseFill: Color = isCorrect ? Color.pkGreen.opacity(0.4)
                            : isWrong   ? Color.pkRed.opacity(0.4)
                            : .white
        let activeFill: Color = isFlashing
            ? (flashIsCorrect ? Color.pkGreen : Color.pkRed)
            : baseFill

        Button {
            guard !isGuessed else { return }
            handleTap(letter)
        } label: {
            Text(String(letter))
                .font(.pkKey)
                .foregroundStyle(isGuessed ? Color.pkInk.opacity(0.3) : Color.pkInk)
                .strikethrough(isGuessed)
                .frame(width: 30, height: 38)
        }
        .buttonStyle(.plain)
        .sticker(fill: activeFill,
                 cornerRadius: 6,
                 strokeWidth: 2,
                 shadowOffset: isGuessed && !isFlashing ? 0 : 2)
        .offset(x: (isFlashing && !flashIsCorrect) ? shakeOffset : 0)
        .accessibilityLabel("\(letter)\(isGuessed ? ", already guessed" : "")")
    }

    private func handleTap(_ letter: Character) {
        onGuess(letter)
        // Decide correct vs wrong based on whether the letter ended up in
        // correctGuesses or wrongGuesses (the parent has already mutated state).
        // Schedule on the next runloop so the parent state has propagated.
        DispatchQueue.main.async {
            let nowCorrect = correctGuesses.contains(letter)
            let nowWrong = wrongGuesses.contains(letter)
            guard nowCorrect || nowWrong else { return }
            flashingLetter = letter
            flashIsCorrect = nowCorrect
            if !nowCorrect {
                // Wrong: shake. Decaying oscillation over ~250ms.
                withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = -6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = 6 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = -3 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = 0 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                flashingLetter = nil
                shakeOffset = 0
            }
        }
    }
}

#Preview {
    KeyboardView(correctGuesses: ["E"], wrongGuesses: ["T", "Z"]) { _ in }
        .padding()
        .background(Color.pkPaper)
}
