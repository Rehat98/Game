# Pictok Web Version Design

**Date:** 2026-05-21
**Author:** Rehat + Claude
**Status:** Approved (scope locked via brainstorm: feature-parity, local-only state)
**Builds on:** All current iOS specs. Reuses `Pictok/Resources/puzzles.json` verbatim as the puzzle source.

## Background

The iOS app's share card links to `pictok.app`. For the share to drive virality, the recipient must be able to **play immediately** when they tap the link — not hit a "download the app on the App Store" wall. The web version is that destination: full-feature Pictok in the browser, no download required.

User decision (2026-05-21): build a feature-parity web app. Same 59 puzzles, same Daily / Endless / streak / share / stats mechanics, local-only state via `localStorage` (matches iOS's no-account model). Hosted statically; mobile-responsive; installable as a PWA so the experience is app-like on phones.

## Architecture

### Tech stack

- **HTML + CSS + vanilla JavaScript (ES2020+).** No framework, no build step.
- **Single static folder** at `web/` in the repo, deployable to any static host.
- **PWA manifest** (`web/manifest.webmanifest`) + service worker (`web/sw.js`) so visitors on mobile can "Add to Home Screen" and play offline.
- **No backend.** All game state lives in the player's browser via `localStorage`. Puzzles.json is loaded once at startup and cached by the service worker for offline play.

### File structure

```
web/
├── index.html              # The whole game shell — header, puzzle area, keyboard, modals
├── style.css               # Sticker aesthetic styling (mirrors iOS pkPaper/pkInk/etc.)
├── manifest.webmanifest    # PWA manifest with icon + display: standalone
├── sw.js                   # Service worker for offline puzzle caching
├── icon-192.png            # PWA icon (small)
├── icon-512.png            # PWA icon (large; reuses the Wordle-grid app icon design)
├── puzzles.json            # Symlinked or copied from Pictok/Resources/puzzles.json
└── js/
    ├── main.js             # Entry point — instantiates the game, wires DOM events
    ├── game-engine.js      # Port of GameEngine.swift (isCorrect, isSolved, isFailed,
    │                       #   letterToReveal, streakAfterSolve, streakAfterFail)
    ├── user-state.js       # localStorage-backed UserState (load, save, migrate)
    ├── puzzle-loader.js    # Date-keyed puzzle lookup (mirrors PuzzleLoader.bundled())
    ├── endless-session.js  # Endless mode orchestrator (mirrors EndlessSession.swift)
    ├── share.js            # Web Share API + clipboard fallback
    ├── celebration.js      # Win/fail celebration animations (Canvas fireworks/rain)
    └── stats.js            # Stats screen rendering + chart
```

Total: ~1500 lines of JS + ~400 lines of CSS estimated. Bundle size ≤ 60 KB gzipped.

### State model

`localStorage` key: `pictok.state.v1` (same identifier as iOS's UserDefaults key, intentional — if a future "import state" cross-platform feature is built, the schema is portable).

The JSON shape matches the iOS `UserState` exactly:

```js
{
  currentStreak: 0,
  longestStreak: 0,
  lastSolvedDate: null,
  streakFreezesAvailable: 1,
  totalSolved: 0,
  totalPlayed: 0,
  guessDistribution: {},
  lives: 5,
  todayPuzzleId: null,
  todayWrongGuesses: [],
  todayCorrectGuesses: [],
  todayHintUsed: null,
  todayRevealedLetter: null,
  todaySolved: false,
  todayFailed: false,
  hasEverSolved: false,
  hasAskedForNotificationPermission: false,
  solvedPuzzleIds: [],
  failedPuzzleIds: [],
  lifetimeSolvedCount: 0,
  recentEndlessIds: []
}
```

(Web won't use `hasAskedForNotificationPermission` since browser notifications need a different flow; the field is preserved in the schema for portability.)

### Game logic

Direct port of the post-revert iOS `GameEngine`:

- `isCorrect(letter, answer)` — letter ∈ answer (case-insensitive).
- `isSolved(answer, correctGuesses, revealedLetter)` — every letter in answer ∈ correctGuesses ∪ {revealedLetter}.
- `isFailed(lives)` — lives ≤ 0.
- `letterToReveal(answer, correctGuesses)` — first unguessed letter in answer.
- `heartCost(hint)` — `category: 1`, `letter: 2`.
- `streakAfterSolve(today, lastSolvedDate, currentStreak, streakFreezesAvailable)` — same +1 / freeze / reset rules.
- `streakAfterFail(currentStreak)` — returns 0.

Word-by-word reveal is NOT in scope (reverted on iOS; web matches).

### UI screens

| Screen | Purpose |
|---|---|
| Play (Today) | Today's Daily puzzle on top, "Continue Playing" button below. Mirrors `TodayView`. |
| Endless | Auto-queue Endless mode after tapping Continue Playing. Mirrors `EndlessView` with the new "Next puzzle →" gating. |
| Stats | Streak, lifetime count, win %, distribution chart. Mirrors the post-redesign `StatsView` (editorial cards). |
| Result sheet (Daily solve/fail) | Same modal as iOS — answer + Share button + countdown. |

Single-page app — no routing needed. Mode is tracked in JS state and the DOM swaps content sections.

### Sticker aesthetic in CSS

The iOS app's sticker style (offset hard shadow, thick stroke, rounded corners) translates directly to CSS:

```css
.sticker {
  background: #fff;
  border: 3px solid #1A1A1A;
  border-radius: 14px;
  box-shadow: 4px 4px 0 0 #1A1A1A;   /* hard offset, no blur */
}
```

Theme variables matching `Theme.swift`:

```css
:root {
  --pk-paper: #FEF3D9;
  --pk-ink: #1A1A1A;
  --pk-yellow: #FFD60A;
  --pk-red: #E63946;
  --pk-green: #06D6A0;
  --pk-blue: #118AB2;
}
```

Font: `system-ui` with weight 900 for headers (matches the rounded-design intent on iOS).

### Animations

- **Win celebration:** Canvas-rendered fireworks. Ports the `FireworksEmitter` logic — 6 burst origins, ~30 particles each, gravity-arcing trajectories, color cycle through pk-yellow/red/green/blue. 1.8s total.
- **Fail celebration:** Canvas-rendered rain. Ports `RainEmitter` — 40 slim blue drops falling for 2.8s.
- **Sound:** the four .wav files (`correct`, `wrong`, `win`, `fail`) ship in `web/sounds/`. Played via `Audio` API on user-triggered events (browsers require user-interaction-gated audio).

### Share

- Detect Web Share API (`navigator.share`) — on mobile browsers and Safari, opens the native share sheet directly with the same text as iOS.
- Fallback: copy-to-clipboard button + a toast confirming "Share text copied".
- Share text generated by a 1:1 JS port of `ShareCardBuilder.successCard` / `failureCard`, including the Unicode-bold "𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲?" line.

### Daily puzzle date logic

- Date string `YYYY-MM-DD` in the user's local timezone (matches iOS).
- `puzzleLoader.puzzleFor(date)` returns the puzzle whose `date` field matches.
- If no puzzle for today (e.g., date is beyond 2026-07-16, past the bundle), show a friendly "no puzzle today" state pointing the user to Endless.

### Hosting + domain

- **Repo path:** `web/` folder at the root, alongside `Pictok/`. Single repo, single source of truth.
- **Deploy target:** Cloudflare Pages connected to the GitHub repo. Builds happen on push to `main`; the `web/` directory is the published root.
- **Domain:** `pictok.app` (assumed available; if not yet registered, registration is a one-time prerequisite — Cloudflare Registrar or any registrar pointing nameservers to Cloudflare).
- **HTTPS:** Cloudflare provides free auto-issued cert once the domain is connected to Pages.
- **Service worker:** caches `puzzles.json`, the JS bundle, the CSS, the sound files, and the icon. After first visit the game works fully offline.

## Out of scope (v1.0 web)

- Cross-device sync between iOS and web (would need accounts + backend).
- Web push notifications for the daily reminder (browser permissions are intrusive; users can install as PWA + use OS-level notifications later).
- Multi-language UI.
- Achievements / leaderboards.
- Social login.
- Server-side puzzle ingestion or content updates without redeploy.
- Native ad / analytics tracking. (Cloudflare Web Analytics may be added separately if desired — privacy-respecting, no cookies.)

## Success criteria

1. `pictok.app` URL loads the game directly — no install gate.
2. Today's Daily puzzle is the same as the iOS app's Daily (same date → same puzzle).
3. Solve / fail flow with celebrations matches iOS feel.
4. Endless mode auto-queue with "Next puzzle →" gating works.
5. Stats persist across browser refreshes via `localStorage`.
6. Share button opens the native share sheet (mobile) or copies the share text (desktop).
7. Service worker caches assets; game playable offline after first visit.
8. PWA "Add to Home Screen" works on iOS Safari, Android Chrome.
9. Lighthouse Performance ≥ 90, Accessibility ≥ 95, Best Practices ≥ 90.
10. Total page weight (gzipped) ≤ 100 KB initial load.

## Open questions

None — all design decisions resolved.
