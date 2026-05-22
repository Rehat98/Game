# Pictok Daily Archive Mode Design

**Date:** 2026-05-22
**Author:** Rehat + Claude
**Status:** Approved
**Extends:** `2026-05-18-emoji-decode-design.md` (Daily mechanics), `2026-05-19-endless-mode-streaks-design.md` (streak rules, Endless distinction)

## Background

A lapsed player who misses one or more days of Pictok hits a retention cliff: the broken streak resets to 0, and there is no way to play the puzzles they missed. The audit identified this as a meaningful retention drag — players who skip a few days and find no path back tend not to come back at all.

This spec adds a **Daily Archive**: a lightweight catch-up surface that lets players play missed past puzzles. The archive deliberately does **not** repair broken streaks — the streak system stays sacred — but it gives lapsed players content and progress to engage with on return.

## Goals

- Lapsed players can play puzzles from days they missed (within a 28-day window).
- Players can peek at the answers of past puzzles they already solved or failed.
- Archive plays update lifetime stats (so Stats reflect completion progress) but do not touch streak fields.
- Discovery surface reuses the existing Stats calendar — no new tab, no new top-level navigation.

## Non-goals (deliberate YAGNI)

- Replaying solved or failed puzzles (one outcome per puzzle, permanent).
- Archive older than 28 days (no calendar scroll, no "all puzzles" screen).
- Retroactive streak restoration or grace-window streak rules.
- "You missed N puzzles" nudge banner on the Today tab.
- Web/iOS friend leaderboards on archive completion.

## Mechanics

The Stats calendar heatmap currently shows the last 28 days as colored cells (green = perfect, yellow = solved, red = failed, empty = unplayed/future). Cells become tappable with three behaviors driven by cell state and date:

| Cell state | Tap behavior |
|------------|--------------|
| Unplayed past (date < today, no record) | Open **Archive game** for that date |
| Solved (green / yellow) | Open **Answer peek sheet** |
| Failed (red) | Open **Answer peek sheet** |
| Today's cell | No-op (today is reachable via the Today tab) |
| Future cells | No-op |
| Outside 28-day window | Not visible in the calendar — not reachable |

### Archive game

A fullScreenCover presenting an `ArchiveView`. UI mirrors the Daily game:

- 5 hearts (independent of any other game state).
- Emoji header, category chip, blanks, keyboard.
- Hint button: free, 1 per puzzle (same rule as Daily).
- Submit ✓ sticker once all letters are revealed.
- Win celebration (fireworks) on solve, fail celebration (rain) on hearts exhausted.
- One-chance alert when hearts drop 2 → 1, same copy as Daily.
- Close affordance (X) in the top bar — unlike Endless, archive is a focused single-puzzle session, so a clear "back to Stats" button belongs.
- **Closing mid-game discards state**: tapping close before solve or fail writes nothing. The cell stays unplayed, the player can retry later. No partial-progress persistence.
- **Celebrations omit streak references**: the win celebration text says e.g. "Caught up!" rather than "Streak: N" since archive doesn't bank the streak.

### Answer peek sheet

A small `.sheet` (not fullScreenCover) showing:

- Emoji clue
- Category + subcategory line
- The answer revealed (large, bold)
- A small status line: "✓ Solved" / "✗ Beat you"
- "Got it" close button

No interactivity beyond closing. Plain reference card.

### Streak rule

**Archive plays are streak-neutral.** On solve or fail:

- `solvedPuzzleIds` / `failedPuzzleIds` updated (so Endless rotation and Stats counts reflect)
- `totalSolved` / `totalPlayed` incremented (so lifetime stats grow)
- `guessDistribution` updated (so the chart reflects)
- `currentStreak` / `longestStreak` / `lastSolvedDate` / `streakFreezesAvailable` **never** modified

This is the critical invariant: solving a missed puzzle in archive does not retroactively repair the broken streak. The "daily ritual" promise stays intact.

## Data model

No new persistent fields. The existing `UserState` already tracks per-puzzle outcomes via `solvedPuzzleIds` and `failedPuzzleIds`, plus the lifetime counters. Archive solves write to the same fields a Daily solve writes to, minus the streak fields.

A new method on `UserStateStore`:

```swift
func recordArchiveOutcome(puzzleId: String,
                         solved: Bool,
                         wrongGuesses: Int,
                         hintUsed: Bool)
```

This is a deliberate subset of the Daily recorder. It does **not** accept a date parameter (puzzleId is enough to identify) and does **not** update any streak field. It is the single write site for archive outcomes.

## Architecture

### iOS

| Component | Role | Notes |
|-----------|------|-------|
| `ArchiveSession` (new) | Owns one puzzle pinned to a date; runs game loop; calls `recordArchiveOutcome` on solve/fail | Mirrors `EndlessSession` patterns but date-fixed, single-puzzle, no advance() |
| `ArchiveView` (new) | SwiftUI view for the archive game | Lightweight `TodayView` cousin — hearts, emoji header, keyboard, submit, celebrations, close button |
| `AnswerPeekSheet` (new) | `.sheet` showing emoji + answer for played puzzles | Read-only reference card |
| `CalendarHeatmapView` (modified) | Cells wrap in `Button`; tap bubbles a callback with cell date + state | No layout change |
| `StatsView` (modified) | Receives cell tap; routes to Archive game, Answer peek, or no-op based on state + date | Holds the modal presentation state |
| `UserStateStore` (modified) | New `recordArchiveOutcome(...)` method | Subset of daily recorder; never touches streak |

### Web

Mirror the iOS structure in `web/js/`:

- New `archive-session.js` mirroring `endless-session.js` (no `advance()`, takes a fixed puzzle).
- New `archive.js` UI module rendering the archive game inside a modal.
- New peek modal in `ui.js` for already-played cells.
- `stats.js`: calendar cells become clickable; tap fires through to a callback in `main.js`.
- Service worker cache version bump.

## UI flow

```
Stats tab
   │
   ├── Calendar cell (unplayed past) tapped
   │      │
   │      └── ArchiveView (fullScreenCover)
   │             ├── Solve → win celebration → record outcome → close → back to Stats
   │             └── Fail  → fail celebration → record outcome → close → back to Stats
   │
   ├── Calendar cell (solved or failed) tapped
   │      │
   │      └── AnswerPeekSheet (.sheet, ~half screen)
   │             └── "Got it" → dismiss
   │
   └── Calendar cell (today / future / no puzzle for that date) tapped
          └── No-op
```

## Tests

### iOS (XCTest)

- `ArchiveSessionTests`
  - `init` loads the requested puzzle and starts with 5 hearts.
  - `guess` correct/wrong updates state as expected.
  - `submit` on solved → calls `recordArchiveOutcome(solved: true)`.
  - Hearts exhausted → calls `recordArchiveOutcome(solved: false)`.
  - Hint usage tracked per puzzle.
- `UserStateStoreTests.recordArchiveOutcome`
  - Updates `solvedPuzzleIds` / `failedPuzzleIds` and lifetime counters.
  - **Never** changes `currentStreak`, `longestStreak`, `lastSolvedDate`, `streakFreezesAvailable`. This is the critical invariant — assert all four explicitly before and after.
  - Idempotent if the same puzzleId is recorded twice (defensive — shouldn't happen since cells lock).

### Web (node:test)

- `archive-session.test.js` mirroring the iOS session tests.
- `user-state.test.js` additions: same `recordArchiveOutcome` invariant.

### Manual QA (added to existing matrix)

- Tap unplayed past cell → game launches → solve → outcome recorded → streak unchanged.
- Tap unplayed past cell → fail → outcome recorded → streak unchanged.
- Tap a previously-solved cell → peek sheet → close.
- Tap a previously-failed cell → peek sheet shows "Beat you" → close.
- Tap today's cell → nothing happens.
- Tap a future cell → nothing happens.
- Solve all 28 archive days → calendar fully green → no streak change.

## Web service worker

Cache key bumps from `pictok-v12` to `pictok-v13` so the new archive modules + clickable cells reach existing PWA installs.

## Open questions

None. All four foundational decisions are made:

1. Streak impact → **neutral**
2. UI placement → **tappable Stats calendar cells**
3. Replay rule → **locked once played; peek sheet for solved/failed**
4. Scope → **last 28 days, matches calendar window**
