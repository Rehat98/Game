import Foundation

struct PuzzleLoader {
    let allPuzzles: [Puzzle]
    private let puzzlesByDate: [String: Puzzle]

    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([Puzzle].self, from: data)
        self.allPuzzles = decoded
        self.puzzlesByDate = Dictionary(uniqueKeysWithValues: decoded.map { ($0.date, $0) })
    }

    static func bundled(bundle: Bundle = .main) throws -> PuzzleLoader {
        guard let url = bundle.url(forResource: "puzzles", withExtension: "json") else {
            throw NSError(domain: "Pictok", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "puzzles.json missing from bundle"])
        }
        return try PuzzleLoader(url: url)
    }

    func puzzle(for date: Date, timeZone: TimeZone = .current) -> Puzzle? {
        let key = Self.dateString(for: date, timeZone: timeZone)
        return puzzlesByDate[key]
    }

    static func dateString(for date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Returns the 1-based puzzle number for the given puzzle (index in the sorted bundle).
    /// Used for the share card's "#N" stamp.
    func puzzleNumber(for puzzle: Puzzle) -> Int {
        let sorted = allPuzzles.sorted { $0.date < $1.date }
        return (sorted.firstIndex(of: puzzle) ?? 0) + 1
    }
}
