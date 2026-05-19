import SwiftUI

struct HeartsRow: View {
    let remaining: Int
    let total: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                ZStack {
                    Text("🖤")
                    if i < remaining {
                        Text("❤️")
                            .transition(.scale(scale: 1.4).combined(with: .opacity))
                    }
                }
                .font(.system(size: 18))
            }
        }
        .animation(.easeOut(duration: 0.35), value: remaining)
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
