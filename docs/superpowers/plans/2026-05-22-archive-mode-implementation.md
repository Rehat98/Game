# Archive Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Daily Archive that lets lapsed players play missed puzzles from the last 28 days via tappable Stats-calendar cells, without ever touching the streak fields.

**Architecture:** Two new game classes (iOS `ArchiveSession`, web `archive-session.js`) wrap one puzzle pinned to a date. A new outcome-recorder (`UserStateStore.recordArchiveOutcome` / `recordArchiveOutcome` in web `user-state.js`) writes to lifetime fields + `solveHistory` only — `currentStreak`, `longestStreak`, `lastSolvedDate`, `streakFreezesAvailable` are never modified. The Stats calendar cells become buttons that route by cell state: unplayed past → fullScreenCover archive game; solved/failed → answer-peek sheet; today/future → no-op.

**Tech Stack:** Swift 5 + SwiftUI iOS 17, XCTest. Vanilla ES modules in `web/`, `node:test`. xcodegen at the iOS layer (no `.xcodeproj` edits — new files in `Pictok/` auto-include).

**Spec:** `docs/superpowers/specs/2026-05-22-archive-mode-design.md`

---

## File Structure

### iOS — files to CREATE

| Path | Responsibility |
|------|----------------|
| `Pictok/Game/ArchiveSession.swift` | Single-puzzle game session pinned to a date; runs guess loop; calls outcome recorder on solve/fail. |
| `Pictok/Views/ArchiveView.swift` | FullScreen game UI for the archive — hearts, emoji header, keyboard, submit, win/fail celebrations, close X. |
| `Pictok/Views/AnswerPeekSheet.swift` | Sheet showing emoji + revealed answer + category for already-played past puzzles. |
| `PictokTests/ArchiveSessionTests.swift` | Unit tests for `ArchiveSession`. |

### iOS — files to MODIFY

| Path | Change |
|------|--------|
| `Pictok/Game/UserStateStore.swift` | Add `recordArchiveOutcome(puzzleId:solved:wrongGuesses:hintUsed:date:)` method. |
| `Pictok/Views/Components/CalendarHeatmapView.swift` | Add `onCellTap: (CalendarCell) -> Void = { _ in }` callback; wrap each cell in `Button`. |
| `Pictok/Views/StatsView.swift` | Pass tap handler; present `ArchiveView` (fullScreenCover) or `AnswerPeekSheet` (sheet) based on cell state. |
| `PictokTests/UserStateStoreTests.swift` | Add `recordArchiveOutcome` tests, especially the streak-invariance assertions. |

### Web — files to CREATE

| Path | Responsibility |
|------|----------------|
| `web/js/archive-session.js` | Single-puzzle session mirroring iOS `ArchiveSession`. |
| `web/js/archive.js` | UI module rendering the archive game inside a modal. |
| `web/tests/archive-session.test.js` | Unit tests for the session. |

### Web — files to MODIFY

| Path | Change |
|------|--------|
| `web/js/user-state.js` | Add exported `recordArchiveOutcome(state, puzzle, { solved, wrongGuesses, hintUsed })`. |
| `web/js/stats.js` | Make calendar cells clickable; add an `onCellTap` callback; add `renderAnswerPeek(puzzle, result)` helper. |
| `web/js/main.js` | Wire calendar tap → launch archive game or peek; mount/unmount the archive modal. |
| `web/sw.js` | Bump cache `pictok-v12` → `pictok-v13`. |
| `web/tests/user-state.test.js` | Add `recordArchiveOutcome` invariant tests. |
| `web/tests/puzzle-loader.test.js` | (No change — included here only as a reminder that puzzle count stays 60.) |

### Docs

| Path | Change |
|------|--------|
| `docs/launch/testflight.md` | Add a line in "What to test" mentioning the new archive cells. |

---

## Task 1: `recordArchiveOutcome` on `UserStateStore` (iOS)

**Files:**
- Modify: `Pictok/Game/UserStateStore.swift` (append method)
- Test: `PictokTests/UserStateStoreTests.swift` (append tests)

The single write site for archive outcomes. Updates `solvedPuzzleIds` / `failedPuzzleIds` / `totalSolved` / `totalPlayed` / `guessDistribution` / `lifetimeSolvedCount` / `solveHistory`. **Never** touches streak fields.

- [ ] **Step 1: Read the existing test file** to match its helper patterns (`makeStore`, suite name, etc.)

Run: `cat PictokTests/UserStateStoreTests.swift`

- [ ] **Step 2: Append failing tests** to `PictokTests/UserStateStoreTests.swift`

```swift
// MARK: - recordArchiveOutcome

func test_recordArchiveOutcome_solved_updatesLifetimeFields() {
    let store = makeStore()
    store.state.currentStreak = 3
    store.state.longestStreak = 5
    store.state.lastSolvedDate = "2026-05-15"
    store.state.streakFreezesAvailable = 1

    store.recordArchiveOutcome(puzzleId: "puzzle-010",
                               solved: true,
                               wrongGuesses: 2,
                               hintUsed: false,
                               date: "2026-05-10")

    XCTAssertTrue(store.state.solvedPuzzleIds.contains("puzzle-010"))
    XCTAssertEqual(store.state.totalSolved, 1)
    XCTAssertEqual(store.state.totalPlayed, 1)
    XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
    XCTAssertEqual(store.state.guessDistribution[2], 1)
    XCTAssertTrue(store.state.solveHistory.contains(where: {
        $0.date == "2026-05-10" && $0.result == .solved
    }))
}

func test_recordArchiveOutcome_perfectRun_recordsAsPerfect() {
    let store = makeStore()
    store.recordArchiveOutcome(puzzleId: "puzzle-011",
                               solved: true,
                               wrongGuesses: 0,
                               hintUsed: false,
                               date: "2026-05-11")
    XCTAssertTrue(store.state.solveHistory.contains(where: {
        $0.date == "2026-05-11" && $0.result == .perfect
    }))
}

func test_recordArchiveOutcome_solvedWithHint_recordsAsSolvedNotPerfect() {
    let store = makeStore()
    store.recordArchiveOutcome(puzzleId: "puzzle-012",
                               solved: true,
                               wrongGuesses: 0,
                               hintUsed: true,
                               date: "2026-05-12")
    XCTAssertTrue(store.state.solveHistory.contains(where: {
        $0.date == "2026-05-12" && $0.result == .solved
    }))
}

func test_recordArchiveOutcome_failed_updatesFailedSetAndHistory() {
    let store = makeStore()
    store.recordArchiveOutcome(puzzleId: "puzzle-013",
                               solved: false,
                               wrongGuesses: 5,
                               hintUsed: false,
                               date: "2026-05-13")

    XCTAssertTrue(store.state.failedPuzzleIds.contains("puzzle-013"))
    XCTAssertEqual(store.state.totalPlayed, 1)
    XCTAssertEqual(store.state.totalSolved, 0)
    XCTAssertEqual(store.state.lifetimeSolvedCount, 0)
    XCTAssertTrue(store.state.solveHistory.contains(where: {
        $0.date == "2026-05-13" && $0.result == .failed
    }))
}

func test_recordArchiveOutcome_neverChangesStreakFields() {
    let store = makeStore()
    store.state.currentStreak = 7
    store.state.longestStreak = 12
    store.state.lastSolvedDate = "2026-05-21"
    store.state.streakFreezesAvailable = 1
    let beforeStreak = store.state.currentStreak
    let beforeLongest = store.state.longestStreak
    let beforeLast = store.state.lastSolvedDate
    let beforeFreezes = store.state.streakFreezesAvailable

    store.recordArchiveOutcome(puzzleId: "puzzle-009",
                               solved: true,
                               wrongGuesses: 1,
                               hintUsed: false,
                               date: "2026-05-09")
    store.recordArchiveOutcome(puzzleId: "puzzle-010",
                               solved: false,
                               wrongGuesses: 5,
                               hintUsed: true,
                               date: "2026-05-10")

    XCTAssertEqual(store.state.currentStreak, beforeStreak)
    XCTAssertEqual(store.state.longestStreak, beforeLongest)
    XCTAssertEqual(store.state.lastSolvedDate, beforeLast)
    XCTAssertEqual(store.state.streakFreezesAvailable, beforeFreezes)
}

func test_recordArchiveOutcome_replacesAnyExistingHistoryEntryForDate() {
    let store = makeStore()
    store.state.solveHistory = [SolveRecord(date: "2026-05-10", result: .failed)]

    store.recordArchiveOutcome(puzzleId: "puzzle-010",
                               solved: true,
                               wrongGuesses: 0,
                               hintUsed: false,
                               date: "2026-05-10")

    let matches = store.state.solveHistory.filter { $0.date == "2026-05-10" }
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches.first?.result, .perfect)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/UserStateStoreTests 2>&1 | grep -E "error:|failed"
```

Expected: build error "Value of type 'UserStateStore' has no member 'recordArchiveOutcome'".

- [ ] **Step 4: Append the method** to `Pictok/Game/UserStateStore.swift` (inside the class, before the closing brace)

```swift
    /// Records the outcome of an archive (catch-up) play. Updates lifetime fields
    /// and `solveHistory`, but **never** touches `currentStreak`, `longestStreak`,
    /// `lastSolvedDate`, or `streakFreezesAvailable` — archive plays are
    /// streak-neutral by design.
    func recordArchiveOutcome(puzzleId: String,
                              solved: Bool,
                              wrongGuesses: Int,
                              hintUsed: Bool,
                              date: String) {
        state.totalPlayed += 1
        if solved {
            state.solvedPuzzleIds.insert(puzzleId)
            state.totalSolved += 1
            state.lifetimeSolvedCount += 1
            state.guessDistribution[wrongGuesses, default: 0] += 1
        } else {
            state.failedPuzzleIds.insert(puzzleId)
        }
        let result: SolveResult = solved
            ? (wrongGuesses == 0 && !hintUsed ? .perfect : .solved)
            : .failed
        var history = state.solveHistory.filter { $0.date != date }
        history.append(SolveRecord(date: date, result: result))
        state.solveHistory = history
        save()
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/UserStateStoreTests 2>&1 | grep -E "Executed|failed"
```

Expected: "Executed N tests, with 0 failures".

- [ ] **Step 6: Commit**

```bash
git add Pictok/Game/UserStateStore.swift PictokTests/UserStateStoreTests.swift
git commit -m "archive: UserStateStore.recordArchiveOutcome — streak-neutral write site"
```

---

## Task 2: `ArchiveSession` game class (iOS)

**Files:**
- Create: `Pictok/Game/ArchiveSession.swift`
- Create: `PictokTests/ArchiveSessionTests.swift`

A single-puzzle session pinned to one puzzle + date. Mirrors `EndlessSession` shape (Observable, `hearts`, `correctGuesses`, `wrongGuesses`, `guess()`, `submit()`, `useHint()`, `isSolved`, `isFailed`, `needsSubmit`, `hasShownOneChanceWarning`) but with no `advance()` and no puzzle picking — the puzzle is injected at init.

On solve / fail, the session calls `store.recordArchiveOutcome(...)`.

- [ ] **Step 1: Read `EndlessSession.swift` to match shape exactly**

Run: `cat Pictok/Game/EndlessSession.swift`

- [ ] **Step 2: Create the failing test file** at `PictokTests/ArchiveSessionTests.swift`

```swift
import XCTest
@testable import Pictok

final class ArchiveSessionTests: XCTestCase {

    private func makePuzzle(answer: String = "CAT") -> Puzzle {
        Puzzle(id: "puzzle-010", date: "2026-05-10", emoji: "🐱", answer: answer,
               category: .movie, subcategory: "t", difficulty: .medium)
    }

    private func makeStore(state: UserState = UserState.fresh(at: Date(timeIntervalSince1970: 0))) -> UserStateStore {
        let suiteName = "test.archive.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserStateStore(defaults: defaults)
        store.state = state
        return store
    }

    func test_init_pinsPuzzle_5Hearts_noGuesses() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertEqual(session.puzzle.id, "puzzle-010")
        XCTAssertTrue(session.correctGuesses.isEmpty)
        XCTAssertTrue(session.wrongGuesses.isEmpty)
        XCTAssertFalse(session.isSolved)
        XCTAssertFalse(session.isFailed)
    }

    func test_correctGuess_addsLetter_keepsHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.guess(letter: "C")
        XCTAssertTrue(session.correctGuesses.contains("C"))
        XCTAssertEqual(session.hearts, 5)
    }

    func test_wrongGuess_addsLetter_decrementsHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.guess(letter: "Z")
        XCTAssertTrue(session.wrongGuesses.contains("Z"))
        XCTAssertEqual(session.hearts, 4)
    }

    func test_submitWhenAllLettersRevealed_solvesAndRecordsOutcome() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        XCTAssertTrue(session.needsSubmit)
        session.submit()
        XCTAssertTrue(session.isSolved)
        XCTAssertTrue(store.state.solvedPuzzleIds.contains("puzzle-010"))
        XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
    }

    func test_perfectRun_recordsAsPerfect() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        session.submit()
        XCTAssertTrue(store.state.solveHistory.contains(where: {
            $0.date == "2026-05-10" && $0.result == .perfect
        }))
    }

    func test_5WrongGuesses_failsAndRecordsOutcome() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["B", "D", "E", "F", "G"] { session.guess(letter: Character(letter)) }
        XCTAssertTrue(session.isFailed)
        XCTAssertEqual(session.hearts, 0)
        XCTAssertTrue(store.state.failedPuzzleIds.contains("puzzle-010"))
    }

    func test_solve_neverChangesStreak() {
        let store = makeStore()
        store.state.currentStreak = 4
        store.state.longestStreak = 9
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        for letter in ["C", "A", "T"] { session.guess(letter: Character(letter)) }
        session.submit()
        XCTAssertEqual(store.state.currentStreak, 4)
        XCTAssertEqual(store.state.longestStreak, 9)
    }

    func test_useHint_revealsOneLetter_butStaysAtFiveHearts() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(), store: store)
        session.useHint()
        XCTAssertTrue(session.hintUsedThisPuzzle)
        XCTAssertEqual(session.hearts, 5)
        XCTAssertFalse(session.correctGuesses.isEmpty,
                       "Hint should reveal at least one letter")
    }

    func test_oneChanceWarningFiresAt2to1Transition() {
        let store = makeStore()
        let session = ArchiveSession(puzzle: makePuzzle(answer: "AAA"), store: store)
        for letter in ["B", "C", "D"] { session.guess(letter: Character(letter)) }
        XCTAssertEqual(session.hearts, 2)
        XCTAssertFalse(session.hasShownOneChanceWarning)
        session.guess(letter: "E")
        XCTAssertEqual(session.hearts, 1)
        XCTAssertTrue(session.hasShownOneChanceWarning)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/ArchiveSessionTests 2>&1 | grep -E "error:|failed"
```

Expected: build error "Cannot find 'ArchiveSession' in scope".

- [ ] **Step 4: Create `Pictok/Game/ArchiveSession.swift`**

```swift
import Foundation
import Observation

/// Single-puzzle game session pinned to one past Daily puzzle, used by the
/// Archive feature. Mirrors EndlessSession in shape but never advances and
/// records its outcome via `UserStateStore.recordArchiveOutcome` (which is
/// streak-neutral by design).
@Observable
final class ArchiveSession {
    let puzzle: Puzzle
    private let store: UserStateStore

    private(set) var hearts: Int = 5
    private(set) var correctGuesses: Set<Character> = []
    private(set) var wrongGuesses: Set<Character> = []
    private(set) var isSolved: Bool = false
    private(set) var isFailed: Bool = false
    private(set) var hintUsedThisPuzzle: Bool = false
    private(set) var hasShownOneChanceWarning: Bool = false

    init(puzzle: Puzzle, store: UserStateStore) {
        self.puzzle = puzzle
        self.store = store
    }

    var needsSubmit: Bool {
        guard !isSolved, !isFailed else { return false }
        return GameEngine.isSolved(answer: puzzle.answer, correctGuesses: correctGuesses)
    }

    func guess(letter: Character) {
        guard !isSolved, !isFailed else { return }
        let upper = Character(String(letter).uppercased())
        guard !correctGuesses.contains(upper), !wrongGuesses.contains(upper) else { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle.answer) {
            correctGuesses.insert(upper)
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
            if hearts == 1 && !hasShownOneChanceWarning {
                hasShownOneChanceWarning = true
            }
            if hearts <= 0 {
                isFailed = true
                recordOutcome(solved: false)
            }
        }
    }

    func submit() {
        guard needsSubmit else { return }
        isSolved = true
        recordOutcome(solved: true)
    }

    func useHint() {
        guard !hintUsedThisPuzzle, !isSolved, !isFailed else { return }
        hintUsedThisPuzzle = true
        // Reveal the first as-yet-unrevealed letter from the answer.
        for char in puzzle.answer where char.isLetter {
            let upper = Character(String(char).uppercased())
            if !correctGuesses.contains(upper) {
                correctGuesses.insert(upper)
                return
            }
        }
    }

    private func recordOutcome(solved: Bool) {
        store.recordArchiveOutcome(
            puzzleId: puzzle.id,
            solved: solved,
            wrongGuesses: wrongGuesses.count,
            hintUsed: hintUsedThisPuzzle,
            date: puzzle.date
        )
    }
}
```

- [ ] **Step 5: Regenerate the xcodeproj** so the new file is picked up

Run: `xcodegen generate`

Expected: "Loaded project: Pictok ... Created project: Pictok.xcodeproj".

- [ ] **Step 6: Run tests to verify they pass**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/ArchiveSessionTests 2>&1 | grep -E "Executed|failed"
```

Expected: "Executed 9 tests, with 0 failures".

- [ ] **Step 7: Commit**

```bash
git add Pictok/Game/ArchiveSession.swift PictokTests/ArchiveSessionTests.swift Pictok.xcodeproj
git commit -m "archive: ArchiveSession — single-puzzle session for catch-up plays"
```

---

## Task 3: `AnswerPeekSheet` (iOS)

**Files:**
- Create: `Pictok/Views/AnswerPeekSheet.swift`

Read-only sheet for already-played past puzzles. Shows the emoji, category + subcategory, the answer in big letters, an outcome line, and a "Got it" close button.

- [ ] **Step 1: Create `Pictok/Views/AnswerPeekSheet.swift`**

```swift
import SwiftUI

/// Read-only reference card shown when a player taps a calendar cell for a
/// puzzle they have already solved or failed. No game state, no interactivity
/// beyond closing.
struct AnswerPeekSheet: View {
    let puzzle: Puzzle
    /// `.perfect` / `.solved` / `.failed` — the recorded outcome.
    let outcome: SolveResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(puzzle.emoji)
                .font(.system(size: 56))
                .padding(.top, 24)

            CategoryChip(category: puzzle.category, subcategory: puzzle.subcategory)

            Text(puzzle.answer)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(outcomeLine)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(outcomeColor)

            Spacer()

            StickerButton(title: "Got it", icon: nil, fill: .white) {
                dismiss()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.pkPaper.ignoresSafeArea())
    }

    private var outcomeLine: String {
        switch outcome {
        case .perfect: return "✓ Perfect run"
        case .solved:  return "✓ Solved"
        case .failed:  return "✗ Beat you"
        }
    }

    private var outcomeColor: Color {
        switch outcome {
        case .perfect: return .pkGreen
        case .solved:  return .pkInk.opacity(0.7)
        case .failed:  return .pkRed
        }
    }
}
```

- [ ] **Step 2: Regenerate the xcodeproj**

Run: `xcodegen generate`

- [ ] **Step 3: Build to confirm it compiles**

Run:
```
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "error:|BUILD"
```

Expected: "BUILD SUCCEEDED" with no errors.

- [ ] **Step 4: Commit**

```bash
git add Pictok/Views/AnswerPeekSheet.swift Pictok.xcodeproj
git commit -m "archive: AnswerPeekSheet — read-only reference card for played past puzzles"
```

---

## Task 4: `ArchiveView` (iOS)

**Files:**
- Create: `Pictok/Views/ArchiveView.swift`

Full-screen game UI. Mirrors `EndlessView` shape (HeartsRow, EmojiHeader, CategoryChip, BlanksView, KeyboardView, HintButton, Submit ✓ sticker, win/fail celebration overlays) but uses `ArchiveSession`, has a close X (no "End Session" since there's no session continuation), and auto-dismisses after celebration completes.

- [ ] **Step 1: Read `EndlessView.swift` to copy the celebration overlay pattern**

Run: `cat Pictok/Views/EndlessView.swift`

- [ ] **Step 2: Create `Pictok/Views/ArchiveView.swift`**

```swift
import SwiftUI

/// Full-screen game for a past Daily puzzle. Owns the ArchiveSession for the
/// presented puzzle. Auto-dismisses ~1s after a win or fail celebration
/// finishes so the player lands back on the Stats calendar with the cell now
/// colored.
struct ArchiveView: View {
    @State var session: ArchiveSession
    @Environment(\.dismiss) private var dismiss

    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var showOneChanceAlert: Bool = false

    init(puzzle: Puzzle, store: UserStateStore) {
        _session = State(initialValue: ArchiveSession(puzzle: puzzle, store: store))
    }

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()
            content
            if showWinCelebration {
                WinCelebrationView(answer: session.puzzle.answer)
                    .transition(.opacity)
            }
            if showFailCelebration {
                FailCelebrationView(answer: session.puzzle.answer)
                    .transition(.opacity)
            }
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved {
                showWinCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    dismiss()
                }
            }
        }
        .onChange(of: session.isFailed) { _, failed in
            if failed {
                showFailCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + FailCelebrationView.totalDuration) {
                    dismiss()
                }
            }
        }
        .onChange(of: session.hasShownOneChanceWarning) { _, shown in
            if shown { showOneChanceAlert = true }
        }
        .alert("One chance left", isPresented: $showOneChanceAlert) {
            Button("OK") { showOneChanceAlert = false }
        } message: {
            Text("Make it count — one more wrong guess ends the puzzle.")
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            topBar
            HeartsRow(remaining: session.hearts)
            EmojiHeader(emoji: session.puzzle.emoji)
            CategoryChip(category: session.puzzle.category,
                         subcategory: session.puzzle.subcategory)
            BlanksView(answer: session.puzzle.answer,
                       correctGuesses: session.correctGuesses,
                       revealedLetter: nil)
            HStack {
                Spacer()
                HintButton(
                    isEnabled: !session.hintUsedThisPuzzle && !session.isSolved && !session.isFailed,
                    action: { session.useHint() }
                )
            }
            .padding(.horizontal, 8)
            if session.needsSubmit {
                StickerButton(title: "Submit ✓", icon: nil, fill: .pkGreen) {
                    session.submit()
                }
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            KeyboardView(
                correctGuesses: session.correctGuesses,
                wrongGuesses: session.wrongGuesses,
                onGuess: { letter in session.guess(letter: letter) }
            )
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.needsSubmit)
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.pkInk)
                    .padding(10)
                    .sticker(fill: .white, cornerRadius: 16, strokeWidth: 2, shadowOffset: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(dateLabel)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private var dateLabel: String {
        // "2026-05-10" → "May 10"
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        inFormatter.timeZone = TimeZone(identifier: "UTC")
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "MMM d"
        outFormatter.timeZone = TimeZone(identifier: "UTC")
        if let d = inFormatter.date(from: session.puzzle.date) {
            return outFormatter.string(from: d)
        }
        return session.puzzle.date
    }
}
```

- [ ] **Step 3: Regenerate xcodeproj**

Run: `xcodegen generate`

- [ ] **Step 4: Build to confirm it compiles**

Run:
```
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "error:|BUILD"
```

Expected: "BUILD SUCCEEDED".

- [ ] **Step 5: Commit**

```bash
git add Pictok/Views/ArchiveView.swift Pictok.xcodeproj
git commit -m "archive: ArchiveView — full-screen game UI for past Daily puzzles"
```

---

## Task 5: Make `CalendarHeatmapView` cells tappable

**Files:**
- Modify: `Pictok/Views/Components/CalendarHeatmapView.swift`

Add an `onCellTap: (CalendarCell) -> Void = { _ in }` callback. Wrap each cell in a `Button` that calls the callback. Existing call sites (StatsView) compile unchanged because the callback has a default value. Cell appearance is unchanged.

- [ ] **Step 1: Modify the struct declaration** (line 6 area) — add the callback parameter

Replace:
```swift
struct CalendarHeatmapView: View {
    let history: [SolveRecord]
    /// `YYYY-MM-DD` for today in the user's local timezone.
    let today: String
```

With:
```swift
struct CalendarHeatmapView: View {
    let history: [SolveRecord]
    /// `YYYY-MM-DD` for today in the user's local timezone.
    let today: String
    var onCellTap: (CalendarCell) -> Void = { _ in }
```

- [ ] **Step 2: Wrap the cell view in a Button** — find the `ForEach(cells.indices, id: \.self) { i in ... }` block (around line 38) and replace `cellView(cells[i])` with:

```swift
Button {
    onCellTap(cells[i])
} label: {
    cellView(cells[i])
}
.buttonStyle(.plain)
```

- [ ] **Step 3: Build to confirm existing call sites still compile**

Run:
```
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "error:|BUILD"
```

Expected: "BUILD SUCCEEDED".

- [ ] **Step 4: Run the full test suite to confirm no regressions**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "Executed.*All tests|failed"
```

Expected: previous total + 9 (ArchiveSessionTests) + 6 (recordArchiveOutcome tests) — should be around 82 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Views/Components/CalendarHeatmapView.swift
git commit -m "archive: CalendarHeatmapView cells become tappable buttons"
```

---

## Task 6: Wire tap routing in `StatsView`

**Files:**
- Modify: `Pictok/Views/StatsView.swift`

`StatsView` already holds a `store` reference (line 39 confirms). Add `loader: PuzzleLoader` parameter (callers will pass it down from RootView). Hold state for the presented archive game or peek sheet. Route taps based on cell state:

- Cell is solved (`.perfect`, `.solved`) or failed (`.failed`) → present `AnswerPeekSheet`
- Cell is past, unplayed (`result == nil`), not today, not future, and a puzzle exists for that date → present `ArchiveView` as `fullScreenCover`
- Otherwise → no-op

- [ ] **Step 1: Read the current `StatsView.swift`** to find the exact location of `CalendarHeatmapView(...)`

Run: `cat Pictok/Views/StatsView.swift`

- [ ] **Step 2: Add a `loader: PuzzleLoader` parameter** to the `StatsView` struct (place it next to the existing `store`).

```swift
struct StatsView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader
    // ... rest unchanged
```

- [ ] **Step 3: Add presentation state** below the existing properties:

```swift
    @State private var archiveTarget: Puzzle? = nil
    @State private var peekTarget: PeekItem? = nil
```

- [ ] **Step 4: Replace the `CalendarHeatmapView(...)` call** so it passes the tap handler:

```swift
CalendarHeatmapView(history: store.state.solveHistory,
                    today: PuzzleLoader.dateString(for: Date()),
                    onCellTap: handleCellTap)
```

- [ ] **Step 5: Attach the modal modifiers** to the outermost VStack/ScrollView of StatsView's body (whatever wraps everything). Append to the end of body:

```swift
.fullScreenCover(item: $archiveTarget) { puzzle in
    ArchiveView(puzzle: puzzle, store: store)
}
.sheet(item: $peekTarget) { item in
    AnswerPeekSheet(puzzle: item.puzzle, outcome: item.outcome)
        .presentationDetents([.medium])
}
```

- [ ] **Step 6: Add `PeekItem` and `handleCellTap`** as private members of the struct:

```swift
    private struct PeekItem: Identifiable {
        let puzzle: Puzzle
        let outcome: SolveResult
        var id: String { puzzle.id }
    }

    private func handleCellTap(_ cell: CalendarHeatmapView.CalendarCell) {
        if cell.isToday || cell.isFuture { return }
        guard let puzzle = loader.allPuzzles.first(where: { $0.date == cell.date }) else {
            return
        }
        if let result = cell.result {
            peekTarget = PeekItem(puzzle: puzzle, outcome: result)
        } else {
            archiveTarget = puzzle
        }
    }
```

Note: `Puzzle` must conform to `Identifiable` for `fullScreenCover(item:)`. Verify by running grep:

Run: `grep -n "Identifiable" Pictok/Models/Puzzle.swift`

If `Puzzle` does **not** conform to `Identifiable`, add this extension in `Pictok/Models/Puzzle.swift`:

```swift
extension Puzzle: Identifiable {}
```

(Puzzle already has `let id: String` so this is a no-cost conformance.)

- [ ] **Step 7: Update the caller in `PictokApp.swift`** so StatsView receives the loader:

Find `StatsView(store: store)` in `Pictok/PictokApp.swift` (it's inside the TabView) and replace with:

```swift
StatsView(store: store, loader: loader)
```

- [ ] **Step 8: Build to confirm compile**

Run:
```
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "error:|BUILD"
```

Expected: "BUILD SUCCEEDED".

- [ ] **Step 9: Run the full test suite**

Run:
```
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | grep -E "Executed.*All tests|failed"
```

Expected: same count as Task 5, 0 failures.

- [ ] **Step 10: Manual smoke-test in simulator** — launch with screenshot preset that has played + unplayed past cells, then tap each kind. **You will not be able to do this from CLI; flag for human verification.**

Verification checklist (record results in commit message body or PR description):
- [ ] Tap an unplayed past cell → ArchiveView appears → solve → cell becomes green/yellow → streak unchanged
- [ ] Tap an unplayed past cell → fail → cell becomes red → streak unchanged
- [ ] Tap a solved cell → answer peek sheet shows correct answer + "✓ Solved" → dismiss
- [ ] Tap a failed cell → answer peek sheet shows "✗ Beat you" → dismiss
- [ ] Tap today's cell → nothing happens
- [ ] Tap a future cell → nothing happens

- [ ] **Step 11: Commit**

```bash
git add Pictok/Views/StatsView.swift Pictok/PictokApp.swift Pictok/Models/Puzzle.swift
git commit -m "archive: StatsView routes calendar taps to ArchiveView or AnswerPeekSheet"
```

---

## Task 7: `recordArchiveOutcome` in `web/js/user-state.js`

**Files:**
- Modify: `web/js/user-state.js`
- Test: `web/tests/user-state.test.js`

Mirror the iOS recorder. Pure function that mutates a state object.

- [ ] **Step 1: Read existing user-state tests** to match style

Run: `cat web/tests/user-state.test.js`

- [ ] **Step 2: Append failing tests** to `web/tests/user-state.test.js`

```javascript
test('recordArchiveOutcome: solved with no hint or wrong → perfect, lifetime fields bump', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 0, hintUsed: false });
  assert.ok(state.solvedPuzzleIds.includes('puzzle-010'));
  assert.equal(state.totalSolved, 1);
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.lifetimeSolvedCount, 1);
  assert.deepEqual(state.guessDistribution, { 0: 1 });
  assert.deepEqual(state.solveHistory, [{ date: '2026-05-10', result: 'perfect' }]);
});

test('recordArchiveOutcome: solved with hint → "solved" not "perfect"', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-011', date: '2026-05-11' },
                          { solved: true, wrongGuesses: 0, hintUsed: true });
  assert.equal(state.solveHistory[0].result, 'solved');
});

test('recordArchiveOutcome: failed → adds to failedPuzzleIds, no totalSolved', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-013', date: '2026-05-13' },
                          { solved: false, wrongGuesses: 5, hintUsed: false });
  assert.ok(state.failedPuzzleIds.includes('puzzle-013'));
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.totalSolved, 0);
  assert.equal(state.lifetimeSolvedCount, 0);
  assert.equal(state.solveHistory[0].result, 'failed');
});

test('recordArchiveOutcome: NEVER changes streak fields', () => {
  const state = us.fresh();
  state.currentStreak = 7;
  state.longestStreak = 12;
  state.lastSolvedDate = '2026-05-21';
  state.streakFreezesAvailable = 1;

  us.recordArchiveOutcome(state, { id: 'puzzle-009', date: '2026-05-09' },
                          { solved: true, wrongGuesses: 1, hintUsed: false });
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: false, wrongGuesses: 5, hintUsed: true });

  assert.equal(state.currentStreak, 7);
  assert.equal(state.longestStreak, 12);
  assert.equal(state.lastSolvedDate, '2026-05-21');
  assert.equal(state.streakFreezesAvailable, 1);
});

test('recordArchiveOutcome: replaces existing history entry for the same date', () => {
  const state = us.fresh();
  state.solveHistory = [{ date: '2026-05-10', result: 'failed' }];

  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 0, hintUsed: false });

  const matches = state.solveHistory.filter(h => h.date === '2026-05-10');
  assert.equal(matches.length, 1);
  assert.equal(matches[0].result, 'perfect');
});
```

(Assumes `import * as us from '../js/user-state.js';` is already at the top of the file. If not, add it.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd web && npm test --silent 2>&1 | grep -E "fail|recordArchive"`

Expected: failures referencing `us.recordArchiveOutcome is not a function`.

- [ ] **Step 4: Append the function** to `web/js/user-state.js`

```javascript
/**
 * Records the outcome of an archive (catch-up) play. Mutates `state` in place:
 * updates lifetime fields and `solveHistory`, but never touches `currentStreak`,
 * `longestStreak`, `lastSolvedDate`, or `streakFreezesAvailable` — archive plays
 * are streak-neutral by design.
 */
export function recordArchiveOutcome(state, puzzle, { solved, wrongGuesses, hintUsed }) {
  state.totalPlayed += 1;
  if (solved) {
    if (!state.solvedPuzzleIds.includes(puzzle.id)) {
      state.solvedPuzzleIds.push(puzzle.id);
    }
    state.totalSolved += 1;
    state.lifetimeSolvedCount += 1;
    state.guessDistribution[wrongGuesses] = (state.guessDistribution[wrongGuesses] ?? 0) + 1;
  } else {
    if (!state.failedPuzzleIds.includes(puzzle.id)) {
      state.failedPuzzleIds.push(puzzle.id);
    }
  }
  const result = solved
    ? (wrongGuesses === 0 && !hintUsed ? 'perfect' : 'solved')
    : 'failed';
  state.solveHistory = state.solveHistory.filter(h => h.date !== puzzle.date);
  state.solveHistory.push({ date: puzzle.date, result });
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd web && npm test --silent 2>&1 | tail -10`

Expected: all tests pass (count = previous + 5).

- [ ] **Step 6: Commit**

```bash
git add web/js/user-state.js web/tests/user-state.test.js
git commit -m "archive: recordArchiveOutcome in web user-state — mirrors iOS recorder"
```

---

## Task 8: `archive-session.js` (web)

**Files:**
- Create: `web/js/archive-session.js`
- Create: `web/tests/archive-session.test.js`

Mirror iOS `ArchiveSession`. Factory function returning a session object with `hearts`, `correct` (Set), `wrong` (Set), `hintUsed`, `solved`, `failed`, `hasShownOneChanceWarning`, `needsSubmit` (getter), `guess(letter)`, `submit()`, `useHint()`.

- [ ] **Step 1: Read `web/js/endless-session.js`** to match the helper shape

Run: `cat web/js/endless-session.js`

- [ ] **Step 2: Create the failing test file** at `web/tests/archive-session.test.js`

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createArchiveSession } from '../js/archive-session.js';
import * as us from '../js/user-state.js';

function makePuzzle(answer = 'CAT') {
  return {
    id: 'puzzle-010', date: '2026-05-10', emoji: '🐱', answer,
    category: 'Movie', subcategory: 't', difficulty: 'medium',
  };
}

test('init: 5 hearts, no guesses, puzzle pinned', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  assert.equal(s.hearts, 5);
  assert.equal(s.puzzle.id, 'puzzle-010');
  assert.equal(s.correct.size, 0);
  assert.equal(s.wrong.size, 0);
  assert.equal(s.solved, false);
  assert.equal(s.failed, false);
});

test('correct guess: adds letter, keeps hearts', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.guess('C');
  assert.ok(s.correct.has('C'));
  assert.equal(s.hearts, 5);
});

test('wrong guess: adds letter, decrements hearts', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.guess('Z');
  assert.ok(s.wrong.has('Z'));
  assert.equal(s.hearts, 4);
});

test('submit when all letters revealed: solved + outcome recorded', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  assert.ok(s.needsSubmit);
  s.submit();
  assert.ok(s.solved);
  assert.ok(state.solvedPuzzleIds.includes('puzzle-010'));
  assert.equal(state.lifetimeSolvedCount, 1);
});

test('perfect run: records "perfect" in history', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  s.submit();
  assert.equal(state.solveHistory[0].result, 'perfect');
});

test('5 wrong guesses: fails + outcome recorded', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['B', 'D', 'E', 'F', 'G'].forEach(l => s.guess(l));
  assert.ok(s.failed);
  assert.equal(s.hearts, 0);
  assert.ok(state.failedPuzzleIds.includes('puzzle-010'));
});

test('solve never changes streak fields', () => {
  const state = us.fresh();
  state.currentStreak = 4;
  state.longestStreak = 9;
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  s.submit();
  assert.equal(state.currentStreak, 4);
  assert.equal(state.longestStreak, 9);
});

test('useHint: reveals one letter, hearts stay at 5', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.useHint();
  assert.ok(s.hintUsed);
  assert.equal(s.hearts, 5);
  assert.ok(s.correct.size >= 1);
});

test('one-chance warning fires at 2→1 transition', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle('AAA'), state);
  ['B', 'C', 'D'].forEach(l => s.guess(l));
  assert.equal(s.hearts, 2);
  assert.equal(s.hasShownOneChanceWarning, false);
  s.guess('E');
  assert.equal(s.hearts, 1);
  assert.equal(s.hasShownOneChanceWarning, true);
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd web && npm test --silent 2>&1 | grep -E "fail|archive"`

Expected: import error / function not found.

- [ ] **Step 4: Create `web/js/archive-session.js`**

```javascript
import * as engine from './game-engine.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;

/**
 * Creates a session pinned to a single past Daily puzzle. Records its outcome
 * via `us.recordArchiveOutcome` (streak-neutral) on solve or fail. Mirrors
 * iOS `ArchiveSession`.
 */
export function createArchiveSession(puzzle, state, storage) {
  const session = {
    puzzle,
    hearts: MAX_HEARTS,
    correct: new Set(),
    wrong: new Set(),
    solved: false,
    failed: false,
    hintUsed: false,
    hasShownOneChanceWarning: false,

    get needsSubmit() {
      if (session.solved || session.failed) return false;
      return engine.isSolved(puzzle.answer, session.correct, null);
    },

    guess(letter) {
      if (session.solved || session.failed) return;
      const u = String(letter).toUpperCase();
      if (session.correct.has(u) || session.wrong.has(u)) return;

      if (engine.isCorrect(u, puzzle.answer)) {
        session.correct.add(u);
      } else {
        session.wrong.add(u);
        session.hearts -= 1;
        if (session.hearts === 1 && !session.hasShownOneChanceWarning) {
          session.hasShownOneChanceWarning = true;
        }
        if (session.hearts <= 0) {
          session.failed = true;
          recordOutcome(state, session, false, storage);
        }
      }
    },

    submit() {
      if (!session.needsSubmit) return;
      session.solved = true;
      recordOutcome(state, session, true, storage);
    },

    useHint() {
      if (session.hintUsed || session.solved || session.failed) return;
      session.hintUsed = true;
      for (const char of puzzle.answer) {
        if (!/[A-Z]/i.test(char)) continue;
        const u = char.toUpperCase();
        if (!session.correct.has(u)) {
          session.correct.add(u);
          return;
        }
      }
    },
  };

  return session;
}

function recordOutcome(state, session, solved, storage) {
  us.recordArchiveOutcome(state, session.puzzle, {
    solved,
    wrongGuesses: session.wrong.size,
    hintUsed: session.hintUsed,
  });
  if (storage) us.save(state, storage);
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd web && npm test --silent 2>&1 | tail -10`

Expected: previous count + 9 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add web/js/archive-session.js web/tests/archive-session.test.js
git commit -m "archive: archive-session.js — single-puzzle session for web catch-up plays"
```

---

## Task 9: `stats.js` clickable cells + answer-peek modal (web)

**Files:**
- Modify: `web/js/stats.js`

`renderStats(state, today)` becomes `renderStats(state, today, { onCellTap = () => {} } = {})`. Calendar cell elements get a `cursor: pointer` style and a click handler that bubbles `{ date, result, isToday, isFuture }` through. Add a `renderAnswerPeek(puzzle, outcome)` helper that builds an in-page modal element with emoji + answer + outcome line + close button.

- [ ] **Step 1: Read the current calendar render in `web/js/stats.js`**

Run: `cat web/js/stats.js`

- [ ] **Step 2: Modify `renderStats` signature and the cell render**

Replace:
```javascript
export function renderStats(state, today) {
```
With:
```javascript
export function renderStats(state, today, { onCellTap = () => {} } = {}) {
```

Find the loop that creates `.calendar-cell` divs. Each cell creation needs to wrap in a clickable button OR add `role="button"` + click handler to the div. Replace whatever creates the cell with:

```javascript
const cellEl = el('button', {
  type: 'button',
  class: `calendar-cell calendar-cell--${cell.result ?? 'empty'}${cell.isToday ? ' calendar-cell--today' : ''}${cell.isFuture ? ' calendar-cell--future' : ''}`,
  'aria-label': cellAriaLabel(cell),
  onclick: () => onCellTap(cell),
}, []);
```

(Use whatever existing class names the codebase already applies — preserve those. The `cellAriaLabel` helper is described in the next step.)

- [ ] **Step 3: Add `cellAriaLabel` helper** at the bottom of `web/js/stats.js`

```javascript
function cellAriaLabel(cell) {
  if (cell.isToday) return `Today, ${cell.date}`;
  if (cell.isFuture) return `Future, ${cell.date}`;
  if (cell.result === 'perfect') return `${cell.date}: perfect`;
  if (cell.result === 'solved')  return `${cell.date}: solved`;
  if (cell.result === 'failed')  return `${cell.date}: failed`;
  return `${cell.date}: unplayed`;
}
```

- [ ] **Step 4: Add `renderAnswerPeek` export**

```javascript
export function renderAnswerPeek(puzzle, outcome, { onDismiss } = {}) {
  const outcomeLine = outcome === 'perfect' ? '✓ Perfect run'
                    : outcome === 'solved'  ? '✓ Solved'
                    : outcome === 'failed'  ? '✗ Beat you'
                    : '';
  const outcomeClass = outcome === 'failed' ? 'peek-outcome peek-outcome--fail' : 'peek-outcome';
  return el('div', { class: 'peek-modal-backdrop', onclick: onDismiss }, [
    el('div', { class: 'peek-modal', onclick: (e) => e.stopPropagation() }, [
      el('div', { class: 'peek-emoji' }, [puzzle.emoji]),
      el('div', { class: 'peek-category' }, [`${puzzle.category} · ${puzzle.subcategory}`]),
      el('div', { class: 'peek-answer' }, [puzzle.answer]),
      el('div', { class: outcomeClass }, [outcomeLine]),
      el('button', { type: 'button', class: 'peek-close sticker-button', onclick: onDismiss }, ['Got it']),
    ]),
  ]);
}
```

- [ ] **Step 5: Add minimal CSS** to `web/style.css` for the new peek modal and cell pointer cursor. Append:

```css
.calendar-cell { cursor: pointer; background: transparent; padding: 0; }
.calendar-cell--future { cursor: default; }
.calendar-cell--today  { cursor: default; }
.calendar-cell--empty[disabled] { cursor: default; }

.peek-modal-backdrop {
  position: fixed; inset: 0; background: rgba(0,0,0,0.45);
  display: flex; align-items: flex-end; justify-content: center;
  z-index: 100;
}
.peek-modal {
  width: 100%; max-width: 480px;
  background: var(--pk-paper);
  border: 3px solid var(--pk-ink); border-radius: 22px 22px 0 0;
  padding: 24px 16px 28px;
  display: flex; flex-direction: column; align-items: center; gap: 14px;
}
.peek-emoji    { font-size: 48px; }
.peek-category { font-size: 12px; font-weight: 800; opacity: 0.55; letter-spacing: 0.12em; text-transform: uppercase; }
.peek-answer   { font-size: 28px; font-weight: 900; letter-spacing: -0.01em; text-align: center; }
.peek-outcome  { font-size: 14px; font-weight: 800; opacity: 0.7; }
.peek-outcome--fail { color: var(--pk-red); opacity: 1; }
.peek-close    { margin-top: 8px; }
```

- [ ] **Step 6: Run web tests** to confirm no regressions in stats math

Run: `cd web && npm test --silent 2>&1 | tail -10`

Expected: all tests still pass.

- [ ] **Step 7: Commit**

```bash
git add web/js/stats.js web/style.css
git commit -m "archive: clickable calendar cells + answer-peek modal (web)"
```

---

## Task 10: `archive.js` UI module (web)

**Files:**
- Create: `web/js/archive.js`

Renders the archive game UI inside a modal. Reuses the same engine + render primitives that Today / Endless use. Exports a `mountArchive(rootEl, puzzle, state, { onDone, storage })` function that builds the DOM, owns the session, wires the keyboard + submit, fires celebrations, and calls `onDone()` to dismiss when win/fail celebration finishes.

This file is large because it duplicates the game-loop UI. To keep it bounded, **delegate to existing render primitives in `web/js/ui.js`** wherever possible (HeartsRow, EmojiHeader, KeyboardView, BlanksView equivalents). Read `web/js/ui.js` first.

- [ ] **Step 1: Read `web/js/ui.js` to see the available render primitives**

Run: `cat web/js/ui.js | head -200`

- [ ] **Step 2: Read how the Today / Endless screens build their game UI** to copy the pattern

Run: `grep -l "BlanksView\|renderKeyboard\|renderHearts" web/js/*.js`

- [ ] **Step 3: Create `web/js/archive.js`** mirroring the patterns from the read in Step 2

The exact file contents depend on what the existing render primitives look like. The skeleton:

```javascript
import { el } from './ui.js';
import { createArchiveSession } from './archive-session.js';
import * as us from './user-state.js';
// import additional render helpers from existing modules as needed

/**
 * Mounts the archive game UI inside `rootEl`. Returns a `destroy()` function.
 * Calls `onDone()` after a win or fail celebration finishes so the host can
 * dismiss the modal and re-render the calendar.
 */
export function mountArchive(rootEl, puzzle, state, { onDone, storage }) {
  const session = createArchiveSession(puzzle, state, storage);

  function render() {
    rootEl.innerHTML = '';
    rootEl.appendChild(buildScreen(session, {
      onGuess: (letter) => { session.guess(letter); afterGuess(); },
      onSubmit: ()       => { session.submit();    afterGuess(); },
      onHint: ()         => { session.useHint();   render(); },
      onClose: onDone,
    }));
  }

  function afterGuess() {
    if (session.solved || session.failed) {
      // Show celebration overlay (reuse Today's celebration if exported, else simple text)
      showCelebration(rootEl, session.solved ? 'win' : 'fail', session.puzzle.answer, () => {
        onDone();
      });
    } else {
      render();
    }
  }

  render();

  return {
    destroy() { rootEl.innerHTML = ''; },
  };
}

function buildScreen(session, { onGuess, onSubmit, onHint, onClose }) {
  // Compose: close button, hearts row, emoji header, category chip, blanks,
  // hint button, submit button (when needsSubmit), keyboard. Reuse existing
  // render primitives from ui.js — do NOT re-implement them here.
  // (Implementation details depend on what ui.js exposes — see Step 2.)
  return el('div', { class: 'archive-screen' }, [/* ... */]);
}

function showCelebration(rootEl, kind, answer, onDone) {
  // Reuse the existing celebration code path if exported, else a simple
  // fixed-position overlay with the answer + auto-dismiss after ~2.5s.
  const overlay = el('div', { class: `celebration celebration--${kind}` }, [
    el('div', { class: 'celebration-answer' }, [answer]),
  ]);
  rootEl.appendChild(overlay);
  setTimeout(() => { onDone(); }, 2500);
}
```

> **Note to implementer:** the exact wiring depends on what `web/js/ui.js`, `web/js/today-session.js`, and `web/js/celebration.js` (if it exists — check) export. The implementer should reuse existing helpers rather than duplicating game-loop UI. If a needed helper is private to another file, lift it to `ui.js` first in a small refactor commit.

- [ ] **Step 4: Add CSS for `.archive-screen`** in `web/style.css`. Cell-by-cell layout matching the Today screen — reuse existing game-screen styles if present:

```css
.archive-screen {
  position: fixed; inset: 0; z-index: 90;
  background: var(--pk-paper);
  display: flex; flex-direction: column; padding: 16px;
  gap: 14px; overflow-y: auto;
}
.archive-screen .archive-close {
  align-self: flex-start;
}
```

- [ ] **Step 5: Run tests to confirm no regressions**

Run: `cd web && npm test --silent 2>&1 | tail -10`

Expected: still passes (archive.js has no direct unit tests since it's DOM glue).

- [ ] **Step 6: Commit**

```bash
git add web/js/archive.js web/style.css
git commit -m "archive: archive.js — modal game UI for web catch-up plays"
```

---

## Task 11: Wire the archive in `web/js/main.js` + bump SW cache

**Files:**
- Modify: `web/js/main.js`
- Modify: `web/sw.js`

`main.js` renders the Stats screen; pass an `onCellTap` handler that:
- If `cell.isToday || cell.isFuture` → no-op
- Find the puzzle for `cell.date` in `puzzlesByDate` (look up the existing puzzle index in main.js; if none, build one)
- If `cell.result` is `'perfect' | 'solved' | 'failed'` → mount `renderAnswerPeek(puzzle, cell.result)` into `#modal-root`
- Else → mount `mountArchive(modalRoot, puzzle, state, { onDone, storage })`
- `onDone` re-renders the Stats screen so the cell color updates

- [ ] **Step 1: Read `web/js/main.js`** to find where `renderStats` is called and where the puzzle list lives

Run: `cat web/js/main.js`

- [ ] **Step 2: Build (or locate) a puzzle-by-date lookup** — find where `puzzles` is loaded and add (if absent):

```javascript
const puzzlesByDate = new Map(puzzles.map(p => [p.date, p]));
```

- [ ] **Step 3: Update the `renderStats` call**

Replace:
```javascript
renderStats(state, today)
```
with:
```javascript
renderStats(state, today, { onCellTap: (cell) => handleCalendarTap(cell) })
```

And add the handler near the other top-level functions:

```javascript
function handleCalendarTap(cell) {
  if (cell.isToday || cell.isFuture) return;
  const puzzle = puzzlesByDate.get(cell.date);
  if (!puzzle) return;

  const modalRoot = document.getElementById('modal-root');
  if (cell.result) {
    // Already played — show answer peek
    modalRoot.replaceChildren(
      renderAnswerPeek(puzzle, cell.result, {
        onDismiss: () => modalRoot.replaceChildren(),
      })
    );
  } else {
    // Unplayed past — launch archive game
    mountArchive(modalRoot, puzzle, state, {
      storage: globalThis.localStorage,
      onDone: () => {
        modalRoot.replaceChildren();
        rerenderStats();
      },
    });
  }
}

function rerenderStats() {
  // Replace the contents of the Stats screen section in place so the calendar
  // re-reads `state.solveHistory` and recolours.
  const screen = document.getElementById('screen-stats');
  if (!screen) return;
  screen.replaceChildren(renderStats(state, today, {
    onCellTap: (cell) => handleCalendarTap(cell),
  }));
}
```

Make sure to import the new functions at the top of `main.js`:

```javascript
import { renderStats, renderAnswerPeek } from './stats.js';
import { mountArchive } from './archive.js';
```

- [ ] **Step 4: Bump the service-worker cache** in `web/sw.js`

```javascript
const CACHE = 'pictok-v13';
```

Also append the new module to the `ASSETS` array so it's cache-warmed:

```javascript
  '/js/archive-session.js',
  '/js/archive.js',
```

(Insert these after the existing `/js/share.js` line, preserving the array's trailing comma style.)

- [ ] **Step 5: Smoke-test locally**

Run:
```bash
cd web && python3 -m http.server 8088 > /tmp/pictok-archive.log 2>&1 &
sleep 1
curl -s http://localhost:8088/index.html | grep -E "modal-root" || echo "no modal-root"
kill %1 2>/dev/null
```

Expected: "modal-root" line printed (it's in the existing index.html).

- [ ] **Step 6: Manual browser QA** — load `http://localhost:8088`, switch to Stats, tap cells of each kind.

**Cannot be done from CLI; flag for human verification.**

Checklist:
- [ ] Tap unplayed past cell → archive game opens → solve → cell colours
- [ ] Tap unplayed past cell → fail → cell colours red
- [ ] Tap solved cell → answer-peek modal
- [ ] Tap failed cell → answer-peek modal with "✗ Beat you"
- [ ] Tap today's cell → nothing
- [ ] Tap future cell → nothing
- [ ] Refresh page → all newly-coloured cells persist (localStorage round-trip works)

- [ ] **Step 7: Run web tests one more time**

Run: `cd web && npm test --silent 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add web/js/main.js web/sw.js
git commit -m "archive: wire web calendar taps to archive game / answer peek; sw cache v12 -> v13"
```

---

## Task 12: Update launch-doc QA matrix

**Files:**
- Modify: `docs/launch/testflight.md`

Add a single line to the "What to test" section so TestFlight testers know to try the new feature.

- [ ] **Step 1: Open the file** and find the "What to test" section

Run: `grep -n "What to test\|Things to try" docs/launch/testflight.md`

- [ ] **Step 2: Append a bullet** under that section:

```markdown
- **Archive (catch-up)**: open Stats and tap a calendar cell from a day you didn't play — you can play that day's puzzle. Solving or failing it should NOT change your streak (that stays sacred); only your lifetime stats and the calendar colour update. Tap a day you already solved and you should see an "answer peek" sheet.
```

- [ ] **Step 3: Commit**

```bash
git add docs/launch/testflight.md
git commit -m "docs: TestFlight notes mention archive catch-up cells"
```

---

## Wrap-up

After all 12 tasks land:

1. Push to `origin/main`: `git push`
2. Visually verify on simulator + browser (the manual checklists in Tasks 6 and 11).
3. Update memory `project_pictok.md` with the new feature description and updated test count.
