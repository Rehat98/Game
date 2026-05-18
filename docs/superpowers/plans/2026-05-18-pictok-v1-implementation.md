# Pictok v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a v1 daily emoji-decode puzzle game for iOS (Pictok) — hangman-style gameplay, local-only persistence, sticker/paper-craft visual style, daily local push notification, text share card.

**Architecture:** Pure SwiftUI app, iOS 17+, zero external dependencies. Three layers: `Models/` (pure Codable types), `Game/` (pure logic + persistence wrapper), `Views/` (thin SwiftUI screens reading from a single `@Observable` store). All 60 puzzles bundled as JSON at build time.

**Update note (2026-05-18 mid-execution):** Spec was revised — content trimmed from 90 → 60 puzzles, "easy" tier removed (only medium + hard), random daily ordering instead of day-of-week curve. The puzzles are already authored and approved at `/Users/rehatchugh/emoji-decode/puzzles-draft.json`. Task 6 below reflects the original 90-puzzle scope and should be re-read as: "copy the 60 approved puzzles from `puzzles-draft.json` into the Xcode bundle." Other tasks are unaffected.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest, `UserDefaults`, `UserNotifications`, `AVFoundation`, `UIImpactFeedbackGenerator`, SwiftUI `ShareLink`. Xcode 15+. No SwiftPM packages.

**Spec reference:** [`docs/superpowers/specs/2026-05-18-emoji-decode-design.md`](../specs/2026-05-18-emoji-decode-design.md)

---

## File structure (target)

```
Pictok/                                       (Xcode project root)
├── Pictok.xcodeproj
├── Pictok/
│   ├── PictokApp.swift                        (@main, root view, scheduler hook)
│   ├── Info.plist                             (NSUserNotificationsUsageDescription)
│   ├── Resources/
│   │   ├── puzzles.json                       (60 hand-authored puzzles)
│   │   ├── Assets.xcassets/                   (AppIcon, AccentColor, named colors)
│   │   └── Sounds/                            (correct.wav, wrong.wav, win.wav)
│   ├── Models/
│   │   ├── Puzzle.swift                       (Puzzle, Category, Difficulty)
│   │   └── UserState.swift                    (UserState, HintType)
│   ├── Game/
│   │   ├── GameEngine.swift                   (pure logic — guess, isSolved, hint costs)
│   │   ├── UserStateStore.swift               (@Observable UserDefaults wrapper)
│   │   ├── PuzzleLoader.swift                 (bundle JSON loader + date lookup)
│   │   ├── ShareCardBuilder.swift             (pure string templating)
│   │   ├── NotificationScheduler.swift        (UNUserNotificationCenter wrapper)
│   │   ├── HapticsService.swift               (UIImpactFeedbackGenerator helper)
│   │   └── SoundService.swift                 (AVAudioPlayer helper)
│   └── Views/
│       ├── Theme.swift                        (Color extensions + stickerStyle modifier)
│       ├── TodayView.swift                    (home / play)
│       ├── ResultSheet.swift                  (solve/fail modal)
│       ├── NotificationPermissionSheet.swift  (post-first-solve prompt)
│       ├── StatsView.swift                    (streak + distribution)
│       ├── HowToPlayView.swift                (3-card onboarding)
│       └── Components/
│           ├── EmojiHeader.swift              (big emoji display)
│           ├── BlanksView.swift               (word-slot row)
│           ├── KeyboardView.swift             (26-letter QWERTY)
│           ├── HeartsRow.swift                (lives indicator)
│           ├── CategoryChip.swift             (category pill)
│           └── StickerButton.swift            (sticker-styled button)
└── PictokTests/
    ├── GameEngineTests.swift
    ├── ShareCardBuilderTests.swift
    ├── NotificationSchedulerTests.swift
    ├── UserStateCodableTests.swift
    ├── PuzzleLoaderTests.swift
    └── Resources/
        └── test-puzzles.json                  (small fixture for tests)
```

Two files (`HapticsService`, `SoundService`) are not in the spec's file list; they're tiny helpers extracted from views to keep view code thin. Same intent, more separation.

---

## Test commands

All tests run via:

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

To run a single test class:

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

If `iPhone 15` isn't installed, replace with any available simulator from `xcrun simctl list devices available`.

---

# Phase 0 — Setup

## Task 1: Pre-flight checks (user-blocking)

**Files:** none — this task gates the rest of the plan.

- [ ] **Step 1: Verify Xcode is installed and version ≥ 15**

```bash
xcodebuild -version
```

Expected output contains `Xcode 15.` or higher. If missing/older, install from Mac App Store before continuing.

- [ ] **Step 2: Verify command-line tools point at Xcode**

```bash
xcode-select -p
```

Expected: `/Applications/Xcode.app/Contents/Developer` (not `/Library/Developer/CommandLineTools`). If wrong, run `sudo xcode-select -s /Applications/Xcode.app`.

- [ ] **Step 3: Check at least one iOS 17+ simulator is available**

```bash
xcrun simctl list devices available | grep -E "iPhone.*\(1[7-9]|2[0-9])"
```

Expected: at least one row matching an iOS 17+ device. If none, open Xcode → Settings → Platforms and download an iOS 17 simulator runtime.

- [ ] **Step 4: Flag the trademark clearance open question to the user (DO NOT skip)**

Display the following message to the user and require an acknowledgement before continuing:

> "Before we go further: 'Pictok' is phonetically close to 'TikTok' (ByteDance trademark). Recommended you run a USPTO TESS search (https://tmsearch.uspto.gov) and an App Store name search (https://apps.apple.com → search 'Pictok') before launch. We can build the app under the working name 'Pictok' and rename later if needed — but you should be aware of the risk."

Wait for the user to acknowledge (any response). Do not block further coding tasks on the clearance result.

---

## Task 2: Create the Xcode project

**Files:**
- Create: `/Users/rehatchugh/emoji-decode/Pictok.xcodeproj` (via Xcode wizard)
- Create: `/Users/rehatchugh/emoji-decode/Pictok/` (app source root, created by wizard)
- Create: `/Users/rehatchugh/emoji-decode/PictokTests/` (test target, created by wizard)

- [ ] **Step 1: Launch Xcode and create a new project**

In Xcode: **File → New → Project** → iOS tab → **App** template → Next.

- [ ] **Step 2: Configure project options**

Fill in the wizard:

| Field              | Value                                  |
|--------------------|----------------------------------------|
| Product Name       | `Pictok`                               |
| Team               | (your personal team, or none for now)  |
| Organization ID    | `com.yourname.pictok` (use your own)   |
| Interface          | `SwiftUI`                              |
| Language           | `Swift`                                |
| Storage            | `None` (no Core Data)                  |
| Include Tests      | ✅ checked                              |

Click **Next**.

- [ ] **Step 3: Save into the existing project directory**

Location dialog: navigate to `/Users/rehatchugh/emoji-decode/`. **Uncheck** "Create Git repository on my Mac" (one already exists). Click **Create**.

- [ ] **Step 4: Set deployment target to iOS 17**

Click the project file (top of left sidebar) → select the `Pictok` target → **General** tab → **Minimum Deployments** → set iOS to `17.0`.

- [ ] **Step 5: Verify a clean build runs in the simulator**

In Xcode, select the **iPhone 15** simulator (top toolbar). Press **⌘R** (Run). The simulator should launch and show the default "Hello, world!" SwiftUI screen.

- [ ] **Step 6: Verify CLI tests work**

```bash
cd /Users/rehatchugh/emoji-decode
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: build succeeds, default `testExample` passes, exit code 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/rehatchugh/emoji-decode
git add Pictok.xcodeproj Pictok PictokTests
git commit -m "Scaffold Xcode project for Pictok v1 (iOS 17, SwiftUI)"
```

---

## Task 3: Create folder structure for source files

**Files:** create empty groups in Xcode matching the target file structure above.

- [ ] **Step 1: In Xcode, right-click the `Pictok` group → New Group → name `Models`**

Repeat to create groups: `Game`, `Views`, `Views/Components`, `Resources`, `Resources/Sounds`.

For each: right-click the parent → **New Group** → enter name.

- [ ] **Step 2: Verify the file tree in Xcode left sidebar**

Confirm the tree matches:

```
Pictok/
├── PictokApp.swift          (already exists from template)
├── ContentView.swift        (delete in next step)
├── Assets.xcassets          (move into Resources/)
├── Models/                  (empty group)
├── Game/                    (empty group)
├── Views/
│   └── Components/          (empty group)
└── Resources/
    └── Sounds/              (empty group)
```

- [ ] **Step 3: Move `Assets.xcassets` into `Resources/` group**

In Xcode left sidebar: drag `Assets.xcassets` into the `Resources` group. Also move on disk: `git mv Pictok/Assets.xcassets Pictok/Resources/Assets.xcassets` then re-add via Xcode if needed.

- [ ] **Step 4: Delete the template `ContentView.swift`**

Right-click `ContentView.swift` in Xcode → **Delete** → choose **Move to Trash**. We'll replace it with `TodayView.swift` later.

Edit `PictokApp.swift` to remove the `ContentView()` reference (placeholder for now):

```swift
import SwiftUI

@main
struct PictokApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Pictok – under construction")
                .font(.largeTitle)
        }
    }
}
```

- [ ] **Step 5: Verify build still succeeds**

```bash
cd /Users/rehatchugh/emoji-decode
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: exit code 0.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add folder structure (Models, Game, Views, Resources) and remove template ContentView"
```

---

# Phase 1 — Models

## Task 4: Puzzle, Category, Difficulty models

**Files:**
- Create: `Pictok/Models/Puzzle.swift`
- Create: `PictokTests/Resources/test-puzzles.json` (test fixture, 3 entries)
- Test: `PictokTests/PuzzleDecodingTests.swift`

- [ ] **Step 1: Add a small JSON fixture for tests**

Create `PictokTests/Resources/test-puzzles.json`:

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
  },
  {
    "id": "2026-05-19",
    "date": "2026-05-19",
    "emoji": "🍕🐢🥋",
    "answer": "TEENAGE MUTANT NINJA TURTLES",
    "category": "Movie",
    "subcategory": "Animated · 1990",
    "difficulty": "medium"
  },
  {
    "id": "2026-05-20",
    "date": "2026-05-20",
    "emoji": "🎤🌙🚶",
    "answer": "BILLIE JEAN",
    "category": "Song",
    "subcategory": "Michael Jackson · 1982",
    "difficulty": "easy"
  }
]
```

In Xcode: **File → Add Files to Pictok…** → select this file → **Add to targets: PictokTests** (not the app target). Use folder reference, not group, so it sits under `PictokTests/Resources/`.

- [ ] **Step 2: Write the failing test**

Create `PictokTests/PuzzleDecodingTests.swift`:

```swift
import XCTest
@testable import Pictok

final class PuzzleDecodingTests: XCTestCase {

    func test_decodesAllPuzzlesFromFixture() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let puzzles = try JSONDecoder().decode([Puzzle].self, from: data)

        XCTAssertEqual(puzzles.count, 3)
        XCTAssertEqual(puzzles[0].id, "2026-05-18")
        XCTAssertEqual(puzzles[0].emoji, "🌃🦇🤡")
        XCTAssertEqual(puzzles[0].answer, "THE DARK KNIGHT")
        XCTAssertEqual(puzzles[0].category, .movie)
        XCTAssertEqual(puzzles[0].difficulty, .hard)
        XCTAssertEqual(puzzles[2].category, .song)
        XCTAssertEqual(puzzles[2].difficulty, .easy)
    }

    func test_categoryEmojiIcon_matchesSpec() {
        XCTAssertEqual(Category.movie.icon, "🎬")
        XCTAssertEqual(Category.song.icon, "🎵")
        XCTAssertEqual(Category.book.icon, "📚")
        XCTAssertEqual(Category.brand.icon, "🏷️")
        XCTAssertEqual(Category.celeb.icon, "🎤")
    }

    func test_difficultyDisplayName() {
        XCTAssertEqual(Difficulty.easy.displayName, "Easy")
        XCTAssertEqual(Difficulty.medium.displayName, "Medium")
        XCTAssertEqual(Difficulty.hard.displayName, "Hard")
    }
}
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/PuzzleDecodingTests \
  -quiet
```

Expected: BUILD FAILED (Puzzle, Category, Difficulty undefined).

- [ ] **Step 4: Implement `Puzzle.swift`**

Create `Pictok/Models/Puzzle.swift`:

```swift
import Foundation

struct Puzzle: Codable, Identifiable, Equatable {
    let id: String
    let date: String      // "YYYY-MM-DD"
    let emoji: String
    let answer: String    // UPPERCASE, spaces preserved
    let category: Category
    let subcategory: String
    let difficulty: Difficulty
}

enum Category: String, Codable, CaseIterable {
    case movie = "Movie"
    case song  = "Song"
    case book  = "Book"
    case brand = "Brand"
    case celeb = "Celeb"

    var icon: String {
        switch self {
        case .movie: return "🎬"
        case .song:  return "🎵"
        case .book:  return "📚"
        case .brand: return "🏷️"
        case .celeb: return "🎤"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }
}
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/PuzzleDecodingTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Pictok/Models/Puzzle.swift PictokTests/PuzzleDecodingTests.swift PictokTests/Resources/test-puzzles.json
git commit -m "Add Puzzle, Category, Difficulty models with Codable tests"
```

---

## Task 5: UserState + HintType with Codable round-trip tests

**Files:**
- Create: `Pictok/Models/UserState.swift`
- Test: `PictokTests/UserStateCodableTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PictokTests/UserStateCodableTests.swift`:

```swift
import XCTest
@testable import Pictok

final class UserStateCodableTests: XCTestCase {

    func test_freshState_roundTripsThroughJSON() throws {
        let original = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(UserState.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func test_freshState_hasExpectedDefaults() {
        let s = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertNil(s.lastSolvedDate)
        XCTAssertEqual(s.streakFreezesAvailable, 1)
        XCTAssertEqual(s.totalSolved, 0)
        XCTAssertEqual(s.totalPlayed, 0)
        XCTAssertEqual(s.guessDistribution, [:])
        XCTAssertEqual(s.lives, 5)
        XCTAssertFalse(s.todaySolved)
        XCTAssertFalse(s.todayFailed)
        XCTAssertNil(s.todayPuzzleId)
        XCTAssertEqual(s.todayWrongGuesses, [])
        XCTAssertEqual(s.todayCorrectGuesses, [])
        XCTAssertNil(s.todayHintUsed)
        XCTAssertNil(s.todayRevealedLetter)
    }

    func test_populatedState_roundTrips() throws {
        var s = UserState.fresh(at: Date(timeIntervalSince1970: 1_700_000_000))
        s.currentStreak = 7
        s.longestStreak = 10
        s.lastSolvedDate = "2026-05-17"
        s.streakFreezesAvailable = 0
        s.totalSolved = 23
        s.totalPlayed = 25
        s.guessDistribution = [0: 5, 1: 7, 2: 6, 3: 5]
        s.lives = 3
        s.todayPuzzleId = "2026-05-18"
        s.todayWrongGuesses = ["X", "Z"]
        s.todayCorrectGuesses = ["E", "I"]
        s.todayHintUsed = .category
        s.todayRevealedLetter = nil

        let data = try JSONEncoder().encode(s)
        let restored = try JSONDecoder().decode(UserState.self, from: data)
        XCTAssertEqual(s, restored)
    }

    func test_hintType_codableViaRawValue() throws {
        let cat = try JSONEncoder().encode(HintType.category)
        XCTAssertEqual(String(data: cat, encoding: .utf8), "\"category\"")

        let letter = try JSONEncoder().encode(HintType.letter)
        XCTAssertEqual(String(data: letter, encoding: .utf8), "\"letter\"")
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/UserStateCodableTests \
  -quiet
```

Expected: BUILD FAILED (UserState, HintType undefined).

- [ ] **Step 3: Implement `UserState.swift`**

Create `Pictok/Models/UserState.swift`:

```swift
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
            hasAskedForNotificationPermission: false
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
        livesLastRefilledAt     = try c.decode(Date.self, forKey: .livesLastRefilledAt)
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
    }
}
```

Note: `hasEverSolved` and `hasAskedForNotificationPermission` weren't in the spec's struct but are needed for the contextual notification-permission flow (§3 notification spec). Added here.

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/UserStateCodableTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Models/UserState.swift PictokTests/UserStateCodableTests.swift
git commit -m "Add UserState and HintType with Codable round-trip tests"
```

---

# Phase 2 — Content (puzzles)

## Task 6: Author 90 puzzles (user-reviewed)

**Files:**
- Create: `Pictok/Resources/puzzles.json` (final, after user review)

This is content work, not coding. The task produces the 90-puzzle JSON file that ships in the app bundle.

- [ ] **Step 1: Generate a draft batch of 90 puzzles**

Generate 90 puzzles following these criteria, copy-pasted from spec §6:

**Quality bar**
- Riddle-style, 30-second-to-2-minute solve time.
- NOT direct mappings like `🦁👑 = Lion King`. Should require thought.
- Use 2–4 emojis per puzzle. More than 4 is usually too many.
- The combination should feel like a puzzle, not a sentence.
- Mix iconic + clever. `🌃🦇🤡 = Dark Knight` is iconic-good; `🚿🔪🎻 = Psycho` is clever-good.

**Mix targets (across 90 puzzles)**
- 45 Movies (50%)
- 18 Songs (20%)
- 14 Books (15%)
- 9 Brands (10%)
- 4 Celebs (5%)

**Difficulty distribution (matches day-of-week curve)**
- 26 Easy (~29%)
- 38 Medium (~43%)
- 26 Hard (~29%)

**Cultural calibration**
- Globally recognizable picks. Avoid US-only deep-cuts (e.g., specific game shows, regional brands).
- Avoid puzzles requiring obscure spelling (foreign names without transliteration consensus).
- Skip anything with potential brand/IP litigation risk (e.g., obscure trademarks).

**Output format** — a JSON array, each entry matching the `Puzzle` schema:

```json
{
  "id": "puzzle-NNN",
  "date": "",
  "emoji": "...",
  "answer": "UPPERCASE",
  "category": "Movie|Song|Book|Brand|Celeb",
  "subcategory": "Genre · Year · or other distinguishing detail",
  "difficulty": "easy|medium|hard"
}
```

Leave `date` empty in the draft — dates are assigned by sort order in Step 3.

**Starter set (review these 10 first to calibrate the voice):**

```json
[
  { "id": "puzzle-001", "date": "", "emoji": "🌃🦇🤡", "answer": "THE DARK KNIGHT", "category": "Movie", "subcategory": "Action · 2008", "difficulty": "hard" },
  { "id": "puzzle-002", "date": "", "emoji": "🚿🔪🎻", "answer": "PSYCHO", "category": "Movie", "subcategory": "Thriller · 1960", "difficulty": "hard" },
  { "id": "puzzle-003", "date": "", "emoji": "🐟🔍👨‍👧", "answer": "FINDING NEMO", "category": "Movie", "subcategory": "Animated · 2003", "difficulty": "easy" },
  { "id": "puzzle-004", "date": "", "emoji": "🍕🐢🥋", "answer": "TEENAGE MUTANT NINJA TURTLES", "category": "Movie", "subcategory": "Animated · 1990", "difficulty": "medium" },
  { "id": "puzzle-005", "date": "", "emoji": "👻🚫📞", "answer": "GHOSTBUSTERS", "category": "Movie", "subcategory": "Comedy · 1984", "difficulty": "medium" },
  { "id": "puzzle-006", "date": "", "emoji": "🎤🌙🚶", "answer": "BILLIE JEAN", "category": "Song", "subcategory": "Michael Jackson · 1982", "difficulty": "easy" },
  { "id": "puzzle-007", "date": "", "emoji": "👁️🌧️🍷", "answer": "BLADE RUNNER", "category": "Movie", "subcategory": "Sci-Fi · 1982", "difficulty": "hard" },
  { "id": "puzzle-008", "date": "", "emoji": "🏰💍🌋", "answer": "THE LORD OF THE RINGS", "category": "Book", "subcategory": "Fantasy · J.R.R. Tolkien", "difficulty": "medium" },
  { "id": "puzzle-009", "date": "", "emoji": "🪞🍎😴", "answer": "SNOW WHITE", "category": "Movie", "subcategory": "Animated · 1937", "difficulty": "medium" },
  { "id": "puzzle-010", "date": "", "emoji": "🏝️📻🎁", "answer": "CAST AWAY", "category": "Movie", "subcategory": "Drama · 2000", "difficulty": "easy" }
]
```

- [ ] **Step 2: Present the draft to the user and iterate**

Show the full 90-puzzle draft (in batches of 15–20 if needed) and ask for feedback. The user will reject any that feel too obvious, too obscure, or culturally narrow. Replace rejections with new puzzles drawn from the same quality bar. Loop until the user approves the full set.

Do not move to Step 3 until the user explicitly approves the final 90.

- [ ] **Step 3: Assign launch-anchored dates by difficulty curve**

Decide a **launch date** with the user (defaults to "next Monday" if they don't specify).

Sort the 90 puzzles by difficulty curve: starting from the launch date, assign:
- Mon: Easy
- Tue: Easy
- Wed: Medium
- Thu: Medium
- Fri: Hard
- Sat: Hard
- Sun: Medium

Cycle through this pattern, picking an unassigned puzzle of the matching difficulty for each date. Continue for 90 consecutive days.

Update each puzzle's `id` and `date` fields to the assigned ISO date (`"YYYY-MM-DD"`).

- [ ] **Step 4: Write the final JSON to the app bundle**

Save the result to `Pictok/Resources/puzzles.json`. In Xcode: **File → Add Files to Pictok…** → select `puzzles.json` → add to the **Pictok** app target (not the test target).

- [ ] **Step 5: Verify the bundled JSON parses (smoke test)**

Add this temporary test to `PictokTests/PuzzleDecodingTests.swift`:

```swift
func test_bundledPuzzlesJson_loadsAndHas60Entries() throws {
    let url = Bundle.main.url(forResource: "puzzles", withExtension: "json")
    XCTAssertNotNil(url, "puzzles.json must be in the app bundle")
    let data = try Data(contentsOf: url!)
    let puzzles = try JSONDecoder().decode([Puzzle].self, from: data)
    XCTAssertEqual(puzzles.count, 60)
    XCTAssertEqual(Set(puzzles.map { $0.date }).count, 60, "all dates must be unique")
}
```

Run:

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/PuzzleDecodingTests/test_bundledPuzzlesJson_loadsAndHas60Entries \
  -quiet
```

Expected: TEST SUCCEEDED.

⚠️ Note: this test references the app bundle (`Bundle.main`), which requires the test host. The default Xcode App+Tests setup wires this up; verify the test target's "Host Application" is set to Pictok.

- [ ] **Step 6: Commit**

```bash
git add Pictok/Resources/puzzles.json PictokTests/PuzzleDecodingTests.swift
git commit -m "Add 60 hand-authored puzzles for v1 launch + bundle smoke test"
```

---

# Phase 3 — Game logic (TDD)

## Task 7: PuzzleLoader — load bundle JSON + find today's puzzle

**Files:**
- Create: `Pictok/Game/PuzzleLoader.swift`
- Test: `PictokTests/PuzzleLoaderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PictokTests/PuzzleLoaderTests.swift`:

```swift
import XCTest
@testable import Pictok

final class PuzzleLoaderTests: XCTestCase {

    func test_loadsFromFixture() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)
        XCTAssertEqual(loader.allPuzzles.count, 3)
    }

    func test_findsPuzzleForKnownDate() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)

        // 2026-05-19 12:00 UTC → "2026-05-19" in UTC
        let date = ISO8601DateFormatter().date(from: "2026-05-19T12:00:00Z")!
        let puzzle = loader.puzzle(for: date, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(puzzle?.answer, "TEENAGE MUTANT NINJA TURTLES")
    }

    func test_returnsNilForDateWithNoPuzzle() throws {
        let url = Bundle(for: type(of: self))
            .url(forResource: "test-puzzles", withExtension: "json")!
        let loader = try PuzzleLoader(url: url)

        let date = ISO8601DateFormatter().date(from: "2030-01-01T12:00:00Z")!
        XCTAssertNil(loader.puzzle(for: date, timeZone: TimeZone(identifier: "UTC")!))
    }

    func test_dateStringHelper_returnsYYYYMMDDInTimeZone() {
        let date = ISO8601DateFormatter().date(from: "2026-05-18T23:30:00Z")!
        // In UTC the date string is "2026-05-18"
        XCTAssertEqual(PuzzleLoader.dateString(for: date, timeZone: TimeZone(identifier: "UTC")!),
                       "2026-05-18")
        // In Asia/Tokyo (+9) it's already "2026-05-19"
        XCTAssertEqual(PuzzleLoader.dateString(for: date, timeZone: TimeZone(identifier: "Asia/Tokyo")!),
                       "2026-05-19")
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/PuzzleLoaderTests \
  -quiet
```

Expected: BUILD FAILED (PuzzleLoader undefined).

- [ ] **Step 3: Implement `PuzzleLoader.swift`**

Create `Pictok/Game/PuzzleLoader.swift`:

```swift
import Foundation

struct PuzzleLoader {
    let allPuzzles: [Puzzle]
    private let puzzlesByDate: [String: Puzzle]

    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([Puzzle].self, from: data)
        self.allPuzzles = decoded
        self.puzzlesByDate = Dictionary(uniqueKeysWithValues: decoded.map { ($0.date, $0) })
    }

    static func bundled(bundle: Bundle = .main) throws -> PuzzleLoader {
        guard let url = bundle.url(forResource: "puzzles", withExtension: "json") else {
            throw NSError(domain: "Pictok", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "puzzles.json missing from bundle"])
        }
        return try PuzzleLoader(url: url)
    }

    func puzzle(for date: Date, timeZone: TimeZone = .current) -> Puzzle? {
        let key = Self.dateString(for: date, timeZone: timeZone)
        return puzzlesByDate[key]
    }

    static func dateString(for date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Returns the 1-based puzzle number for the given puzzle (index in the sorted bundle).
    /// Used for the share card's "#N" stamp.
    func puzzleNumber(for puzzle: Puzzle) -> Int {
        let sorted = allPuzzles.sorted { $0.date < $1.date }
        return (sorted.firstIndex(of: puzzle) ?? 0) + 1
    }
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/PuzzleLoaderTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/PuzzleLoader.swift PictokTests/PuzzleLoaderTests.swift
git commit -m "Add PuzzleLoader for bundle JSON + date-keyed lookup"
```

---

## Task 8: GameEngine — letter guessing + win/fail conditions

**Files:**
- Create: `Pictok/Game/GameEngine.swift`
- Test: `PictokTests/GameEngineTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PictokTests/GameEngineTests.swift`:

```swift
import XCTest
@testable import Pictok

final class GameEngineTests: XCTestCase {

    func makeSamplePuzzle() -> Puzzle {
        Puzzle(id: "t-1", date: "2026-05-18",
               emoji: "🌃🦇🤡", answer: "THE DARK KNIGHT",
               category: .movie, subcategory: "Action · 2008",
               difficulty: .hard)
    }

    // MARK: Letter classification

    func test_isLetterCorrect_trueWhenLetterInAnswer() {
        let p = makeSamplePuzzle()
        XCTAssertTrue(GameEngine.isCorrect(letter: "T", in: p))
        XCTAssertTrue(GameEngine.isCorrect(letter: "K", in: p))
    }

    func test_isLetterCorrect_falseWhenLetterNotInAnswer() {
        let p = makeSamplePuzzle()
        XCTAssertFalse(GameEngine.isCorrect(letter: "Z", in: p))
        XCTAssertFalse(GameEngine.isCorrect(letter: "B", in: p))
    }

    func test_isLetterCorrect_caseInsensitive() {
        let p = makeSamplePuzzle()
        XCTAssertTrue(GameEngine.isCorrect(letter: "t", in: p))
    }

    // MARK: Win/fail

    func test_isSolved_falseWithMissingLetters() {
        let p = makeSamplePuzzle()
        let guessed: Set<Character> = ["T", "H", "E"]
        XCTAssertFalse(GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: nil))
    }

    func test_isSolved_trueWhenAllLettersGuessed() {
        let p = makeSamplePuzzle()
        let allLetters = Set("THE DARK KNIGHT".filter { $0.isLetter })
        XCTAssertTrue(GameEngine.isSolved(answer: p.answer, correctGuesses: allLetters, revealedLetter: nil))
    }

    func test_isSolved_trueWhenAllLettersIncludingRevealedHint() {
        let p = makeSamplePuzzle()
        // All letters except T → solved only when revealedLetter is T
        var guessed = Set("THE DARK KNIGHT".filter { $0.isLetter })
        guessed.remove("T")
        XCTAssertFalse(GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: nil))
        XCTAssertTrue (GameEngine.isSolved(answer: p.answer, correctGuesses: guessed, revealedLetter: "T"))
    }

    func test_isFailed_whenLivesAtZero() {
        XCTAssertTrue(GameEngine.isFailed(lives: 0))
        XCTAssertFalse(GameEngine.isFailed(lives: 1))
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: BUILD FAILED (GameEngine undefined).

- [ ] **Step 3: Implement `GameEngine.swift` (minimal — for the tests above)**

Create `Pictok/Game/GameEngine.swift`:

```swift
import Foundation

enum GameEngine {

    static func isCorrect(letter: Character, in puzzle: Puzzle) -> Bool {
        let upper = Character(String(letter).uppercased())
        return puzzle.answer.contains(upper)
    }

    static func isSolved(answer: String,
                         correctGuesses: Set<Character>,
                         revealedLetter: Character?) -> Bool {
        let answerLetters = Set(answer.filter { $0.isLetter })
        var known = correctGuesses
        if let r = revealedLetter { known.insert(r) }
        return answerLetters.isSubset(of: known)
    }

    static func isFailed(lives: Int) -> Bool {
        lives <= 0
    }
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/GameEngine.swift PictokTests/GameEngineTests.swift
git commit -m "Add GameEngine: letter guessing + solved/failed predicates"
```

---

## Task 9: GameEngine — hint costs

**Files:**
- Modify: `Pictok/Game/GameEngine.swift`
- Modify: `PictokTests/GameEngineTests.swift`

- [ ] **Step 1: Add failing tests for hint mechanics**

Append to `PictokTests/GameEngineTests.swift`:

```swift
    // MARK: Hints

    func test_hintCost_categoryCostsOneHeart() {
        XCTAssertEqual(GameEngine.heartCost(for: .category), 1)
    }

    func test_hintCost_letterCostsTwoHearts() {
        XCTAssertEqual(GameEngine.heartCost(for: .letter), 2)
    }

    func test_letterHint_returnsFirstUnguessedLetterFromAnswer() {
        let p = makeSamplePuzzle()
        // No correct guesses yet — should return one of THEDARKNIGHT letters
        let revealed = GameEngine.letterToReveal(for: p, correctGuesses: [])
        XCTAssertNotNil(revealed)
        XCTAssertTrue("THE DARK KNIGHT".contains(revealed!))
    }

    func test_letterHint_skipsAlreadyGuessedLetters() {
        let p = makeSamplePuzzle()
        // Already guessed all of T, H, E
        let already: Set<Character> = ["T", "H", "E"]
        let revealed = GameEngine.letterToReveal(for: p, correctGuesses: already)
        XCTAssertNotNil(revealed)
        XCTAssertFalse(already.contains(revealed!))
        XCTAssertTrue("DARKNIGHT".contains(revealed!))
    }

    func test_letterHint_returnsNilWhenAllLettersAlreadyGuessed() {
        let p = makeSamplePuzzle()
        let all = Set("THE DARK KNIGHT".filter { $0.isLetter })
        XCTAssertNil(GameEngine.letterToReveal(for: p, correctGuesses: all))
    }
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: TEST FAILED — undefined methods.

- [ ] **Step 3: Extend `GameEngine.swift`**

Append to `Pictok/Game/GameEngine.swift`:

```swift
extension GameEngine {

    static func heartCost(for hint: HintType) -> Int {
        switch hint {
        case .category: return 1
        case .letter:   return 2
        }
    }

    /// Returns a deterministic "best" letter to reveal: the first letter in the answer
    /// (left-to-right) that the player hasn't already guessed. Returns nil if all
    /// letters are already known.
    static func letterToReveal(for puzzle: Puzzle, correctGuesses: Set<Character>) -> Character? {
        for ch in puzzle.answer where ch.isLetter {
            if !correctGuesses.contains(ch) { return ch }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/GameEngine.swift PictokTests/GameEngineTests.swift
git commit -m "GameEngine: hint heart costs + letter-reveal selection"
```

---

## Task 10: GameEngine — streak transitions

**Files:**
- Modify: `Pictok/Game/GameEngine.swift`
- Modify: `PictokTests/GameEngineTests.swift`

- [ ] **Step 1: Add failing tests for streak math**

Append to `PictokTests/GameEngineTests.swift`:

```swift
    // MARK: Streak transitions

    func test_streakAfterSolve_incrementsWhenYesterdayWasSolved() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-18",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 0
        )
        XCTAssertEqual(next.streak, 8)
        XCTAssertEqual(next.freezesAvailable, 0)
    }

    func test_streakAfterSolve_setsToOneWhenLastSolveIsNil() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-18",
            lastSolvedDate: nil,
            currentStreak: 0,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 1)
    }

    func test_streakAfterSolve_setsToOneWhenLastSolveIsTwoOrMoreDaysAgo_andNoFreeze() {
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-20",
            lastSolvedDate: "2026-05-17",   // 3 days ago
            currentStreak: 7,
            streakFreezesAvailable: 0
        )
        XCTAssertEqual(next.streak, 1)
    }

    func test_streakAfterSolve_consumesFreezeForExactlyOneMissedDay() {
        // Yesterday was missed (last solve = day-before-yesterday) → freeze rescues
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-19",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 8)
        XCTAssertEqual(next.freezesAvailable, 0)
    }

    func test_streakAfterSolve_doesNotConsumeFreezeForMoreThanOneMissedDay() {
        // Two missed days → freeze can't save it, streak resets to 1, freeze NOT consumed
        let next = GameEngine.streakAfterSolve(
            today: "2026-05-20",
            lastSolvedDate: "2026-05-17",
            currentStreak: 7,
            streakFreezesAvailable: 1
        )
        XCTAssertEqual(next.streak, 1)
        XCTAssertEqual(next.freezesAvailable, 1)
    }

    func test_streakAfterFail_resetsToZero() {
        XCTAssertEqual(GameEngine.streakAfterFail(currentStreak: 23), 0)
    }
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: TEST FAILED — undefined methods.

- [ ] **Step 3: Extend `GameEngine.swift`**

Append to `Pictok/Game/GameEngine.swift`:

```swift
extension GameEngine {

    struct StreakResult: Equatable {
        let streak: Int
        let freezesAvailable: Int
    }

    static func streakAfterSolve(today: String,
                                 lastSolvedDate: String?,
                                 currentStreak: Int,
                                 streakFreezesAvailable: Int) -> StreakResult {
        guard let last = lastSolvedDate else {
            return StreakResult(streak: 1, freezesAvailable: streakFreezesAvailable)
        }
        let daysApart = daysBetween(last, today)
        switch daysApart {
        case 1:
            // Solved consecutive day — straight increment.
            return StreakResult(streak: currentStreak + 1,
                                freezesAvailable: streakFreezesAvailable)
        case 2 where streakFreezesAvailable > 0:
            // Missed exactly one day, freeze rescues the streak.
            return StreakResult(streak: currentStreak + 1,
                                freezesAvailable: streakFreezesAvailable - 1)
        default:
            // 0 (same day — shouldn't happen during a real solve), or >1 missed days.
            return StreakResult(streak: 1, freezesAvailable: streakFreezesAvailable)
        }
    }

    static func streakAfterFail(currentStreak: Int) -> Int { 0 }

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

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/GameEngineTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/GameEngine.swift PictokTests/GameEngineTests.swift
git commit -m "GameEngine: streak transitions with one-day freeze rescue"
```

---

## Task 11: UserStateStore — UserDefaults wrapper + lives refill

**Files:**
- Create: `Pictok/Game/UserStateStore.swift`
- Test: `PictokTests/UserStateStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PictokTests/UserStateStoreTests.swift`:

```swift
import XCTest
@testable import Pictok

final class UserStateStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.pictok.state"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_freshStore_returnsDefaultState() {
        let store = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(store.state.lives, 5)
        XCTAssertEqual(store.state.currentStreak, 0)
    }

    func test_save_persistsAcrossInstances() {
        let store1 = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store1.state.currentStreak = 5
        store1.save()

        let store2 = UserStateStore(defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(store2.state.currentStreak, 5)
    }

    func test_refillLives_addsOneHeartPerFourHours() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 2
        store.state.livesLastRefilledAt = t0

        // 4 hours later → +1 heart
        store.refillLives(now: t0.addingTimeInterval(4 * 3600))
        XCTAssertEqual(store.state.lives, 3)

        // 12 hours later (3 refills) but capped at 5
        store.refillLives(now: t0.addingTimeInterval(12 * 3600 + 1))
        XCTAssertEqual(store.state.lives, 5)
    }

    func test_refillLives_doesNothingWhenAlreadyMaxed() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 5
        store.refillLives(now: t0.addingTimeInterval(100 * 3600))
        XCTAssertEqual(store.state.lives, 5)
    }

    func test_refillLives_advancesAnchorByExactRefillCount() {
        let t0 = Date(timeIntervalSince1970: 0)
        let store = UserStateStore(defaults: defaults, now: { t0 })
        store.state.lives = 0
        store.state.livesLastRefilledAt = t0

        // 5 hours later → 1 refill, anchor advances by exactly 4h (not 5h),
        // so the next refill will fire after another 3 hours.
        let now1 = t0.addingTimeInterval(5 * 3600)
        store.refillLives(now: now1)
        XCTAssertEqual(store.state.lives, 1)
        XCTAssertEqual(store.state.livesLastRefilledAt, t0.addingTimeInterval(4 * 3600))
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/UserStateStoreTests \
  -quiet
```

Expected: BUILD FAILED.

- [ ] **Step 3: Implement `UserStateStore.swift`**

Create `Pictok/Game/UserStateStore.swift`:

```swift
import Foundation
import Observation

@Observable
final class UserStateStore {
    static let defaultsKey = "pictok.state.v1"
    private static let refillInterval: TimeInterval = 4 * 3600   // 4 hours
    private static let maxLives = 5

    private let defaults: UserDefaults
    private let now: () -> Date

    var state: UserState

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.defaultsKey),
           let restored = try? JSONDecoder().decode(UserState.self, from: data) {
            self.state = restored
        } else {
            self.state = UserState.fresh(at: now())
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Refill lives based on elapsed time since the anchor. Caller passes `now`
    /// explicitly so this is testable.
    func refillLives(now currentTime: Date? = nil) {
        let nowValue = currentTime ?? now()
        guard state.lives < Self.maxLives else {
            // Keep the anchor current so we don't accumulate a huge backlog while maxed.
            state.livesLastRefilledAt = nowValue
            return
        }
        let elapsed = nowValue.timeIntervalSince(state.livesLastRefilledAt)
        guard elapsed >= Self.refillInterval else { return }

        let livesToAdd = min(Int(elapsed / Self.refillInterval),
                             Self.maxLives - state.lives)
        state.lives += livesToAdd
        state.livesLastRefilledAt = state.livesLastRefilledAt
            .addingTimeInterval(Double(livesToAdd) * Self.refillInterval)
    }
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/UserStateStoreTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/UserStateStore.swift PictokTests/UserStateStoreTests.swift
git commit -m "Add UserStateStore: @Observable UserDefaults wrapper + lives refill"
```

---

## Task 12: ShareCardBuilder

**Files:**
- Create: `Pictok/Game/ShareCardBuilder.swift`
- Test: `PictokTests/ShareCardBuilderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PictokTests/ShareCardBuilderTests.swift`:

```swift
import XCTest
@testable import Pictok

final class ShareCardBuilderTests: XCTestCase {

    func test_successCard_basicFormat() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 3,
            hintUsed: false,
            currentStreak: 7,
            url: "pictok.app"
        )
        let expected = """
        Pictok #142 📌
        🎬 Hard
        ❤️❤️❤️🖤🖤 · 🔥 7

        pictok.app
        """
        XCTAssertEqual(card, expected)
    }

    func test_successCard_withHint_appendsBulbAfterHearts() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            heartsRemaining: 3,
            hintUsed: true,
            currentStreak: 7,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️🖤🖤 · 💡 · 🔥 7"))
    }

    func test_failureCard_format() {
        let card = ShareCardBuilder.failureCard(
            puzzleNumber: 142,
            category: .movie,
            difficulty: .hard,
            previousStreak: 7,
            url: "pictok.app"
        )
        let expected = """
        Pictok #142 📌
        🎬 Hard · today got me 🥲
        🔥 7 → 0

        pictok.app
        """
        XCTAssertEqual(card, expected)
    }

    func test_successCard_fullHearts_zeroLost() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 1,
            category: .song,
            difficulty: .easy,
            heartsRemaining: 5,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("❤️❤️❤️❤️❤️ · 🔥 1"))
    }

    func test_successCard_zeroHearts_allLost_butStillSolved() {
        let card = ShareCardBuilder.successCard(
            puzzleNumber: 50,
            category: .book,
            difficulty: .medium,
            heartsRemaining: 0,
            hintUsed: false,
            currentStreak: 1,
            url: "pictok.app"
        )
        XCTAssertTrue(card.contains("🖤🖤🖤🖤🖤 · 🔥 1"))
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/ShareCardBuilderTests \
  -quiet
```

Expected: BUILD FAILED.

- [ ] **Step 3: Implement `ShareCardBuilder.swift`**

Create `Pictok/Game/ShareCardBuilder.swift`:

```swift
import Foundation

enum ShareCardBuilder {

    static func successCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            heartsRemaining: Int,
                            hintUsed: Bool,
                            currentStreak: Int,
                            url: String) -> String {
        let hearts = heartsBar(remaining: heartsRemaining)
        let hint = hintUsed ? " · 💡" : ""
        return """
        Pictok #\(puzzleNumber) 📌
        \(category.icon) \(difficulty.displayName)
        \(hearts)\(hint) · 🔥 \(currentStreak)

        \(url)
        """
    }

    static func failureCard(puzzleNumber: Int,
                            category: Category,
                            difficulty: Difficulty,
                            previousStreak: Int,
                            url: String) -> String {
        return """
        Pictok #\(puzzleNumber) 📌
        \(category.icon) \(difficulty.displayName) · today got me 🥲
        🔥 \(previousStreak) → 0

        \(url)
        """
    }

    private static func heartsBar(remaining: Int) -> String {
        let r = max(0, min(5, remaining))
        return String(repeating: "❤️", count: r) + String(repeating: "🖤", count: 5 - r)
    }
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/ShareCardBuilderTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Game/ShareCardBuilder.swift PictokTests/ShareCardBuilderTests.swift
git commit -m "Add ShareCardBuilder: success/failure variants with hint marker"
```

---

## Task 13: NotificationScheduler

**Files:**
- Create: `Pictok/Game/NotificationScheduler.swift`
- Test: `PictokTests/NotificationSchedulerTests.swift`

This is the only mockable async-ish system in v1. We abstract `UNUserNotificationCenter` behind a tiny protocol so tests can verify scheduling without real iOS APIs.

- [ ] **Step 1: Write the failing test**

Create `PictokTests/NotificationSchedulerTests.swift`:

```swift
import XCTest
@testable import Pictok

final class NotificationSchedulerTests: XCTestCase {

    final class MockCenter: NotificationCenterProtocol {
        var pending: [String] = []
        var added: [(id: String, components: DateComponents)] = []
        var removed: [String] = []

        func pendingIdentifiers() async -> [String] { pending }
        func add(identifier: String, components: DateComponents) async {
            pending.append(identifier)
            added.append((identifier, components))
        }
        func remove(identifier: String) async {
            pending.removeAll { $0 == identifier }
            removed.append(identifier)
        }
    }

    func test_schedulesTomorrow9amWhenNothingPending() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T15:30:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        XCTAssertEqual(mock.added.count, 1)
        let comps = mock.added.first!.components
        // The scheduled fire time is the next 9 AM in the device timezone (UTC here)
        // 2026-05-18T15:30 UTC → next 9 AM is 2026-05-19T09:00 UTC
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 19)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    func test_schedulesSameDay9amIfNotYetFired_andNotSolved() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        let comps = mock.added.first!.components
        XCTAssertEqual(comps.day, 18)  // today
        XCTAssertEqual(comps.hour, 9)
    }

    func test_skipsSchedulingForToday_ifAlreadySolved_andBefore9am() async {
        let mock = MockCenter()
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: true)

        // Schedules tomorrow instead
        let comps = mock.added.first!.components
        XCTAssertEqual(comps.day, 19)
    }

    func test_doesNotDoubleSchedule_whenIdentifierAlreadyPending() async {
        let mock = MockCenter()
        mock.pending = [NotificationScheduler.dailyReminderIdentifier]
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T06:00:00Z")!

        await scheduler.scheduleDailyReminderIfNeeded(now: now, alreadySolvedToday: false)

        XCTAssertEqual(mock.added.count, 0)
    }

    func test_cancelTodaysReminder_removesPendingIdentifier() async {
        let mock = MockCenter()
        mock.pending = [NotificationScheduler.dailyReminderIdentifier]
        let scheduler = NotificationScheduler(center: mock,
                                              calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)

        await scheduler.cancelDailyReminder()

        XCTAssertEqual(mock.removed, [NotificationScheduler.dailyReminderIdentifier])
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/NotificationSchedulerTests \
  -quiet
```

Expected: BUILD FAILED.

- [ ] **Step 3: Implement `NotificationScheduler.swift`**

Create `Pictok/Game/NotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications

protocol NotificationCenterProtocol {
    func pendingIdentifiers() async -> [String]
    func add(identifier: String, components: DateComponents) async
    func remove(identifier: String) async
}

/// Real UNUserNotificationCenter adapter.
struct UNNotificationCenterAdapter: NotificationCenterProtocol {
    let title = "Your puzzle is ready 📌"
    let body  = "Keep your streak going 🔥 — today's emoji decode awaits."

    func pendingIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }

    func add(identifier: String, components: DateComponents) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func remove(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }
}

struct NotificationScheduler {
    static let dailyReminderIdentifier = "pictok.daily-reminder"
    private static let fireHour = 9

    let center: NotificationCenterProtocol
    let calendar: Calendar
    let timeZone: TimeZone

    init(center: NotificationCenterProtocol = UNNotificationCenterAdapter(),
         calendar: Calendar = Calendar(identifier: .gregorian),
         timeZone: TimeZone = .current) {
        self.center = center
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }

    /// Schedule the next 9 AM reminder. If `alreadySolvedToday` is true, skip
    /// today's notification and schedule tomorrow's.
    func scheduleDailyReminderIfNeeded(now: Date, alreadySolvedToday: Bool) async {
        let pending = await center.pendingIdentifiers()
        guard !pending.contains(Self.dailyReminderIdentifier) else { return }

        let fireDate = nextFireDate(after: now, skipTodayBecauseSolved: alreadySolvedToday)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                            from: fireDate)
        await center.add(identifier: Self.dailyReminderIdentifier, components: comps)
    }

    func cancelDailyReminder() async {
        await center.remove(identifier: Self.dailyReminderIdentifier)
    }

    /// Returns the next 9 AM moment that should fire. If today's 9 AM is still
    /// in the future AND the user hasn't already solved, fire today; otherwise tomorrow.
    private func nextFireDate(after now: Date, skipTodayBecauseSolved: Bool) -> Date {
        let todayAt9 = calendar.date(bySettingHour: Self.fireHour, minute: 0, second: 0, of: now)!
        if !skipTodayBecauseSolved && now < todayAt9 {
            return todayAt9
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAt9)!
    }
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild test \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:PictokTests/NotificationSchedulerTests \
  -quiet
```

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Add usage description to `Info.plist`**

In Xcode: click the Pictok target → **Info** tab. Under **Custom iOS Target Properties**, add a new row:

| Key                                        | Type   | Value                                                          |
|--------------------------------------------|--------|----------------------------------------------------------------|
| `NSUserNotificationsUsageDescription`      | String | We use a daily notification to remind you to keep your streak. |

(This key is technically optional in iOS 15+ but it's good hygiene to have it.)

- [ ] **Step 6: Commit**

```bash
git add Pictok/Game/NotificationScheduler.swift PictokTests/NotificationSchedulerTests.swift Pictok/Info.plist
git commit -m "Add NotificationScheduler with mockable center protocol + Info.plist key"
```

---

## Task 14: Tiny helpers — HapticsService and SoundService

**Files:**
- Create: `Pictok/Game/HapticsService.swift`
- Create: `Pictok/Game/SoundService.swift`

These are too thin to TDD. Skip-test, manual verification.

- [ ] **Step 1: Implement `HapticsService.swift`**

Create `Pictok/Game/HapticsService.swift`:

```swift
import UIKit

enum HapticsService {
    static func tap()        { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func correct()    { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func wrong()      { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func solved()     { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failed()     { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
```

- [ ] **Step 2: Implement `SoundService.swift`**

Create `Pictok/Game/SoundService.swift`:

```swift
import AVFoundation

enum Sound: String {
    case correct, wrong, win
}

final class SoundService {
    static let shared = SoundService()
    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for sound in [Sound.correct, .wrong, .win] {
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
                players[sound] = try? AVAudioPlayer(contentsOf: url)
                players[sound]?.prepareToPlay()
            }
        }
    }

    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }
}
```

- [ ] **Step 3: Verify build succeeds**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: exit code 0. Missing sound files are silently ignored (no `.wav` files exist yet); they'll be added in Task 28.

- [ ] **Step 4: Commit**

```bash
git add Pictok/Game/HapticsService.swift Pictok/Game/SoundService.swift
git commit -m "Add HapticsService and SoundService helper wrappers"
```

---

# Phase 4 — Theme + UI components

## Task 15: Theme — colors, fonts, sticker modifier

**Files:**
- Create: `Pictok/Views/Theme.swift`

- [ ] **Step 1: Implement `Theme.swift`**

Create `Pictok/Views/Theme.swift`:

```swift
import SwiftUI

extension Color {
    static let pkPaper      = Color(red: 0xFE/255, green: 0xF3/255, blue: 0xD9/255)
    static let pkInk        = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
    static let pkYellow     = Color(red: 0xFF/255, green: 0xD6/255, blue: 0x0A/255)
    static let pkRed        = Color(red: 0xE6/255, green: 0x39/255, blue: 0x46/255)
    static let pkGreen      = Color(red: 0x06/255, green: 0xD6/255, blue: 0xA0/255)
    static let pkBlue       = Color(red: 0x11/255, green: 0x8A/255, blue: 0xB2/255)
}

extension Font {
    static let pkTitle      = Font.system(size: 36, weight: .black, design: .rounded)
    static let pkSubtitle   = Font.system(size: 17, weight: .heavy, design: .rounded)
    static let pkBody       = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let pkKey        = Font.system(size: 18, weight: .bold, design: .monospaced)
    static let pkBlank      = Font.system(size: 22, weight: .heavy, design: .monospaced)
}

/// Applies the sticker look: rounded rect, 3pt black stroke, hard-edged drop shadow.
struct StickerModifier: ViewModifier {
    var fill: Color = .white
    var cornerRadius: CGFloat = 12
    var strokeWidth: CGFloat = 3
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.pkInk, lineWidth: strokeWidth)
            )
            .shadow(color: .pkInk, radius: 0, x: shadowOffset, y: shadowOffset)
    }
}

extension View {
    func sticker(fill: Color = .white,
                 cornerRadius: CGFloat = 12,
                 strokeWidth: CGFloat = 3,
                 shadowOffset: CGFloat = 4) -> some View {
        modifier(StickerModifier(fill: fill,
                                 cornerRadius: cornerRadius,
                                 strokeWidth: strokeWidth,
                                 shadowOffset: shadowOffset))
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: exit code 0.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/Theme.swift
git commit -m "Add Theme: colors, fonts, sticker view modifier"
```

---

## Task 16: StickerButton component

**Files:**
- Create: `Pictok/Views/Components/StickerButton.swift`

- [ ] **Step 1: Implement `StickerButton.swift`**

Create `Pictok/Views/Components/StickerButton.swift`:

```swift
import SwiftUI

struct StickerButton: View {
    let title: String
    var fill: Color = .pkYellow
    var icon: String? = nil
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Text(icon) }
                Text(title)
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .sticker(fill: fill, cornerRadius: 14, strokeWidth: 3,
                 shadowOffset: pressed ? 1 : 4)
        .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StickerButton(title: "Share", icon: "📤") {}
        StickerButton(title: "How to Play", icon: "💡", fill: .pkGreen) {}
        StickerButton(title: "Continue", fill: .pkRed) {}
    }
    .padding()
    .background(Color.pkPaper)
}
```

- [ ] **Step 2: Verify in SwiftUI preview**

Open `StickerButton.swift` in Xcode. Press **⌘⌥↩** to refresh preview. Confirm three buttons render with the sticker look.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/Components/StickerButton.swift
git commit -m "Add StickerButton component with press-down sticker animation"
```

---

## Task 17: EmojiHeader component

**Files:**
- Create: `Pictok/Views/Components/EmojiHeader.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/Components/EmojiHeader.swift`:

```swift
import SwiftUI

struct EmojiHeader: View {
    let emoji: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .sticker(fill: .white, cornerRadius: 20, strokeWidth: 3, shadowOffset: 5)
    }
}

#Preview {
    EmojiHeader(emoji: "🌃🦇🤡")
        .padding()
        .background(Color.pkPaper)
}
```

- [ ] **Step 2: Verify build + preview renders**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/Components/EmojiHeader.swift
git commit -m "Add EmojiHeader component"
```

---

## Task 18: CategoryChip component

**Files:**
- Create: `Pictok/Views/Components/CategoryChip.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/Components/CategoryChip.swift`:

```swift
import SwiftUI

struct CategoryChip: View {
    let category: Category
    var subcategory: String? = nil   // shown only if reveal-category hint was used

    var body: some View {
        HStack(spacing: 6) {
            Text(category.icon)
            Text(displayText)
                .font(.pkBody)
                .foregroundStyle(Color.pkInk)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sticker(fill: .pkGreen, cornerRadius: 10, strokeWidth: 2, shadowOffset: 2)
    }

    private var displayText: String {
        if let sub = subcategory {
            return "\(category.rawValue) · \(sub)"
        }
        return category.rawValue
    }
}

#Preview {
    VStack {
        CategoryChip(category: .movie)
        CategoryChip(category: .movie, subcategory: "Action · 2008")
    }
    .padding()
    .background(Color.pkPaper)
}
```

- [ ] **Step 2: Commit**

```bash
git add Pictok/Views/Components/CategoryChip.swift
git commit -m "Add CategoryChip component"
```

---

## Task 19: HeartsRow component

**Files:**
- Create: `Pictok/Views/Components/HeartsRow.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/Components/HeartsRow.swift`:

```swift
import SwiftUI

struct HeartsRow: View {
    let remaining: Int
    let total: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Text(i < remaining ? "❤️" : "🖤")
                    .font(.system(size: 18))
            }
        }
        .accessibilityLabel("\(remaining) of \(total) lives remaining")
    }
}

#Preview {
    VStack {
        HeartsRow(remaining: 5)
        HeartsRow(remaining: 3)
        HeartsRow(remaining: 0)
    }
    .padding()
    .background(Color.pkPaper)
}
```

- [ ] **Step 2: Commit**

```bash
git add Pictok/Views/Components/HeartsRow.swift
git commit -m "Add HeartsRow component with accessibility label"
```

---

## Task 20: BlanksView component

**Files:**
- Create: `Pictok/Views/Components/BlanksView.swift`

Renders the answer as `L _ O N` style slots. Letters revealed = visible. Non-letter chars (spaces, hyphens) are always visible. Word breaks render as wider gaps.

- [ ] **Step 1: Implement**

Create `Pictok/Views/Components/BlanksView.swift`:

```swift
import SwiftUI

struct BlanksView: View {
    let answer: String                   // "THE DARK KNIGHT"
    let revealedLetters: Set<Character>  // correct guesses ∪ revealed-by-hint

    var body: some View {
        let words = answer.split(separator: " ", omittingEmptySubsequences: false)
        return VStack(spacing: 8) {
            ForEach(0..<words.count, id: \.self) { wIndex in
                HStack(spacing: 6) {
                    ForEach(Array(words[wIndex].enumerated()), id: \.offset) { (_, ch) in
                        slot(for: ch)
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func slot(for ch: Character) -> some View {
        if !ch.isLetter {
            // Punctuation, numerals — always shown.
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
        } else if revealedLetters.contains(ch) {
            Text(String(ch))
                .font(.pkBlank)
                .foregroundStyle(Color.pkInk)
                .frame(width: 22)
                .overlay(Rectangle().fill(Color.pkInk).frame(height: 3).offset(y: 14))
        } else {
            Text(" ")
                .font(.pkBlank)
                .frame(width: 22)
                .overlay(Rectangle().fill(Color.pkInk).frame(height: 3).offset(y: 14))
        }
    }

    private var accessibilityText: String {
        let mapped = answer.map { ch -> String in
            if !ch.isLetter { return String(ch) }
            return revealedLetters.contains(ch) ? String(ch) : "blank"
        }
        return mapped.joined(separator: " ")
    }
}

#Preview {
    VStack(spacing: 20) {
        BlanksView(answer: "THE DARK KNIGHT", revealedLetters: ["E"])
        BlanksView(answer: "BILLIE JEAN", revealedLetters: ["L", "E"])
    }
    .padding()
    .background(Color.pkPaper)
}
```

- [ ] **Step 2: Commit**

```bash
git add Pictok/Views/Components/BlanksView.swift
git commit -m "Add BlanksView component (letter slots with underscores)"
```

---

## Task 21: KeyboardView component

**Files:**
- Create: `Pictok/Views/Components/KeyboardView.swift`

QWERTY rows. Letters get dimmed + strike-through once guessed. No "likely letter" coloring — guessed vs. not-guessed only.

- [ ] **Step 1: Implement**

Create `Pictok/Views/Components/KeyboardView.swift`:

```swift
import SwiftUI

struct KeyboardView: View {
    let guessed: Set<Character>           // both correct and wrong guesses
    let onTap: (Character) -> Void

    private static let rows: [[Character]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<Self.rows.count, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(Self.rows[r], id: \.self) { letter in
                        key(letter)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func key(_ letter: Character) -> some View {
        let isGuessed = guessed.contains(letter)
        Button {
            guard !isGuessed else { return }
            onTap(letter)
        } label: {
            Text(String(letter))
                .font(.pkKey)
                .foregroundStyle(isGuessed ? Color.pkInk.opacity(0.3) : Color.pkInk)
                .strikethrough(isGuessed)
                .frame(width: 30, height: 38)
        }
        .buttonStyle(.plain)
        .sticker(fill: isGuessed ? Color.pkPaper : .white,
                 cornerRadius: 6,
                 strokeWidth: 2,
                 shadowOffset: isGuessed ? 0 : 2)
        .accessibilityLabel("\(letter)\(isGuessed ? ", already guessed" : "")")
    }
}

#Preview {
    KeyboardView(guessed: ["E", "T", "Z"]) { _ in }
        .padding()
        .background(Color.pkPaper)
}
```

- [ ] **Step 2: Commit**

```bash
git add Pictok/Views/Components/KeyboardView.swift
git commit -m "Add KeyboardView: QWERTY keys with guessed-state styling"
```

---

# Phase 5 — Screens

## Task 22: TodayView — the main game screen

**Files:**
- Create: `Pictok/Views/TodayView.swift`

This is the largest view. It owns the game loop: lay out the components, dispatch keyboard taps into the store, surface the hint button, and present the result sheet when puzzle ends.

- [ ] **Step 1: Implement**

Create `Pictok/Views/TodayView.swift`:

```swift
import SwiftUI

struct TodayView: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle?            // nil = no puzzle for today (out-of-bundle date)
    let puzzleNumber: Int          // 1-based, passed from PictokApp (via loader)
    let onSolveOrFail: () async -> Void   // triggers notification reschedule

    @State private var showHintMenu = false
    @State private var showResult   = false
    @State private var showHowToPlay = false
    @State private var showPermissionPrompt = false

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()

            if let puzzle {
                content(for: puzzle)
            } else {
                Text("No puzzle for today — check back tomorrow.")
                    .font(.pkSubtitle)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .sheet(isPresented: $showResult) {
            if let puzzle {
                ResultSheet(store: store, puzzle: puzzle, puzzleNumber: puzzleNumber)
            }
        }
        .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
        .sheet(isPresented: $showPermissionPrompt) {
            NotificationPermissionSheet(store: store)
        }
    }

    @ViewBuilder
    private func content(for puzzle: Puzzle) -> some View {
        VStack(spacing: 16) {
            topBar
            EmojiHeader(emoji: puzzle.emoji)
            CategoryChip(category: puzzle.category,
                         subcategory: revealedSubcategory(for: puzzle))
            BlanksView(answer: puzzle.answer,
                       revealedLetters: revealedLetters(for: puzzle))
            Spacer(minLength: 0)
            KeyboardView(guessed: guessedLetters) { letter in
                handleGuess(letter, in: puzzle)
            }
        }
        .padding()
        .task {
            // First-time-app entry today: link store to this puzzle.
            if store.state.todayPuzzleId != puzzle.id {
                resetTodayState(for: puzzle.id)
            }
            store.refillLives()
            store.save()
            // If puzzle already finished, surface the result sheet.
            if store.state.todaySolved || store.state.todayFailed {
                showResult = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            HeartsRow(remaining: store.state.lives)
            Spacer()
            Button { showHintMenu = true } label: { Text("💡").font(.system(size: 26)) }
                .disabled(store.state.todayHintUsed != nil || store.state.todaySolved || store.state.todayFailed)
                .confirmationDialog("Pick a hint", isPresented: $showHintMenu) {
                    Button("Reveal category (−1 ❤️)") { useHint(.category) }
                        .disabled(store.state.lives < 1)
                    Button("Reveal a letter (−2 ❤️)") { useHint(.letter) }
                        .disabled(store.state.lives < 2)
                    Button("Cancel", role: .cancel) {}
                }
            Button { showHowToPlay = true } label: { Text("⚙️").font(.system(size: 24)) }
        }
    }

    // MARK: Derived

    private var guessedLetters: Set<Character> {
        Set(store.state.todayWrongGuesses + store.state.todayCorrectGuesses)
    }

    private func revealedLetters(for puzzle: Puzzle) -> Set<Character> {
        var set = Set(store.state.todayCorrectGuesses)
        if let r = store.state.todayRevealedLetter { set.insert(r) }
        if store.state.todaySolved || store.state.todayFailed {
            set.formUnion(puzzle.answer.filter { $0.isLetter })
        }
        return set
    }

    private func revealedSubcategory(for puzzle: Puzzle) -> String? {
        store.state.todayHintUsed == .category ? puzzle.subcategory : nil
    }

    // MARK: Actions

    private func resetTodayState(for puzzleId: String) {
        store.state.todayPuzzleId = puzzleId
        store.state.todayWrongGuesses = []
        store.state.todayCorrectGuesses = []
        store.state.todayHintUsed = nil
        store.state.todayRevealedLetter = nil
        store.state.todaySolved = false
        store.state.todayFailed = false
    }

    private func handleGuess(_ letter: Character, in puzzle: Puzzle) {
        guard !store.state.todaySolved, !store.state.todayFailed else { return }
        let correct = GameEngine.isCorrect(letter: letter, in: puzzle)
        if correct {
            store.state.todayCorrectGuesses.append(letter)
            HapticsService.correct()
            SoundService.shared.play(.correct)
        } else {
            store.state.todayWrongGuesses.append(letter)
            store.state.lives -= 1
            HapticsService.wrong()
            SoundService.shared.play(.wrong)
        }
        checkEndState(for: puzzle)
        store.save()
    }

    private func useHint(_ hint: HintType) {
        guard store.state.todayHintUsed == nil else { return }
        let cost = GameEngine.heartCost(for: hint)
        guard store.state.lives >= cost else { return }
        store.state.lives -= cost
        store.state.todayHintUsed = hint
        if hint == .letter, let puzzle = currentPuzzleSnapshot() {
            store.state.todayRevealedLetter = GameEngine.letterToReveal(
                for: puzzle,
                correctGuesses: Set(store.state.todayCorrectGuesses)
            )
        }
        checkEndState(for: currentPuzzleSnapshot())
        store.save()
    }

    private func currentPuzzleSnapshot() -> Puzzle? { puzzle }

    private func checkEndState(for puzzle: Puzzle?) {
        guard let puzzle else { return }
        let revealed = Set(store.state.todayCorrectGuesses)
        if GameEngine.isSolved(answer: puzzle.answer,
                               correctGuesses: revealed,
                               revealedLetter: store.state.todayRevealedLetter) {
            store.state.todaySolved = true
            applySolveSideEffects(for: puzzle)
            HapticsService.solved()
            SoundService.shared.play(.win)
            showResult = true
            Task { await onSolveOrFail() }
        } else if GameEngine.isFailed(lives: store.state.lives) {
            store.state.todayFailed = true
            applyFailSideEffects()
            HapticsService.failed()
            showResult = true
            Task { await onSolveOrFail() }
        }
    }

    private func applySolveSideEffects(for puzzle: Puzzle) {
        let today = PuzzleLoader.dateString(for: Date(), timeZone: .current)
        let next = GameEngine.streakAfterSolve(
            today: today,
            lastSolvedDate: store.state.lastSolvedDate,
            currentStreak: store.state.currentStreak,
            streakFreezesAvailable: store.state.streakFreezesAvailable
        )
        store.state.currentStreak = next.streak
        store.state.streakFreezesAvailable = next.freezesAvailable
        store.state.longestStreak = max(store.state.longestStreak, next.streak)
        store.state.lastSolvedDate = today
        store.state.totalSolved += 1
        store.state.totalPlayed += 1
        let wrongs = store.state.todayWrongGuesses.count
        store.state.guessDistribution[wrongs, default: 0] += 1

        // First-ever solve → arm the contextual notification permission prompt
        if !store.state.hasEverSolved {
            store.state.hasEverSolved = true
            if !store.state.hasAskedForNotificationPermission {
                showPermissionPrompt = true
            }
        }
    }

    private func applyFailSideEffects() {
        store.state.currentStreak = GameEngine.streakAfterFail(currentStreak: store.state.currentStreak)
        store.state.totalPlayed += 1
    }
}
```

- [ ] **Step 2: Verify build succeeds**

`ResultSheet`, `HowToPlayView`, and `NotificationPermissionSheet` are referenced but not yet implemented. Add temporary stubs so the build passes — we'll fill them in next tasks.

Create temporary file `Pictok/Views/_Stubs.swift` (will be deleted in Task 25):

```swift
import SwiftUI

struct ResultSheet: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle
    var body: some View { Text("Result – stub") }
}

struct HowToPlayView: View {
    var body: some View { Text("How to play – stub") }
}

struct NotificationPermissionSheet: View {
    @Bindable var store: UserStateStore
    var body: some View { Text("Permission – stub") }
}
```

Now:

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/TodayView.swift Pictok/Views/_Stubs.swift
git commit -m "Add TodayView: hangman game loop + state wiring (stubs for child sheets)"
```

---

## Task 23: ResultSheet — solve/fail modal with share

**Files:**
- Create: `Pictok/Views/ResultSheet.swift`
- Modify: `Pictok/Views/_Stubs.swift` (remove ResultSheet stub)

- [ ] **Step 1: Replace stub with real implementation**

Delete the `ResultSheet` struct from `Pictok/Views/_Stubs.swift`. Create `Pictok/Views/ResultSheet.swift`:

```swift
import SwiftUI

struct ResultSheet: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle
    let puzzleNumber: Int     // passed in from parent (computed via PuzzleLoader.puzzleNumber(for:))
    @Environment(\.dismiss) private var dismiss

    private var solved: Bool { store.state.todaySolved }

    var body: some View {
        VStack(spacing: 20) {
            Text(solved ? "Solved!" : "Today got you 🥲")
                .font(.pkTitle)
                .padding(.top, 12)

            Text(puzzle.answer)
                .font(.pkSubtitle)
                .multilineTextAlignment(.center)

            CategoryChip(category: puzzle.category, subcategory: puzzle.subcategory)

            HStack(spacing: 24) {
                stat("Wrong", value: "\(store.state.todayWrongGuesses.count)")
                stat("❤️ left", value: "\(store.state.lives)")
                stat("Hint", value: store.state.todayHintUsed == nil ? "—" : "✓")
                stat("🔥", value: "\(store.state.currentStreak)")
            }

            Text(shareText)
                .font(.system(size: 14, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sticker(fill: .white, cornerRadius: 12, strokeWidth: 2, shadowOffset: 3)

            HStack(spacing: 12) {
                StickerButton(title: "Copy", icon: "📋", fill: .pkYellow) {
                    UIPasteboard.general.string = shareText
                }
                ShareLink(item: shareText) {
                    HStack(spacing: 8) {
                        Text("📤")
                        Text("Share").font(.pkSubtitle).foregroundStyle(Color.pkInk)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
                .sticker(fill: .pkGreen, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
            }

            Text(countdownText)
                .font(.pkBody)
                .foregroundStyle(.gray)
                .padding(.top, 4)

            Spacer()
        }
        .padding()
        .background(Color.pkPaper)
        .presentationDetents([.medium, .large])
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack {
            Text(value).font(.pkSubtitle)
            Text(label).font(.pkBody).foregroundStyle(.gray)
        }
    }

    private var shareText: String {
        if solved {
            return ShareCardBuilder.successCard(
                puzzleNumber: puzzleNumber,
                category: puzzle.category,
                difficulty: puzzle.difficulty,
                heartsRemaining: store.state.lives,
                hintUsed: store.state.todayHintUsed != nil,
                currentStreak: store.state.currentStreak,
                url: "pictok.app"
            )
        } else {
            // For failure, "previous streak" is the streak before fail reset.
            let prior = max(store.state.longestStreak, 0)
            return ShareCardBuilder.failureCard(
                puzzleNumber: puzzleNumber,
                category: puzzle.category,
                difficulty: puzzle.difficulty,
                previousStreak: prior,
                url: "pictok.app"
            )
        }
    }

    private var countdownText: String {
        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let interval = tomorrow.timeIntervalSince(now)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "Next puzzle in \(h)h \(m)m"
    }
}
```

- [ ] **Step 2: Remove the ResultSheet stub from `_Stubs.swift`**

Edit `Pictok/Views/_Stubs.swift` so only the other two stubs remain.

- [ ] **Step 3: Verify build**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

- [ ] **Step 4: Commit**

```bash
git add Pictok/Views/ResultSheet.swift Pictok/Views/_Stubs.swift
git commit -m "Add ResultSheet with share/copy buttons and countdown"
```

---

## Task 24: NotificationPermissionSheet

**Files:**
- Create: `Pictok/Views/NotificationPermissionSheet.swift`
- Modify: `Pictok/Views/_Stubs.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/NotificationPermissionSheet.swift`:

```swift
import SwiftUI
import UserNotifications

struct NotificationPermissionSheet: View {
    @Bindable var store: UserStateStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🔥")
                .font(.system(size: 96))

            Text("Keep your streak alive")
                .font(.pkTitle)
                .multilineTextAlignment(.center)

            Text("Want a daily reminder so you don't lose your streak? We'll send one ping at 9 AM.")
                .font(.pkBody)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            StickerButton(title: "Yes, remind me", icon: "📌", fill: .pkGreen) {
                Task { await requestPermission() }
            }
            .padding(.horizontal)

            Button("No thanks") {
                store.state.hasAskedForNotificationPermission = true
                store.save()
                dismiss()
            }
            .foregroundStyle(.gray)
            .padding(.bottom, 24)
        }
        .padding()
        .background(Color.pkPaper)
        .presentationDetents([.medium])
    }

    private func requestPermission() async {
        store.state.hasAskedForNotificationPermission = true
        store.save()
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        dismiss()
    }
}
```

- [ ] **Step 2: Remove the stub from `_Stubs.swift`**

Edit `Pictok/Views/_Stubs.swift` so only `HowToPlayView` remains.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/NotificationPermissionSheet.swift Pictok/Views/_Stubs.swift
git commit -m "Add NotificationPermissionSheet shown after first solve"
```

---

## Task 25: HowToPlayView

**Files:**
- Create: `Pictok/Views/HowToPlayView.swift`
- Delete: `Pictok/Views/_Stubs.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/HowToPlayView.swift`:

```swift
import SwiftUI

struct HowToPlayView: View {
    @State private var page = 0
    @Environment(\.dismiss) private var dismiss

    private let pages: [(emoji: String, title: String, body: String, fill: Color)] = [
        ("📌", "One puzzle a day",
         "A new emoji puzzle drops every day. Movies, songs, books, brands, celebs.",
         .pkYellow),
        ("❤️", "Five hearts, no mercy",
         "Each wrong letter costs a heart. Out of hearts = puzzle locked until tomorrow.",
         .pkRed),
        ("🔥", "Keep the streak alive",
         "Solve daily to build your streak. Share your result spoiler-free. Brag responsibly.",
         .pkGreen),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    let p = pages[i]
                    VStack(spacing: 20) {
                        Text(p.emoji).font(.system(size: 96))
                        Text(p.title).font(.pkTitle)
                        Text(p.body).font(.pkBody).multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .tag(i)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(p.fill.opacity(0.25))
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            StickerButton(title: page < pages.count - 1 ? "Next" : "Start playing",
                          fill: .pkBlue) {
                if page < pages.count - 1 { page += 1 } else { dismiss() }
            }
            .padding(.bottom, 24)
        }
        .background(Color.pkPaper)
    }
}
```

- [ ] **Step 2: Delete `Pictok/Views/_Stubs.swift`**

```bash
rm Pictok/Views/_Stubs.swift
```

In Xcode: right-click `_Stubs.swift` in the left sidebar → **Delete** → **Move to Trash** (to remove from project file too).

- [ ] **Step 3: Verify build**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

- [ ] **Step 4: Commit**

```bash
git add Pictok/Views/HowToPlayView.swift Pictok.xcodeproj
git rm Pictok/Views/_Stubs.swift
git commit -m "Add HowToPlayView (3-page onboarding) and remove placeholder stubs"
```

---

## Task 26: StatsView

**Files:**
- Create: `Pictok/Views/StatsView.swift`

- [ ] **Step 1: Implement**

Create `Pictok/Views/StatsView.swift`:

```swift
import SwiftUI
import Charts

struct StatsView: View {
    @Bindable var store: UserStateStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Stats").font(.pkTitle).padding(.top, 12)

                HStack(spacing: 16) {
                    statTile("🔥 Streak", "\(store.state.currentStreak)")
                    statTile("Best", "\(store.state.longestStreak)")
                }
                HStack(spacing: 16) {
                    statTile("Solved", "\(store.state.totalSolved)")
                    statTile("Win %", winPercentText)
                }

                Text("Guess distribution").font(.pkSubtitle).padding(.top)
                distributionChart
            }
            .padding()
        }
        .background(Color.pkPaper)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.pkTitle)
            Text(label).font(.pkBody).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .sticker(fill: .white, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
    }

    private var winPercentText: String {
        guard store.state.totalPlayed > 0 else { return "—" }
        let pct = Int(round(Double(store.state.totalSolved) / Double(store.state.totalPlayed) * 100))
        return "\(pct)%"
    }

    private var distributionChart: some View {
        let dist = store.state.guessDistribution
        let maxKey = (dist.keys.max() ?? 0)
        let buckets = (0...max(5, maxKey)).map { ($0, dist[$0] ?? 0) }

        return Chart {
            ForEach(buckets, id: \.0) { bucket in
                BarMark(
                    x: .value("Wrong", "\(bucket.0)"),
                    y: .value("Count", bucket.1)
                )
                .foregroundStyle(Color.pkGreen)
                .cornerRadius(4)
            }
        }
        .frame(height: 180)
        .padding()
        .sticker(fill: .white, cornerRadius: 14, strokeWidth: 3, shadowOffset: 4)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Note: `Charts` is built-in on iOS 16+.

- [ ] **Step 3: Commit**

```bash
git add Pictok/Views/StatsView.swift
git commit -m "Add StatsView with streak tiles + guess distribution chart"
```

---

# Phase 6 — App wire-up

## Task 27: PictokApp — root + tab bar + lifecycle hooks

**Files:**
- Modify: `Pictok/PictokApp.swift`

- [ ] **Step 1: Replace placeholder with real root**

Replace contents of `Pictok/PictokApp.swift`:

```swift
import SwiftUI

@main
struct PictokApp: App {
    @State private var store = UserStateStore()
    @State private var loader: PuzzleLoader? = nil
    @State private var loadError: String? = nil
    private let scheduler = NotificationScheduler()

    var body: some Scene {
        WindowGroup {
            RootView(store: store, loader: loader, loadError: loadError) {
                await rescheduleNotification()
            }
            .task { setup() }
            .onChange(of: scenePhase) { _, new in
                if new == .active { Task { await rescheduleNotification() } }
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private func setup() {
        do {
            loader = try PuzzleLoader.bundled()
            loadError = nil
        } catch {
            loadError = "Failed to load puzzles: \(error.localizedDescription)"
        }
        store.refillLives()
        store.save()
        Task { await rescheduleNotification() }
    }

    private func rescheduleNotification() async {
        let solvedToday = store.state.todaySolved &&
            store.state.todayPuzzleId == PuzzleLoader.dateString(for: Date())
        if solvedToday {
            await scheduler.cancelDailyReminder()
        }
        await scheduler.scheduleDailyReminderIfNeeded(
            now: Date(),
            alreadySolvedToday: solvedToday
        )
    }
}

struct RootView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader?
    let loadError: String?
    let onSolveOrFail: () async -> Void

    var body: some View {
        if let loader {
            let todays = loader.puzzle(for: Date())
            TabView {
                TodayView(
                    store: store,
                    puzzle: todays,
                    puzzleNumber: todays.map { loader.puzzleNumber(for: $0) } ?? 1,
                    onSolveOrFail: onSolveOrFail
                )
                .tabItem { Label("Today", systemImage: "calendar") }

                StatsView(store: store)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
            }
            .tint(.pkBlue)
        } else if let loadError {
            VStack(spacing: 12) {
                Text("⚠️").font(.system(size: 64))
                Text(loadError).font(.pkBody).multilineTextAlignment(.center).padding()
            }
        } else {
            ProgressView().background(Color.pkPaper)
        }
    }
}
```

- [ ] **Step 2: Verify the simulator launches with a real puzzle**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Press **⌘R** in Xcode. The app should open to the Today tab showing today's puzzle (or the "no puzzle for today" fallback if outside the bundled 60-day range).

- [ ] **Step 3: Commit**

```bash
git add Pictok/PictokApp.swift
git commit -m "Wire up PictokApp root: tab bar, puzzle loader, notification reschedule on foreground"
```

---

# Phase 7 — Assets

## Task 28: App icon (user-blocking)

**Files:**
- Modify: `Pictok/Resources/Assets.xcassets/AppIcon.appiconset/`

- [ ] **Step 1: Brief the user on the icon design**

Designer/user needs to produce one 1024×1024 PNG, named `AppIcon-1024.png`, matching:

- Cream paper background (`#FEF3D9`)
- Centered chunky `📌` motif as the focal element, OR a hand-drawn "PT" wordmark
- Solid black 3pt stroke around the focal element
- Hard-edged black drop shadow offset down-right
- No transparency — opaque background required

Reference: spec §2 (Visual style) and the sticker mockups from brainstorming.

- [ ] **Step 2: Add to Xcode**

In Xcode: open `Assets.xcassets` → click `AppIcon` set → drag the 1024×1024 PNG into the "App Store" slot.

iOS 17+ accepts a single 1024×1024 icon — no need for the 30+ legacy sizes.

- [ ] **Step 3: Set the asset name in target**

Project settings → Pictok target → **General** → **App Icons and Launch Screen** → confirm "AppIcon" is selected.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

Run in simulator. Long-press app icon to see it on the home screen.

- [ ] **Step 5: Commit**

```bash
git add Pictok/Resources/Assets.xcassets
git commit -m "Add app icon (sticker pin motif)"
```

---

## Task 29: Sound effects

**Files:**
- Create: `Pictok/Resources/Sounds/correct.wav`
- Create: `Pictok/Resources/Sounds/wrong.wav`
- Create: `Pictok/Resources/Sounds/win.wav`

- [ ] **Step 1: Source three royalty-free sound effects**

Recommended sources (free, CC0 / no attribution required):
- https://freesound.org (filter by CC0)
- https://pixabay.com/sound-effects
- https://mixkit.co/free-sound-effects/game

Pick three short clips (< 1 second each):
- `correct.wav` — soft pop or chime for a correct letter
- `wrong.wav` — gentle thud or low buzz for a wrong letter
- `win.wav` — quick triumphant flourish for solve

Convert to 16-bit PCM mono WAV at 44.1 kHz (use Audacity if needed — File → Export Audio).

- [ ] **Step 2: Add to Xcode bundle**

Drag the three `.wav` files into the `Resources/Sounds/` group in Xcode. Make sure **Pictok** target checkbox is ticked in the dialog.

- [ ] **Step 3: Smoke test in the simulator**

Run the app, make one correct and one wrong guess. Confirm sounds play (if device sound is on).

- [ ] **Step 4: Commit**

```bash
git add Pictok/Resources/Sounds
git commit -m "Add royalty-free sound effects (correct, wrong, win)"
```

---

# Phase 8 — Manual QA + ship

## Task 30: Manual QA matrix

**Files:** none — exploratory testing.

- [ ] **Step 1: Solve flow (happy path)**

In the simulator:
- Open app cold. Today's puzzle shows.
- Tap correct letters. Confirm hearts don't decrement, slots fill in, correct haptic + sound fires.
- Solve the puzzle. Confetti-equivalent celebration plays. Result sheet appears with the share card.
- Tap **Copy**. In the simulator menu: **Edit → Paste** anywhere — confirm clipboard has the share card text.
- Tap **Share**. iOS share sheet opens. Cancel.
- Close the sheet. Background the app. Reopen. The Today screen now shows the result-locked state with countdown.

- [ ] **Step 2: Fail flow**

- Reset the simulator (Device → Erase All Content and Settings) or delete the app to clear state.
- Open fresh. Deliberately guess 5 wrong letters. Confirm failure sheet shows. Streak should display as 0.

- [ ] **Step 3: Mid-puzzle resume**

- Reset state. Start a puzzle, guess a few letters, then home-button to background.
- Re-open the app. All guesses, lives, and revealed letters should be preserved.

- [ ] **Step 4: Streak day-skip and freeze**

- Reset state. Set the device clock forward day by day in simulator (Features → Date and Time? — actually the simulator uses host time; manipulate via `Settings → General → Date & Time` inside the simulator, disabling auto-set).
- Solve consecutive days. Verify streak counter increments.
- Skip exactly one day → solve. Verify streak freezes (advances to next + freeze consumed).
- Skip two days → solve. Verify streak resets to 1.

⚠️ Note: simulators clamp local notification fire times to host time; manipulating only the in-app date won't fire push notifications. This is acceptable for streak QA but not for notification QA — see next step.

- [ ] **Step 5: Lives refill**

- Reset state. Burn all 5 hearts.
- Quit + relaunch the app immediately. Lives should still be 0.
- Advance the simulator clock 4 hours forward. Quit + relaunch. Lives should now be 1.

- [ ] **Step 6: Share card variants**

Verify all three variants by reaching them in normal play:
- Success without hint → hearts bar shows hint-mark missing.
- Success with hint → 💡 marker appears.
- Failure → 🥲 framing and streak `N → 0`.

- [ ] **Step 7: Notifications (real device required)**

In Xcode: change run target from simulator to a real connected iPhone. Run the app.
- Solve a puzzle for the first time. Permission sheet appears. Approve.
- Force quit the app. iOS lock screen.
- Set device clock forward to next 9 AM. Confirm notification fires with the expected copy.
- Tap notification. App launches to Today screen.
- Reset state, solve before 9 AM. Confirm next-day's notification fires (not today's).

- [ ] **Step 8: VoiceOver smoke test**

In Settings → Accessibility → VoiceOver, enable it. Open the app.
- Swipe through the Today screen. Confirm hearts row reads "N of 5 lives remaining."
- Confirm keyboard keys read their letter (and "already guessed" for greyed ones).
- Confirm blanks read aloud as "T H E space blank A blank K blank K blank I blank H T".

- [ ] **Step 9: Capture findings**

Open `docs/superpowers/QA-notes.md` (create if missing) and list any bugs found. For each:
- Reproduction steps
- Expected vs actual
- Severity (blocker / major / minor / polish)

- [ ] **Step 10: Fix blockers, defer minors**

Address any blocker-severity bugs found above. Commit fixes with descriptive messages. Minor and polish items go into a "v1.0.1" backlog at the bottom of `QA-notes.md`.

- [ ] **Step 11: Commit QA notes**

```bash
git add docs/superpowers/QA-notes.md
git commit -m "Capture v1 manual QA notes and v1.0.1 backlog"
```

---

## Task 31: TestFlight + App Store submission prep

**Files:** Apple Developer portal + App Store Connect (no code changes).

- [ ] **Step 1: Apple Developer account setup**

Sign in at https://developer.apple.com. You need an active paid membership ($99/year) to submit to App Store / TestFlight. Personal team accounts allow simulator/device builds only.

- [ ] **Step 2: Bundle identifier**

In Xcode project settings → Pictok target → Signing & Capabilities → set Bundle Identifier to a unique reverse-DNS string like `com.yourname.pictok`. Enable **Automatically manage signing**, select your team.

- [ ] **Step 3: Archive build**

In Xcode: Product → Destination → **Any iOS Device (arm64)**. Then **Product → Archive**. Wait for build to complete; the Organizer window opens.

- [ ] **Step 4: Validate**

In Organizer: select the archive → **Validate App** → follow prompts. Fix any validation warnings (most common: missing usage strings for permissions — `NSUserNotificationsUsageDescription` should already be set from Task 13).

- [ ] **Step 5: Upload to App Store Connect**

In Organizer: **Distribute App** → **App Store Connect** → **Upload** → follow prompts.

- [ ] **Step 6: Configure App Store listing**

In https://appstoreconnect.apple.com:
- Create a new app record (name: "Pictok", primary language English).
- Fill in app description, keywords, support URL, privacy policy URL.
- Upload screenshots (6.7" iPhone 15 Pro Max screenshots required; 5.5" optional).
- Set age rating (likely 4+).
- Set pricing (Free).
- Pick the uploaded build for TestFlight.

- [ ] **Step 7: Internal TestFlight build**

In App Store Connect → TestFlight tab → assign internal testers (your Apple ID + up to 99 others on your team). Send the invite link.

- [ ] **Step 8: External TestFlight (optional)**

Add an external test group (up to 10,000 testers). Each new build requires Apple Beta App Review (24–48h turnaround).

- [ ] **Step 9: Submit for App Store review**

Once TestFlight is stable (~1 week of internal testing per spec checklist), submit the build for App Store review. Typical turnaround: 24–72 hours.

- [ ] **Step 10: Commit any final config**

```bash
git add -A
git commit -m "Final release config for v1 App Store submission"
git tag v1.0.0
```

---

## Done

When all tasks above are checked, you have shipped Pictok v1. See spec §10 for v2/v3 roadmap items to plan next.
