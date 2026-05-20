# Pictok Mechanic Revert + Safety Net Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revert word-by-word reveal to classic hangman (letter fills across all words on correct guess), add an explicit "Submit ✓" confirmation before the win fires, add a one-time "1 chance left" alert when hearts hit 1, and drop the JOHN LEGEND puzzle whose toilet-slang emoji didn't land.

**Architecture:** Surgical edits across `EndlessSession`, `TodayView`, `EndlessView`, `BlanksView` to use the existing simple `GameEngine.isCorrect(letter:in:)` and `GameEngine.isSolved(answer:correctGuesses:revealedLetter:)` instead of the word-by-word variants. The WBW additions on `GameEngine` are deleted last, after all callers have been reverted. Submit-ready state is a computed property, not a new persisted field. The 1-heart warning lives in each view's `@State` and resets when the puzzle changes.

**Tech Stack:** Swift 5, SwiftUI (iOS 17 deployment), XCTest, xcodegen, iPhone 17 Pro Max / iOS 26.5 Simulator.

**Spec:** `docs/superpowers/specs/2026-05-20-mechanic-revert-and-safeguards-design.md` — non-negotiable, read before any task.

---

## File structure

| Path | Status | Responsibility |
|------|--------|----------------|
| `Pictok/Resources/puzzles.json` | modify | Remove the puzzle-059 entry (JOHN LEGEND). Leave the id as a gap rather than renumbering — `PuzzleLoader` is date-keyed. |
| `Pictok/Game/EndlessSession.swift` | modify | `guess()` uses simple GameEngine helpers. `useHint()` uses simple helpers. New computed `needsSubmit: Bool` (not persisted). New method `submit()` that flips `isSolved = true` and calls `recordSolve`. New transient `private(set) var hasShownOneChanceWarning: Bool` resets on `advance()`. |
| `Pictok/Views/Components/BlanksView.swift` | modify | Revert to classic reveal: position reveals iff `letter ∈ correctGuesses ∨ letter == revealedLetter`. Drop all `activeWordIndex` / `isPositionRevealed` calls. |
| `Pictok/Views/TodayView.swift` | modify | Guess handler uses simple GameEngine helpers. Don't set `todaySolved` directly when all letters revealed — show Submit button instead. Tap Submit → set `todaySolved = true` + bank streak. Add `@State hasShownOneChanceWarning`. Show `.alert` when hearts → 1. |
| `Pictok/Views/EndlessView.swift` | modify | Render Submit button overlay when `session.needsSubmit`. Tap → `session.submit()`. Add `@State hasShownOneChanceWarning`. Show `.alert` when `session.hearts == 1` first transition. |
| `Pictok/Game/GameEngine.swift` | modify | Delete: `connectorWords`, `WordBreakdown`, `wordBreakdown(answer:)`, `activeWordIndex`, `isCorrect(letter:inWord:of:)`, `isSolvedByWord`, `isPositionRevealed`. Keep the originals: `isCorrect(letter:in:)`, `isSolved(answer:correctGuesses:revealedLetter:)`, `isFailed`, `heartCost`, `letterToReveal`, `streakAfterSolve`, `streakAfterFail`. |
| `PictokTests/GameEngineWordByWordTests.swift` | delete | Whole file goes away. |
| `PictokTests/EndlessSessionTests.swift` | modify | Remove `test_wrongGuessInCurrentWord_evenIfLetterInLaterWord_decrementsHearts` (it's WBW-specific). Add 3 new tests covering submit + 1-heart-warning behavior. |

## Test command

```bash
xcodebuild test \
  -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -quiet
```

After any task that creates or deletes a Swift file, regenerate the Xcode project first:

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
```

---

## Task 1: Remove puzzle-059 (JOHN LEGEND) from `puzzles.json`

**Files:**
- Modify: `Pictok/Resources/puzzles.json`

- [ ] **Step 1: Find the puzzle entry**

```bash
grep -n "JOHN LEGEND\|puzzle-059" /Users/rehatchugh/emoji-decode/Pictok/Resources/puzzles.json
```

Expected: one match around `"id": "puzzle-059"` with `"answer": "JOHN LEGEND"`.

- [ ] **Step 2: Delete that entry**

Open `Pictok/Resources/puzzles.json` and remove the entire object for `puzzle-059`, including its trailing comma. The neighboring puzzles (`puzzle-058` and `puzzle-060`) stay; the array now has a gap at index where 059 would be. JSON does not require sequential `id` values.

- [ ] **Step 3: Re-validate**

```bash
python3 /Users/rehatchugh/emoji-decode/scripts/validate-puzzles.py /Users/rehatchugh/emoji-decode/Pictok/Resources/puzzles.json
```

Expected:
- `Total: 59 puzzles` (was 60)
- `Categories: {'Movie': 14, 'Song': 12, 'Book': 12, 'Brand': 10, 'Celeb': 11}` (Celeb dropped 12→11)
- `OK: all checks passed.`

If validation fails because a hard-coded "60 expected" check exists, update the validator to use `>= 50` as a sanity floor.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: all current tests pass. The puzzle removal does not affect any test fixture (tests use their own `test-puzzles.json` fixture).

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Resources/puzzles.json
git -C /Users/rehatchugh/emoji-decode commit -m "Remove puzzle-059 (JOHN LEGEND): toilet=john slang didn't land"
```

---

## Task 2: EndlessSession revert + submit + 1-heart warning, with tests

**Files:**
- Modify: `Pictok/Game/EndlessSession.swift`
- Modify: `PictokTests/EndlessSessionTests.swift`

This is the biggest task. Read the current `EndlessSession.swift` first to remember the structure.

- [ ] **Step 1: Add the 3 new tests (failing)**

In `PictokTests/EndlessSessionTests.swift`, inside the existing class, after the last test method, append:

```swift
func test_solvingDoesNotSetIsSolved_butSetsNeedsSubmit() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    let answer = session.currentPuzzle!.answer
    // Guess every unique letter of the answer.
    for ch in Set(answer.filter { $0.isLetter }) {
        session.guess(letter: ch)
    }
    XCTAssertFalse(session.isSolved,
                   "guess() must not auto-solve; player must tap Submit first")
    XCTAssertTrue(session.needsSubmit,
                  "all letters revealed → needsSubmit must be true")
}

func test_submit_flipsIsSolved_andRecordsSolve() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    let solvedId = session.currentPuzzle!.id
    for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
        session.guess(letter: ch)
    }
    XCTAssertTrue(session.needsSubmit)

    session.submit()
    XCTAssertTrue(session.isSolved)
    XCTAssertTrue(store.state.solvedPuzzleIds.contains(solvedId))
    XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
}

func test_oneChanceWarning_firesOnceWhenHeartsHitOne() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    let answerLetters = Set(session.currentPuzzle!.answer.filter { $0.isLetter })
    // Burn 4 wrong guesses → hearts go 5→4→3→2→1.
    let wrongLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".filter { !answerLetters.contains($0) }
    for ch in wrongLetters.prefix(4) {
        session.guess(letter: ch)
    }
    XCTAssertEqual(session.hearts, 1)
    XCTAssertTrue(session.hasShownOneChanceWarning,
                  "Transitioning into hearts == 1 should mark hasShownOneChanceWarning")

    // Advance to next puzzle → flag should reset.
    session.advance()
    XCTAssertFalse(session.hasShownOneChanceWarning,
                   "advance() must reset hasShownOneChanceWarning")
}
```

Also DELETE the existing `test_wrongGuessInCurrentWord_evenIfLetterInLaterWord_decrementsHearts` test from the same file — its assertion ("X costs a heart even though X is not in word 0") becomes wrong under classic hangman; the trapped-letter behavior is exactly what we're removing.

- [ ] **Step 2: Run tests to verify the new ones fail**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: build FAILS with "value of type 'EndlessSession' has no member 'needsSubmit'", or the new tests fail with assertion errors. Either confirms TDD red state.

- [ ] **Step 3: Modify `EndlessSession.swift`**

Open `Pictok/Game/EndlessSession.swift`. Replace the `guess(letter:)` method and `useHint()` method, add the new state + method.

After `private(set) var isFailed: Bool = false` (and the existing `hintUsedThisPuzzle`), add:

```swift
    private(set) var hasShownOneChanceWarning: Bool = false

    /// True when every letter in the answer has been correctly guessed (or revealed
    /// via hint), but the player has not yet tapped Submit. Win celebration is gated
    /// on the player tapping Submit, which calls `submit()`.
    var needsSubmit: Bool {
        guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return false }
        return GameEngine.isSolved(answer: puzzle.answer,
                                   correctGuesses: correctGuesses,
                                   revealedLetter: nil)
    }
```

Replace `guess(letter:)` with:

```swift
    func guess(letter: Character) {
        guard let puzzle = currentPuzzle, !isSolved, !isFailed else { return }
        let upper = Character(String(letter).uppercased())
        if correctGuesses.contains(upper) || wrongGuesses.contains(upper) { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle) {
            correctGuesses.insert(upper)
            // NOTE: do not flip isSolved here. The player must tap Submit;
            // that path runs in submit().
        } else {
            wrongGuesses.insert(upper)
            hearts -= 1
            if hearts == 1 && !hasShownOneChanceWarning {
                hasShownOneChanceWarning = true
            }
            if GameEngine.isFailed(lives: hearts) {
                isFailed = true
                recordFail(id: puzzle.id)
            }
        }
    }
```

Replace `useHint()` with:

```swift
    func useHint() {
        guard !hintUsedThisPuzzle,
              let puzzle = currentPuzzle,
              !isSolved, !isFailed else { return }
        // Pick the first unguessed letter in the answer, left to right.
        guard let toReveal = puzzle.answer.first(where: {
            $0.isLetter && !correctGuesses.contains($0)
        }) else { return }
        correctGuesses.insert(toReveal)
        hintUsedThisPuzzle = true
        // Like guess(): do not auto-solve. needsSubmit becomes true via its
        // computed getter, and the view shows the Submit button.
    }
```

Add a new method `submit()` after `useHint()`:

```swift
    /// Player-tap finisher: flips isSolved and records the solve. Only does work
    /// if the puzzle is currently `needsSubmit` (all letters revealed but not yet
    /// celebrated). Safe to call redundantly.
    func submit() {
        guard needsSubmit, let puzzle = currentPuzzle else { return }
        isSolved = true
        recordSolve(id: puzzle.id)
    }
```

Modify `advance()`'s reset block (the part that resets hearts, correctGuesses, etc.) to also reset the new flag:

```swift
        hearts = Self.maxHearts
        correctGuesses = []
        wrongGuesses = []
        isSolved = false
        isFailed = false
        hintUsedThisPuzzle = false
        hasShownOneChanceWarning = false  // <-- add this line
        currentPuzzle = selector.nextPuzzle(allPuzzles: allPuzzles,
                                            state: store.state,
                                            today: today)
```

- [ ] **Step 4: Run the test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: all `EndlessSessionTests` pass, including the 3 new ones. The old solve-test `test_solving_addsToSolvedSet_incrementsLifetime_andDoesNotChangeStreak` may now fail because guess() no longer triggers recordSolve — that test will need to call `session.submit()` after the loop. Update it:

```swift
func test_solving_addsToSolvedSet_incrementsLifetime_andDoesNotChangeStreak() {
    let store = makeStore()
    let startStreak = store.state.currentStreak
    let session = EndlessSession(allPuzzles: makePuzzles(),
                                 store: store,
                                 today: "2026-05-19")
    let solvedId = session.currentPuzzle!.id
    for ch in Set(session.currentPuzzle!.answer.filter { $0.isLetter }) {
        session.guess(letter: ch)
    }
    session.submit()  // <-- new step; required after the revert
    XCTAssertTrue(session.isSolved)
    XCTAssertTrue(store.state.solvedPuzzleIds.contains(solvedId))
    XCTAssertEqual(store.state.lifetimeSolvedCount, 1)
    XCTAssertEqual(store.state.currentStreak, startStreak,
                   "Endless solve must NOT change the Daily-only streak.")
}
```

Same fix for `test_useHint_solvesPuzzle_whenItRevealsLastNeededLetter` — after `session.useHint()` the puzzle is `needsSubmit`, not `isSolved`. Update the assertions:

```swift
func test_useHint_solvesPuzzle_whenItRevealsLastNeededLetter() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    let answer = session.currentPuzzle!.answer

    let allLetters = Set(answer.filter { $0.isLetter })
    let firstLetter = answer.first(where: { $0.isLetter })!
    for ch in allLetters where ch != firstLetter {
        session.guess(letter: ch)
    }
    XCTAssertFalse(session.isSolved)

    session.useHint()
    XCTAssertTrue(session.needsSubmit, "Hint revealing the last letter triggers Submit")
    XCTAssertFalse(session.isSolved, "Submit must still be tapped")

    session.submit()
    XCTAssertTrue(session.isSolved)
}
```

Also remove `test_advance_resetsHintAvailability`'s mid-test call to `session.advance()` followed by an assertion of `XCTAssertFalse(session.hintUsedThisPuzzle, "advance() must reset hint availability")` — that test stays mostly the same, but ensure it accounts for the new flag reset behavior (`hasShownOneChanceWarning` must also be false after advance, already covered by the new test in Step 1).

Run again to confirm all green.

- [ ] **Step 5: Full test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: all suites pass.

- [ ] **Step 6: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/EndlessSession.swift \
  PictokTests/EndlessSessionTests.swift
git -C /Users/rehatchugh/emoji-decode commit -m "EndlessSession: revert to classic reveal + add submit() and one-chance warning"
```

---

## Task 3: BlanksView revert to classic reveal

**Files:**
- Modify: `Pictok/Views/Components/BlanksView.swift`

- [ ] **Step 1: Read the current file**

```bash
cat /Users/rehatchugh/emoji-decode/Pictok/Views/Components/BlanksView.swift
```

The current `body` computes `activeWordIndex` and calls `GameEngine.isPositionRevealed` for each character position. We're reverting this.

- [ ] **Step 2: Replace the reveal logic**

Find the loop / function that decides whether each position renders the letter or a blank. Replace any call to `GameEngine.activeWordIndex` and `GameEngine.isPositionRevealed` with the classic check:

```swift
let isRevealed: (Character) -> Bool = { ch in
    correctGuesses.contains(ch) || ch == revealedLetter
}
```

Then in the per-character render loop, for each character `ch`:
- if `!ch.isLetter` → render as-is (spaces, punctuation, digits unchanged)
- else if `isRevealed(ch)` → render the letter
- else → render the blank "_"

Concretely, the body that previously called:

```swift
let activeIdx = GameEngine.activeWordIndex(answer: answer, correctGuesses: correctGuesses)
// ... for each character position:
let shown = GameEngine.isPositionRevealed(answer: answer, position: position,
                                          correctGuesses: correctGuesses,
                                          activeWordIndex: activeIdx)
```

Becomes (the cleaner two-line check):

```swift
let shown = !ch.isLetter || correctGuesses.contains(ch) || ch == revealedLetter
```

Keep the existing per-word HStack layout (the way blanks group by word) and the accessibility label. The only thing changing is the per-position reveal predicate.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`. If the build fails because we still reference WBW helpers on `GameEngine`, that's expected — those helpers exist until Task 6. The BlanksView changes here should not introduce new compile errors.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Components/BlanksView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "BlanksView: revert to classic reveal (letter ∈ correctGuesses)"
```

---

## Task 4: TodayView revert + Submit button + 1-heart alert

**Files:**
- Modify: `Pictok/Views/TodayView.swift`

- [ ] **Step 1: Read the current file**

```bash
cat /Users/rehatchugh/emoji-decode/Pictok/Views/TodayView.swift
```

Look for these functions:
- The keyboard handler (currently named something like `handleGuess` or `tapLetter`)
- `checkEndState()` (called after each guess to detect solve/fail)
- The view body (where `BlanksView`, `HeartsRow`, `KeyboardView` are composed)

- [ ] **Step 2: Add transient @State fields at the top of `TodayView`**

After the existing `@State` fields (or near the top of the struct, before `body`), add:

```swift
@State private var hasShownOneChanceWarning: Bool = false
@State private var showOneChanceAlert: Bool = false
```

- [ ] **Step 3: Revert the guess handler to use simple GameEngine helpers**

Find the current guess handler. It likely computes an `activeIdx` and calls `GameEngine.isCorrect(letter:inWord:of:)`. Replace those with:

```swift
private func handleGuess(_ letter: Character) {
    guard let puzzle = puzzle, !store.state.todaySolved, !store.state.todayFailed else { return }
    let upper = Character(String(letter).uppercased())
    if Set(store.state.todayCorrectGuesses).contains(upper) ||
       Set(store.state.todayWrongGuesses).contains(upper) { return }

    if GameEngine.isCorrect(letter: upper, in: puzzle) {
        store.state.todayCorrectGuesses.append(upper)
        SoundService.shared.play(.correct)
        // Submit-button gating handled in checkEndState (below).
    } else {
        store.state.todayWrongGuesses.append(upper)
        store.state.lives -= 1
        SoundService.shared.play(.wrong)
        if store.state.lives == 1 && !hasShownOneChanceWarning {
            hasShownOneChanceWarning = true
            showOneChanceAlert = true
        }
    }
    store.save()
    checkEndState()
}
```

- [ ] **Step 4: Revert `checkEndState` to use simple solve detection**

Replace `checkEndState`:

```swift
private func checkEndState() {
    guard let puzzle = puzzle, !store.state.todaySolved, !store.state.todayFailed else { return }
    // Win: every letter revealed. Note we do NOT set todaySolved here — that's
    // gated on the user tapping Submit (see Submit button section).
    // Fail: lives reached 0.
    if GameEngine.isFailed(lives: store.state.lives) {
        store.state.todayFailed = true
        store.state.currentStreak = GameEngine.streakAfterFail(currentStreak: store.state.currentStreak)
        HapticsService.failed()
        store.save()
    }
    // No-op for solve: the Submit button (rendered in body) is enabled when
    // GameEngine.isSolved returns true, and tapping it calls submitToday().
}
```

Add a new method `submitToday()`:

```swift
private func submitToday() {
    guard let puzzle = puzzle else { return }
    guard !store.state.todaySolved, !store.state.todayFailed else { return }
    let correct = Set(store.state.todayCorrectGuesses)
    guard GameEngine.isSolved(answer: puzzle.answer,
                              correctGuesses: correct,
                              revealedLetter: store.state.todayRevealedLetter) else { return }
    store.state.todaySolved = true
    let today = PuzzleLoader.dateString(for: Date())
    let result = GameEngine.streakAfterSolve(
        today: today,
        lastSolvedDate: store.state.lastSolvedDate,
        currentStreak: store.state.currentStreak,
        streakFreezesAvailable: store.state.streakFreezesAvailable
    )
    store.state.currentStreak = result.streak
    store.state.streakFreezesAvailable = result.freezesAvailable
    store.state.longestStreak = max(store.state.longestStreak, result.streak)
    store.state.lastSolvedDate = today
    store.state.totalSolved += 1
    store.state.lifetimeSolvedCount += 1
    let wrongCount = store.state.todayWrongGuesses.count
    store.state.guessDistribution[wrongCount, default: 0] += 1
    store.state.hasEverSolved = true
    store.save()
    Task { await onSolveOrFail() }
}
```

Note: the original `checkEndState` already had this win-side logic; we're just moving it into `submitToday()` so it runs only when Submit is tapped.

- [ ] **Step 5: Add the Submit button to the layout**

In the `body`, find where `KeyboardView` is rendered. Just above (or below — designer's call) the keyboard, add:

```swift
if isSubmitReady {
    StickerButton(title: "Submit ✓", icon: nil, fill: .pkGreen) {
        submitToday()
    }
    .padding(.top, 8)
    .transition(.scale.combined(with: .opacity))
}
```

And add a private computed `isSubmitReady` to the struct:

```swift
private var isSubmitReady: Bool {
    guard let puzzle = puzzle else { return false }
    guard !store.state.todaySolved, !store.state.todayFailed else { return false }
    let correct = Set(store.state.todayCorrectGuesses)
    return GameEngine.isSolved(answer: puzzle.answer,
                               correctGuesses: correct,
                               revealedLetter: store.state.todayRevealedLetter)
}
```

Animate the button's appearance:

```swift
.animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSubmitReady)
```

- [ ] **Step 6: Add the 1-chance alert modifier**

Attach to the body's outer `ZStack` (or whatever the top-level view is):

```swift
.alert("One chance left", isPresented: $showOneChanceAlert) {
    Button("OK") { showOneChanceAlert = false }
} message: {
    Text("Make it count — one more wrong guess ends the puzzle.")
}
```

- [ ] **Step 7: Reset the 1-chance flag on new day**

If `TodayView` has an `.onChange(of: puzzle?.id)` or `resetTodayState(for:)` block, add `hasShownOneChanceWarning = false` there. If not, add an `.onChange(of: puzzle?.id)` to body:

```swift
.onChange(of: puzzle?.id) { _, _ in
    hasShownOneChanceWarning = false
}
```

- [ ] **Step 8: Build and test**

```bash
xcodebuild test -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "TodayView: revert to classic reveal + Submit button + one-chance alert"
```

---

## Task 5: EndlessView Submit overlay + 1-chance alert

**Files:**
- Modify: `Pictok/Views/EndlessView.swift`

- [ ] **Step 1: Read the current file**

```bash
cat /Users/rehatchugh/emoji-decode/Pictok/Views/EndlessView.swift
```

The view currently uses `.onChange(of: session.isSolved)` to fire the win celebration. After this task, the win celebration still fires on `isSolved` going true — but `isSolved` is now only true after `session.submit()` is called. So the existing `.onChange` block stays as-is.

- [ ] **Step 2: Add Submit button**

Inside `content` (the `@ViewBuilder` private property), find the `BlanksView` line. After the existing HStack with the HintButton, add a new conditional:

```swift
if session.needsSubmit {
    StickerButton(title: "Submit ✓", icon: nil, fill: .pkGreen) {
        session.submit()
    }
    .padding(.top, 8)
    .transition(.scale.combined(with: .opacity))
}
```

And on the parent VStack, add:

```swift
.animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.needsSubmit)
```

- [ ] **Step 3: Add the 1-chance alert**

Add to `EndlessView`:

```swift
@State private var showOneChanceAlert: Bool = false
```

Watch `session.hasShownOneChanceWarning` to trigger the alert:

```swift
.onChange(of: session.hasShownOneChanceWarning) { _, shown in
    if shown {
        showOneChanceAlert = true
    }
}
.alert("One chance left", isPresented: $showOneChanceAlert) {
    Button("OK") { showOneChanceAlert = false }
} message: {
    Text("Make it count — one more wrong guess ends the puzzle.")
}
```

- [ ] **Step 4: Build and test**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/EndlessView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "EndlessView: add Submit button and one-chance alert"
```

---

## Task 6: Delete WBW helpers from GameEngine + delete WBW test file

**Files:**
- Modify: `Pictok/Game/GameEngine.swift`
- Delete: `PictokTests/GameEngineWordByWordTests.swift`

By now no caller references the WBW helpers. This task removes the dead code.

- [ ] **Step 1: Verify there are no remaining callers**

```bash
grep -rn "activeWordIndex\|isCorrect(letter:.*inWord\|isSolvedByWord\|isPositionRevealed\|wordBreakdown\|connectorWords" \
  /Users/rehatchugh/emoji-decode/Pictok \
  /Users/rehatchugh/emoji-decode/PictokTests
```

Expected: only matches inside `Pictok/Game/GameEngine.swift` itself (the definitions we're about to delete) and inside `PictokTests/GameEngineWordByWordTests.swift` (the test file we're about to delete). If there are matches in other files, those callers need to be reverted first — STOP and report.

- [ ] **Step 2: Delete the WBW extension block from `GameEngine.swift`**

Open `Pictok/Game/GameEngine.swift`. Find the extension block that begins with the `connectorWords` static let or `WordBreakdown` struct. Delete the entire extension block, including:
- `static let connectorWords: Set<String>`
- `struct WordBreakdown: Equatable`
- `static func wordBreakdown(answer:)`
- `static func activeWordIndex(answer:correctGuesses:)`
- `static func isCorrect(letter:inWord:of:)`
- `static func isSolvedByWord(answer:correctGuesses:)`
- `static func isPositionRevealed(answer:position:correctGuesses:activeWordIndex:)`

The original methods (`isCorrect(letter:in:)`, `isSolved(answer:correctGuesses:revealedLetter:)`, `isFailed`, `heartCost`, `letterToReveal`, `streakAfterSolve`, `streakAfterFail`) stay.

- [ ] **Step 3: Delete the test file**

```bash
git -C /Users/rehatchugh/emoji-decode rm PictokTests/GameEngineWordByWordTests.swift
```

- [ ] **Step 4: Regenerate the Xcode project**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
```

- [ ] **Step 5: Build and full test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
```

Expected: build succeeds, all remaining tests pass.

- [ ] **Step 6: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/GameEngine.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Remove word-by-word helpers and tests (classic reveal is now the only path)"
```

---

## Task 7: Simulator smoke test

**Files:** none — runtime verification only.

- [ ] **Step 1: Boot iPhone 17 Pro Max simulator (if not booted)**

```bash
xcrun simctl boot "iPhone 17 Pro Max" 2>&1 || true
open -a Simulator
```

- [ ] **Step 2: Reinstall the app with the populated screenshot preset**

```bash
xcrun simctl terminate booted com.rehatchugh.pictok 2>&1 || true
xcrun simctl uninstall booted com.rehatchugh.pictok 2>&1 || true
APP=$(find /Users/rehatchugh/Library/Developer/Xcode/DerivedData -name "Pictok.app" -path "*Debug-iphonesimulator*" -type d | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=populated --present-endless
```

Endless mode opens with a fresh multi-word puzzle. Today's date drives which Daily is showing under it (but we're verifying Endless first since it's easier to capture).

- [ ] **Step 3: Verify classic reveal on a multi-word puzzle**

In the simulator, find an Endless puzzle with a multi-word answer (e.g., TOY STORY, FAST AND FURIOUS, BAD ROMANCE). Tap letters that are in the answer — confirm they fill in across ALL words, not just one. Take a screenshot:

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-revert-classic-reveal.png
```

Read the screenshot. Expected: a letter (e.g., O) that appears in both words is filled in both. Compare to the prior word-by-word behavior where only the first word's O would show.

- [ ] **Step 4: Verify Submit button appears when all letters revealed**

Continue guessing until every letter in the answer is filled. Confirm a "Submit ✓" green sticker button appears below the blanks. The win celebration does NOT fire automatically.

```bash
xcrun simctl io booted screenshot /tmp/pictok-submit-visible.png
```

Read. Expected: blanks all show letters, "Submit ✓" button is visible.

- [ ] **Step 5: Tap Submit and verify celebration fires**

Tap Submit. Within ~1s the fireworks celebration plays. After the celebration ends, the next Endless puzzle slides in. Screenshot during or after celebration to confirm.

- [ ] **Step 6: Verify 1-chance alert**

Start a new Endless puzzle. Tap 4 wrong letters (letters not in the answer). After the 4th wrong guess, hearts drop to 1 and an alert should appear: "One chance left" + "Make it count — one more wrong guess ends the puzzle." Tap OK.

```bash
xcrun simctl io booted screenshot /tmp/pictok-one-chance-alert.png
```

Read. Expected: an iOS-style alert overlay is visible.

- [ ] **Step 7: Verify JOHN LEGEND is gone**

Inspect the bundled puzzle data:

```bash
jq '.[] | select(.answer == "JOHN LEGEND")' \
  /Users/rehatchugh/emoji-decode/Pictok/Resources/puzzles.json
```

Expected: empty output.

```bash
jq 'length' /Users/rehatchugh/emoji-decode/Pictok/Resources/puzzles.json
```

Expected: `59`.

- [ ] **Step 8: Update project memory**

Edit `/Users/rehatchugh/.claude/projects/-Users-rehatchugh/memory/project_pictok.md`. Replace the word-by-word-reveal description with a note that classic reveal is the active mechanic after the 2026-05-20 revert. Mention the Submit button, the 1-chance alert, and that JOHN LEGEND was removed (count is now 59).

---

## Done

After Task 7 the mechanic revert is shipped:

- Classic hangman reveal: letters fill across all words on correct guess.
- Submit button gates the win celebration.
- 1-chance alert fires once per puzzle when hearts hit 1.
- JOHN LEGEND removed; pool is 59 puzzles.
- WBW dead code removed.

Remaining v1 items (still pending, all on the user side):
- Apple Developer Team ID + signing
- App Store Connect record creation
- Privacy policy + Support URL hosting
- Trademark TESS check on "Pictok"
- Signed `xcodebuild archive` + TestFlight upload
