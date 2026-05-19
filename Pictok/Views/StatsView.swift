import SwiftUI
import Charts

struct StatsView: View {
    @Bindable var store: UserStateStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Stats")
                    .font(.pkTitle)
                    .padding(.top, 8)

                section("Current run") {
                    HStack(spacing: 12) {
                        statTile(label: "Streak",
                                 value: "\(store.state.currentStreak)",
                                 prefix: "🔥",
                                 accent: .pkRed)
                        statTile(label: "Best",
                                 value: "\(store.state.longestStreak)",
                                 prefix: nil,
                                 accent: .pkInk)
                    }
                }

                section("Lifetime") {
                    HStack(spacing: 12) {
                        statTile(label: "Solved",
                                 value: "\(store.state.lifetimeSolvedCount)",
                                 prefix: nil,
                                 accent: .pkGreen)
                        statTile(label: "Win %",
                                 value: winPercentText,
                                 prefix: nil,
                                 accent: .pkBlue)
                    }
                }

                section("Guess distribution") {
                    distributionChart
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.pkPaper)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Color.pkInk.opacity(0.55))
            content()
        }
    }

    private func statTile(label: String,
                          value: String,
                          prefix: String?,
                          accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let prefix {
                    Text(prefix).font(.system(size: 22))
                }
                Text(value)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(Color.pkInk.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .sticker(fill: .white, cornerRadius: 10, strokeWidth: 1.5, shadowOffset: 2)
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
                    y: .value("Count", bucket.1),
                    width: .fixed(18)
                )
                .foregroundStyle(Color.pkGreen.opacity(0.85))
                .cornerRadius(3)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
        .frame(height: 160)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sticker(fill: .white, cornerRadius: 10, strokeWidth: 1.5, shadowOffset: 2)
    }
}
