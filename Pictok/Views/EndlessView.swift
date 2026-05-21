import SwiftUI

struct EndlessView: View {
    @State var session: EndlessSession
    @Environment(\.dismiss) private var dismiss

    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var showOneChanceAlert: Bool = false

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()
            content
            if showWinCelebration, let puzzle = session.currentPuzzle {
                WinCelebrationView(answer: puzzle.answer)
                    .transition(.opacity)
            }
            if showFailCelebration, let puzzle = session.currentPuzzle {
                FailCelebrationView(answer: puzzle.answer)
                    .transition(.opacity)
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                showWinCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    showWinCelebration = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        session.advance()
                    }
                }
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed {
                showFailCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + FailCelebrationView.totalDuration) {
                    showFailCelebration = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        session.advance()
                    }
                }
            }
        }
        .onChange(of: session.hasShownOneChanceWarning) { _, shown in
            if shown {
                showOneChanceAlert = true
            }
        }
        .alert("One chance left", isPresented: $showOneChanceAlert) {
            Button("OK") { showOneChanceAlert = false }
        } message: {
            Text("Make it count — one more wrong guess ends the puzzle.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let puzzle = session.currentPuzzle {
            VStack(spacing: 16) {
                topBar
                HeartsRow(remaining: session.hearts)
                EmojiHeader(emoji: puzzle.emoji)
                CategoryChip(category: puzzle.category, subcategory: nil)
                BlanksView(answer: puzzle.answer,
                           correctGuesses: session.correctGuesses,
                           revealedLetter: nil)
                HStack {
                    Spacer()
                    HintButton(
                        isEnabled: !session.hintUsedThisPuzzle && !session.isSolved && !session.isFailed,
                        action: { session.useHint() }
                    )
                }
                .padding(.horizontal, 8)
                if session.needsSubmit {
                    StickerButton(title: "Submit ✓", icon: nil, fill: .pkGreen) {
                        session.submit()
                    }
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                KeyboardView(
                    correctGuesses: session.correctGuesses,
                    wrongGuesses: session.wrongGuesses,
                    onGuess: { letter in session.guess(letter: letter) }
                )
            }
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.needsSubmit)
            .id(puzzle.id)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        } else {
            VStack(spacing: 12) {
                Text("🎉").font(.system(size: 64))
                Text("You've played every puzzle for now! Come back tomorrow for a new Daily.")
                    .font(.pkBody)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(Color.pkInk)
            }
            Spacer()
        }
    }
}
