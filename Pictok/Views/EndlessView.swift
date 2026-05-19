import SwiftUI

struct EndlessView: View {
    @State var session: EndlessSession
    @Environment(\.dismiss) private var dismiss

    @State private var showResultOverlay = false
    @State private var resultLabel: String = ""

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()
            content
            if showResultOverlay {
                resultOverlay
                    .transition(.opacity)
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                showResult(label: "Solved!")
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed, let puzzle = session.currentPuzzle {
                showResult(label: "Answer was \(puzzle.answer)")
            }
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
                Spacer()
                KeyboardView(guessed: session.correctGuesses.union(session.wrongGuesses)) { letter in
                    session.guess(letter: letter)
                }
            }
            .padding(.horizontal, 16)
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

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Text(resultLabel)
                .font(.pkTitle)
                .foregroundStyle(Color.pkInk)
            ProgressView()
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.pkPaper.opacity(0.95))
        )
    }

    private func showResult(label: String) {
        resultLabel = label
        withAnimation { showResultOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showResultOverlay = false }
            session.advance()
        }
    }
}
