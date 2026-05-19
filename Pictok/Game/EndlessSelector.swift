import Foundation

final class EndlessSelector {
    private static let spoilerWindowDays = 7
    private var rng: any RandomNumberGenerator

    init(rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.rng = rng
    }

    /// Returns the next Endless puzzle, applying the 3-tier priority algorithm
    /// from spec §"Endless selection algorithm". Returns nil only when the pool
    /// is empty of every eligible pick (e.g., the only available puzzle is
    /// today's Daily, which is always excluded).
    func nextPuzzle(allPuzzles: [Puzzle], state: UserState, today: String) -> Puzzle? {
        // Exclude today's Daily from every tier.
        let candidates = allPuzzles.filter { $0.date != today }

        let seen = state.solvedPuzzleIds.union(state.failedPuzzleIds)
        let unseen = candidates.filter { !seen.contains($0.id) }

        // Tier 1: unseen + safe from spoilers (Daily date > 7 days away).
        let safe = unseen.filter { Self.daysBetween(today, $0.date) > Self.spoilerWindowDays }
        if let pick = randomPick(from: safe) { return pick }

        // Tier 2: unseen + near-future Daily (any remaining unseen).
        if let pick = randomPick(from: unseen) { return pick }

        // Tier 3: replay rotation — skip anything in recentEndlessIds.
        let recent = Set(state.recentEndlessIds)
        let replayable = candidates.filter { !recent.contains($0.id) }
        if let pick = randomPick(from: replayable) { return pick }

        // Pool too small (recentEndlessIds covers everything). Fall back to any candidate.
        return randomPick(from: candidates)
    }

    private func randomPick(from pool: [Puzzle]) -> Puzzle? {
        guard !pool.isEmpty else { return nil }
        let idx = Int.random(in: 0..<pool.count, using: &rng)
        return pool[idx]
    }

    /// Days between two YYYY-MM-DD strings (UTC). Returns Int.max on parse failure.
    private static func daysBetween(_ a: String, _ b: String) -> Int {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let da = f.date(from: a), let db = f.date(from: b) else { return Int.max }
        let comps = Calendar(identifier: .gregorian).dateComponents([.day], from: da, to: db)
        return comps.day ?? Int.max
    }
}
