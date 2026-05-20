# Pictok Mechanic Revert + Safety Net Design

**Date:** 2026-05-20
**Author:** Rehat + Claude
**Status:** Approved (mechanic + submit-button choices locked via brainstorming Q&A)
**Supersedes:**
- The word-by-word reveal mechanic from `2026-05-19-endless-mode-streaks-design.md` § Word-by-word reveal mechanic (and its implementation in `2026-05-19-endless-mode-streaks-implementation.md` Tasks WBW-1 → WBW-4).
- The strict wrong-guess rule that locks letters across words.

## Background

Word-by-word reveal was introduced in v1.5 to keep multi-word puzzles from being trivially easy (the original behavior auto-filled letters across every word, so guessing "T" in TOY also revealed T in STORY before the player had to think about the second word). The mechanic was approved on paper.

Once shipped, two real-world frustrations surfaced during play:

1. **Trapped letters.** Wrong guess in the active word permanently locks that letter, even if it's correct in a later word. Players who guess "B" while solving TOY can never reveal B in STORY when STORY becomes active — even though B is in STORY. This reads as a bug, not difficulty.

2. **Reveal feels broken.** When a letter IS correct in a future word, BlanksView hides it. Players see no feedback that their guess was "right but for later" — they just see a blank.

User's call (2026-05-20): revert to classic hangman reveal, add safety nets that fix the death-spiral feel, replace the one puzzle whose emoji didn't land.

## Design

### §1 — Mechanic: classic hangman reveal

- All blanks for every word are visible from the start of the puzzle.
- Correct guess → letter reveals in **every word** of the answer where it appears.
- Wrong guess (letter is in no word of the answer) → −1 heart.
- No active-word concept. No connector word auto-fill. No word ordering.
- A puzzle is solved when every letter in the answer has been revealed (via correct guess or hint).

This is the pre-WBW behavior. The WBW additions in `GameEngine` (`wordBreakdown`, `activeWordIndex`, `isCorrect(letter:inWord:of:)`, `isSolvedByWord`, `isPositionRevealed`, `connectorWords`) are removed entirely; the simple variants (`isCorrect(letter:in:)`, `isSolved(answer:correctGuesses:revealedLetter:)`) become the only path again.

### §2 — Submit button

Replaces the silent auto-win moment with an explicit confirmation:

- While the puzzle has unrevealed letters: the keyboard is active and tapping letters works as today.
- When **every** letter in the answer is in `correctGuesses` (or matches `revealedLetter`): a sticker button labelled **"Submit ✓"** appears below the blanks, in `pkGreen`, with a bouncing entrance.
- The win celebration does NOT fire automatically. The player must tap Submit.
- Tapping Submit fires the existing `WinCelebrationView` (Daily) or hands off to `session.advance()` after celebration (Endless).
- The fail path (hearts → 0) is unchanged — it still fires the `FailCelebrationView` automatically.

Player can keep guessing letters even after the puzzle is technically complete (no-ops, no heart cost) — the Submit button just stays visible until they tap it.

### §3 — "One chance left" warning

A one-time popup that fires the **first** time hearts transition to 1 during a puzzle:

- iOS `Alert` with title "One chance left" and body "Make it count — one more wrong guess ends the puzzle."
- Single "OK" button to dismiss.
- Tracked in transient session state (not persisted) — fires once per puzzle, even if hearts go back up via hint (won't happen in current model, but defensive).
- Daily uses a transient flag on `TodayView`; Endless uses a flag on `EndlessSession`.

The warning does NOT block input — the alert is dismissable, and the game continues from wherever it was.

### §4 — JOHN LEGEND puzzle removal

The 🚽🧙 = JOHN LEGEND puzzle relied on the American slang "john = toilet" which didn't land for the user. Replacement candidates (Ice-T, Usher, Pink, others) failed the strict authoring bar similarly.

**Decision:** remove `puzzle-059` entirely. Celeb category goes from 12 → 11. Total puzzle count goes from 60 → 59. Acceptable shortfall; spec target was 60 but Brand was already 10/12 by negotiation.

Renumbering: puzzles 060 (MORGAN FREEMAN) stays as `puzzle-059` after the removal — IDs shift down by one for the gap-filling effect. Alternatively, leave the gap (id `puzzle-059` simply doesn't exist). Either works since `PuzzleLoader` looks up by date, not by sequential id. Going with **leave the gap** to avoid date drift on existing user state.

## File changes

| Path | Status | Responsibility |
|------|--------|----------------|
| `Pictok/Game/GameEngine.swift` | modify | Remove `connectorWords`, `WordBreakdown`, `wordBreakdown(answer:)`, `activeWordIndex`, `isCorrect(letter:inWord:of:)`, `isSolvedByWord`, `isPositionRevealed`. Keep the simple `isCorrect(letter:in:)`, `isSolved(answer:correctGuesses:revealedLetter:)`, `isFailed`. |
| `Pictok/Views/Components/BlanksView.swift` | modify | Revert to simple reveal: position reveals iff letter ∈ correctGuesses ∨ letter == revealedLetter. No `activeWordIndex` computation. |
| `Pictok/Game/EndlessSession.swift` | modify | `guess()` uses `GameEngine.isCorrect(letter:in:)` and `GameEngine.isSolved(...)`. Add transient `hasShownOneChanceWarning: Bool`. After solve check passes, set transient `needsSubmit: Bool = true` — does NOT mark `isSolved` until `submit()` is called. New `submit()` method flips `isSolved = true` and writes to store. |
| `Pictok/Views/TodayView.swift` | modify | Guess handler uses simple `GameEngine.isCorrect`/`isSolved`. Show Submit button when puzzle is solvable. Tap submit triggers celebration. Add `hasShownOneChanceWarning` and Alert. Connect to `EndlessSession`-style transient `needsSubmit`. |
| `Pictok/Views/EndlessView.swift` | modify | Render new Submit button when `session.needsSubmit`. Render Alert when `session.hearts == 1` first transition. |
| `Pictok/Resources/puzzles.json` | modify | Remove the puzzle-059 entry (JOHN LEGEND). 59 entries remain. |
| `PictokTests/GameEngineWordByWordTests.swift` | delete | WBW test suite is dead. |
| `PictokTests/EndlessSessionTests.swift` | modify | Remove WBW-specific tests (`test_wrongGuessInCurrentWord_evenIfLetterInLaterWord_decrementsHearts`). Add submit + 1-heart-warning tests. |
| `PictokTests/GameEngineTests.swift` | unchanged | Existing tests for simple `isCorrect`/`isSolved`/`isFailed` cover the reverted mechanic. |

## Success criteria

1. Multi-word puzzles (TOY STORY, FAST AND FURIOUS, WAR AND PEACE, etc.) reveal letters across all words on correct guess.
2. Wrong guess that's a future-word letter does NOT permanently lock — there are no future words anymore; the letter is just "wrong" because it's not in the answer at all.
3. Solving the last letter does not auto-celebrate; player taps a visible Submit button.
4. When hearts drop from 2 → 1, a one-time alert fires.
5. JOHN LEGEND no longer appears in the puzzle pool.
6. All non-WBW tests still pass.
7. `GameEngineWordByWordTests.swift` is deleted.
8. The simulator smoke test shows the new mechanic on at least one multi-word puzzle (Daily today = YESTERDAY single word; pick an Endless multi-word like TOY STORY for the visual check).

## Out of scope

- Renumbering all puzzle IDs to close the gap (would shift dates).
- Adding hints back to Daily mode (current hint mechanic stays as-is).
- Replacing the JOHN LEGEND puzzle with a different celebrity (it's just removed).
- Restoring word-by-word reveal as an optional difficulty level (future v1.x consideration if play data shows the mechanic is too easy after revert).
