import SwiftUI

/// Read-only reference card shown when a player taps a calendar cell for a
/// puzzle they have already solved or failed. No game state, no interactivity
/// beyond closing.
struct AnswerPeekSheet: View {
    let puzzle: Puzzle
    /// `.perfect` / `.solved` / `.failed` — the recorded outcome.
    let outcome: SolveResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(puzzle.emoji)
                .font(.system(size: 56))
                .padding(.top, 24)

            CategoryChip(category: puzzle.category, subcategory: puzzle.subcategory)

            Text(puzzle.answer)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(outcomeLine)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(outcomeColor)

            Spacer()

            StickerButton(title: "Got it", icon: nil, fill: .white) {
                dismiss()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.pkPaper.ignoresSafeArea())
    }

    private var outcomeLine: String {
        switch outcome {
        case .perfect: return "✓ Perfect run"
        case .solved:  return "✓ Solved"
        case .failed:  return "✗ Beat you"
        }
    }

    private var outcomeColor: Color {
        switch outcome {
        case .perfect: return .pkGreen
        case .solved:  return .pkInk.opacity(0.7)
        case .failed:  return .pkRed
        }
    }
}
