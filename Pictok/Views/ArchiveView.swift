import SwiftUI

/// Full-screen game for a past Daily puzzle. Owns the ArchiveSession for the
/// presented puzzle. Auto-dismisses ~1-2s after a win or fail celebration
/// finishes so the player lands back on the Stats calendar with the cell now
/// coloured by the just-written outcome.
struct ArchiveView: View {
    @State var session: ArchiveSession
    @Environment(\.dismiss) private var dismiss

    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var showOneChanceAlert: Bool = false

    init(puzzle: Puzzle, store: UserStateStore) {
        _session = State(initialValue: ArchiveSession(puzzle: puzzle, store: store))
    }

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()
            content
            if showWinCelebration {
                WinCelebrationView(answer: session.puzzle.answer)
                    .transition(.opacity)
            }
            if showFailCelebration {
                FailCelebrationView(answer: session.puzzle.answer)
                    .transition(.opacity)
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                showWinCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    dismiss()
                }
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed {
                showFailCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + FailCelebrationView.totalDuration) {
                    dismiss()
                }
            }
        }
        .onChange(of: session.hasShownOneChanceWarning) { _, shown in
            if shown { showOneChanceAlert = true }
        }
        .alert("One chance left", isPresented: $showOneChanceAlert) {
            Button("OK") { showOneChanceAlert = false }
        } message: {
            Text("Make it count — one more wrong guess ends the puzzle.")
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            topBar
            HeartsRow(remaining: session.hearts)
            EmojiHeader(emoji: session.puzzle.emoji)
            CategoryChip(category: session.puzzle.category,
                         subcategory: session.puzzle.subcategory)
            BlanksView(answer: session.puzzle.answer,
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
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.pkInk)
                    .padding(10)
                    .sticker(fill: .white, cornerRadius: 16, strokeWidth: 2, shadowOffset: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(dateLabel)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private var dateLabel: String {
        // "2026-05-10" → "May 10"
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        inFormatter.timeZone = TimeZone(identifier: "UTC")
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "MMM d"
        outFormatter.timeZone = TimeZone(identifier: "UTC")
        if let d = inFormatter.date(from: session.puzzle.date) {
            return outFormatter.string(from: d)
        }
        return session.puzzle.date
    }
}
