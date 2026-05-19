# Pictok Endless Mode + Streaks Design

**Date:** 2026-05-19
**Author:** Rehat + Claude
**Status:** Approved (sections 1–4)
**Supersedes:** the daily-cap mechanic and global-hearts-with-refill mechanic of `2026-05-18-emoji-decode-design.md`. All other aspects of the parent spec (visual style, 5 categories, sticker UI, daily 9 AM notification, share card, trademark notes) remain in force.

## Background

The original Pictok v1 spec mirrors Wordle / Connections: one puzzle per day, hearts as a global wrong-guess budget with a 4-hour refill, hard lockout after exhaustion. The retention loop is FOMO and scarcity — "come back tomorrow."

The challenge surfaced during build-out: that model has a low daily ceiling (one solve = done) and no real differentiator vs. existing web games. A binge user who likes the app can't keep playing.

**This spec pivots to a layered model:** the Daily Puzzle stays as the social/streak anchor, but a new **Endless** mode underneath lets players play as many puzzles as they want. The standout factor vs. web games becomes "binge-play with daily-return reward" — no major emoji-rebus app does both.

## Architecture

Single **Play tab** structure (Stats tab layout unchanged, with one added row for `lifetimeSolvedCount`):

```
┌─────────────────────────┐
│  💖💖💖💖💖    💡  ⚙   │
├─────────────────────────┤
│                         │
│   [Daily Puzzle card]   │  ← hero, drives streak + share
│   🧸📖   Movie          │
│   T O Y   _ _ _ _ _     │
│                         │
├─────────────────────────┤
│   ▶ Play Endless        │  ← sticker button
├─────────────────────────┤
│  Today's stats / streak │
└─────────────────────────┘
[Today] [Stats]
```

Tapping **▶ Play Endless** launches the Endless flow on a separate view. The Daily card on the Play tab is the unchanged `TodayView`. The Stats tab keeps its current layout (current streak, longest streak, daily history) with one added stat row showing `lifetimeSolvedCount` (total puzzles solved across Daily and Endless).

The Daily Puzzle and Endless puzzles **share the same 60-puzzle pool** (`puzzles.json`). Today's Daily is `puzzles[where date == today]` — unchanged from the parent spec. Endless picks from the same pool with a selection algorithm that protects upcoming Daily slots.

## Streak rules

Streak banking is **Daily-only**:

- **+1 streak** when player solves today's Daily Puzzle.
- **Endless solves do NOT bank the streak.** They are bonus play with no streak impact.
- **Failed Daily** (hearts exhausted) → streak resets to 0 (or to 1 if freeze absorbs it).
- **Missed day** (player didn't open / didn't solve Daily) → streak freeze absorbs once per streak; subsequent miss resets to 0.
- **Streak freeze** is restored when streak counter is at 0 (i.e., on next 0→1 transition). Capped at 1 stored at a time.

These rules are identical to the parent spec — nothing changes about Daily streak banking.

## Hearts model

Hearts are now **per-puzzle**, not global:

- Every puzzle (Daily or Endless) starts with **5 hearts**.
- Wrong letter guess → **−1 heart**. Correct guess → no change.
- **0 hearts mid-puzzle** = puzzle fails. The answer is revealed. The player can dismiss → next action depends on mode (Daily → return to Play tab; Endless → auto-advance to next).
- **No global lockout. No 4-hour refill timer.** Failing a puzzle does not gate further play.

The hearts UI in the puzzle screen still shows 5 hearts at start, decrementing as guesses miss. The visual treatment is unchanged.

## Endless flow

1. Player taps **▶ Play Endless** from the Play tab.
2. App invokes the **Endless selection algorithm** (below) to pick the next puzzle.
3. The puzzle screen appears — same layout as Daily (emoji header, category chip, blanks, keyboard, hearts).
4. Player guesses letters. Wins → brief "Solved!" overlay (~2 seconds, no share card). Fails (0 hearts) → "Answer was X" overlay (~2 seconds).
5. App **auto-advances** to the next selected puzzle.
6. A small **×** / Quit button in the top-left corner returns the player to the Play tab anytime.

No category filtering, no manual puzzle selection, no preview thumbnails of the next emoji. Pure flow state.

## Endless selection algorithm

For each Endless pick, scan the 60-puzzle pool in this priority order:

1. **Unseen + safe-from-spoilers:** puzzles the player has not solved or failed, AND whose Daily date is more than 7 days away. Random pick from this set. Default case for typical play.
2. **Unseen + near-future Daily:** if (1) is empty, allow puzzles with Daily dates in the next 7 days. Random pick. Triggered when 90%+ of the pool is exhausted.
3. **Replay rotation:** if all 60 are seen, random pick from the seen pool (solved or failed), excluding any puzzle ID present in `recentEndlessIds` (last 5 picks) to avoid immediate déjà-vu.

**Edge cases:**
- **Today's Daily Puzzle is always excluded** from Endless selection. The player solves the Daily on the Play tab; Endless never re-shows it on the same day.
- Failed puzzles enter the same "seen" set as solved puzzles. In replay rotation they can reappear and be re-attempted.
- After a player solves a puzzle in Endless that's also scheduled as a future Daily, the future Daily slot will still appear on its scheduled day; the player will already know the answer. Step (1) of the algorithm prevents this from happening in the common case (90+% of the player's Endless plays).

## Data model & persistence changes

### Additions to `UserState` (`Pictok/Models/UserState.swift`)

```swift
// Cumulative play history (Daily + Endless)
var solvedPuzzleIds: Set<String> = []
var failedPuzzleIds: Set<String> = []
var lifetimeSolvedCount: Int = 0      // for Stats display

// Endless dedup
var recentEndlessIds: [String] = []   // ring buffer of last 5 picks
```

### Unchanged in role (still Daily-specific)

- `currentStreak: Int`, `longestStreak: Int`, `streakFreezeAvailable: Bool` — driven by Daily solves only.
- `todayPuzzleId: String?`, `todaySolved: Bool`, `todayFailed: Bool` — Daily session state.
- `lastSolveDate: String?` — drives streak transitions.
- `todayHintUsed: HintType?`, `todayWrongCount`, `todayGuessedLetters: Set<Character>` — Daily-only session state.

### Removed

- `heartsRefillAnchor: Date` — no more 4-hour refill timer.
- The global `hearts: Int` field is repurposed: it becomes Daily-puzzle-only (each Daily puzzle starts with 5; carries through the session; resets to 5 the next day). For Endless, a transient in-memory `endlessHearts: Int = 5` lives in the Endless view model and is not persisted.

### Codable migration

`UserState` is persisted to UserDefaults as a JSON blob via the `UserStateStore`. To handle existing user data (and the simulator's already-stored state from prior sessions):

- The custom `init(from:)` decoder provides defaults for new fields when the JSON payload lacks them: `solvedPuzzleIds = []`, `failedPuzzleIds = []`, `lifetimeSolvedCount = 0`, `recentEndlessIds = []`.
- The removed `heartsRefillAnchor` field is silently ignored if present in old payloads (decode succeeds; field is dropped).
- No explicit version field is introduced. The graceful-default-on-missing behavior is sufficient for this single migration.

### GameEngine changes

`GameEngine` (in `Pictok/Game/GameEngine.swift`) gains a `mode` parameter:

```swift
enum GameMode { case daily, endless }

struct GameEngine {
    let mode: GameMode
    let puzzle: Puzzle
    // ... existing fields
}
```

Behavior split:
- **`.daily`** — behaves as today. Persists session state to `UserState.today*` fields, banks streak on solve, mutates global `hearts`.
- **`.endless`** — skips all streak banking and daily-state mutations. Manages hearts in a local in-memory counter starting at 5. On solve, only adds the puzzle ID to `solvedPuzzleIds` and increments `lifetimeSolvedCount`. On fail, adds to `failedPuzzleIds`.

### Untouched components

- `ShareCardBuilder` — still generates cards for Daily solves/fails only. Endless wins do not produce a share card.
- `NotificationScheduler` — still 9 AM daily for the Daily Puzzle. No new Endless notifications.
- `PuzzleLoader` — no changes. Loads `puzzles.json` as before.
- `Theme`, sticker UI components — no changes (the sticker shadow fix from `Theme.swift` is preserved).

## Success criteria

1. App launches with no crash for users with old `UserState` JSON payloads (Codable migration verified).
2. Tapping **▶ Play Endless** from the Play tab → an unseen puzzle appears.
3. Solving an Endless puzzle → brief overlay → next unseen puzzle auto-loads.
4. Failing an Endless puzzle (5 wrong letters) → brief overlay → next puzzle auto-loads with fresh 5 hearts.
5. Streak counter only increments on Daily solve. Endless solves do not change `currentStreak`.
6. After playing Endless, returning to the Play tab and solving the Daily still banks the streak normally.
7. `lifetimeSolvedCount` increments on every solve (Daily or Endless) and is visible in Stats.
8. Existing unit-test suite still passes (regression coverage for Daily-mode behavior).
9. Visual style (sticker UI, fonts, colors) unchanged. The post-shadow-fix `Theme.swift` is preserved.

## Out of scope (v1.x)

- **More content beyond 60 puzzles.** Replay rotation handles the post-exhaustion case. A second content drop is a separate project.
- **Share cards for Endless wins.** Daily remains the single social anchor.
- **Category filter or sorting in Endless.** Pure auto-queue.
- **Endless leaderboards or scoring beyond `lifetimeSolvedCount`.**
- **Procedural puzzle generation.**
- **Server-fetched content drops.**
- **Adaptive difficulty curve.** Endless is random within the pool.
- **iCloud / cross-device sync of `UserState`.** Local-only persists.

## Open questions

None — all design decisions resolved in brainstorming.
