import SwiftUI

/// 1.8-second fail overlay: gentle rain + "Oops, better luck next time!" text
/// + sad emoji + answer reveal + fail sound. Mirrors WinCelebrationView for the
/// loss state.
struct FailCelebrationView: View {
    static let totalDuration: TimeInterval = 1.8

    let answer: String

    @State private var emojiScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0.0
    @State private var answerOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.pkPaper.opacity(0.85).ignoresSafeArea()

            RainEmitter()

            VStack(spacing: 16) {
                Text("😞")
                    .font(.system(size: 72))
                    .scaleEffect(emojiScale)

                Text("Oops, better luck next time!")
                    .font(.pkTitle)
                    .foregroundStyle(Color.pkInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(textOpacity)

                Text(answer)
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk)
                    .opacity(answerOpacity)
            }
        }
        .onAppear {
            SoundService.shared.play(.fail)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                textOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.45)) {
                answerOpacity = 1.0
            }
        }
    }
}

#Preview {
    FailCelebrationView(answer: "WAR AND PEACE")
}
