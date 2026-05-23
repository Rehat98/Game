import SwiftUI

struct StatsView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader

    @State private var archiveTarget: Puzzle? = nil
    @State private var peekTarget: PeekItem? = nil

    private struct PeekItem: Identifiable {
        let puzzle: Puzzle
        let outcome: SolveResult
        var id: String { puzzle.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Stats")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.pkInk)
                    .padding(.top, 12)

                section("Current run") {
                    pairCard(
                        leftValue: "\(store.state.currentStreak)",
                        leftLabel: "Streak",
                        leftPrefix: "🔥",
                        leftAccent: .pkRed,
                        rightValue: "\(store.state.longestStreak)",
                        rightLabel: "Best",
                        rightAccent: .pkInk
                    )
                }

                section("Lifetime") {
                    pairCard(
                        leftValue: "\(store.state.lifetimeSolvedCount)",
                        leftLabel: "Solved",
                        leftPrefix: nil,
                        leftAccent: .pkInk,
                        rightValue: winPercentText,
                        rightLabel: "Win rate",
                        rightAccent: .pkInk
                    )
                }

                section("Last 10 days") {
                    CalendarHeatmapView(history: store.state.solveHistory,
                                        today: PuzzleLoader.dateString(for: Date(), timeZone: .current),
                                        onCellTap: handleCellTap)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.pkPaper)
        .fullScreenCover(item: $archiveTarget) { puzzle in
            ArchiveView(puzzle: puzzle, store: store)
        }
        .sheet(item: $peekTarget) { item in
            AnswerPeekSheet(puzzle: item.puzzle, outcome: item.outcome)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.5))
            content()
        }
    }

    /// Two stats side-by-side in one flat white card with a vertical hairline divider.
    private func pairCard(leftValue: String,
                          leftLabel: String,
                          leftPrefix: String?,
                          leftAccent: Color,
                          rightValue: String,
                          rightLabel: String,
                          rightAccent: Color) -> some View {
        HStack(spacing: 0) {
            statBlock(value: leftValue, label: leftLabel, prefix: leftPrefix, accent: leftAccent)
            Rectangle()
                .fill(Color.pkInk.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 18)
            statBlock(value: rightValue, label: rightLabel, prefix: nil, accent: rightAccent)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.pkInk.opacity(0.07), radius: 14, x: 0, y: 6)
                .shadow(color: Color.pkInk.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }

    private func statBlock(value: String,
                           label: String,
                           prefix: String?,
                           accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let prefix {
                    Text(prefix).font(.system(size: 26))
                }
                Text(value)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    private var winPercentText: String {
        guard store.state.totalPlayed > 0 else { return "0%" }
        let pct = Int(round(Double(store.state.totalSolved) / Double(store.state.totalPlayed) * 100))
        return "\(pct)%"
    }

    private func handleCellTap(_ cell: CalendarHeatmapView.CalendarCell) {
        if cell.isToday || cell.isFuture { return }
        guard let puzzle = loader.allPuzzles.first(where: { $0.date == cell.date }) else {
            return
        }
        if let result = cell.result {
            peekTarget = PeekItem(puzzle: puzzle, outcome: result)
        } else {
            archiveTarget = puzzle
        }
    }

}
