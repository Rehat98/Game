# Pictok UI Polish + Endless Hints + Win Celebration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename "Play Endless" to "Continue Playing", add a fireworks win celebration for both modes, add a free 1-per-puzzle hint button to Continue Playing, and add four motion polish layers (keyboard flash, slide transitions, heart pop). Zero new third-party deps.

**Architecture:** Two new effect files (`FireworksEmitter`, `WinCelebrationView`) using native SwiftUI `TimelineView` + `Canvas` for particles. One new component (`HintButton`). One new method + state field on `EndlessSession`. Existing views (`TodayView`, `EndlessView`, `KeyboardView`, `HeartsRow`, `Theme`) get surgical modifications.

**Tech Stack:** Swift 5, SwiftUI (iOS 17 deployment), XCTest, xcodegen, iPhone 17 / iOS 26.5 Simulator.

**Spec:** `docs/superpowers/specs/2026-05-19-ui-polish-and-hints-design.md` — non-negotiable. Read before any task.

---

## File structure

| Path                                                | Status | Responsibility |
|-----------------------------------------------------|--------|----------------|
| `Pictok/Views/Effects/FireworksEmitter.swift`       | create | Native SwiftUI particle source (TimelineView + Canvas); 6 bursts × 30 particles over 1.4s with gravity + fade. |
| `Pictok/Views/Effects/WinCelebrationView.swift`     | create | Overlay: fireworks + bouncing "Solved!" + answer text + `SoundService.playWin()`. 1.8s total. |
| `Pictok/Views/Components/HintButton.swift`          | create | Sticker hint button; disabled state when `!isEnabled`. |
| `Pictok/Views/TodayView.swift`                      | modify | Rename "Play Endless" → "Continue Playing". Show `WinCelebrationView` on solve. |
| `Pictok/Views/EndlessView.swift`                    | modify | Replace text overlay with `WinCelebrationView` on solve. Add `HintButton`. Add slide transition between puzzles. |
| `Pictok/Views/Components/KeyboardView.swift`        | modify | Letter-press color flash (green correct, red+shake wrong). |
| `Pictok/Views/Components/HeartsRow.swift`           | modify | Pop animation when a heart disappears. |
| `Pictok/Game/EndlessSession.swift`                  | modify | Add `hintUsedThisPuzzle: Bool` + `useHint()` method. Reset on `advance()`. |
| `PictokTests/EndlessSessionTests.swift`             | modify | Add 5 hint-mechanic tests. |

## Test command

```bash
xcodebuild test \
  -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -quiet
```

After any task that creates or deletes a Swift file, regenerate the Xcode project first:

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
```

---

## Task 1: Rename "Play Endless" → "Continue Playing"

**Files:**
- Modify: `Pictok/Views/TodayView.swift`

- [ ] **Step 1: Find the existing button**

```bash
grep -n "Play Endless" /Users/rehatchugh/emoji-decode/Pictok/Views/TodayView.swift
```

Expected: one match on a line like `StickerButton(title: "Play Endless", icon: "▶️", fill: .pkGreen) { onPlayEndless() }`.

- [ ] **Step 2: Change the title string**

Replace `title: "Play Endless"` with `title: "Continue Playing"` on that line. Don't rename `onPlayEndless` (internal naming; out of scope).

- [ ] **Step 3: Build**

```bash
xcodebuild build -project /Users/rehatchugh/emoji-decode/Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Rename Play Endless button to Continue Playing"
```

---

## Task 2: `FireworksEmitter` — native particle source

**Files:**
- Create: `Pictok/Views/Effects/FireworksEmitter.swift`

No unit tests (visual component). Verified via Task 3 + smoke test.

- [ ] **Step 1: Ensure the directory exists**

```bash
mkdir -p /Users/rehatchugh/emoji-decode/Pictok/Views/Effects
```

- [ ] **Step 2: Write the file**

Create `Pictok/Views/Effects/FireworksEmitter.swift`:

```swift
import SwiftUI

/// Native SwiftUI particle source. Generates a fixed set of pseudo-random
/// fireworks bursts on init, then renders them every frame via TimelineView
/// + Canvas. No third-party dependencies.
struct FireworksEmitter: View {
    static let totalDuration: TimeInterval = 1.4
    static let burstCount = 6
    static let particlesPerBurst = 30
    static let burstColors: [Color] = [.pkYellow, .pkRed, .pkGreen, .pkBlue]

    private struct Particle {
        let originX: Double          // 0..1 normalized to canvas width
        let originY: Double          // 0..1 normalized to canvas height
        let velocityX: Double        // px/s
        let velocityY: Double        // px/s
        let color: Color
        let isCircle: Bool
        let birthTime: TimeInterval  // seconds from emitter start
        let lifetime: TimeInterval
    }

    let startDate: Date
    private let particles: [Particle]

    init(startDate: Date = Date()) {
        self.startDate = startDate
        self.particles = Self.generateAllParticles()
    }

    private static func generateAllParticles() -> [Particle] {
        var all: [Particle] = []
        for _ in 0..<burstCount {
            let burstTime = Double.random(in: 0..<totalDuration)
            let originX = Double.random(in: 0.15...0.85)
            let originY = Double.random(in: 0.10...0.50)
            let color = burstColors.randomElement()!
            for _ in 0..<particlesPerBurst {
                let angle = Double.random(in: 0..<(2 * .pi))
                let speed = Double.random(in: 80...160)
                all.append(Particle(
                    originX: originX,
                    originY: originY,
                    velocityX: cos(angle) * speed,
                    velocityY: sin(angle) * speed - 50,  // bias upward
                    color: color,
                    isCircle: Bool.random(),
                    birthTime: burstTime,
                    lifetime: 1.2
                ))
            }
        }
        return all
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSince(startDate)
                let gravity = 200.0
                for p in particles {
                    let age = now - p.birthTime
                    guard age >= 0, age <= p.lifetime else { continue }
                    let alpha = 1.0 - (age / p.lifetime)
                    let x = p.originX * size.width + p.velocityX * age
                    let y = p.originY * size.height + p.velocityY * age + 0.5 * gravity * age * age
                    let s: CGFloat = p.isCircle ? 7 : 8
                    let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
                    let path = p.isCircle ? Path(ellipseIn: rect) : Path(rect)
                    ctx.fill(path, with: .color(p.color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.pkPaper.ignoresSafeArea()
        FireworksEmitter()
    }
}
```

- [ ] **Step 3: Regenerate Xcode project and build**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Effects/FireworksEmitter.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add FireworksEmitter native particle source"
```

---

## Task 3: `WinCelebrationView` — overlay composition

**Files:**
- Create: `Pictok/Views/Effects/WinCelebrationView.swift`

- [ ] **Step 1: Write the file**

Create `Pictok/Views/Effects/WinCelebrationView.swift`:

```swift
import SwiftUI

/// 1.8-second win celebration overlay: fireworks burst + bouncing "Solved!" text
/// + answer reveal + win sound. Self-contained — the parent simply presents
/// this view conditionally; it manages its own animation timing.
struct WinCelebrationView: View {
    static let totalDuration: TimeInterval = 1.8

    let answer: String

    @State private var textScale: CGFloat = 0.5
    @State private var answerOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Dimmed paper background so the fireworks pop.
            Color.pkPaper.opacity(0.85).ignoresSafeArea()

            FireworksEmitter()

            VStack(spacing: 18) {
                Text("🎉  Solved!  🎉")
                    .font(.pkTitle)
                    .foregroundStyle(Color.pkInk)
                    .scaleEffect(textScale)

                Text(answer)
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk)
                    .opacity(answerOpacity)
            }
        }
        .onAppear {
            SoundService.playWin()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                textScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                answerOpacity = 1.0
            }
        }
    }
}

#Preview {
    WinCelebrationView(answer: "TOY STORY")
}
```

**Note:** the `pkTitle` and `pkSubtitle` fonts are already defined in `Theme.swift`. `SoundService.playWin()` is already defined in `Pictok/Game/SoundService.swift`.

- [ ] **Step 2: Regenerate Xcode project and build**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`. If `SoundService.playWin()` doesn't exist, check what the public method is in `Pictok/Game/SoundService.swift` (it might be `play(.win)` or similar) and use that instead — but do not introduce a new SoundService method in this task.

- [ ] **Step 3: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Effects/WinCelebrationView.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add WinCelebrationView overlay (fireworks + text + sound)"
```

---

## Task 4: Wire `WinCelebrationView` into both modes' solve flows

**Files:**
- Modify: `Pictok/Views/EndlessView.swift`
- Modify: `Pictok/Views/TodayView.swift`

### Part A — EndlessView

`EndlessView` currently shows a text-only overlay via `showResult(label:)`. Replace the solved branch with `WinCelebrationView`; keep the failed branch as the existing text overlay.

- [ ] **Step 1A: Read the current `EndlessView` `showResult` and `onChange` handlers**

```bash
grep -n "showResult\|onChange\|resultOverlay" /Users/rehatchugh/emoji-decode/Pictok/Views/EndlessView.swift
```

- [ ] **Step 2A: Replace the solved overlay**

Modify the `.onChange(of: session.isSolved)` handler to set a new state `@State private var showWinCelebration = false` and present `WinCelebrationView` instead of the text overlay. Concretely, in `EndlessView`:

Add at the top of the struct (near `showResultOverlay`):
```swift
@State private var showWinCelebration: Bool = false
```

Replace the `onChange(of: session.isSolved)` block:
```swift
.onChange(of: session.isSolved) { _, solved in
    if solved {
        showWinCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
            showWinCelebration = false
            session.advance()
        }
    }
}
```

In the `body` `ZStack`, add the celebration overlay between `content` and the existing `resultOverlay`:
```swift
if showWinCelebration, let puzzle = session.currentPuzzle {
    WinCelebrationView(answer: puzzle.answer)
        .transition(.opacity)
}
```

Leave the failed-state branch (`onChange(of: session.isFailed)`) and `resultOverlay` exactly as they are — fail does NOT trigger the celebration.

### Part B — TodayView

- [ ] **Step 1B: Find the Daily solve transition**

The Daily solve sets `state.todaySolved = true`. Find the `.onChange(of: store.state.todaySolved)` or the solve handler in `Pictok/Views/TodayView.swift`.

```bash
grep -n "todaySolved\|onChange" /Users/rehatchugh/emoji-decode/Pictok/Views/TodayView.swift
```

- [ ] **Step 2B: Inject the celebration**

Add to `TodayView`:
```swift
@State private var showWinCelebration: Bool = false
```

Add (or modify) an `.onChange(of: store.state.todaySolved)` on the outer view:
```swift
.onChange(of: store.state.todaySolved) { _, solved in
    if solved {
        showWinCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
            showWinCelebration = false
        }
    }
}
```

In the `body` `ZStack` (wrap content in a ZStack if it isn't already), overlay the celebration:
```swift
if showWinCelebration {
    WinCelebrationView(answer: puzzle.answer)
        .transition(.opacity)
        .zIndex(10)
}
```

The existing result sheet behavior is unchanged — it appears after the 1.8s celebration window because the result sheet is presented when `state.todaySolved == true`, and the celebration just overlays on top temporarily.

- [ ] **Step 3: Build and run all tests**

```bash
cd /Users/rehatchugh/emoji-decode
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: all 75 existing tests still pass.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/EndlessView.swift Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "Wire WinCelebrationView into Daily + Endless solve flows"
```

---

## Task 5: `EndlessSession` — add `useHint()` + tests

**Files:**
- Modify: `Pictok/Game/EndlessSession.swift`
- Modify: `PictokTests/EndlessSessionTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `PictokTests/EndlessSessionTests.swift`, inside the existing `final class EndlessSessionTests`:

```swift
func test_useHint_revealsFirstUnguessedLetterOfActiveWord() {
    let store = makeStore()
    let multiPuzzle = Puzzle(id: "p_multi", date: "2026-05-28", emoji: "🐝🦴",
                             answer: "BEE BONE",
                             category: .brand, subcategory: "t", difficulty: .medium)
    let allPuzzles = [
        Puzzle(id: "p1", date: "2026-05-19", emoji: "🐝", answer: "X",
               category: .brand, subcategory: "t", difficulty: .medium),
        multiPuzzle
    ]
    let session = EndlessSession(allPuzzles: allPuzzles, store: store, today: "2026-05-19")
    XCTAssertEqual(session.currentPuzzle?.id, "p_multi")

    session.useHint()
    // BEE's first unguessed letter is "B" — that should be revealed.
    XCTAssertTrue(session.correctGuesses.contains("B"))
}

func test_useHint_marksUsed_andSubsequentCallsAreNoOp() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    XCTAssertFalse(session.hintUsedThisPuzzle)

    session.useHint()
    XCTAssertTrue(session.hintUsedThisPuzzle)
    let countAfterFirst = session.correctGuesses.count

    session.useHint()  // should be no-op
    XCTAssertEqual(session.correctGuesses.count, countAfterFirst)
}

func test_useHint_doesNotCostHearts() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    XCTAssertEqual(session.hearts, 5)

    session.useHint()
    XCTAssertEqual(session.hearts, 5, "Hint must be free (no heart cost)")
}

func test_advance_resetsHintAvailability() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")

    session.useHint()
    XCTAssertTrue(session.hintUsedThisPuzzle)

    // Force the puzzle to a state where advance() picks a different one.
    // (Solve it via remaining guesses, then advance.)
    if let answer = session.currentPuzzle?.answer {
        for ch in Set(answer.filter { $0.isLetter }) {
            session.guess(letter: ch)
        }
    }
    session.advance()
    XCTAssertFalse(session.hintUsedThisPuzzle, "advance() must reset hint availability")
}

func test_useHint_solvesPuzzle_whenItRevealsLastNeededLetter() {
    let store = makeStore()
    let session = EndlessSession(allPuzzles: makePuzzles(), store: store, today: "2026-05-19")
    let answer = session.currentPuzzle!.answer

    // Manually guess every letter EXCEPT the first.
    let allLetters = Set(answer.filter { $0.isLetter })
    let firstLetter = answer.first(where: { $0.isLetter })!
    for ch in allLetters where ch != firstLetter {
        session.guess(letter: ch)
    }
    XCTAssertFalse(session.isSolved)

    session.useHint()
    XCTAssertTrue(session.isSolved, "Hint that reveals last needed letter must solve the puzzle")
}
```

- [ ] **Step 2: Run tests to confirm they fail (no `useHint` method)**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: BUILD FAILS — "value of type 'EndlessSession' has no member 'useHint'" (and `hintUsedThisPuzzle`).

- [ ] **Step 3: Add the state field and method to `EndlessSession`**

In `Pictok/Game/EndlessSession.swift`, find the `private(set) var isFailed: Bool = false` line. After it, add:

```swift
    private(set) var hintUsedThisPuzzle: Bool = false
```

After the existing `guess(letter:)` method, add:

```swift
    func useHint() {
        guard !hintUsedThisPuzzle,
              let puzzle = currentPuzzle,
              !isSolved, !isFailed else { return }
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
```

In the `advance()` method, find the existing reset block (`hearts = Self.maxHearts`, `correctGuesses = []`, etc.) and add:

```swift
        hintUsedThisPuzzle = false
```

alongside the existing resets.

- [ ] **Step 4: Run the new tests**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PictokTests/EndlessSessionTests -quiet
```

Expected: all 13 EndlessSessionTests pass (8 existing + 5 new).

- [ ] **Step 5: Full test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: all 80 tests pass (75 prior + 5 new).

- [ ] **Step 6: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Game/EndlessSession.swift \
  PictokTests/EndlessSessionTests.swift
git -C /Users/rehatchugh/emoji-decode commit -m "EndlessSession: add useHint() and hintUsedThisPuzzle state"
```

---

## Task 6: `HintButton` component + wire into `EndlessView`

**Files:**
- Create: `Pictok/Views/Components/HintButton.swift`
- Modify: `Pictok/Views/EndlessView.swift`

- [ ] **Step 1: Create the component**

Create `Pictok/Views/Components/HintButton.swift`:

```swift
import SwiftUI

/// Right-anchored sticker hint button used in EndlessView. Free, 1 use per puzzle.
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

#Preview {
    VStack(spacing: 16) {
        HintButton(isEnabled: true, action: {})
        HintButton(isEnabled: false, action: {})
    }
    .padding()
    .background(Color.pkPaper)
}
```

- [ ] **Step 2: Add the button to EndlessView**

In `Pictok/Views/EndlessView.swift`, find the `content` body where `BlanksView` is rendered. Insert the hint button below `BlanksView` and above the `Spacer()` that pushes the keyboard to the bottom:

```swift
HStack {
    Spacer()
    HintButton(
        isEnabled: !session.hintUsedThisPuzzle && !session.isSolved && !session.isFailed,
        action: { session.useHint() }
    )
}
.padding(.horizontal, 8)
```

- [ ] **Step 3: Regenerate project and build**

```bash
cd /Users/rehatchugh/emoji-decode && xcodegen generate
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: 80 tests pass.

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Components/HintButton.swift \
  Pictok/Views/EndlessView.swift Pictok.xcodeproj
git -C /Users/rehatchugh/emoji-decode commit -m "Add HintButton and wire into EndlessView"
```

---

## Task 7: KeyboardView color flash on letter press

**Files:**
- Modify: `Pictok/Views/Components/KeyboardView.swift`

No unit tests (visual). Verified via Task 10 smoke test.

- [ ] **Step 1: Read the current KeyboardView**

```bash
cat /Users/rehatchugh/emoji-decode/Pictok/Views/Components/KeyboardView.swift
```

Note the existing `onGuess: (Character) -> Void` callback and the `guessed: Set<Character>` parameter (or whatever the existing parameter shape is — the current Endless wires it as `guessed: session.correctGuesses.union(session.wrongGuesses)`).

- [ ] **Step 2: Add flash state and animation**

Modify `KeyboardView` to accept both `correctGuesses` and `wrongGuesses` separately (so it can distinguish correct/wrong flashes), and add the flash state:

```swift
struct KeyboardView: View {
    let correctGuesses: Set<Character>
    let wrongGuesses: Set<Character>
    let onGuess: (Character) -> Void

    @State private var flashingLetter: Character? = nil
    @State private var flashIsCorrect: Bool = false
    @State private var shakeOffset: CGFloat = 0

    private let rows: [[Character]] = [
        Array("QWERTYUIOP"),
        Array("ASDFGHJKL"),
        Array("ZXCVBNM")
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 6) {
                    ForEach(rows[rowIdx], id: \.self) { letter in
                        keyButton(letter)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ letter: Character) -> some View {
        let isCorrect = correctGuesses.contains(letter)
        let isWrong = wrongGuesses.contains(letter)
        let isFlashing = (flashingLetter == letter)
        let baseFill: Color = isCorrect ? Color.pkGreen.opacity(0.4)
                           : isWrong   ? Color.pkRed.opacity(0.4)
                           : .white
        let activeFill: Color = isFlashing
            ? (flashIsCorrect ? .pkGreen : .pkRed)
            : baseFill

        Button {
            handleTap(letter)
        } label: {
            Text(String(letter))
                .font(.pkKey)
                .foregroundStyle(Color.pkInk)
                .frame(minWidth: 26, minHeight: 36)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .sticker(fill: activeFill, cornerRadius: 6, strokeWidth: 2, shadowOffset: 2)
        .offset(x: (isFlashing && !flashIsCorrect) ? shakeOffset : 0)
        .disabled(isCorrect || isWrong)
    }

    private func handleTap(_ letter: Character) {
        onGuess(letter)
        // Decide correct vs wrong based on whether the letter ended up in correctGuesses
        // OR wrongGuesses (the parent has already mutated state).
        // Schedule on next runloop so the parent state has propagated.
        DispatchQueue.main.async {
            let nowCorrect = correctGuesses.contains(letter)
            let nowWrong = wrongGuesses.contains(letter)
            guard nowCorrect || nowWrong else { return }
            flashingLetter = letter
            flashIsCorrect = nowCorrect
            if !nowCorrect {
                // Wrong: shake. Two oscillations over 250ms.
                withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = -6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = 6 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = -3 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = 0 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                flashingLetter = nil
                shakeOffset = 0
            }
        }
    }
}
```

- [ ] **Step 3: Update call sites if the API changed**

Both `EndlessView` and `TodayView` call `KeyboardView(...)`. The new signature requires `correctGuesses` AND `wrongGuesses` separately. Find both call sites:

```bash
grep -rn "KeyboardView(" /Users/rehatchugh/emoji-decode/Pictok
```

Update each to pass both sets. For `EndlessView`:
```swift
KeyboardView(
    correctGuesses: session.correctGuesses,
    wrongGuesses: session.wrongGuesses,
    onGuess: { letter in session.guess(letter: letter) }
)
```

For `TodayView`: pass `store.state.todayCorrectGuesses` (as a Set) and `store.state.todayWrongGuesses` (as a Set). Note: these are stored as `[Character]` arrays in `UserState`, so wrap with `Set(...)`:
```swift
KeyboardView(
    correctGuesses: Set(store.state.todayCorrectGuesses),
    wrongGuesses: Set(store.state.todayWrongGuesses),
    onGuess: handleGuess
)
```

If the previous parameter name was `guessed: Set<Character>` (a merged set), remove that parameter from the call sites — the new API uses the split sets.

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Run full tests**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: 80 tests pass.

- [ ] **Step 6: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Components/KeyboardView.swift \
  Pictok/Views/EndlessView.swift Pictok/Views/TodayView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "KeyboardView: color flash + shake on letter press"
```

---

## Task 8: HeartsRow pop animation on heart loss

**Files:**
- Modify: `Pictok/Views/Components/HeartsRow.swift`

- [ ] **Step 1: Read the current HeartsRow**

```bash
cat /Users/rehatchugh/emoji-decode/Pictok/Views/Components/HeartsRow.swift
```

Likely structure: a parameter `let remaining: Int` (or `hearts: Int`), rendering `ForEach(0..<5)` with conditional fill.

- [ ] **Step 2: Add transition + animation**

Rewrite to render only the currently-active hearts and use `.transition(.scale.combined(with: .opacity))` so removed hearts pop out:

```swift
import SwiftUI

struct HeartsRow: View {
    static let maxHearts = 5
    let remaining: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.maxHearts, id: \.self) { idx in
                if idx < remaining {
                    Text("❤️")
                        .font(.system(size: 20))
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.35), value: remaining)
    }
}

#Preview {
    VStack {
        HeartsRow(remaining: 5)
        HeartsRow(remaining: 3)
        HeartsRow(remaining: 0)
    }
}
```

If the existing parameter name is `hearts` instead of `remaining`, keep the existing name and adjust the body. Don't break call sites.

- [ ] **Step 3: Verify call sites still compile**

```bash
grep -rn "HeartsRow(" /Users/rehatchugh/emoji-decode/Pictok
```

Both `TodayView` and `EndlessView` use this component. The animation lives entirely inside `HeartsRow`; no call-site changes needed unless you renamed the parameter.

- [ ] **Step 4: Build and run tests**

```bash
xcodebuild test -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: 80 tests pass.

- [ ] **Step 5: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/Components/HeartsRow.swift
git -C /Users/rehatchugh/emoji-decode commit -m "HeartsRow: pop animation when a heart disappears"
```

---

## Task 9: EndlessView slide transition between puzzles

**Files:**
- Modify: `Pictok/Views/EndlessView.swift`

- [ ] **Step 1: Wrap puzzle content in a transitioning view**

In `EndlessView.content` (the `@ViewBuilder` private property), find the `if let puzzle = session.currentPuzzle` branch. The inner `VStack(spacing: 16) { ... }` is the puzzle content. Apply `.id(puzzle.id)` and `.transition(...)`:

```swift
@ViewBuilder
private var content: some View {
    if let puzzle = session.currentPuzzle {
        VStack(spacing: 16) {
            topBar
            HeartsRow(remaining: session.hearts)
            EmojiHeader(emoji: puzzle.emoji)
            CategoryChip(category: puzzle.category, subcategory: nil)
            BlanksView(answer: puzzle.answer,
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
            Spacer()
            KeyboardView(
                correctGuesses: session.correctGuesses,
                wrongGuesses: session.wrongGuesses,
                onGuess: { letter in session.guess(letter: letter) }
            )
        }
        .padding(.horizontal, 16)
        .id(puzzle.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    } else {
        // existing empty-pool fallback unchanged
        // ...
    }
}
```

- [ ] **Step 2: Wrap `session.advance()` in `withAnimation`**

In `EndlessView.showResult(label:)` (or wherever `session.advance()` is called from inside the celebration timeout), wrap the call:

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
    showWinCelebration = false
    withAnimation(.easeInOut(duration: 0.25)) {
        session.advance()
    }
}
```

For the failure path (`showResult(label:)` called from `onChange(of: session.isFailed)`), also wrap the existing `session.advance()` in `withAnimation`.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/rehatchugh/emoji-decode add Pictok/Views/EndlessView.swift
git -C /Users/rehatchugh/emoji-decode commit -m "EndlessView: slide transition between puzzles"
```

---

## Task 10: Simulator smoke test

**Files:** none — runtime verification only.

- [ ] **Step 1: Boot the simulator and reinstall**

```bash
xcrun simctl boot "iPhone 17" 2>&1 || true
open -a Simulator
xcrun simctl terminate booted com.rehatchugh.pictok 2>&1 || true
xcrun simctl uninstall booted com.rehatchugh.pictok 2>&1 || true
APP=$(find /Users/rehatchugh/Library/Developer/Xcode/DerivedData -name "Pictok.app" -path "*Debug-iphonesimulator*" -type d | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.rehatchugh.pictok
```

- [ ] **Step 2: Screenshot the Play tab — verify rename**

```bash
sleep 2 && xcrun simctl io booted screenshot /tmp/pictok-step1.png
```

Read `/tmp/pictok-step1.png`. Expected: today's Daily puzzle visible, **"▶ Continue Playing"** sticker button below the keyboard (not "Play Endless").

- [ ] **Step 3: Manually tap Continue Playing in the simulator, screenshot**

(Requires opening the Simulator.app window and clicking the button — `simctl` cannot tap by text. Document this as a manual step.)

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-step2.png
```

Read. Expected: EndlessView with a puzzle. **Verify the Hint button is visible**, right-anchored above the keyboard (yellow sticker, 💡 icon, "Hint" label).

- [ ] **Step 4: Manually solve the Endless puzzle (or use the hint)**

Tap the correct letters in the simulator. When the puzzle resolves, the WinCelebrationView should appear: fireworks bursts, bouncing "🎉 Solved! 🎉" text, the answer underneath.

```bash
sleep 1 && xcrun simctl io booted screenshot /tmp/pictok-step3.png
```

Read. Expected: fireworks particles visible (colored squares/circles in motion), "Solved!" text centered, answer below. If the screenshot caught the moment after the 1.8s celebration ended, you'll see the next puzzle (slide-in transition complete) — still good.

- [ ] **Step 5: Verify motion polish on the next puzzle**

Tap a wrong letter — the key should flash red and shake. Tap a correct letter — green flash. Watch a heart decrement: it should pop out. Document any motion that doesn't fire as expected.

- [ ] **Step 6: Update project memory**

Edit `/Users/rehatchugh/.claude/projects/-Users-rehatchugh/memory/project_pictok.md` to reflect:
- "Play Endless" renamed to "Continue Playing"
- Fireworks win celebration ships for Daily + Endless
- Endless mode has a free 1-per-puzzle hint button
- Motion polish: keyboard flash, slide transitions, heart pop

Update the Status line and add a Polish ships note.

---

## Done

After Task 10 the UI polish + hint + celebration work is complete:

- "Continue Playing" button reads correctly.
- Daily and Endless solves trigger fireworks + bouncing text + win sound.
- Continue Playing has a hint button (free, 1 per puzzle, resets on advance).
- Keyboard letter presses flash green/red with shake on wrong.
- Hearts pop on loss.
- Endless puzzles slide-transition on advance.
- All 80 tests pass.
- Visual smoke test confirms each layer.

Remaining v1 plan items still pending (in `2026-05-18-pictok-v1-implementation.md`):
- Task 28: Final app icon asset
- Task 29: Final sound effects (real claps for win.wav)
- Task 30: Manual QA matrix (updated for Endless + celebration)
- Task 31: TestFlight + App Store submission prep
