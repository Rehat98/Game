import Foundation

enum HintType: String, Codable, Equatable {
    case category
    case letter
}

enum SolveResult: String, Codable, Equatable {
    case perfect    // solved with no hint and no wrong guesses
    case solved     // solved with hint or at least one wrong guess
    case failed     // hearts ran out
}

struct SolveRecord: Codable, Equatable {
    let date: String        // "YYYY-MM-DD"
    let result: SolveResult
}

struct UserState: Codable, Equatable {
    // Streak
    var currentStreak: Int
    var longestStreak: Int
    var lastSolvedDate: String?      // "YYYY-MM-DD"
    var streakFreezesAvailable: Int  // 0 or 1, resets weekly

    // Lifetime
    var totalSolved: Int
    var totalPlayed: Int
    var guessDistribution: [Int: Int]   // wrongGuessCount -> # of solves

    // Lives
    var lives: Int                  // 0..5

    // Today's puzzle progress (resumable)
    var todayPuzzleId: String?
    var todayWrongGuesses: [Character]
    var todayCorrectGuesses: [Character]
    var todayHintUsed: HintType?
    var todayRevealedLetter: Character?
    var todaySolved: Bool
    var todayFailed: Bool

    // First-solve flag for notification permission contextual prompt
    var hasEverSolved: Bool
    var hasAskedForNotificationPermission: Bool

    // Cumulative play history (Daily + Endless)
    var solvedPuzzleIds: Set<String>
    var failedPuzzleIds: Set<String>
    var lifetimeSolvedCount: Int

    // Endless dedup ring buffer (last 5 picks)
    var recentEndlessIds: [String]

    // Daily solve history (one entry per played Daily date) — drives the
    // last-4-weeks calendar on the Stats screen. Endless plays are NOT recorded.
    var solveHistory: [SolveRecord]

    /// First-launch ambassador: when true, the Daily tab serves `puzzle-001`
    /// (TOY STORY) regardless of today's date so the first puzzle a new user
    /// ever sees is a well-vetted ambassador. Cleared on first solve or fail
    /// (in `TodayView.applySolveSideEffects` / `applyFailSideEffects`). Fresh
    /// state has it true; existing users upgrading default to false.
    var ambassadorActive: Bool

    static func fresh(at now: Date) -> UserState {
        UserState(
            currentStreak: 0,
            longestStreak: 0,
            lastSolvedDate: nil,
            streakFreezesAvailable: 1,
            totalSolved: 0,
            totalPlayed: 0,
            guessDistribution: [:],
            lives: 5,
            todayPuzzleId: nil,
            todayWrongGuesses: [],
            todayCorrectGuesses: [],
            todayHintUsed: nil,
            todayRevealedLetter: nil,
            todaySolved: false,
            todayFailed: false,
            hasEverSolved: false,
            hasAskedForNotificationPermission: false,
            solvedPuzzleIds: [],
            failedPuzzleIds: [],
            lifetimeSolvedCount: 0,
            recentEndlessIds: [],
            solveHistory: [],
            ambassadorActive: true
        )
    }
}

// Character is not Codable by default. Encode as a single-char String.
extension UserState {
    enum CodingKeys: String, CodingKey {
        case currentStreak, longestStreak, lastSolvedDate, streakFreezesAvailable
        case totalSolved, totalPlayed, guessDistribution
        case lives
        case todayPuzzleId, todayWrongGuesses, todayCorrectGuesses
        case todayHintUsed, todayRevealedLetter, todaySolved, todayFailed
        case hasEverSolved, hasAskedForNotificationPermission
        case solvedPuzzleIds, failedPuzzleIds, lifetimeSolvedCount, recentEndlessIds
        case solveHistory
        case ambassadorActive
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak           = try c.decode(Int.self, forKey: .currentStreak)
        longestStreak           = try c.decode(Int.self, forKey: .longestStreak)
        lastSolvedDate          = try c.decodeIfPresent(String.self, forKey: .lastSolvedDate)
        streakFreezesAvailable  = try c.decode(Int.self, forKey: .streakFreezesAvailable)
        totalSolved             = try c.decode(Int.self, forKey: .totalSolved)
        totalPlayed             = try c.decode(Int.self, forKey: .totalPlayed)
        guessDistribution       = try c.decode([Int: Int].self, forKey: .guessDistribution)
        lives                   = try c.decode(Int.self, forKey: .lives)
        todayPuzzleId           = try c.decodeIfPresent(String.self, forKey: .todayPuzzleId)

        let wrongStrings        = try c.decode([String].self, forKey: .todayWrongGuesses)
        todayWrongGuesses       = wrongStrings.compactMap { $0.first }
        let correctStrings      = try c.decode([String].self, forKey: .todayCorrectGuesses)
        todayCorrectGuesses     = correctStrings.compactMap { $0.first }

        todayHintUsed           = try c.decodeIfPresent(HintType.self, forKey: .todayHintUsed)
        if let revealedString   = try c.decodeIfPresent(String.self, forKey: .todayRevealedLetter) {
            todayRevealedLetter = revealedString.first
        } else {
            todayRevealedLetter = nil
        }
        todaySolved             = try c.decode(Bool.self, forKey: .todaySolved)
        todayFailed             = try c.decode(Bool.self, forKey: .todayFailed)
        hasEverSolved           = try c.decodeIfPresent(Bool.self, forKey: .hasEverSolved) ?? false
        hasAskedForNotificationPermission = try c.decodeIfPresent(Bool.self, forKey: .hasAskedForNotificationPermission) ?? false
        solvedPuzzleIds        = try c.decodeIfPresent(Set<String>.self, forKey: .solvedPuzzleIds) ?? []
        failedPuzzleIds        = try c.decodeIfPresent(Set<String>.self, forKey: .failedPuzzleIds) ?? []
        lifetimeSolvedCount    = try c.decodeIfPresent(Int.self, forKey: .lifetimeSolvedCount) ?? totalSolved
        recentEndlessIds       = try c.decodeIfPresent([String].self, forKey: .recentEndlessIds) ?? []
        solveHistory           = try c.decodeIfPresent([SolveRecord].self, forKey: .solveHistory) ?? []
        // Defaults to false for existing users (pre-fix saved state has no key).
        // Truly fresh state goes through `UserState.fresh()` which sets it true.
        ambassadorActive       = try c.decodeIfPresent(Bool.self, forKey: .ambassadorActive) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(currentStreak,          forKey: .currentStreak)
        try c.encode(longestStreak,          forKey: .longestStreak)
        try c.encodeIfPresent(lastSolvedDate, forKey: .lastSolvedDate)
        try c.encode(streakFreezesAvailable, forKey: .streakFreezesAvailable)
        try c.encode(totalSolved,            forKey: .totalSolved)
        try c.encode(totalPlayed,            forKey: .totalPlayed)
        try c.encode(guessDistribution,      forKey: .guessDistribution)
        try c.encode(lives,                  forKey: .lives)
        try c.encodeIfPresent(todayPuzzleId, forKey: .todayPuzzleId)
        try c.encode(todayWrongGuesses.map  { String($0) }, forKey: .todayWrongGuesses)
        try c.encode(todayCorrectGuesses.map { String($0) }, forKey: .todayCorrectGuesses)
        try c.encodeIfPresent(todayHintUsed, forKey: .todayHintUsed)
        try c.encodeIfPresent(todayRevealedLetter.map { String($0) }, forKey: .todayRevealedLetter)
        try c.encode(todaySolved,            forKey: .todaySolved)
        try c.encode(todayFailed,            forKey: .todayFailed)
        try c.encode(hasEverSolved,          forKey: .hasEverSolved)
        try c.encode(hasAskedForNotificationPermission, forKey: .hasAskedForNotificationPermission)
        try c.encode(solvedPuzzleIds,     forKey: .solvedPuzzleIds)
        try c.encode(failedPuzzleIds,     forKey: .failedPuzzleIds)
        try c.encode(lifetimeSolvedCount, forKey: .lifetimeSolvedCount)
        try c.encode(recentEndlessIds,    forKey: .recentEndlessIds)
        try c.encode(solveHistory,        forKey: .solveHistory)
        try c.encode(ambassadorActive,    forKey: .ambassadorActive)
    }
}
