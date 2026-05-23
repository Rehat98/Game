import SwiftUI

/// Last-10-days activity strip for the Stats screen. Two rows of five cells,
/// each cell labelled with its date number. Green = perfect, yellow = solved
/// with hint or heart loss, red = failed, hollow = didn't play. Today gets a
/// thick outline.
struct CalendarHeatmapView: View {
    let history: [SolveRecord]
    /// `YYYY-MM-DD` for today in the user's local timezone.
    let today: String
    /// Tap callback fired with the tapped cell's state. Default is a no-op so
    /// existing callers (previews, tests) need no change.
    var onCellTap: (CalendarCell) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            grid
            legend
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.pkInk.opacity(0.07), radius: 14, x: 0, y: 6)
                .shadow(color: Color.pkInk.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }

    private var grid: some View {
        let cells = Self.buildLastDays(today: today, history: history, days: 10)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(cells.indices, id: \.self) { i in
                VStack(spacing: 4) {
                    Button {
                        onCellTap(cells[i])
                    } label: {
                        cellView(cells[i])
                    }
                    .buttonStyle(.plain)
                    Text(Self.dayLabel(for: cells[i].date))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.pkInk.opacity(0.55))
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: CalendarCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let (fill, stroke) = appearance(for: cell)
        ZStack {
            shape.fill(fill)
            shape.strokeBorder(stroke, lineWidth: 2)
            if cell.isToday {
                shape
                    .strokeBorder(Color.pkInk, lineWidth: 2)
                    .padding(-3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func appearance(for cell: CalendarCell) -> (Color, Color) {
        switch cell.result {
        case .perfect: return (Color.pkGreen,  Color.pkInk)
        case .solved:  return (Color.pkYellow, Color.pkInk)
        case .failed:  return (Color.pkRed,    Color.pkInk)
        case nil:      return (Color.pkInk.opacity(0.06), Color.pkInk.opacity(0.25))
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendChip(color: .pkGreen,  label: "Perfect")
            legendChip(color: .pkYellow, label: "Solved")
            legendChip(color: .pkRed,    label: "Failed")
        }
        .font(.system(size: 11, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.pkInk.opacity(0.7))
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.pkInk, lineWidth: 1)
                )
                .frame(width: 11, height: 11)
            Text(label)
        }
    }

    // MARK: Calendar math

    struct CalendarCell: Equatable {
        let date: String
        let result: SolveResult?
        let isToday: Bool
        /// Always false for the last-10-days layout (today is the last cell);
        /// kept on the struct so the tap-routing in StatsView still compiles.
        let isFuture: Bool
    }

    /// Builds a flat `days`-cell array ending today.
    static func buildLastDays(today: String, history: [SolveRecord], days: Int = 10) -> [CalendarCell] {
        let formatter = ymdFormatter()
        guard let todayDate = formatter.date(from: today) else { return [] }

        var byDate = [String: SolveResult]()
        for h in history { byDate[h.date] = h.result }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: todayDate) else { return [] }

        var cells: [CalendarCell] = []
        for offset in 0..<days {
            guard let cellDate = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = formatter.string(from: cellDate)
            cells.append(CalendarCell(
                date: key,
                result: byDate[key],
                isToday: key == today,
                isFuture: false
            ))
        }
        return cells
    }

    static func dayLabel(for ymd: String) -> String {
        // "2026-05-23" → "23"
        let parts = ymd.split(separator: "-")
        return parts.last.map(String.init) ?? ymd
    }

    private static func ymdFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
