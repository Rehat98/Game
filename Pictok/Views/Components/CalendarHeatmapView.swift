import SwiftUI

/// Wordle-style 4-week activity grid for the Stats screen.
/// Green = perfect, yellow = solved with hint or heart loss, red = failed,
/// hollow = didn't play, dashed = future. Today gets a thick outline.
struct CalendarHeatmapView: View {
    let history: [SolveRecord]
    /// `YYYY-MM-DD` for today in the user's local timezone.
    let today: String
    /// Tap callback fired with the tapped cell's state. Default is a no-op so
    /// existing callers (previews, tests) need no change.
    var onCellTap: (CalendarCell) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            grid
            legend
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.pkInk.opacity(0.07), radius: 14, x: 0, y: 6)
                .shadow(color: Color.pkInk.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }

    private var grid: some View {
        let cells = Self.buildCalendar(today: today, history: history, weeks: 4)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return VStack(spacing: 8) {
            // Day-of-week labels (M T W T F S S).
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.pkInk.opacity(0.45))
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells.indices, id: \.self) { i in
                    Button {
                        onCellTap(cells[i])
                    } label: {
                        cellView(cells[i])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: CalendarCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let (fill, stroke, dashed) = appearance(for: cell)
        ZStack {
            shape.fill(fill)
            shape.strokeBorder(stroke,
                               style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
            if cell.isToday {
                shape
                    .strokeBorder(Color.pkInk, lineWidth: 2)
                    .padding(-3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func appearance(for cell: CalendarCell) -> (Color, Color, Bool) {
        if cell.isFuture {
            return (Color.clear, Color.pkInk.opacity(0.2), true)
        }
        switch cell.result {
        case .perfect: return (Color.pkGreen,  Color.pkInk, false)
        case .solved:  return (Color.pkYellow, Color.pkInk, false)
        case .failed:  return (Color.pkRed,    Color.pkInk, false)
        case nil:      return (Color.pkInk.opacity(0.06), Color.pkInk.opacity(0.25), false)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: .pkGreen,  label: "Perfect")
            legendRow(color: .pkYellow, label: "Solved with hint or lost hearts")
            legendRow(color: .pkRed,    label: "Failed")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Color.pkInk.opacity(0.75))
        .padding(.top, 4)
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.pkInk, lineWidth: 1.5)
                )
                .frame(width: 14, height: 14)
            Text(label)
        }
    }

    // MARK: Calendar math

    struct CalendarCell: Equatable {
        let date: String
        let result: SolveResult?
        let isToday: Bool
        let isFuture: Bool
    }

    /// Builds a flat 28-cell array (4 weeks × 7, Monday-first) ending in the week containing `today`.
    static func buildCalendar(today: String, history: [SolveRecord], weeks: Int = 4) -> [CalendarCell] {
        let formatter = ymdFormatter()
        guard let todayDate = formatter.date(from: today) else { return [] }

        var byDate = [String: SolveResult]()
        for h in history { byDate[h.date] = h.result }

        // Find Monday of the week containing today (UTC anchor since our YYYY-MM-DD strings are TZ-less keys).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let weekday = cal.component(.weekday, from: todayDate)        // 1=Sun, 2=Mon, ..., 7=Sat
        let daysFromMonday = (weekday == 1) ? 6 : (weekday - 2)
        guard let mondayThisWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: todayDate),
              let start = cal.date(byAdding: .day, value: -(weeks - 1) * 7, to: mondayThisWeek)
        else { return [] }

        var cells: [CalendarCell] = []
        for offset in 0..<(weeks * 7) {
            guard let cellDate = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = formatter.string(from: cellDate)
            cells.append(CalendarCell(
                date: key,
                result: byDate[key],
                isToday: key == today,
                isFuture: cellDate > todayDate
            ))
        }
        return cells
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
