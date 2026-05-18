import SwiftUI

struct KeyboardView: View {
    let guessed: Set<Character>           // both correct and wrong guesses
    let onTap: (Character) -> Void

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
        let isGuessed = guessed.contains(letter)
        Button {
            guard !isGuessed else { return }
            onTap(letter)
        } label: {
            Text(String(letter))
                .font(.pkKey)
                .foregroundStyle(isGuessed ? Color.pkInk.opacity(0.3) : Color.pkInk)
                .strikethrough(isGuessed)
                .frame(width: 30, height: 38)
        }
        .buttonStyle(.plain)
        .sticker(fill: isGuessed ? Color.pkPaper : .white,
                 cornerRadius: 6,
                 strokeWidth: 2,
                 shadowOffset: isGuessed ? 0 : 2)
        .accessibilityLabel("\(letter)\(isGuessed ? ", already guessed" : "")")
    }
}

#Preview {
    KeyboardView(guessed: ["E", "T", "Z"]) { _ in }
        .padding()
        .background(Color.pkPaper)
}
