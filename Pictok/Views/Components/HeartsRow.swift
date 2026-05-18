import SwiftUI

struct HeartsRow: View {
    let remaining: Int
    let total: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Text(i < remaining ? "❤️" : "🖤")
                    .font(.system(size: 18))
            }
        }
        .accessibilityLabel("\(remaining) of \(total) lives remaining")
    }
}

#Preview {
    VStack {
        HeartsRow(remaining: 5)
        HeartsRow(remaining: 3)
        HeartsRow(remaining: 0)
    }
    .padding()
    .background(Color.pkPaper)
}
