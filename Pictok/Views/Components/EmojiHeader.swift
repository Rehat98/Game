import SwiftUI

struct EmojiHeader: View {
    let emoji: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .sticker(fill: .white, cornerRadius: 20, strokeWidth: 3, shadowOffset: 5)
    }
}

#Preview {
    EmojiHeader(emoji: "🌃🦇🤡")
        .padding()
        .background(Color.pkPaper)
}
