import SwiftUI
import Charts

struct StatsView: View {
    @Bindable var store: UserStateStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Stats").font(.pkTitle).padding(.top, 12)

                HStack(spacing: 16) {
                    statTile("🔥 Streak", "\(store.state.currentStreak)")
                    statTile("Best", "\(store.state.longestStreak)")
                }
                HStack(spacing: 16) {
                    statTile("Solved", "\(store.state.totalSolved)")
                    statTile("Win %", winPercentText)
                }
                HStack(spacing: 16) {
                    statTile("Total solved", "\(store.state.lifetimeSolvedCount)")
                }

                Text("Guess distribution").font(.pkSubtitle).padding(.top)
                distributionChart
            }
            .padding()
        }
        .background(Color.pkPaper)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.pkTitle)
            Text(label).font(.pkBody).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .sticker(fill: .white, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
    }

    private var winPercentText: String {
        guard store.state.totalPlayed > 0 else { return "—" }
        let pct = Int(round(Double(store.state.totalSolved) / Double(store.state.totalPlayed) * 100))
        return "\(pct)%"
    }

    private var distributionChart: some View {
        let dist = store.state.guessDistribution
        let maxKey = (dist.keys.max() ?? 0)
        let buckets = (0...max(5, maxKey)).map { ($0, dist[$0] ?? 0) }

        return Chart {
            ForEach(buckets, id: \.0) { bucket in
                BarMark(
                    x: .value("Wrong", "\(bucket.0)"),
                    y: .value("Count", bucket.1)
                )
                .foregroundStyle(Color.pkGreen)
                .cornerRadius(4)
            }
        }
        .frame(height: 180)
        .padding()
        .sticker(fill: .white, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
    }
}
