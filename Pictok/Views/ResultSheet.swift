import SwiftUI

struct ResultSheet: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle
    let puzzleNumber: Int     // passed in from parent (computed via PuzzleLoader.puzzleNumber(for:))
    @Environment(\.dismiss) private var dismiss

    private var solved: Bool { store.state.todaySolved }

    var body: some View {
        VStack(spacing: 20) {
            Text(solved ? "Solved!" : "Today got you 🥲")
                .font(.pkTitle)
                .padding(.top, 12)

            Text(puzzle.answer)
                .font(.pkSubtitle)
                .multilineTextAlignment(.center)

            CategoryChip(category: puzzle.category, subcategory: puzzle.subcategory)

            HStack(spacing: 24) {
                stat("Wrong", value: "\(store.state.todayWrongGuesses.count)")
                stat("❤️ left", value: "\(store.state.lives)")
                stat("Hint", value: (store.state.todayCategoryHintUsed || store.state.todayLetterHintUsed) ? "✓" : "No")
                stat("🔥", value: "\(store.state.currentStreak)")
            }

            Text(shareText)
                .font(.system(size: 14, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sticker(fill: .white, cornerRadius: 12, strokeWidth: 2, shadowOffset: 3)

            HStack(spacing: 12) {
                StickerButton(title: "Copy", icon: "📋", fill: .pkYellow) {
                    UIPasteboard.general.string = shareText
                }
                ShareLink(item: shareText) {
                    HStack(spacing: 8) {
                        Text("📤")
                        Text("Share").font(.pkSubtitle).foregroundStyle(Color.pkInk)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
                .sticker(fill: .pkGreen, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
            }

            Text(countdownText)
                .font(.pkBody)
                .foregroundStyle(.gray)
                .padding(.top, 4)

            Spacer()
        }
        .padding()
        .background(Color.pkPaper)
        .presentationDetents([.medium, .large])
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack {
            Text(value).font(.pkSubtitle)
            Text(label).font(.pkBody).foregroundStyle(.gray)
        }
    }

    private var shareText: String {
        if solved {
            return ShareCardBuilder.successCard(
                puzzleNumber: puzzleNumber,
                category: puzzle.category,
                difficulty: puzzle.difficulty,
                heartsRemaining: store.state.lives,
                hintUsed: store.state.todayCategoryHintUsed || store.state.todayLetterHintUsed,
                currentStreak: store.state.currentStreak,
                url: "pictok.pages.dev"
            )
        } else {
            // For failure, "previous streak" is the streak before fail reset.
            let prior = max(store.state.longestStreak, 0)
            return ShareCardBuilder.failureCard(
                puzzleNumber: puzzleNumber,
                category: puzzle.category,
                difficulty: puzzle.difficulty,
                previousStreak: prior,
                url: "pictok.pages.dev"
            )
        }
    }

    private var countdownText: String {
        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let interval = tomorrow.timeIntervalSince(now)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "Next puzzle in \(h)h \(m)m"
    }
}
