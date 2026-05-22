import SwiftUI

struct EndlessView: View {
    @State var session: EndlessSession

    init(loader: PuzzleLoader, store: UserStateStore) {
        let today = PuzzleLoader.dateString(for: Date())
        _session = State(initialValue: EndlessSession(allPuzzles: loader.allPuzzles,
                                                      store: store,
                                                      today: today))
    }

    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var showOneChanceAlert: Bool = false
    /// Set true after a celebration finishes its animation. Surfaces a "Next puzzle →"
    /// button so the player advances on their own beat instead of being auto-queued.
    @State private var awaitingNext: Bool = false
    /// Solved count for the current Endless session. Resets when the view is re-presented.
    @State private var solvedThisSession: Int = 0

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
            if awaitingNext {
                nextPuzzleOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                solvedThisSession += 1
                showWinCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showWinCelebration = false
                        awaitingNext = true
                    }
                }
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed {
                showFailCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + FailCelebrationView.totalDuration) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showFailCelebration = false
                        awaitingNext = true
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
            emptyPoolFallback
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Text(solvedCountLabel)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Spacer()
        }
    }

    private var solvedCountLabel: String {
        switch solvedThisSession {
        case 0: return "Just started"
        case 1: return "1 solved"
        default: return "\(solvedThisSession) solved"
        }
    }

    private var nextPuzzleOverlay: some View {
        ZStack {
            Color.pkPaper.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(solvedThisSession == 0
                     ? "Better luck next round."
                     : "Nice. Keep going?")
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk.opacity(0.7))

                StickerButton(title: "Next puzzle →", icon: nil, fill: .pkGreen) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        awaitingNext = false
                        session.advance()
                    }
                }
            }
        }
    }

    private var emptyPoolFallback: some View {
        VStack(spacing: 12) {
            Text("🎉").font(.system(size: 64))
            Text("You've played every puzzle for now! Come back tomorrow for a new Daily.")
                .font(.pkBody)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
