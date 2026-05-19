# Pictok Endless Mode + Streaks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Endless Mode auto-queue flow below the existing Daily Puzzle, keep streak banking Daily-only, switch hearts from global-with-refill to per-puzzle, and migrate persisted `UserState` for existing users without crash.

**Architecture:** Daily Puzzle path stays as-is (TodayView, GameEngine helpers, daily streak logic). Endless is a new layer: a small `EndlessSelector` picks the next puzzle from the same 60-pool with 7-day Daily-spoiler protection; a `@Observable EndlessSession` orchestrates per-puzzle hearts and progress; an `EndlessView` renders the auto-queue UI. `UserState` gains four cumulative-progress fields with default values, and the `livesLastRefilledAt` field plus `UserStateStore.refillLives()` are removed.

**Tech Stack:** Swift 5, SwiftUI (iOS 17 deployment), XCTest, xcodegen, iPhone 17 / iOS 26.5 Simulator.

**Spec:** `docs/superpowers/specs/2026-05-19-endless-mode-streaks-design.md` — non-negotiable. Re-read it before any task.

---

## File structure

| Path                                        | Status   | Responsibility |
|---------------------------------------------|----------|----------------|
| `Pictok/Models/UserState.swift`             | modify   | Add `solvedPuzzleIds`, `failedPuzzleIds`, `lifetimeSolvedCount`, `recentEndlessIds`. Remove `livesLastRefilledAt`. Custom Codable tolerates old payloads (missing new fields → defaults; legacy `livesLastRefilledAt` → ignored). |
| `Pictok/Game/UserStateStore.swift`          | modify   | Remove `refillLives(now:)`, `refillInterval`, `maxLives`. No replacement — hearts logic moves into per-puzzle scope. |
| `Pictok/Game/EndlessSelector.swift`         | create   | `nextPuzzle(allPuzzles:state:today:)` → returns the next Endless pick using the 3-tier priority algorithm from spec §"Endless selection algorithm". |
| `Pictok/Game/EndlessSession.swift`          | create   | `@Observable` class. Owns current `puzzle`, in-memory `hearts: Int = 5`, `correctGuesses`, `wrongGuesses`. `guess(letter:)` mutates state, `advance()` calls selector for next puzzle, `recordResult()` writes to store (solvedPuzzleIds / failedPuzzleIds / lifetimeSolvedCount + recentEndlessIds). |
| `Pictok/Views/EndlessView.swift`            | create   | The Endless screen. Header (✕ to quit + heart row + emoji + category), keyboard, brief solved/failed overlay (~2s), auto-advance to next puzzle. |
| `Pictok/Views/TodayView.swift`              | modify   | Add a "▶ Play Endless" sticker button below the existing puzzle content. Tapping it sets a navigation flag the root view observes. |
| `Pictok/Views/StatsView.swift`              | modify   | Add a `lifetimeSolvedCount` row to the existing stat list. |
| `Pictok/PictokApp.swift`                    | modify   | Remove `store.refillLives()` from `setup()`. Add navigation to `EndlessView` (sheet or fullScreenCover). |
| `PictokTests/UserStateMigrationTests.swift` | create   | Tests: fresh-state encode/decode round-trip; legacy-payload (with `livesLastRefilledAt`, missing new fields) decodes with defaults. |
| `PictokTests/EndlessSelectorTests.swift`    | create   | Tests for each priority tier: unseen-safe, unseen-near-future fallback, replay rotation, recentEndlessIds dedup, exclusion of today's Daily. |
| `PictokTests/EndlessSessionTests.swift`     | create   | Tests: per-puzzle hearts reset on advance, solve increments `lifetimeSolvedCount` and adds to `solvedPuzzleIds`, fail adds to `failedPuzzleIds`, Endless solve does NOT change `currentStreak`. |

## Test command

```bash
xcodebuild test \
  -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -quiet
```

Re-run after every implementation task. The existing 7 test suites must keep passing in addition to the new tests.

After any task that creates or deletes a Swift file, regenerate the Xcode project:

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
```

`xcodegen` auto-picks up new files under `Pictok/` and `PictokTests/` based on `project.yml`'s globs.

---

## Phase 1 — Data model

### Task 1: Add new fields to `UserState` with Codable migration

**Files:**
- Modify: `Pictok/Models/UserState.swift`
- Create: `PictokTests/UserStateMigrationTests.swift`

- [ ] **Step 1: Write the failing migration test**

Create `PictokTests/UserStateMigrationTests.swift`:

```swift
import XCTest
@testable import Pictok

final class UserStateMigrationTests: XCTestCase {

    // A legacy JSON payload that includes `livesLastRefilledAt` (now removed)
    // and lacks the new endless-mode fields. Must decode without throwing,
    // with new fields defaulting to empty/zero.
    func test_decodesLegacyPayload_withDefaultsForNewFields() throws {
        let legacy = """
        {
          "currentStreak": 3,
          "longestStreak": 5,
          "lastSolvedDate": "2026-05-17",
          "streakFreezesAvailable": 1,
          "totalSolved": 7,
          "totalPlayed": 9,
          "guessDistribution": {"0": 2, "1": 4, "2": 1},
          "lives": 4,
          "livesLastRefilledAt": "2026-05-18T08:00:00Z",
          "todayPuzzleId": "puzzle-002",
          "todayWrongGuesses": ["B"],
          "todayCorrectGuesses": ["R", "O"],
          "todaySolved": false,
          "todayFailed": false,
          "hasEverSolved": true,
          "hasAskedForNotificationPermission": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(UserState.self, from: legacy)

        XCTAssertEqual(decoded.currentStreak, 3)
        XCTAssertEqual(decoded.lives, 4)
        XCTAssertEqual(decoded.solvedPuzzleIds, [])
        XCTAssertEqual(decoded.failedPuzzleIds, [])
        XCTAssertEqual(decoded.lifetimeSolvedCount, 0)
        XCTAssertEqual(decoded.recentEndlessIds, [])
    }

    // Fresh state must encode and decode losslessly, including the new fields.
    func test_freshState_encodesAndDecodes_withNewFields() throws {
        var fresh = UserState.fresh(at: Date(timeIntervalSince1970: 1747569600))
        fresh.solvedPuzzleIds = ["puzzle-001", "puzzle-005"]
        fresh.failedPuzzleIds = ["puzzle-010"]
        fresh.lifetimeSolvedCount = 2
        fresh.recentEndlessIds = ["puzzle-005", "puzzle-001"]

        let data = try JSONEncoder().encode(fresh)
        let roundTripped = try JSONDecoder().decode(UserState.self, from: data)

        XCTAssertEqual(roundTripped.solvedPuzzleIds, ["puzzle-001", "puzzle-005"])
        XCTAssertEqual(roundTripped.failedPuzzleIds, ["puzzle-010"])
        XCTAssertEqual(roundTripped.lifetimeSolvedCount, 2)
        XCTAssertEqual(roundTripped.recentEndlessIds, ["puzzle-005", "puzzle-001"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Regenerate the project (since a new test file was added) and run:

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/UserStateMigrationTests -quiet
```

Expected: build FAILS with "value of type 'UserState' has no member 'solvedPuzzleIds'" (and the other new fields). This confirms the test is exercising the new contract.

- [ ] **Step 3: Add the four new stored properties to `UserState`**

Edit `Pictok/Models/UserState.swift`. In the `struct UserState` body, after the existing fields, before `static func fresh(at:)`:

```swift
    // Cumulative play history (Daily + Endless)
    var solvedPuzzleIds: Set<String>
    var failedPuzzleIds: Set<String>
    var lifetimeSolvedCount: Int

    // Endless dedup ring buffer (last 5 picks)
    var recentEndlessIds: [String]
```

Update `UserState.fresh(at:)` to initialize them:

```swift
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
```

Note: `livesLastRefilledAt` stays for now — we remove it in **Task 2** after refactoring the store. Keeping it intact in Task 1 isolates the diff.

- [ ] **Step 4: Update `CodingKeys` and add encode/decode for the new fields**

In the `extension UserState` Codable block, update `CodingKeys`:

```swift
    enum CodingKeys: String, CodingKey {
        case currentStreak, longestStreak, lastSolvedDate, streakFreezesAvailable
        case totalSolved, totalPlayed, guessDistribution
        case lives, livesLastRefilledAt
        case todayPuzzleId, todayWrongGuesses, todayCorrectGuesses
        case todayHintUsed, todayRevealedLetter, todaySolved, todayFailed
        case hasEverSolved, hasAskedForNotificationPermission
        case solvedPuzzleIds, failedPuzzleIds, lifetimeSolvedCount, recentEndlessIds
    }
```

In `init(from decoder:)`, after the `hasAskedForNotificationPermission` line, add (note the `decodeIfPresent` with defaults — this is the migration path):

```swift
        solvedPuzzleIds        = try c.decodeIfPresent(Set<String>.self, forKey: .solvedPuzzleIds) ?? []
        failedPuzzleIds        = try c.decodeIfPresent(Set<String>.self, forKey: .failedPuzzleIds) ?? []
        lifetimeSolvedCount    = try c.decodeIfPresent(Int.self, forKey: .lifetimeSolvedCount) ?? 0
        recentEndlessIds       = try c.decodeIfPresent([String].self, forKey: .recentEndlessIds) ?? []
```

In `encode(to encoder:)`, after the `hasAskedForNotificationPermission` encode line, add:

```swift
        try c.encode(solvedPuzzleIds,     forKey: .solvedPuzzleIds)
        try c.encode(failedPuzzleIds,     forKey: .failedPuzzleIds)
        try c.encode(lifetimeSolvedCount, forKey: .lifetimeSolvedCount)
        try c.encode(recentEndlessIds,    forKey: .recentEndlessIds)
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/UserStateMigrationTests -quiet
```

Expected: both new tests pass.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: all suites pass (existing 7 + the new UserStateMigrationTests).

- [ ] **Step 7: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Models/UserState.swift \
  PictokTests/UserStateMigrationTests.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add endless-mode fields to UserState with Codable migration"
```

---

### Task 2: Remove `livesLastRefilledAt` and `UserStateStore.refillLives()`

**Files:**
- Modify: `Pictok/Models/UserState.swift`
- Modify: `Pictok/Game/UserStateStore.swift`
- Modify: `PictokTests/UserStateStoreTests.swift` (remove refill-specific tests; tests that depend on the field name go away)
- Modify: `PictokTests/UserStateCodableTests.swift` (remove the field from any fixtures)
- Modify: `Pictok/PictokApp.swift` (remove the `store.refillLives()` call)

- [ ] **Step 1: Find every reference to `livesLastRefilledAt` and `refillLives`**

```bash
grep -rn "livesLastRefilledAt\|refillLives\|refillInterval" \
  /Users/rehatchugh/emoji-decode/Pictok \
  /Users/rehatchugh/emoji-decode/PictokTests
```

Expected references: UserState.swift (property, CodingKeys, encode/decode, fresh), UserStateStore.swift (refillInterval constant, refillLives method), UserStateStoreTests.swift (existing refill tests), PictokApp.swift (`store.refillLives()` in `setup()`). The legacy-payload test from Task 1 also references the field name in the JSON string — leave that intact (the test exercises decoding old payloads, which must continue to work even after the field is removed from the struct).

- [ ] **Step 2: Remove the field from `UserState`**

In `Pictok/Models/UserState.swift`:
- Delete the line `var livesLastRefilledAt: Date`
- Remove `livesLastRefilledAt` from `CodingKeys`
- Remove the encode and decode lines for it
- Remove the `livesLastRefilledAt: now,` argument from `UserState.fresh(at:)`'s init call

Note: the legacy-payload test from Task 1 will still pass because `init(from:)` no longer attempts to decode the legacy field — it's simply ignored.

- [ ] **Step 3: Remove `refillLives()` and constants from `UserStateStore`**

In `Pictok/Game/UserStateStore.swift`:
- Delete the lines `private static let refillInterval: TimeInterval = 4 * 3600` and `private static let maxLives = 5`
- Delete the entire `refillLives(now:)` method

- [ ] **Step 4: Remove the `store.refillLives()` call from `PictokApp`**

In `Pictok/PictokApp.swift`, inside `setup()`, remove the line `store.refillLives()`. Keep `store.save()` and the rest.

- [ ] **Step 5: Delete the now-broken tests in `UserStateStoreTests.swift`**

Open `PictokTests/UserStateStoreTests.swift`. Delete the test methods that depend on lives-refill behavior:
- `test_refillLives_addsOneHeartPerFourHours`
- `test_refillLives_advancesAnchorByExactRefillCount`
- `test_refillLives_doesNothingWhenAlreadyMaxed`

Keep `test_freshStore_returnsDefaultState` and `test_save_persistsAcrossInstances`.

- [ ] **Step 6: Update `UserStateCodableTests.swift`**

Open `PictokTests/UserStateCodableTests.swift`. Find any `livesLastRefilledAt` reference (it's likely in a hard-coded JSON fixture or an `XCTAssertEqual` for fresh state). Replace with the new defaults shape; do not assert presence of `livesLastRefilledAt`.

- [ ] **Step 7: Build and run tests**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: all suites pass. The 3 deleted refill tests are gone; remaining UserStateStore tests still pass; UserStateMigrationTests still pass (legacy-payload test confirms the migration tolerance).

- [ ] **Step 8: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Models/UserState.swift \
  Pictok/Game/UserStateStore.swift Pictok/PictokApp.swift \
  PictokTests/UserStateStoreTests.swift PictokTests/UserStateCodableTests.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Remove global lives refill: drop livesLastRefilledAt and refillLives()"
```

---

## Phase 2 — Endless engine

### Task 3: `EndlessSelector` (selection algorithm)

**Files:**
- Create: `Pictok/Game/EndlessSelector.swift`
- Create: `PictokTests/EndlessSelectorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PictokTests/EndlessSelectorTests.swift`:

```swift
import XCTest
@testable import Pictok

final class EndlessSelectorTests: XCTestCase {

    // Helper: build a deterministic puzzle set with given dates.
    private func makePuzzles(_ specs: [(id: String, date: String)]) -> [Puzzle] {
        specs.map { spec in
            Puzzle(
                id: spec.id,
                date: spec.date,
                emoji: "🐝",
                answer: "BEE",
                category: .brand,
                subcategory: "test",
                difficulty: .medium
            )
        }
    }

    func test_priority1_picksUnseenSafePuzzle_excludingTodaysDaily() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily — must be excluded
            ("p2", "2026-05-20"),  // <7 days, skip in tier 1
            ("p3", "2026-05-28"),  // ≥7 days, eligible
            ("p4", "2026-06-15"),  // ≥7 days, eligible
        ])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p3", "p4"].contains(pick?.id),
                      "Expected p3 or p4 (tier-1 eligible), got \(pick?.id ?? "nil")")
    }

    func test_priority2_fallsBackToNearFutureWhenSafePoolEmpty() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily
            ("p2", "2026-05-20"),  // <7 days
            ("p3", "2026-05-22"),  // <7 days
        ])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p2", "p3"].contains(pick?.id),
                      "Expected p2 or p3 (tier-2), got \(pick?.id ?? "nil")")
    }

    func test_priority3_replayRotation_avoidsRecentEndlessIds() {
        let puzzles = makePuzzles([
            ("p1", "2026-05-19"),  // today's Daily, excluded
            ("p2", "2026-05-20"),
            ("p3", "2026-05-22"),
            ("p4", "2026-05-28"),
            ("p5", "2026-06-01"),
            ("p6", "2026-06-02"),
        ])
        var state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        // Everything seen.
        state.solvedPuzzleIds = ["p2", "p3", "p4", "p5", "p6"]
        // p2 and p3 are in the recent buffer — should be skipped in tier 3.
        state.recentEndlessIds = ["p2", "p3"]
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertTrue(["p4", "p5", "p6"].contains(pick?.id),
                      "Expected p4/p5/p6 (not in recent buffer), got \(pick?.id ?? "nil")")
    }

    func test_returnsNilWhenOnlyTodaysDailyExists() {
        let puzzles = makePuzzles([("p1", "2026-05-19")])
        let state = UserState.fresh(at: Date(timeIntervalSince1970: 0))
        let selector = EndlessSelector(rng: SystemRandomNumberGenerator())
        let pick = selector.nextPuzzle(allPuzzles: puzzles, state: state, today: "2026-05-19")
        XCTAssertNil(pick)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (no `EndlessSelector` exists yet)**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSelectorTests -quiet
```

Expected: BUILD FAILS with "cannot find 'EndlessSelector' in scope".

- [ ] **Step 3: Implement `EndlessSelector`**

Create `Pictok/Game/EndlessSelector.swift`. We use `final class` (not `struct`) because the selector holds a mutating RNG that the view layer references across renders:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSelectorTests -quiet
```

Expected: all four EndlessSelectorTests pass.

- [ ] **Step 5: Full test suite, then commit**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/EndlessSelector.swift \
  PictokTests/EndlessSelectorTests.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add EndlessSelector with 3-tier priority + spoiler protection"
```

---

### Task 4: `EndlessSession` (state orchestrator)

**Files:**
- Create: `Pictok/Game/EndlessSession.swift`
- Create: `PictokTests/EndlessSessionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PictokTests/EndlessSessionTests.swift`:

```swift
import XCTest
@testable import Pictok

final class EndlessSessionTests: XCTestCase {

    private func makePuzzles() -> [Puzzle] {
        [
            Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "BEE",
                   category: .brand, subcategory: "t", difficulty: .medium),
            Puzzle(id: "p2", date: "2026-05-28", emoji: "🐶", answer: "DOG",
                   category: .brand, subcategory: "t", difficulty: .medium),
            Puzzle(id: "p3", date: "2026-05-29", emoji: "🐱", answer: "CAT",
                   category: .brand, subcategory: "t", difficulty: .medium),
        ]
    }

    private func makeStore(state: UserState = UserState.fresh(at: Date(timeIntervalSince1970: 0))) -> UserStateStore {
        // Use a fresh in-memory UserDefaults suite so tests don't leak.
        let suiteName = "test.endless.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserStateStore(defaults: defaults)
        store.state = state
        return store
    }

    func test_freshSession_startsWith5Hearts_andFirstPuzzle() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        XCTAssertEqual(session.hearts, 5)
        XCTAssertNotNil(session.currentPuzzle)
        XCTAssertNotEqual(session.currentPuzzle?.id, "p1")  // today's daily excluded
    }

    func test_correctGuess_keepsHearts_butLetterIsTracked() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let correctLetter = session.currentPuzzle!.answer.first { $0.isLetter }!
        session.guess(letter: correctLetter)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertTrue(session.correctGuesses.contains(correctLetter))
    }

    func test_wrongGuess_decrementsHearts() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        // pick a letter guaranteed not in the answer
        let allAnswerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
        let wrongLetter: Character = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first { !allAnswerLetters.contains($0) }!
        session.guess(letter: wrongLetter)
        XCTAssertEqual(session.hearts, 4)
    }

    func test_solving_addsToSolvedSet_incrementsLifetime_andDoesNotChangeStreak() {
        let store = makeStore()
        let startStreak = store.state.currentStreak
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let solvedId = session.currentPuzzle!.id
        // Guess every unique letter of the answer.
        for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        XCTAssertTrue(session.isSolved)
        XCTAssertTrue(store.state.solvedPuzzleIds.contains(solvedId))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
        XCTAssertEqual(store.state.currentStreak, startStreak,
                       "Endless solve must NOT change the Daily-only streak.")
    }

    func test_failing_addsToFailedSet_andDoesNotIncrementLifetime() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let failedId = session.currentPuzzle!.id
        // Force-fail by burning all 5 hearts on wrong letters.
        let allAnswerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
        let wrongPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".filter { !allAnswerLetters.contains($0) }
        for ch in wrongPool.prefix(5) {
            session.guess(letter: ch)
        }
        XCTAssertTrue(session.isFailed)
        XCTAssertTrue(store.state.failedPuzzleIds.contains(failedId))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 0)
    }

    func test_advance_resetsHeartsTo5_andSwitchesPuzzle() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let firstId = session.currentPuzzle!.id
        // Solve the first puzzle.
        for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
        // Now burn one heart to verify it actually resets (sanity check is silly here
        // since the puzzle is solved — we still expect advance to set hearts to 5).
        session.advance()
        XCTAssertEqual(session.hearts, 5)
        XCTAssertNotEqual(session.currentPuzzle?.id, firstId)
    }

    func test_advance_addsPreviousIdToRecentEndlessIds_ringBufferAt5() {
        let store = makeStore()
        let session = EndlessSession(allPuzzles: makePuzzles(),
                                     store: store,
                                     today: "2026-05-19")
        let firstId = session.currentPuzzle!.id
        session.advance()
        XCTAssertEqual(store.state.recentEndlessIds.last, firstId)
        XCTAssertLessThanOrEqual(store.state.recentEndlessIds.count, 5)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (no `EndlessSession` exists)**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: BUILD FAILS with "cannot find 'EndlessSession' in scope".

- [ ] **Step 3: Implement `EndlessSession`**

Create `Pictok/Game/EndlessSession.swift`:

```swift
import Foundation
import Observation

@Observable
final class EndlessSession {
    private static let maxHearts = 5
    private static let recentIdsBufferSize = 5

    private let allPuzzles: [Puzzle]
    private let store: UserStateStore
    private let today: String
    private let selector: EndlessSelector

    private(set) var currentPuzzle: Puzzle?
    private(set) var hearts: Int = maxHearts
    private(set) var correctGuesses: Set<Character> = []
    private(set) var wrongGuesses: Set<Character> = []
    private(set) var isSolved: Bool = false
    private(set) var isFailed: Bool = false

    init(allPuzzles: [Puzzle], store: UserStateStore, today: String,
         selector: EndlessSelector = EndlessSelector()) {
        self.allPuzzles = allPuzzles
        self.store = store
        self.today = today
        self.selector = selector
        self.currentPuzzle = selector.nextPuzzle(allPuzzles: allPuzzles,
                                                 state: store.state,
                                                 today: today)
    }

    func guess(letter: Character) {
        guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return }
        let upper = Character(String(letter).uppercased())
        if correctGuesses.contains(upper) || wrongGuesses.contains(upper) { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle) {
            correctGuesses.insert(upper)
            if GameEngine.isSolved(answer: puzzle.answer,
                                   correctGuesses: correctGuesses,
                                   revealedLetter: nil) {
                isSolved = true
                recordSolve(id: puzzle.id)
            }
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
            if GameEngine.isFailed(lives: hearts) {
                isFailed = true
                recordFail(id: puzzle.id)
            }
        }
    }

    func advance() {
        if let prevId = currentPuzzle?.id {
            var buffer = store.state.recentEndlessIds
            buffer.append(prevId)
            if buffer.count > Self.recentIdsBufferSize {
                buffer.removeFirst(buffer.count - Self.recentIdsBufferSize)
            }
            store.state.recentEndlessIds = buffer
            store.save()
        }
        hearts = Self.maxHearts
        correctGuesses = []
        wrongGuesses = []
        isSolved = false
        isFailed = false
        currentPuzzle = selector.nextPuzzle(allPuzzles: allPuzzles,
                                            state: store.state,
                                            today: today)
    }

    private func recordSolve(id: String) {
        store.state.solvedPuzzleIds.insert(id)
        store.state.lifetimeSolvedCount += 1
        store.save()
    }

    private func recordFail(id: String) {
        store.state.failedPuzzleIds.insert(id)
        store.save()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: all 7 EndlessSessionTests pass.

- [ ] **Step 5: Full test suite, then commit**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/EndlessSession.swift \
  PictokTests/EndlessSessionTests.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add EndlessSession orchestrator with per-puzzle hearts"
```

---

## Phase 2.5 — Word-by-word reveal mechanic

Discovered mid-implementation: typing letters in a multi-word puzzle reveals them in **every word simultaneously**, which makes long answers trivially easy. Pivoting to **sequential word-by-word reveal**: typing only reveals letters in the active word; connector words (AND, OF, THE, A, IN, etc.) auto-reveal at puzzle start; wrong guess = letter not in current active word costs a heart globally.

### Task WBW-1: GameEngine word-by-word helpers

**Files:**
- Modify: `Pictok/Game/GameEngine.swift`
- Create: `PictokTests/GameEngineWordByWordTests.swift`

- [ ] **Step 1: Write the tests first**

```swift
import XCTest
@testable import Pictok

final class GameEngineWordByWordTests: XCTestCase {

    func test_wordBreakdown_singleWord() {
        let bd = GameEngine.wordBreakdown(answer: "BELOVED")
        XCTAssertEqual(bd.words, ["BELOVED"])
        XCTAssertEqual(bd.connectorIndices, [])
    }

    func test_wordBreakdown_multiWordWithConnectors() {
        let bd = GameEngine.wordBreakdown(answer: "PRIDE AND PREJUDICE")
        XCTAssertEqual(bd.words, ["PRIDE", "AND", "PREJUDICE"])
        XCTAssertEqual(bd.connectorIndices, [1])
    }

    func test_wordBreakdown_multipleConnectors() {
        let bd = GameEngine.wordBreakdown(answer: "CALL OF THE WILD")
        XCTAssertEqual(bd.words, ["CALL", "OF", "THE", "WILD"])
        XCTAssertEqual(bd.connectorIndices, [1, 2])
    }

    func test_activeWordIndex_singleWord_unsolved() {
        let idx = GameEngine.activeWordIndex(answer: "BELOVED", correctGuesses: ["B", "E"])
        XCTAssertEqual(idx, 0)
    }

    func test_activeWordIndex_singleWord_fullySolved_returnsNil() {
        let idx = GameEngine.activeWordIndex(answer: "BEE", correctGuesses: ["B", "E"])
        XCTAssertNil(idx)
    }

    func test_activeWordIndex_skipsConnectors() {
        // "PRIDE AND PREJUDICE" — index 1 is "AND" (connector). Player has solved PRIDE fully.
        let idx = GameEngine.activeWordIndex(answer: "PRIDE AND PREJUDICE",
                                             correctGuesses: ["P", "R", "I", "D", "E"])
        XCTAssertEqual(idx, 2, "Should skip AND and land on PREJUDICE")
    }

    func test_activeWordIndex_returnsFirstUnsolvedNonConnector() {
        // "TOY STORY" — TOY needs T,O,Y. Player has T but not O,Y.
        let idx = GameEngine.activeWordIndex(answer: "TOY STORY", correctGuesses: ["T"])
        XCTAssertEqual(idx, 0)
    }

    func test_activeWordIndex_advancesWhenFirstWordComplete() {
        // "TOY STORY" — player has T,O,Y. TOY is complete; STORY needs S,T,O,R,Y.
        let idx = GameEngine.activeWordIndex(answer: "TOY STORY", correctGuesses: ["T", "O", "Y"])
        XCTAssertEqual(idx, 1)
    }

    func test_isCorrect_inWord_matchesLettersOnlyInActiveWord() {
        // "TOY STORY", active = 0 (TOY). S is in STORY only.
        XCTAssertFalse(GameEngine.isCorrect(letter: "S", inWord: 0, of: "TOY STORY"))
        XCTAssertTrue(GameEngine.isCorrect(letter: "T", inWord: 0, of: "TOY STORY"))
        XCTAssertTrue(GameEngine.isCorrect(letter: "S", inWord: 1, of: "TOY STORY"))
    }

    func test_isCorrect_caseInsensitive() {
        XCTAssertTrue(GameEngine.isCorrect(letter: "t", inWord: 0, of: "TOY STORY"))
    }

    func test_isSolved_byWord_singleWord() {
        XCTAssertTrue(GameEngine.isSolvedByWord(answer: "BEE", correctGuesses: ["B", "E"]))
        XCTAssertFalse(GameEngine.isSolvedByWord(answer: "BEE", correctGuesses: ["B"]))
    }

    func test_isSolved_byWord_multiWordWithConnectors() {
        // PRIDE AND PREJUDICE — connectors auto-solved; need PRIDE + PREJUDICE letters.
        let needed: Set<Character> = ["P", "R", "I", "D", "E", "J", "U"]
        XCTAssertTrue(GameEngine.isSolvedByWord(answer: "PRIDE AND PREJUDICE", correctGuesses: needed))
    }

    func test_isPositionRevealed_connectorAlwaysRevealed() {
        // PRIDE AND PREJUDICE — char at index 6 is 'A' (start of AND).
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "PRIDE AND PREJUDICE",
                                                    position: 6,
                                                    correctGuesses: [],
                                                    activeWordIndex: 0))
    }

    func test_isPositionRevealed_activeWordLetterInGuesses() {
        // TOY STORY — position 0 ('T') with T guessed, active=0.
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                    position: 0,
                                                    correctGuesses: ["T"],
                                                    activeWordIndex: 0))
    }

    func test_isPositionRevealed_futureWordHiddenEvenIfLetterGuessed() {
        // TOY STORY — position 4 ('T' in STORY) with T guessed, active=0.
        XCTAssertFalse(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                     position: 4,
                                                     correctGuesses: ["T"],
                                                     activeWordIndex: 0),
                       "T in STORY must stay hidden while TOY is the active word")
    }

    func test_isPositionRevealed_pastWordRevealedWithGuess() {
        // TOY STORY — position 0 ('T' in TOY) with T guessed, active=1 (advanced).
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                    position: 0,
                                                    correctGuesses: ["T", "O", "Y"],
                                                    activeWordIndex: 1))
    }
}
```

- [ ] **Step 2: Run to verify fail**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/GameEngineWordByWordTests -quiet
```

Expected: BUILD FAILS — `GameEngine.wordBreakdown` and friends don't exist yet.

- [ ] **Step 3: Add helpers to `GameEngine.swift`**

Append to `Pictok/Game/GameEngine.swift`:

```swift
extension GameEngine {

    /// Common English stop/connector words that are auto-revealed at puzzle start
    /// so the player doesn't have to type them letter by letter.
    static let connectorWords: Set<String> = [
        "A", "AN", "AND", "AS", "AT", "BY", "FOR", "IN", "IS", "IT",
        "OF", "ON", "OR", "TO", "THE"
    ]

    struct WordBreakdown: Equatable {
        let words: [String]
        let connectorIndices: Set<Int>
    }

    /// Splits the answer into words and identifies which indices are connectors.
    static func wordBreakdown(answer: String) -> WordBreakdown {
        let words = answer.split(separator: " ").map(String.init)
        let connectors = Set(words.enumerated().compactMap { (idx, w) -> Int? in
            connectorWords.contains(w) ? idx : nil
        })
        return WordBreakdown(words: words, connectorIndices: connectors)
    }

    /// Returns the index of the first non-connector word that isn't fully solved.
    /// Returns nil when every non-connector word's letters are all in correctGuesses.
    static func activeWordIndex(answer: String,
                                correctGuesses: Set<Character>) -> Int? {
        let bd = wordBreakdown(answer: answer)
        for (idx, word) in bd.words.enumerated() {
            if bd.connectorIndices.contains(idx) { continue }
            let neededLetters = Set(word.filter { $0.isLetter })
            if !neededLetters.isSubset(of: correctGuesses) {
                return idx
            }
        }
        return nil
    }

    /// Whether the given letter appears in the word at `wordIndex` of `answer`.
    static func isCorrect(letter: Character, inWord wordIndex: Int, of answer: String) -> Bool {
        let upper = Character(String(letter).uppercased())
        let bd = wordBreakdown(answer: answer)
        guard wordIndex < bd.words.count else { return false }
        return bd.words[wordIndex].contains(upper)
    }

    /// Word-by-word solve check: the puzzle is solved when every non-connector
    /// word's letters are all in correctGuesses.
    static func isSolvedByWord(answer: String, correctGuesses: Set<Character>) -> Bool {
        return activeWordIndex(answer: answer, correctGuesses: correctGuesses) == nil
    }

    /// Whether the character at `position` of `answer` should currently be visible.
    /// Connector-word positions are always revealed; positions in past/current
    /// words reveal if the letter is in correctGuesses; future-word positions stay hidden.
    static func isPositionRevealed(answer: String,
                                   position: Int,
                                   correctGuesses: Set<Character>,
                                   activeWordIndex: Int?) -> Bool {
        let chars = Array(answer)
        guard position < chars.count else { return false }
        let ch = chars[position]
        if !ch.isLetter { return true }  // spaces, punctuation always "revealed"

        // Determine which word index this position belongs to.
        let bd = wordBreakdown(answer: answer)
        var charCursor = 0
        for (idx, word) in bd.words.enumerated() {
            let wordRange = charCursor..<(charCursor + word.count)
            if wordRange.contains(position) {
                // Connectors always shown.
                if bd.connectorIndices.contains(idx) { return true }
                // Past + current word: reveal if letter guessed.
                let active = activeWordIndex ?? bd.words.count
                if idx <= active && correctGuesses.contains(ch) { return true }
                return false
            }
            charCursor += word.count + 1  // +1 for the space delimiter
        }
        return false
    }
}
```

- [ ] **Step 4: Run tests to confirm pass**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/GameEngineWordByWordTests -quiet
```

Expected: all 15 new tests pass.

- [ ] **Step 5: Full test suite, then commit**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/GameEngine.swift \
  PictokTests/GameEngineWordByWordTests.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add word-by-word GameEngine helpers (connectors, active word, position reveal)"
```

---

### Task WBW-2: BlanksView uses word-by-word reveal

**Files:**
- Modify: `Pictok/Views/Components/BlanksView.swift`

- [ ] **Step 1: Read the current `BlanksView`** to understand the rendering approach.

- [ ] **Step 2: Update the render rule**

Replace the existing per-character render logic with one that uses `GameEngine.isPositionRevealed`. Inputs needed: `answer`, `correctGuesses`, `revealedLetter` (still supported for the hint), `activeWordIndex`.

A reasonable update — calculate `activeWordIndex` once via `GameEngine.activeWordIndex(answer:correctGuesses:)` and then call `GameEngine.isPositionRevealed` per character to decide whether to render the letter or a blank.

The existing API was likely `BlanksView(answer:correctGuesses:revealedLetter:)`. Keep that signature; compute the active word internally. No new parameters needed.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Components/BlanksView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "BlanksView: reveal letters word-by-word via active-word index"
```

---

### Task WBW-3: Daily flow (TodayView) uses word-by-word

**Files:**
- Modify: `Pictok/Views/TodayView.swift`

In the Daily-puzzle flow, when the player taps a letter:

1. Compute `activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer, correctGuesses: state.todayCorrectGuesses)`
2. If `activeIdx == nil`, the puzzle is solved — no-op.
3. Otherwise:
   - `correct = GameEngine.isCorrect(letter: upper, inWord: activeIdx!, of: puzzle.answer)`
   - If correct: add to `todayCorrectGuesses`. If `GameEngine.isSolvedByWord(answer: puzzle.answer, correctGuesses: ...)` → mark `todaySolved = true`, bank streak.
   - If wrong: add to `todayWrongGuesses`. `state.lives -= 1`. If lives ≤ 0 → mark `todayFailed = true`, reset streak.

The existing reveal-letter hint (single letter forced into `todayRevealedLetter`) keeps working: BlanksView will treat the revealed letter as if it were in `correctGuesses` for rendering (existing behavior).

- [ ] **Step 1: Read TodayView's guess handler.**
- [ ] **Step 2: Replace `GameEngine.isCorrect(letter:in:)` with `GameEngine.isCorrect(letter:inWord:of:)` using the computed `activeIdx`.**
- [ ] **Step 3: Replace `GameEngine.isSolved(answer:correctGuesses:revealedLetter:)` with `GameEngine.isSolvedByWord(answer:correctGuesses:)`** (note: `revealedLetter` is still applied for rendering, but solve check is via word index per active-word semantics).
- [ ] **Step 4: Build and run.**
- [ ] **Step 5: Run all tests; commit.**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "TodayView Daily flow: switch to word-by-word reveal mechanic"
```

---

### Task WBW-4: EndlessSession uses word-by-word

**Files:**
- Modify: `Pictok/Game/EndlessSession.swift`
- Modify: `PictokTests/EndlessSessionTests.swift` (the wrong-guess test needs updating)

The existing `guess(letter:)` calls `GameEngine.isCorrect(letter:in:)`. Switch to the word-by-word variant:

```swift
func guess(letter: Character) {
    guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return }
    let upper = Character(String(letter).uppercased())
    if correctGuesses.contains(upper) || wrongGuesses.contains(upper) { return }

    guard let activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer,
                                                     correctGuesses: correctGuesses) else {
        // Already solved (shouldn't happen because of the isSolved guard, but safe).
        return
    }

    if GameEngine.isCorrect(letter: upper, inWord: activeIdx, of: puzzle.answer) {
        correctGuesses.insert(upper)
        if GameEngine.isSolvedByWord(answer: puzzle.answer, correctGuesses: correctGuesses) {
            isSolved = true
            recordSolve(id: puzzle.id)
        }
    } else {
        wrongGuesses.insert(upper)
        hearts -= 1
        if GameEngine.isFailed(lives: hearts) {
            isFailed = true
            recordFail(id: puzzle.id)
        }
    }
}
```

The existing tests still pass for single-word puzzles ("BEE", "DOG", "CAT"). Add one new test for a multi-word puzzle to cover the new behavior:

```swift
func test_wrongGuessInCurrentWord_evenIfLetterInLaterWord_decrementsHearts() {
    // Create a puzzle with multi-word answer where letters in word 2 are NOT in word 1.
    let multiPuzzle = Puzzle(id: "p_multi", date: "2026-05-28", emoji: "🐝🦴",
                             answer: "BEE BONE",
                             category: .brand, subcategory: "t", difficulty: .medium)
    let allPuzzles = [
        Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "X",
               category: .brand, subcategory: "t", difficulty: .medium),
        multiPuzzle
    ]
    let store = makeStore()
    let session = EndlessSession(allPuzzles: allPuzzles,
                                 store: store,
                                 today: "2026-05-19")
    // Force the session onto the multi-word puzzle.
    // Since both 'p1' and 'p_multi' could be picked, we just guarantee multi-puzzle is the
    // only eligible one by marking p1 as today's daily (above).
    XCTAssertEqual(session.currentPuzzle?.id, "p_multi")

    // 'O' is in BONE (word 1) but NOT in BEE (word 0, active). Should cost a heart.
    session.guess(letter: "O")
    XCTAssertEqual(session.hearts, 4, "O is not in active word BEE — must cost a heart")
}
```

- [ ] **Step 1: Update EndlessSession.guess(letter:)** per the above.
- [ ] **Step 2: Add the multi-word test.**
- [ ] **Step 3: Run all tests, ensure full suite green.**
- [ ] **Step 4: Commit.**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/EndlessSession.swift \
  PictokTests/EndlessSessionTests.swift
git -C /Users/rehatchugh/emoji-decode commit -m "EndlessSession: switch to word-by-word reveal mechanic"
```

---

## Phase 3 — UI

### Task 5: `EndlessView` — the auto-queue screen

**Files:**
- Create: `Pictok/Views/EndlessView.swift`

This view has no unit tests (SwiftUI views are typically smoke-tested via simulator). The smoke test happens in Task 9.

- [ ] **Step 1: Write `EndlessView`**

Create `Pictok/Views/EndlessView.swift`:

```swift
import SwiftUI

struct EndlessView: View {
    @State var session: EndlessSession
    @Environment(\.dismiss) private var dismiss

    @State private var showResultOverlay = false
    @State private var resultLabel: String = ""

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()
            content
            if showResultOverlay {
                resultOverlay
                    .transition(.opacity)
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                showResult(label: "Solved!")
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed, let puzzle = session.currentPuzzle {
                showResult(label: "Answer was \(puzzle.answer)")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let puzzle = session.currentPuzzle {
            VStack(spacing: 16) {
                topBar
                HeartsRow(hearts: session.hearts)
                EmojiHeader(emoji: puzzle.emoji)
                CategoryChip(category: puzzle.category, subcategory: nil)
                BlanksView(answer: puzzle.answer,
                           correctGuesses: session.correctGuesses,
                           revealedLetter: nil)
                Spacer()
                KeyboardView(
                    correctGuesses: session.correctGuesses,
                    wrongGuesses: session.wrongGuesses,
                    onGuess: { letter in session.guess(letter: letter) }
                )
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 12) {
                Text("🎉").font(.system(size: 64))
                Text("You've played every puzzle for now! Come back tomorrow for a new Daily.")
                    .font(.pkBody)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(Color.pkInk)
            }
            Spacer()
        }
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Text(resultLabel)
                .font(.pkTitle)
                .foregroundStyle(Color.pkInk)
            ProgressView()
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.pkPaper.opacity(0.95))
        )
    }

    private func showResult(label: String) {
        resultLabel = label
        withAnimation { showResultOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showResultOverlay = false }
            session.advance()
        }
    }
}
```

- [ ] **Step 2: Regenerate project and build**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/EndlessView.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add EndlessView auto-queue screen"
```

---

### Task 6: TodayView — add "Play Endless" entry point

**Files:**
- Modify: `Pictok/Views/TodayView.swift`

The Daily-Puzzle UI inside `TodayView` is unchanged. We add a "▶ Play Endless" sticker button below the existing content, plus a binding the parent can observe to present `EndlessView`.

- [ ] **Step 1: Read the current `TodayView`**

Open `Pictok/Views/TodayView.swift`. Identify where the puzzle and result UI live. We want to add the button below the main `VStack` content, above any bottom safe area.

- [ ] **Step 2: Add `onPlayEndless` closure parameter**

In the `TodayView` declaration, after the existing properties, add:

```swift
    var onPlayEndless: () -> Void = {}
```

- [ ] **Step 3: Add the Endless button to the layout**

Find the outermost `VStack` (or `ScrollView`) in TodayView's `body`. Just before the closing brace of the main content container, add:

```swift
            StickerButton(title: "Play Endless", icon: "▶️", fill: .pkGreen) {
                onPlayEndless()
            }
            .padding(.top, 12)
```

If TodayView has both an in-progress and a solved/failed state, add the button to the in-progress state. The solved/failed state already shows ResultSheet with the share button; placing the Endless button on top of that screen as well is fine — adjust placement so it's visible regardless of puzzle outcome.

- [ ] **Step 4: Build to verify the view still compiles**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: BUILD SUCCEEDED. If the build fails because `StickerButton` is missing in scope, confirm the import — TodayView and StickerButton are in the same module so no import needed.

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Add Play Endless button to TodayView"
```

---

### Task 7: StatsView — add lifetime solved count

**Files:**
- Modify: `Pictok/Views/StatsView.swift`

- [ ] **Step 1: Read current StatsView**

Open `Pictok/Views/StatsView.swift`. Identify the existing stat-row layout pattern (likely a `VStack` of rows showing current streak, longest streak, etc.).

- [ ] **Step 2: Add a new row for `lifetimeSolvedCount`**

In the stat-row stack, after the longest-streak row (or as the last item in the cumulative-stats section), insert:

```swift
            statRow(label: "Total solved", value: "\(store.state.lifetimeSolvedCount)")
```

If `statRow` is not the helper's name in the existing file, use the same idiom that other rows use. The goal is one new row labeled "Total solved" showing the integer.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/StatsView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Show lifetime solved count in StatsView"
```

---

### Task 8: PictokApp — wire up Endless presentation + remove refillLives call

**Files:**
- Modify: `Pictok/PictokApp.swift`

`store.refillLives()` was already removed in Task 2 step 4. This task wires `TodayView.onPlayEndless` to present `EndlessView` as a full-screen cover.

- [ ] **Step 1: Read the current `PictokApp` and `RootView` structure**

In `Pictok/PictokApp.swift`, find `RootView`. It currently renders `TodayView(...)` inside a `TabView`. We need to:
1. Add an `@State private var presentingEndless: Bool = false` to `RootView`.
2. Pass `onPlayEndless: { presentingEndless = true }` to `TodayView`.
3. Attach `.fullScreenCover(isPresented: $presentingEndless) { ... }` to the `TabView` (or the `TodayView` tab) that constructs `EndlessSession` from the loader + store and shows `EndlessView`.

- [ ] **Step 2: Apply the edits**

In `RootView.body`, where `TodayView(...)` is currently constructed:

```swift
                TodayView(
                    store: store,
                    puzzle: todays,
                    puzzleNumber: todays.map { loader.puzzleNumber(for: $0) } ?? 1,
                    onSolveOrFail: onSolveOrFail,
                    onPlayEndless: { presentingEndless = true }
                )
                .tabItem { Label("Today", systemImage: "calendar") }
```

Add at the top of `RootView`:

```swift
    @State private var presentingEndless: Bool = false
```

Attach the cover at the end of the `TabView`:

```swift
            .fullScreenCover(isPresented: $presentingEndless) {
                let today = PuzzleLoader.dateString(for: Date())
                let session = EndlessSession(allPuzzles: loader.allPuzzles,
                                             store: store,
                                             today: today)
                EndlessView(session: session)
            }
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: all suites pass (UserStateMigration, EndlessSelector, EndlessSession, the original 7).

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/PictokApp.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Wire Play Endless full-screen cover into RootView"
```

---

## Phase 4 — End-to-end verification

### Task 9: Simulator smoke test

**Files:** none — runtime verification only.

- [ ] **Step 1: Boot iPhone 17 simulator (if not already booted)**

```bash
xcrun simctl boot "iPhone 17" 2>&1 || true
open -a Simulator
```

- [ ] **Step 2: Reinstall the app with a clean user state**

```bash
xcrun simctl uninstall booted com.rehatchugh.pictok 2>&1 || true
APP=$(find /Users/rehatchugh/Library/Developer/Xcode/DerivedData -name "Pictok.app" -path "*Debug-iphonesimulator*" -type d | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.rehatchugh.pictok
```

Expected: prints `com.rehatchugh.pictok: <PID>`.

- [ ] **Step 3: Verify the Play tab shows the Daily Puzzle AND the Play Endless button**

```bash
sleep 2 && xcrun simctl io booted screenshot /tmp/pictok-play-tab.png
```

Read `/tmp/pictok-play-tab.png`. Expected: today's Daily emoji + category chip + blanks + keyboard + a "▶ Play Endless" sticker button somewhere in the layout.

- [ ] **Step 4: Tap "Play Endless" via the simulator**

There is no reliable headless tap-by-text in `simctl`. Instead: use `xcrun simctl io booted tap-by-id` if available, or document the manual tap. For automation in this plan we treat this as a visual confirmation step — read the next screenshot manually to confirm the EndlessView appears.

Tap the "Play Endless" button manually in the simulator (open Simulator.app and click it), then:

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-endless.png
```

Read `/tmp/pictok-endless.png`. Expected: an Endless puzzle screen with ✕ in top-left, hearts row at top, a new emoji + category, blanks, keyboard. The puzzle shown must NOT be today's Daily (the one from Step 3).

- [ ] **Step 5: Solve the Endless puzzle, verify auto-advance**

Tap correct letters until the puzzle resolves. Within ~2 seconds, the screen should auto-advance to a different puzzle. Screenshot:

```bash
sleep 3 && xcrun simctl io booted screenshot /tmp/pictok-endless-next.png
```

Read. Expected: a new emoji header and reset state (5 full hearts, empty blanks).

- [ ] **Step 6: Tap ✕ to return to the Play tab**

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-back-to-play.png
```

Read. Expected: the Play tab UI (Daily Puzzle visible).

- [ ] **Step 7: Open Stats tab, verify lifetime count incremented**

Tap Stats tab. Screenshot:

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-stats.png
```

Read. Expected: a "Total solved" row showing `1` (the one Endless puzzle just solved). Daily streak is still 0 (Daily wasn't solved).

- [ ] **Step 8: Update project memory**

Edit `/Users/rehatchugh/.claude/projects/-Users-rehatchugh/memory/project_pictok.md`:

- Mark the endless-mode pivot complete (build green, simulator-verified).
- Note the new files (`EndlessSelector`, `EndlessSession`, `EndlessView`).
- Note `livesLastRefilledAt` and `refillLives()` are gone.
- Confirm `puzzles.json` is bundled and today's Daily renders.

---

## Done

After Task 9 the endless-mode pivot is shipped:

- Daily Puzzle path intact and tested.
- Per-puzzle hearts replace global refill (no more 4-hour lockout).
- Endless mode shows unseen puzzles first, protects upcoming Dailies, replays after exhaustion.
- Streak still Daily-only; lifetime solved count visible in Stats.
- `UserState` migrates cleanly for existing users.

Remaining v1 plan items not covered by this plan (still tracked in `2026-05-18-pictok-v1-implementation.md`):

- Task 28: Final app icon asset
- Task 29: Final sound effects (current ones are synthetic placeholders)
- Task 30: Manual QA matrix (now includes Endless flow)
- Task 31: TestFlight + App Store submission prep
