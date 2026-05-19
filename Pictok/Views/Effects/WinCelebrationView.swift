import SwiftUI

/// 1.8-second win celebration overlay: fireworks burst + bouncing "Solved!" text
/// + answer reveal + win sound. Self-contained — the parent simply presents
/// this view conditionally; it manages its own animation timing.
struct WinCelebrationView: View {
    static let totalDuration: TimeInterval = 1.8

    let answer: String

    @State private var textScale: CGFloat = 0.5
    @State private var answerOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Dimmed paper background so the fireworks pop.
            Color.pkPaper.opacity(0.85).ignoresSafeArea()

            FireworksEmitter()

            VStack(spacing: 18) {
                Text("🎉  Solved!  🎉")
                    .font(.pkTitle)
                    .foregroundStyle(Color.pkInk)
                    .scaleEffect(textScale)

                Text(answer)
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk)
                    .opacity(answerOpacity)
            }
        }
        .onAppear {
            SoundService.shared.play(.win)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                textScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                answerOpacity = 1.0
            }
        }
    }
}

#Preview {
    WinCelebrationView(answer: "TOY STORY")
}
