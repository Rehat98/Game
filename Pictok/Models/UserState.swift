import Foundation

enum HintType: String, Codable, Equatable {
    case category
    case letter
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
    var livesLastRefilledAt: Date   // anchor for +1/4h math

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
            livesLastRefilledAt: now,
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
            recentEndlessIds: []
        )
    }
}

// Character is not Codable by default. Encode as a single-char String.
extension UserState {
    enum CodingKeys: String, CodingKey {
        case currentStreak, longestStreak, lastSolvedDate, streakFreezesAvailable
        case totalSolved, totalPlayed, guessDistribution
        case lives, livesLastRefilledAt
        case todayPuzzleId, todayWrongGuesses, todayCorrectGuesses
        case todayHintUsed, todayRevealedLetter, todaySolved, todayFailed
        case hasEverSolved, hasAskedForNotificationPermission
        case solvedPuzzleIds, failedPuzzleIds, lifetimeSolvedCount, recentEndlessIds
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
        // Tolerate legacy/foreign date encodings (e.g. ISO-8601 strings); the field
        // is being phased out in Task 2 of the endless-mode plan.
        livesLastRefilledAt     = (try? c.decodeIfPresent(Date.self, forKey: .livesLastRefilledAt)) ?? Date()
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
        try c.encode(livesLastRefilledAt,    forKey: .livesLastRefilledAt)
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
    }
}
