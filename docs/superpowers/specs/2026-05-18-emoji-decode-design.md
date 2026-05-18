# Emojidle — v1 design spec

**Date:** 2026-05-18
**Status:** Approved by user (ready for implementation plan)
**Author working title:** "Emojidle" (final name TBD before App Store submission)

## Overview

A daily emoji-decode puzzle game for iOS. Player sees a string of emojis that represents a movie, song, book, brand, or celebrity, and guesses the answer hangman-style by tapping letters on an on-screen keyboard. One puzzle per day, shareable spoiler-free result card. Built solo by a first-time iOS game developer; explicit goal of shipping a lean v1 to validate the daily-retention hook before investing in backend/social infrastructure.

## Goals (v1)

- Ship a complete, polished, daily puzzle game in ~2–3 weekends of build time.
- Validate the core hook: do users come back tomorrow?
- Establish a recognizable visual brand (sticker / paper-craft aesthetic) and viral artifact (the share card).
- Local-only — no backend, no accounts, no networking.

## Non-goals (v1)

See [§9 Out of scope](#9-out-of-scope) for the explicit cut list. Everything social, backend-driven, or monetized is deferred to later versions.

---

## 1. Player experience

### Screens (4 total)

1. **Today (home, default tab)**
   - Top bar: hearts row (lives remaining), 💡 hint button, gear icon (How to Play).
   - Hero: large emoji puzzle (e.g., 🌃🦇🤡).
   - Below: category chip showing just the category (e.g., "Movie"). After the "reveal subcategory" hint is purchased, the chip expands to include the subcategory (e.g., "Movie · Action · 2008").
   - Word slots: `_ _ _ _ / _ _ _ _ _ _ / _ _ _ _ _ _` for each word in the answer.
   - On-screen 26-letter keyboard (QWERTY rows). Letters dim and strike-through after being guessed; no color hints beyond "guessed" vs "not guessed."
   - Resumable mid-puzzle. Backgrounding the app preserves all state.
   - If today's puzzle is already solved/failed: shows result card, share button, and countdown to next puzzle.

2. **Result sheet** (modal over Today, on solve or fail)
   - Confetti or simple celebration animation on success; muted "today got me" framing on failure.
   - Result summary: wrong-guess count, hearts left, hint used (y/n).
   - **Share** button (system share sheet) and **Copy** button.
   - Countdown to next puzzle.

3. **Stats** (second tab)
   - Current streak, longest streak, total solved, total played, win %.
   - Distribution chart: number of solves per "wrong guesses" bucket.

4. **How to Play** (one-time onboarding + reachable later via gear icon)
   - 3-card horizontal swipe explainer.

### Navigation

- Bottom tab bar: **[Today]** **[Stats]** — that's it.
- Top-right gear icon on Today opens **How to Play**.
- No additional settings, profile, or menu screens in v1.

---

## 2. Visual style

**Direction: Sticker / Paper Craft.**

- Background: cream paper (`#fef3d9`).
- Primary stroke: solid black (`#1a1a1a`), 2–3px on every interactive element.
- Drop shadows: hard-edged, offset bottom-right (no Gaussian blur), in solid black — creates the "sticker pasted on paper" effect.
- Color palette (primaries, used liberally):
  - Yellow `#ffd60a`
  - Red `#e63946`
  - Green `#06d6a0`
  - Blue `#118ab2`
  - Hearts `#e63946` filled, `#1a1a1a` outlined when lost.
- Typography: chunky/bold sans-serif (Rubik or system bold). Keyboard letters in monospace for clarity.
- Categories use their own emoji-icon (🎬 Movie · 🎵 Song · 📚 Book · 🏷️ Brand · 🎤 Celeb).

Centralized in `Views/Theme.swift` so the style is tunable from one place.

---

## 3. Gameplay mechanics

### Lives

- Each player starts with **5 hearts**.
- Each wrong letter guess = **−1 heart**.
- All hearts gone before solving = puzzle **failed** (the answer is revealed; streak resets).
- Hearts refill **1 every 4 hours**, capped at 5. Refill timer is global, not per-puzzle.
- No ad-watch or IAP refill in v1.

### Hints (stingy by design)

- **Exactly 1 hint per puzzle**, no more. Choose one of:
  - **Reveal subcategory** (e.g., "Movie" → "Movie · Animated · 1990s") — costs **1 heart**.
  - **Reveal one letter** in the answer — costs **2 hearts**.
- The on-screen keyboard never highlights "likely" letters. Players guess blind.

### Streak

- Solve today → streak +1.
- Skip a day OR fail → streak resets to 0.
- **Streak freeze**: 1 per week (auto-uses on a missed day). Compassionate, not generous.

### Difficulty curve

Each puzzle is tagged Easy / Medium / Hard. Days of the week rotate difficulty so players don't burn out:

- Mon–Tue: Easy
- Wed–Thu: Medium
- Fri–Sat: Hard
- Sun: Medium (gentle Sunday)

### Target puzzle "feel"

Puzzles aim for a 30-second-to-2-minute solve, riddle-style. Examples of the target cleverness bar (these are illustrative — final 90 will be reviewed):

- 🌃🦇🤡 → *The Dark Knight*
- 🚿🔪🎻 → *Psycho*
- 🐟🔍👨‍👧 → *Finding Nemo*
- 🍕🐢🥋 → *Teenage Mutant Ninja Turtles*
- 👻🚫📞 → *Ghostbusters*

Explicitly **not** the target: `🦁👑 = Lion King`-style direct mappings. Should require thought.

---

## 4. Data model

### Bundled puzzle pack

Single read-only `puzzles.json` shipped with the app:

```json
[
  {
    "id": "2026-05-18",
    "date": "2026-05-18",
    "emoji": "🌃🦇🤡",
    "answer": "THE DARK KNIGHT",
    "category": "Movie",
    "subcategory": "Action · 2008",
    "difficulty": "hard"
  }
]
```

- One entry per calendar day.
- 90 entries for v1 (~3 months of runway from launch).
- `answer` uppercase, spaces preserved. Non-letter characters (apostrophes, hyphens, numerals) are pre-revealed.
- `subcategory` is what's exposed by the "reveal category" hint.
- Today's puzzle = `puzzles[date == device's current date]`.

### Local user state (single `UserDefaults` JSON blob, key `emojidle.state.v1`)

```swift
struct UserState: Codable {
  // Streak
  var currentStreak: Int
  var longestStreak: Int
  var lastSolvedDate: String?      // "YYYY-MM-DD"
  var streakFreezesAvailable: Int  // 0..1, resets weekly (Monday 00:00 local)

  // Lifetime
  var totalSolved: Int
  var totalPlayed: Int
  var guessDistribution: [Int: Int]   // wrongGuessCount -> # of solves

  // Lives
  var lives: Int                   // 0..5
  var livesLastRefilledAt: Date    // anchor for the +1/4h math

  // Today's puzzle in-progress state (resumable)
  var todayPuzzleId: String?
  var todayWrongGuesses: [Character]
  var todayCorrectGuesses: [Character]
  var todayHintUsed: HintType?     // .category | .letter | nil
  var todayRevealedLetter: Character?
  var todaySolved: Bool
  var todayFailed: Bool
}

enum HintType: String, Codable { case category, letter }
```

### Settings (separate `UserDefaults` keys)

- `soundEnabled: Bool` (default true)
- `hapticsEnabled: Bool` (default true)

### Derived values (computed, not stored)

- Today's puzzle (lookup from `puzzles.json`).
- Time until next life (now − `livesLastRefilledAt` math).
- Streak status (`lastSolvedDate` vs today).

---

## 5. Share card format

Text-only, spoiler-free, instantly recognizable. No image rendering in v1.

### Success format

```
Emojidle #142 📌
🎬 Hard
❤️❤️❤️🖤🖤 · 🔥 7

emojidle.app
```

- `📌` is the app's recognizable mark (matches sticker aesthetic).
- `#N` = days since launch (puzzle number, shared across all players).
- Category icon + difficulty word; no answer leak.
- Hearts bar: filled = remaining, hollow/black = lost.
- `🔥 N` = current streak.
- Trailing URL (App Store short link after launch).

### Failure variant

```
Emojidle #142 📌
🎬 Hard · today got me 🥲
🔥 7 → 0

emojidle.app
```

### Hint-used variant

A `💡` is appended next to the hearts to mark hint use. No further detail.

### Mechanism

- Generated via pure string templating in `Game/ShareCardBuilder.swift`.
- Surface on the Result sheet:
  - **Copy** button → `UIPasteboard.general.string = card`.
  - **Share** button → SwiftUI `ShareLink(item: card)` opens the system share sheet.

---

## 6. Content pipeline (v1)

**Source:** All 90 puzzles for v1 are hand-authored by Claude (the AI assistant working with the developer in this design session). The developer reviews each puzzle for difficulty calibration and "not-too-obvious" quality before bundling.

**Why this works for v1:** Eliminates the entire backend/admin-tool dependency. 90 puzzles = ~3 months of runway, which is enough to:

- Launch
- Validate daily-retention numbers
- Decide whether to invest in the v2 LLM pipeline + backend

**Workflow:**

1. After this spec is approved, Claude generates 90 puzzles in a structured batch (text format with emoji, answer, category, subcategory, suggested difficulty).
2. Developer reviews — rejects any that feel too obvious, too obscure, or culturally narrow; requests replacements.
3. Final approved set is serialized to `puzzles.json` and added to the Xcode project's `Resources/`.
4. Dates are assigned by sorting on difficulty curve (Mon–Tue easy, etc.) starting from the chosen launch date.

**Mix targets (rough — adjusted during review):**

- 50% Movies, 20% Songs, 15% Books, 10% Brands, 5% Celebrities
- ~29% Easy, ~43% Medium, ~29% Hard (matches the day-of-week curve: 2 Easy + 3 Medium + 2 Hard per week)

---

## 7. Tech stack & file structure

### Stack

- Swift 5.9+, SwiftUI
- Xcode 15+
- Target: **iOS 17+** (uses `ShareLink`, `@Observable`)
- Persistence: `UserDefaults` (single JSON-encoded blob)
- Sharing: SwiftUI `ShareLink`
- Haptics: `UIImpactFeedbackGenerator`
- Sound: `AVFoundation` (3 effects: correct, wrong, win)
- **Zero external dependencies** — no SwiftPM packages.

### Layout

```
EmojiDecode/
├── EmojiDecodeApp.swift              // @main App entry
├── Resources/
│   ├── puzzles.json                  // 90 bundled puzzles
│   ├── Assets.xcassets/              // app icon, colors
│   └── Sounds/                       // correct.wav, wrong.wav, win.wav
├── Models/
│   ├── Puzzle.swift                  // Puzzle, Category, Difficulty
│   └── UserState.swift               // UserState, HintType
├── Game/
│   ├── GameEngine.swift              // pure logic: guess(letter), isSolved, etc.
│   ├── UserStateStore.swift          // @Observable wrapper over UserDefaults
│   ├── PuzzleLoader.swift            // loads bundle JSON, finds today's puzzle
│   └── ShareCardBuilder.swift        // builds the share string
├── Views/
│   ├── TodayView.swift
│   ├── ResultSheet.swift
│   ├── StatsView.swift
│   ├── HowToPlayView.swift
│   ├── Theme.swift                   // sticker colors, fonts, shadow modifier
│   └── Components/
│       ├── EmojiHeader.swift
│       ├── BlanksView.swift
│       ├── KeyboardView.swift
│       ├── HeartsRow.swift
│       ├── CategoryChip.swift
│       └── StickerButton.swift
└── Tests/
    ├── GameEngineTests.swift
    └── ShareCardBuilderTests.swift
```

### Boundaries

- **`GameEngine`** is pure logic, no SwiftUI, no `UserDefaults`. Inputs → outputs. Fully unit-testable.
- **`UserStateStore`** is the only thing that touches `UserDefaults`. Single writer, published via `@Observable`.
- **`PuzzleLoader`** runs once on app launch. Loads bundle JSON.
- **`ShareCardBuilder`** is pure string templating.
- **Views are thin** — read from store, call into engine, render. No business logic in views.
- **`Theme.swift`** centralizes the sticker aesthetic. One source of truth for the look.

### Tests (lightweight)

- `GameEngineTests` — correct/wrong letter, win, fail, hint costs, streak math edges.
- `ShareCardBuilderTests` — success, failure, hint-used, edge cases (streak = 0, hint + failure).
- Views are not unit-tested; SwiftUI previews + manual QA.

---

## 8. Build & ship checklist

1. Create Xcode 15+ project, SwiftUI App template, iOS 17 target.
2. Create the file structure above.
3. Implement `Models/`, `Game/`, then `Views/Components/`, then screens.
4. Author 90 puzzles (Claude generates batch → developer reviews → finalize).
5. Bundle `puzzles.json`, app icon, sound effects.
6. Manual QA matrix:
   - Solve flow, fail flow, mid-puzzle backgrounding/resume.
   - Streak: solve consecutive days (manipulate device date), break streak, streak-freeze.
   - Lives refill timing.
   - Share card variants (success, failure, hint-used).
   - VoiceOver labels on keyboard and hearts.
7. TestFlight beta (~10 users, 1 week).
8. App Store submission.

---

## 9. Out of scope (v1)

Explicit cut list. Each item is intentional and deferred:

- 🚫 **Backend / accounts** — no Firebase, Supabase, or Sign in with Apple. Local-only. *(v2)*
- 🚫 **LLM puzzle pipeline + admin tool** — v1 puzzles are hand-authored. *(v2)*
- 🚫 **Global leaderboard** — no backend = no leaderboard. *(v2)*
- 🚫 **Friend challenge / deep links** — no "send today's puzzle to a friend." *(v3)*
- 🚫 **Image-rendered share card** — text-only v1. *(v2)*
- 🚫 **IAP / cosmetics** — free, no purchases. *(post-retention)*
- 🚫 **Rewarded video ads** — no ad refill of hearts. *(post-retention)*
- 🚫 **Push notifications** — no daily ping. *(easy v1.1 add if retention is decent)*
- 🚫 **Settings screen** — only "How to play." No sound toggle screen.
- 🚫 **iPad-optimized layout** — iPhone layout runs on iPad as-is.
- 🚫 **Localization** — English only.
- 🚫 **Full accessibility audit** — basic VoiceOver labels only; full Dynamic Type / WCAG pass deferred.

---

## 10. Future roadmap (informational only — not part of v1 scope)

**v2 — Social foundation (~6 weeks of work)**

- Backend (likely Firebase: Firestore + Sign in with Apple).
- Migrate `puzzles.json` from bundle to Firestore collection.
- LLM puzzle generation + admin web tool for review.
- Global daily leaderboard.
- Image-rendered share card.
- Push notifications.

**v3 — Viral expansion (~3 weeks)**

- Friend challenge: deep link to today's puzzle, head-to-head score comparison.
- Themed weeks (movie week, song week, brand week).
- IAP: hint packs, streak freezes, cosmetic sticker themes.

---

## 11. Open questions for implementation plan

- Final app name (working title: Emojidle). Confirm before App Store.
- App icon design — sticker aesthetic mark, likely featuring the `📌` motif.
- Specific sound effects — record or use royalty-free?
- Launch date — anchors puzzle #1's date in `puzzles.json`.

These don't block implementation but should be decided early in the plan.
