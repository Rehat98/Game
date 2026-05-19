# Pictok UI Polish + Endless Hints + Win Celebration Design

**Date:** 2026-05-19
**Author:** Rehat + Claude
**Status:** Approved (all sections)
**Builds on:** `2026-05-19-endless-mode-streaks-design.md`
**Inherits constraints from:** `2026-05-18-emoji-decode-design.md` (visual style, palette, dependency policy)

## Background

After the endless-mode + word-by-word work shipped, the app's structure was right but the UI felt "boring" — solid paper background, sparse layout, no motion, no celebration on wins. Continue Playing (formerly "Play Endless") also lacked a hint button. This spec adds four additive polish layers without changing the existing sticker/paper-craft identity:

1. **Rename** the entry point from "Play Endless" to "Continue Playing."
2. **Fireworks win celebration** with bouncing text and the existing win sound, in both Daily and Continue Playing modes.
3. **Hint button** in Continue Playing — one free letter-reveal per puzzle.
4. **Motion polish:** keyboard color flash on letter press, slide transitions between Continue-Playing puzzles, heart pop on loss.

Daily mode's existing hint mechanic (1-heart subcategory reveal, 2-heart letter reveal) is unchanged. The 60-puzzle pool, puzzles.json schema, streak rules, and per-puzzle hearts model from the prior spec are all preserved.

## Scope discipline

**Adding:**
- 3 new files: `WinCelebrationView.swift`, `FireworksEmitter.swift`, `HintButton.swift`
- 1 new method on `EndlessSession`: `useHint()`
- 1 new state field on `EndlessSession`: `hintUsedThisPuzzle: Bool`
- 1 new `pkPink` accent color in `Theme.swift`
- 4 motion adds: keyboard flash, slide transitions, heart pop, win celebration

**NOT changing:**
- Sticker visual identity (paper background, offset shadow, rounded fonts)
- Daily-mode hint mechanic
- Bundled puzzles.json
- Streak rules
- Stats tab layout
- Hearts mechanic in Daily mode
- Per-puzzle hearts in Endless

**Dependency policy:** zero third-party libraries. All animation and particles use native SwiftUI primitives (`TimelineView`, `Canvas`, `.transition`, `.scaleEffect`, spring animations).

## Section 1 — Rename "Play Endless" → "Continue Playing"

One-line label change in `TodayView.swift`:

```swift
// Before
StickerButton(title: "Play Endless", icon: "▶️", fill: .pkGreen) { onPlayEndless() }
// After
StickerButton(title: "Continue Playing", icon: "▶️", fill: .pkGreen) { onPlayEndless() }
```

No semantic changes. The `onPlayEndless` closure name stays for now (internal naming; not user-visible). Renaming the closure to `onContinuePlaying` is a future cleanup; out of scope.

## Section 2 — Win celebration (fireworks)

A short, dramatic overlay that fires when the player solves a puzzle.

### Trigger

- **Daily (`TodayView`):** when `todaySolved` transitions from `false` to `true`, present `WinCelebrationView` as an overlay for 1.8 seconds, then the existing result sheet slides up underneath. The existing solve handler keeps running unchanged; only the visual moment is enhanced.
- **Continue Playing (`EndlessView`):** when `session.isSolved` transitions to `true`, replace the current text-only "Solved!" overlay with `WinCelebrationView` for 1.8 seconds, then call `session.advance()`.

**Fail state (hearts depleted):** keeps its current quieter text-only overlay ("Answer was X"). No fireworks for failures.

### Visual composition

```
   ✨   *      ✨    *
       *  ✨        *
    *      *  ✨
   ┌─────────────────────────┐
   │      🎉  Solved!  🎉    │   ← scale-bounce 0.5x → 1.1x → 1.0x
   └─────────────────────────┘
            T O Y                ← answer text below, fade-in
          S T O R Y
```

### Components

**`FireworksEmitter.swift`** — native SwiftUI particle source:
- Uses `TimelineView(.animation)` for per-frame updates at 60fps.
- Renders into a `Canvas`.
- Emits 5–8 burst origins at randomized positions across the upper 2/3 of the screen, spaced over the first 1.4s of the overlay.
- Each burst spawns ~30 small particles (mix of circles and squares, 4–8pt) that radiate outward at a fixed initial velocity per particle, with linear gravity pulling them down.
- Particle colors cycle through `pkYellow`, `pkRed`, `pkGreen`, `pkBlue`, and the new `pkPink` (added to `Theme.swift`).
- Particles fade alpha 1 → 0 over their 1.2s lifetime.

**`WinCelebrationView.swift`** — composes:
- `FireworksEmitter` filling the safe area.
- A centered text block: "Solved!" (`Font.pkTitle`) with a spring-bounce scale animation (0.5 → 1.1 → 1.0 over 200ms via `withAnimation(.spring(response: 0.4, dampingFraction: 0.6))`).
- The answer text (`Font.pkSubtitle`) below the "Solved!" label, fade-in from opacity 0 → 1 over 300ms starting at 150ms.
- Plays `SoundService.playWin()` (existing) on `.onAppear`.

### Duration tuning

| Time   | Event                                              |
|--------|----------------------------------------------------|
| 0ms    | Overlay appears, text begins scale-bounce, sound starts |
| 0–1400ms | Fireworks emit + particles arc                    |
| 200ms  | Text settles at 1.0x scale                         |
| 300ms  | Answer text fades to opacity 1.0                   |
| 1400ms | Last fireworks burst emitted                       |
| 1400–1800ms | Particles fall + fade, text holds              |
| 1800ms | Overlay dismisses → result sheet (Daily) / auto-advance (Endless) |

### Performance

Native `Canvas` + `TimelineView` handles roughly 200 concurrent particles smoothly on iPhone 17 / iOS 26.5. At peak (after burst #8, before earlier bursts have fully decayed), we expect ~120–150 particles. No performance risk.

### Sound

The existing `win.wav` synthetic placeholder plays once on celebration appear via `SoundService.playWin()`. Task 29 of the original v1 plan ("replace synthetic sounds with real ones") remains pending but does not block this work — the celebration plays whatever sound is wired.

## Section 3 — Hint button in Continue Playing

### Placement

Right-anchored sticker button between the blanks and the keyboard:

```
   ❤️❤️❤️❤️❤️
   ┌───────────────────┐
   │   🧸  📖          │
   └───────────────────┘
       [Movie]
     _ _ _    _ _ _ _ _

                          [💡 Hint]   ← right-anchored, sticker style

   Q W E R T Y U I O P
   A S D F G H J K L
       Z X C V B N M
```

### Behavior

- **Cost:** free (no heart cost).
- **Limit:** 1 use per puzzle.
- **Effect on tap:** reveals the first unguessed letter in the active word (using `activeWord.first(where: { !correctGuesses.contains($0) })`). The revealed letter is added to `session.correctGuesses`.
- **After use:** the button greys out (still visible but disabled) for the rest of the current puzzle.
- **Reset:** `EndlessSession.advance()` resets `hintUsedThisPuzzle = false` alongside the existing per-puzzle resets.
- **Disabled states:** also disabled when `isSolved || isFailed` (puzzle is over).

### Edge case: hint reveals last needed letter

If the hint reveals the final letter required to solve the puzzle, the same end-of-`useHint()` check triggers `isSolved = true` and calls `recordSolve(id:)`. Win celebration fires normally. This mirrors how the Daily-mode hint can complete a puzzle.

### `EndlessSession` changes

```swift
private(set) var hintUsedThisPuzzle: Bool = false

func useHint() {
    guard !hintUsedThisPuzzle, let puzzle = currentPuzzle, !isSolved, !isFailed else { return }
    guard let activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer,
                                                     correctGuesses: correctGuesses) else { return }
    let activeWord = GameEngine.wordBreakdown(answer: puzzle.answer).words[activeIdx]
    guard let toReveal = activeWord.first(where: { !correctGuesses.contains($0) }) else { return }
    correctGuesses.insert(toReveal)
    hintUsedThisPuzzle = true
    if GameEngine.isSolvedByWord(answer: puzzle.answer, correctGuesses: correctGuesses) {
        isSolved = true
        recordSolve(id: puzzle.id)
    }
}

// In advance() — add:
hintUsedThisPuzzle = false
```

### Tests (additions to `EndlessSessionTests.swift`)

- `test_useHint_revealsFirstLetterOfActiveWord` — confirms it reveals the right letter
- `test_useHint_marksUsed_andSubsequentCallsAreNoOp` — confirms 1-per-puzzle cap
- `test_useHint_doesNotCostHearts` — confirms hearts unchanged
- `test_advance_resetsHintAvailability` — confirms the reset on puzzle change
- `test_useHint_solvesPuzzle_whenItRevealsLastNeededLetter` — confirms auto-solve

### `HintButton.swift` (component)

```swift
struct HintButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        StickerButton(title: "Hint", icon: "💡", fill: .pkYellow) {
            if isEnabled { action() }
        }
        .opacity(isEnabled ? 1.0 : 0.4)
        .disabled(!isEnabled)
    }
}
```

`EndlessView` passes `isEnabled: !session.hintUsedThisPuzzle && !session.isSolved && !session.isFailed` and `action: { session.useHint() }`.

## Section 4 — Motion polish

Four small motion adds that breathe life into the existing screens without restyling them.

### 4.1 Keyboard letter-press color flash

In `KeyboardView`, when the player taps a letter:
- **Correct guess** → key flashes `pkGreen` for 250ms, then settles into its post-guess state (correct-guessed keys retain a subtle green tint).
- **Wrong guess** → key flashes `pkRed` for 250ms + a 6px horizontal shake oscillating twice, then settles into the wrong-guessed state (red tint).
- **Already-guessed letter** → no animation (no-op).

State on `KeyboardView`:
```swift
@State private var flashingLetter: (letter: Character, isCorrect: Bool, expiresAt: Date)?
```

Implementation note: when `onGuess` fires, the parent already mutates `correctGuesses` or `wrongGuesses`. `KeyboardView` observes which set the letter ended up in (within 1 frame) and triggers the flash via a `.task` modifier scheduled to clear after 250ms.

### 4.2 StickerButton press feedback (unchanged)

`StickerButton.swift` already animates a 3px offset on press via `DragGesture(minimumDistance: 0)`. Verified post-Theme-shadow-fix. No change needed.

### 4.3 EndlessView puzzle slide transition

When `session.advance()` swaps puzzles:
- Current puzzle content slides out to the left (-30px offset + opacity 0) over 250ms.
- New puzzle content slides in from the right (+30px offset starting, settling to 0) over 250ms.

Implementation: wrap the puzzle content `VStack` (inside `EndlessView.content`) in a view keyed by `puzzle.id`, and apply:
```swift
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal:   .move(edge: .leading).combined(with: .opacity)
))
```

The `withAnimation(.easeInOut(duration: 0.25))` wraps the call to `session.advance()` inside `EndlessView.showResult(...)`.

### 4.4 HeartsRow pulse on heart loss

In `HeartsRow`, when `hearts` decrements:
- The heart that just disappeared scales 1.0 → 1.4 → 0.0 over 350ms (pop-then-vanish).
- Remaining hearts gently shift to fill the space.

Implementation: change `HeartsRow` to render `ForEach(0..<5, id: \.self)` with a `.transition(.scale.combined(with: .opacity))` on each heart and `withAnimation(.easeOut(duration: 0.35))` keyed by the parent state mutation.

The animation triggers automatically when `hearts` changes; no explicit dispatching needed.

### What's NOT in this section

- No emoji header entrance animation (would compete visually with the slide transition).
- No background gradient or pattern change (stays solid `pkPaper` to preserve the v1 sticker identity).
- No haptics changes (existing `HapticsService.tap()` continues firing).
- No new animation library / third-party deps.

## File structure summary

| Path                                                | Status | Responsibility |
|-----------------------------------------------------|--------|----------------|
| `Pictok/Views/Effects/WinCelebrationView.swift`     | create | Overlay with fireworks + bouncing "Solved!" + win sound |
| `Pictok/Views/Effects/FireworksEmitter.swift`       | create | Native particle source (TimelineView + Canvas) |
| `Pictok/Views/Components/HintButton.swift`          | create | Sticker hint button (1 free use per puzzle) |
| `Pictok/Views/EndlessView.swift`                    | modify | Wire hint button + win celebration + slide transition |
| `Pictok/Views/TodayView.swift`                      | modify | Wire win celebration + rename label |
| `Pictok/Views/Components/KeyboardView.swift`        | modify | Letter-press color flash + shake on wrong |
| `Pictok/Views/Components/HeartsRow.swift`           | modify | Heart pop on loss |
| `Pictok/Game/EndlessSession.swift`                  | modify | Add `hintUsedThisPuzzle` + `useHint()` |
| `Pictok/Views/Theme.swift`                          | modify | Add `pkPink` accent color for fireworks |
| `PictokTests/EndlessSessionTests.swift`             | modify | Add 5 hint-mechanic tests |

## Success criteria

1. Tapping "Continue Playing" enters Endless mode (rename only — flow unchanged).
2. Solving a Daily or Endless puzzle triggers the fireworks celebration with "Solved!" text bounce and `win.wav`, lasting ~1.8s before result sheet / advance.
3. Continue Playing shows a `💡 Hint` sticker button. Tapping it reveals the first unguessed letter of the active word, doesn't change hearts, and disables the button until the next puzzle.
4. Wrong keyboard guesses flash red + shake; correct ones flash green.
5. Advancing in Continue Playing slides the puzzle out left + new puzzle in right.
6. Losing a heart pops the empty heart out of the row.
7. All 75+ existing tests still pass; new tests cover the hint mechanic.
8. App launches and renders correctly on iPhone 17 simulator.

## Out of scope (v1.x and beyond)

- Real win sound (synthetic placeholder stays — Task 29 of v1 plan)
- App icon refinement (Task 28)
- Manual QA matrix (Task 30)
- TestFlight submission (Task 31)
- Background gradient or pattern
- Mascot character / illustration
- Dark mode
- Animated emoji header on puzzle load
- Haptic feedback for win / fail

## Open questions

None — all design decisions resolved.
