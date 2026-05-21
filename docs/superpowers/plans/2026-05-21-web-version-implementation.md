# Pictok Web Version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a feature-parity Pictok web app at `pictok.app` so iOS share links open into a playable browser game.

**Architecture:** Single static SPA in `web/`. Vanilla HTML + CSS + ES2020 JS, no build step. Pure-logic modules (game engine, state, selector, share text) ported 1:1 from Swift and unit-tested under Node's built-in test runner. UI modules orchestrate the DOM. Service worker caches assets for offline play. Deployed to Cloudflare Pages connected to the GitHub repo.

**Tech Stack:** HTML5, CSS3 (custom properties, no preprocessor), JavaScript ES2020 modules, Node 18+ built-in test runner (`node --test`), Cloudflare Pages, PWA manifest + service worker.

**Spec:** `docs/superpowers/specs/2026-05-21-web-version-design.md`

---

## File Structure

```
web/
├── index.html              # SPA shell — header, screen containers, modals
├── style.css               # Theme variables + sticker aesthetic + layout
├── package.json            # type:module + node --test scripts
├── manifest.webmanifest    # PWA manifest
├── sw.js                   # Service worker (cache-first static assets)
├── icon-192.png            # PWA icon (from iOS AppIcon source)
├── icon-512.png            # PWA icon (from iOS AppIcon source)
├── puzzles.json            # COPY of Pictok/Resources/puzzles.json
├── sync-puzzles.sh         # One-line script that re-copies puzzles.json + sounds
├── sounds/                 # COPY of Pictok/Resources/Sounds/*.wav
│   ├── correct.wav
│   ├── wrong.wav
│   ├── win.wav
│   └── fail.wav
├── js/
│   ├── main.js             # entry: bootstrap, screen routing, DOM event wiring
│   ├── ui.js               # DOM helpers + screen show/hide + toast
│   ├── game-engine.js      # PURE: isCorrect, isSolved, isFailed, heartCost,
│   │                       #       letterToReveal, streakAfterSolve, streakAfterFail
│   ├── user-state.js       # localStorage load/save + fresh()
│   ├── puzzle-loader.js    # fetch puzzles.json, dateString(date, tz), puzzleFor(date)
│   ├── endless-selector.js # PURE: 3-tier nextPuzzle algorithm + RNG injection
│   ├── endless-session.js  # mutable Endless session (hearts, guesses, submit, advance)
│   ├── today-session.js    # mutable Daily session (re-uses logic; persists to UserState.today*)
│   ├── share.js            # PURE successCard/failureCard + Web Share API + clipboard fallback
│   ├── celebration.js      # Canvas fireworks (win) + rain (fail) + sound playback
│   └── stats.js            # PURE stats math + DOM render of stats screen
└── tests/
    ├── game-engine.test.js
    ├── user-state.test.js
    ├── puzzle-loader.test.js
    ├── endless-selector.test.js
    ├── share.test.js
    └── stats.test.js
```

**Module dependency graph (lower depends on upper):**
```
game-engine, share, user-state, puzzle-loader (pure leaves)
        ↓
endless-selector (depends on user-state shape)
        ↓
endless-session, today-session (depend on engine + state + selector)
        ↓
celebration, stats (depend on session/state for input)
        ↓
ui (depends on all data layers)
        ↓
main (entry — wires everything together)
```

**Testing approach:** Node's built-in `node --test` runner. Pure-JS units (engine, state, selector, share, stats math, puzzle-loader) get unit tests. UI files (main.js, ui.js, celebration.js) are verified by manual browser QA at the end of each UI task.

---

## Task 1: Scaffold `web/` directory + Node test runner

**Files:**
- Create: `web/package.json`
- Create: `web/.gitignore`
- Create: `web/sync-puzzles.sh`
- Create: `web/puzzles.json` (copy of `Pictok/Resources/puzzles.json`)
- Create: `web/sounds/correct.wav` `wrong.wav` `win.wav` `fail.wav` (copies)
- Create: `web/tests/sanity.test.js`

- [ ] **Step 1: Create the web/ folder structure**

```bash
mkdir -p /Users/rehatchugh/emoji-decode/web/js /Users/rehatchugh/emoji-decode/web/tests /Users/rehatchugh/emoji-decode/web/sounds
```

Expected: directories created, no errors.

- [ ] **Step 2: Write `web/sync-puzzles.sh`**

```bash
#!/usr/bin/env bash
# Sync the web copy of puzzles.json and sounds from the iOS source of truth.
# Run after editing Pictok/Resources/puzzles.json or Pictok/Resources/Sounds/.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cp "$REPO_ROOT/Pictok/Resources/puzzles.json" "$SCRIPT_DIR/puzzles.json"
cp "$REPO_ROOT/Pictok/Resources/Sounds/"*.wav "$SCRIPT_DIR/sounds/"
echo "Synced $(jq length "$SCRIPT_DIR/puzzles.json" 2>/dev/null || echo '?') puzzles + $(ls "$SCRIPT_DIR/sounds/"*.wav | wc -l | tr -d ' ') sounds → web/"
```

Then make it executable: `chmod +x /Users/rehatchugh/emoji-decode/web/sync-puzzles.sh`

- [ ] **Step 3: Run the sync script to populate puzzles.json + sounds**

Run: `/Users/rehatchugh/emoji-decode/web/sync-puzzles.sh`
Expected: `Synced 59 puzzles + 4 sounds → web/`

- [ ] **Step 4: Write `web/package.json`**

```json
{
  "name": "pictok-web",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "scripts": {
    "test": "node --test tests/",
    "serve": "python3 -m http.server 8080"
  }
}
```

- [ ] **Step 5: Write `web/.gitignore`**

```
node_modules/
.DS_Store
```

- [ ] **Step 6: Write a sanity test to confirm `node --test` works**

`web/tests/sanity.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';

test('node test runner is wired', () => {
  assert.equal(1 + 1, 2);
});
```

- [ ] **Step 7: Run the sanity test**

Run: `cd /Users/rehatchugh/emoji-decode/web && npm test`
Expected output contains: `# pass 1` and exit code 0.

- [ ] **Step 8: Commit**

```bash
cd /Users/rehatchugh/emoji-decode
git add web/
git commit -m "web: scaffold static SPA folder, Node test runner, sync script"
```

---

## Task 2: Port GameEngine (pure logic)

**Files:**
- Create: `web/js/game-engine.js`
- Create: `web/tests/game-engine.test.js`

- [ ] **Step 1: Write failing tests for `isCorrect`**

`web/tests/game-engine.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as engine from '../js/game-engine.js';

test('isCorrect: letter in answer (case-insensitive)', () => {
  assert.equal(engine.isCorrect('T', 'TOY STORY'), true);
  assert.equal(engine.isCorrect('t', 'TOY STORY'), true);
  assert.equal(engine.isCorrect('Z', 'TOY STORY'), false);
});

test('isCorrect: ignores spaces and non-letters in answer', () => {
  assert.equal(engine.isCorrect(' ', 'TOY STORY'), false);
});
```

- [ ] **Step 2: Run to verify FAIL**

Run: `cd /Users/rehatchugh/emoji-decode/web && npm test`
Expected: FAIL with `Cannot find module ... game-engine.js`

- [ ] **Step 3: Implement `isCorrect`**

`web/js/game-engine.js`:
```js
// Mirrors Pictok/Game/GameEngine.swift. Keep this file pure — no DOM, no fetch.

const LETTER_RE = /^[A-Z]$/;

export function isCorrect(letter, answer) {
  const u = String(letter).toUpperCase();
  if (!LETTER_RE.test(u)) return false;
  return answer.toUpperCase().includes(u);
}
```

- [ ] **Step 4: Run, expect PASS for those two tests**

Run: `npm test`

- [ ] **Step 5: Add tests for `isSolved`**

Append to `web/tests/game-engine.test.js`:
```js
test('isSolved: all answer letters in correctGuesses', () => {
  const correct = new Set(['T','O','Y','S','R']);
  assert.equal(engine.isSolved('TOY STORY', correct, null), true);
});

test('isSolved: missing letter -> false', () => {
  const correct = new Set(['T','O','Y','S']);
  assert.equal(engine.isSolved('TOY STORY', correct, null), false);
});

test('isSolved: revealedLetter counts as known', () => {
  const correct = new Set(['T','O','Y','S']);
  assert.equal(engine.isSolved('TOY STORY', correct, 'R'), true);
});

test('isSolved: spaces in answer are ignored', () => {
  const correct = new Set(['A','B']);
  assert.equal(engine.isSolved('A B', correct, null), true);
});
```

- [ ] **Step 6: Run, expect FAIL**

Run: `npm test`

- [ ] **Step 7: Implement `isSolved`**

Append to `web/js/game-engine.js`:
```js
export function isSolved(answer, correctGuesses, revealedLetter) {
  const known = new Set(correctGuesses);
  if (revealedLetter) known.add(String(revealedLetter).toUpperCase());
  for (const ch of answer.toUpperCase()) {
    if (!LETTER_RE.test(ch)) continue;
    if (!known.has(ch)) return false;
  }
  return true;
}
```

- [ ] **Step 8: Run, expect PASS**

Run: `npm test`

- [ ] **Step 9: Add tests for `isFailed`, `heartCost`, `letterToReveal`**

Append:
```js
test('isFailed: zero lives or negative -> true', () => {
  assert.equal(engine.isFailed(0), true);
  assert.equal(engine.isFailed(-1), true);
  assert.equal(engine.isFailed(1), false);
});

test('heartCost: category=1, letter=2', () => {
  assert.equal(engine.heartCost('category'), 1);
  assert.equal(engine.heartCost('letter'), 2);
});

test('letterToReveal: first un-guessed letter in answer', () => {
  assert.equal(engine.letterToReveal('TOY STORY', new Set(['T','O'])), 'Y');
  assert.equal(engine.letterToReveal('TOY STORY', new Set(['T','O','Y','S','R'])), null);
});
```

- [ ] **Step 10: Run, expect FAIL**

- [ ] **Step 11: Implement those three**

Append:
```js
export function isFailed(lives) {
  return lives <= 0;
}

export function heartCost(hintType) {
  return hintType === 'category' ? 1 : 2;
}

export function letterToReveal(answer, correctGuesses) {
  for (const ch of answer.toUpperCase()) {
    if (!LETTER_RE.test(ch)) continue;
    if (!correctGuesses.has(ch)) return ch;
  }
  return null;
}
```

- [ ] **Step 12: Run, expect PASS**

- [ ] **Step 13: Add tests for `streakAfterSolve`**

Append:
```js
test('streakAfterSolve: first solve -> streak 1', () => {
  const r = engine.streakAfterSolve('2026-05-21', null, 0, 1);
  assert.deepEqual(r, { streak: 1, freezesAvailable: 1 });
});

test('streakAfterSolve: consecutive day -> +1, freezes unchanged', () => {
  const r = engine.streakAfterSolve('2026-05-21', '2026-05-20', 7, 1);
  assert.deepEqual(r, { streak: 8, freezesAvailable: 1 });
});

test('streakAfterSolve: missed 1 day with freeze -> +1, freeze consumed', () => {
  const r = engine.streakAfterSolve('2026-05-21', '2026-05-19', 7, 1);
  assert.deepEqual(r, { streak: 8, freezesAvailable: 0 });
});

test('streakAfterSolve: missed 1 day without freeze -> reset to 1', () => {
  const r = engine.streakAfterSolve('2026-05-21', '2026-05-19', 7, 0);
  assert.deepEqual(r, { streak: 1, freezesAvailable: 0 });
});

test('streakAfterSolve: missed multiple days -> reset to 1', () => {
  const r = engine.streakAfterSolve('2026-05-21', '2026-05-15', 7, 1);
  assert.deepEqual(r, { streak: 1, freezesAvailable: 1 });
});

test('streakAfterFail: always 0', () => {
  assert.equal(engine.streakAfterFail(99), 0);
});
```

- [ ] **Step 14: Run, expect FAIL**

- [ ] **Step 15: Implement streak functions**

Append:
```js
export function streakAfterSolve(today, lastSolvedDate, currentStreak, freezesAvailable) {
  if (!lastSolvedDate) {
    return { streak: 1, freezesAvailable };
  }
  const apart = daysBetween(lastSolvedDate, today);
  if (apart === 1) {
    return { streak: currentStreak + 1, freezesAvailable };
  }
  if (apart === 2 && freezesAvailable > 0) {
    return { streak: currentStreak + 1, freezesAvailable: freezesAvailable - 1 };
  }
  return { streak: 1, freezesAvailable };
}

export function streakAfterFail(_currentStreak) {
  return 0;
}

// Days between two YYYY-MM-DD strings (interpreted as UTC midnight).
// Returns Number.MAX_SAFE_INTEGER on malformed input.
function daysBetween(a, b) {
  const da = parseYMD(a);
  const db = parseYMD(b);
  if (da === null || db === null) return Number.MAX_SAFE_INTEGER;
  return Math.round((db - da) / 86_400_000);
}

function parseYMD(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}
```

- [ ] **Step 16: Run all engine tests, expect PASS**

Run: `npm test`
Expected: all 13 game-engine tests pass.

- [ ] **Step 17: Commit**

```bash
git add web/js/game-engine.js web/tests/game-engine.test.js
git commit -m "web: port GameEngine — isCorrect/isSolved/isFailed/letterToReveal/streak*"
```

---

## Task 3: Port UserState (localStorage I/O)

**Files:**
- Create: `web/js/user-state.js`
- Create: `web/tests/user-state.test.js`

- [ ] **Step 1: Write failing tests for `fresh()` and `load()` with stub localStorage**

`web/tests/user-state.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as us from '../js/user-state.js';

function fakeStorage() {
  const map = new Map();
  return {
    getItem: k => map.has(k) ? map.get(k) : null,
    setItem: (k, v) => { map.set(k, String(v)); },
    removeItem: k => { map.delete(k); },
    _raw: map,
  };
}

test('fresh: returns canonical initial state', () => {
  const s = us.fresh();
  assert.equal(s.currentStreak, 0);
  assert.equal(s.longestStreak, 0);
  assert.equal(s.lastSolvedDate, null);
  assert.equal(s.streakFreezesAvailable, 1);
  assert.equal(s.lives, 5);
  assert.deepEqual(s.solvedPuzzleIds, []);
  assert.deepEqual(s.recentEndlessIds, []);
});

test('load: empty storage -> fresh state', () => {
  const storage = fakeStorage();
  const s = us.load(storage);
  assert.equal(s.currentStreak, 0);
});

test('save then load: round-trips', () => {
  const storage = fakeStorage();
  const original = us.fresh();
  original.currentStreak = 5;
  original.solvedPuzzleIds = ['puzzle-001', 'puzzle-002'];
  us.save(original, storage);
  const restored = us.load(storage);
  assert.equal(restored.currentStreak, 5);
  assert.deepEqual(restored.solvedPuzzleIds, ['puzzle-001', 'puzzle-002']);
});

test('load: corrupt JSON falls back to fresh', () => {
  const storage = fakeStorage();
  storage.setItem('pictok.state.v1', '{not json');
  const s = us.load(storage);
  assert.equal(s.currentStreak, 0);
});

test('load: missing fields filled with defaults (forward-compat)', () => {
  const storage = fakeStorage();
  storage.setItem('pictok.state.v1', JSON.stringify({ currentStreak: 9 }));
  const s = us.load(storage);
  assert.equal(s.currentStreak, 9);
  assert.equal(s.lives, 5, 'missing lives field should default');
  assert.deepEqual(s.solvedPuzzleIds, []);
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `npm test`

- [ ] **Step 3: Implement `user-state.js`**

`web/js/user-state.js`:
```js
// Mirrors Pictok/Models/UserState.swift schema. Persists to localStorage.

export const STORAGE_KEY = 'pictok.state.v1';

export function fresh() {
  return {
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
    recentEndlessIds: [],
  };
}

export function load(storage = globalThis.localStorage) {
  if (!storage) return fresh();
  const raw = storage.getItem(STORAGE_KEY);
  if (!raw) return fresh();
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return fresh();
  }
  return { ...fresh(), ...parsed };
}

export function save(state, storage = globalThis.localStorage) {
  if (!storage) return;
  storage.setItem(STORAGE_KEY, JSON.stringify(state));
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `npm test`

- [ ] **Step 5: Commit**

```bash
git add web/js/user-state.js web/tests/user-state.test.js
git commit -m "web: UserState — localStorage load/save + fresh schema"
```

---

## Task 4: Port PuzzleLoader

**Files:**
- Create: `web/js/puzzle-loader.js`
- Create: `web/tests/puzzle-loader.test.js`

- [ ] **Step 1: Write failing tests**

`web/tests/puzzle-loader.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import * as loader from '../js/puzzle-loader.js';

const SAMPLE = [
  { id: 'p1', date: '2026-05-18', emoji: '🧸📖', answer: 'TOY STORY',  category: 'Movie', subcategory: '',          difficulty: 'medium' },
  { id: 'p2', date: '2026-05-19', emoji: '👁️🤖',  answer: 'I ROBOT',    category: 'Movie', subcategory: '',          difficulty: 'hard'   },
  { id: 'p3', date: '2026-05-21', emoji: '💧🚽',  answer: 'WATERLOO',   category: 'Song',  subcategory: 'ABBA · 1974', difficulty: 'hard' },
];

test('PuzzleLoader.fromArray: indexes by date', () => {
  const pl = loader.fromArray(SAMPLE);
  assert.equal(pl.puzzleFor('2026-05-18').answer, 'TOY STORY');
  assert.equal(pl.puzzleFor('2026-05-21').answer, 'WATERLOO');
  assert.equal(pl.puzzleFor('2026-05-20'), null);
});

test('PuzzleLoader.allPuzzles: returns all', () => {
  const pl = loader.fromArray(SAMPLE);
  assert.equal(pl.allPuzzles.length, 3);
});

test('dateString: formats YYYY-MM-DD in given timezone', () => {
  const d = new Date('2026-05-21T17:30:00Z');
  assert.equal(loader.dateString(d, 'UTC'), '2026-05-21');
  // In a far-west timezone the wall-clock is earlier — still same day at 17:30 UTC.
  assert.equal(loader.dateString(d, 'America/Los_Angeles'), '2026-05-21');
  // Just past midnight UTC -> previous calendar day in LA.
  const d2 = new Date('2026-05-22T01:00:00Z');
  assert.equal(loader.dateString(d2, 'America/Los_Angeles'), '2026-05-21');
});

test('puzzles.json on disk parses and has 59 puzzles', async () => {
  const path = fileURLToPath(new URL('../puzzles.json', import.meta.url));
  const data = JSON.parse(await readFile(path, 'utf-8'));
  assert.equal(data.length, 59);
  assert.ok(data.every(p => p.id && p.date && p.answer));
});
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement puzzle-loader**

`web/js/puzzle-loader.js`:
```js
// Mirrors Pictok/Game/PuzzleLoader.swift. fetch()-based for browser, fromArray for tests.

export async function fromUrl(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch puzzles.json: ${res.status}`);
  const data = await res.json();
  return fromArray(data);
}

export function fromArray(puzzles) {
  const byDate = new Map(puzzles.map(p => [p.date, p]));
  return {
    allPuzzles: puzzles,
    puzzleFor(date) {
      return byDate.get(date) ?? null;
    },
  };
}

/// Formats a Date to "YYYY-MM-DD" in the given IANA timezone.
export function dateString(date, timeZone) {
  // en-CA uses YYYY-MM-DD natively, sidestepping locale formatting.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}
```

- [ ] **Step 4: Run, expect PASS (all 4 tests)**

- [ ] **Step 5: Commit**

```bash
git add web/js/puzzle-loader.js web/tests/puzzle-loader.test.js
git commit -m "web: PuzzleLoader — fromUrl/fromArray + dateString (TZ-aware)"
```

---

## Task 5: Port EndlessSelector

**Files:**
- Create: `web/js/endless-selector.js`
- Create: `web/tests/endless-selector.test.js`

- [ ] **Step 1: Write failing tests**

`web/tests/endless-selector.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextPuzzle } from '../js/endless-selector.js';
import { fresh } from '../js/user-state.js';

// Deterministic RNG: returns sequential picks from the pool.
function fixedRng(seq) {
  let i = 0;
  return () => seq[i++ % seq.length];
}

const POOL = [
  { id: 'today',     date: '2026-05-21' },
  { id: 'tomorrow',  date: '2026-05-22' },  // inside 7-day spoiler window
  { id: 'next-week', date: '2026-05-30' },  // outside spoiler window
  { id: 'far',       date: '2026-06-15' },  // far future
  { id: 'past',      date: '2026-05-10' },  // already past
];
const TODAY = '2026-05-21';

test('tier 1: prefers unseen + spoiler-safe (>7 days from today)', () => {
  const state = fresh();
  // RNG that picks index 0 from each candidate list.
  const pick = nextPuzzle(POOL, state, TODAY, fixedRng([0]));
  assert.ok(['next-week', 'far', 'past'].includes(pick.id),
    `expected a spoiler-safe puzzle, got ${pick.id}`);
});

test('excludes today\'s Daily from every tier', () => {
  const state = fresh();
  for (let i = 0; i < 20; i++) {
    const pick = nextPuzzle(POOL, state, TODAY, fixedRng([i % POOL.length]));
    assert.notEqual(pick.id, 'today');
  }
});

test('tier 2: falls back to any unseen when no spoiler-safe puzzle exists', () => {
  // Mark every spoiler-safe puzzle as seen.
  const state = fresh();
  state.solvedPuzzleIds = ['next-week', 'far', 'past'];
  const pick = nextPuzzle(POOL, state, TODAY, fixedRng([0]));
  assert.equal(pick.id, 'tomorrow');
});

test('tier 3: replays from candidates not in recentEndlessIds when all are seen', () => {
  const state = fresh();
  state.solvedPuzzleIds = ['tomorrow', 'next-week', 'far', 'past'];
  state.recentEndlessIds = ['past'];
  const pick = nextPuzzle(POOL, state, TODAY, fixedRng([0]));
  assert.notEqual(pick.id, 'past');
  assert.notEqual(pick.id, 'today');
});

test('fallback: when recent covers everything, returns any non-today candidate', () => {
  const state = fresh();
  state.solvedPuzzleIds = ['tomorrow', 'next-week', 'far', 'past'];
  state.recentEndlessIds = ['tomorrow', 'next-week', 'far', 'past'];
  const pick = nextPuzzle(POOL, state, TODAY, fixedRng([0]));
  assert.ok(pick !== null);
  assert.notEqual(pick.id, 'today');
});

test('returns null when pool only contains today\'s puzzle', () => {
  const tiny = [{ id: 'only', date: TODAY }];
  const pick = nextPuzzle(tiny, fresh(), TODAY, fixedRng([0]));
  assert.equal(pick, null);
});
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement endless-selector**

`web/js/endless-selector.js`:
```js
// Mirrors Pictok/Game/EndlessSelector.swift. 3-tier priority.

const SPOILER_WINDOW_DAYS = 7;

export function nextPuzzle(allPuzzles, state, today, rng = Math.random) {
  const candidates = allPuzzles.filter(p => p.date !== today);

  const seen = new Set([...(state.solvedPuzzleIds ?? []), ...(state.failedPuzzleIds ?? [])]);
  const unseen = candidates.filter(p => !seen.has(p.id));

  // Tier 1: unseen + spoiler-safe.
  const safe = unseen.filter(p => Math.abs(daysBetween(today, p.date)) > SPOILER_WINDOW_DAYS);
  const pick1 = randomPick(safe, rng);
  if (pick1) return pick1;

  // Tier 2: any unseen.
  const pick2 = randomPick(unseen, rng);
  if (pick2) return pick2;

  // Tier 3: replay, skip recent.
  const recent = new Set(state.recentEndlessIds ?? []);
  const replayable = candidates.filter(p => !recent.has(p.id));
  const pick3 = randomPick(replayable, rng);
  if (pick3) return pick3;

  // Last resort: any non-today candidate.
  return randomPick(candidates, rng);
}

function randomPick(pool, rng) {
  if (!pool.length) return null;
  return pool[Math.floor(rng() * pool.length)];
}

function daysBetween(a, b) {
  const da = parseYMD(a);
  const db = parseYMD(b);
  if (da === null || db === null) return Number.MAX_SAFE_INTEGER;
  return Math.round((db - da) / 86_400_000);
}

function parseYMD(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}
```

- [ ] **Step 4: Run, expect PASS (6 selector tests)**

- [ ] **Step 5: Commit**

```bash
git add web/js/endless-selector.js web/tests/endless-selector.test.js
git commit -m "web: EndlessSelector — 3-tier priority (spoiler-safe → unseen → replay)"
```

---

## Task 6: Port ShareCardBuilder

**Files:**
- Create: `web/js/share.js` (logic-only; Web Share API wiring lands in Task 12)
- Create: `web/tests/share.test.js`

- [ ] **Step 1: Write failing tests against the exact iOS strings**

`web/tests/share.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { successCard, failureCard, CHALLENGE_BOLD, FAIL_BOLD } from '../js/share.js';

test('successCard: perfect run (no hint, no wrong)', () => {
  const card = successCard({
    heartsRemaining: 5, hintUsed: false, currentStreak: 7, url: 'pictok.app',
  });
  const expected =
    `I solved today's Pictok with no hints — perfect run.\n` +
    `Streak: 7\n` +
    `\n` +
    `🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯\n` +
    `→ pictok.app`;
  assert.equal(card, expected);
});

test('successCard: hint used, no wrong', () => {
  const card = successCard({ heartsRemaining: 5, hintUsed: true, currentStreak: 3, url: 'pictok.app' });
  assert.ok(card.startsWith("I solved today's Pictok using 1 hint."));
});

test('successCard: one wrong guess (singular)', () => {
  const card = successCard({ heartsRemaining: 4, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('(1 wrong guess)'), card);
});

test('successCard: multiple wrong guesses (plural)', () => {
  const card = successCard({ heartsRemaining: 2, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('(3 wrong guesses)'), card);
});

test('successCard: hint AND wrong guesses', () => {
  const card = successCard({ heartsRemaining: 3, hintUsed: true, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('with 1 hint and 2 wrong guesses'), card);
});

test('successCard: includes bold challenge line + URL, no puzzle index', () => {
  const card = successCard({ heartsRemaining: 5, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes(CHALLENGE_BOLD));
  assert.ok(card.includes('→ pictok.app'));
  assert.ok(!card.includes('#'));
});

test('failureCard: exact format', () => {
  const card = failureCard({ previousStreak: 7, url: 'pictok.app' });
  const expected =
    `Today's Pictok beat me.\n` +
    `Streak: 7 → 0\n` +
    `\n` +
    `🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯\n` +
    `→ pictok.app`;
  assert.equal(card, expected);
});
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement share.js**

`web/js/share.js`:
```js
// Mirrors Pictok/Game/ShareCardBuilder.swift. Pure text builders.
// Uses Unicode Mathematical Sans-Serif Bold codepoints for bold-without-Markdown.

export const CHALLENGE_BOLD = '🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯';
export const FAIL_BOLD      = '🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯';

export function successCard({ heartsRemaining, hintUsed, currentStreak, url }) {
  const heartsLost = Math.max(0, Math.min(5, 5 - heartsRemaining));
  const firstLine = challengeLine(hintUsed, heartsLost);
  return `${firstLine}\nStreak: ${currentStreak}\n\n${CHALLENGE_BOLD}\n→ ${url}`;
}

export function failureCard({ previousStreak, url }) {
  return `Today's Pictok beat me.\nStreak: ${previousStreak} → 0\n\n${FAIL_BOLD}\n→ ${url}`;
}

function challengeLine(hintUsed, heartsLost) {
  if (!hintUsed && heartsLost === 0) {
    return "I solved today's Pictok with no hints — perfect run.";
  }
  if (hintUsed && heartsLost === 0) {
    return "I solved today's Pictok using 1 hint.";
  }
  if (!hintUsed) {
    const noun = heartsLost === 1 ? 'guess' : 'guesses';
    return `I solved today's Pictok (${heartsLost} wrong ${noun}).`;
  }
  const noun = heartsLost === 1 ? 'guess' : 'guesses';
  return `I solved today's Pictok with 1 hint and ${heartsLost} wrong ${noun}.`;
}
```

- [ ] **Step 4: Run, expect PASS (7 share tests)**

- [ ] **Step 5: Commit**

```bash
git add web/js/share.js web/tests/share.test.js
git commit -m "web: ShareCardBuilder — Unicode-bold challenge + 4 challenge variants"
```

---

## Task 7: HTML skeleton + CSS sticker system

**Files:**
- Create: `web/index.html`
- Create: `web/style.css`
- Create: `web/js/main.js` (stub — just confirms DOM loads)

- [ ] **Step 1: Write `web/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#FEF3D9" />
  <title>Pictok — Daily Emoji Puzzle</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <div id="app">
    <header id="top-bar">
      <h1>Pictok</h1>
      <nav>
        <button data-screen="today"   class="tab" aria-current="page">Play</button>
        <button data-screen="endless" class="tab">Endless</button>
        <button data-screen="stats"   class="tab">Stats</button>
      </nav>
    </header>

    <main>
      <section id="screen-today"   class="screen active"></section>
      <section id="screen-endless" class="screen" hidden></section>
      <section id="screen-stats"   class="screen" hidden></section>
    </main>

    <div id="modal-root"></div>
    <div id="toast-root"></div>
  </div>
  <script type="module" src="js/main.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `web/style.css`**

```css
/* Theme — mirrors Pictok/Views/Theme.swift */
:root {
  --pk-paper:  #FEF3D9;
  --pk-ink:    #1A1A1A;
  --pk-yellow: #FFD60A;
  --pk-red:    #E63946;
  --pk-green:  #06D6A0;
  --pk-blue:   #118AB2;

  --font-rounded: system-ui, -apple-system, "SF Pro Rounded", "Segoe UI", sans-serif;
  --font-mono:    ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  padding: 0;
  background: var(--pk-paper);
  color: var(--pk-ink);
  font-family: var(--font-rounded);
  font-weight: 600;
  -webkit-font-smoothing: antialiased;
}

#app {
  max-width: 480px;
  margin: 0 auto;
  padding: 16px;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

#top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

#top-bar h1 {
  margin: 0;
  font-size: 28px;
  font-weight: 900;
  letter-spacing: -0.02em;
}

#top-bar nav {
  display: flex;
  gap: 8px;
}

.tab {
  background: transparent;
  border: none;
  color: var(--pk-ink);
  opacity: 0.5;
  font-family: inherit;
  font-weight: 800;
  font-size: 14px;
  padding: 8px 12px;
  cursor: pointer;
  border-radius: 10px;
}
.tab[aria-current="page"] { opacity: 1; background: rgba(0,0,0,0.06); }

.screen { display: flex; flex-direction: column; gap: 16px; }
.screen[hidden] { display: none; }

/* Sticker — mirrors StickerModifier (hard offset shadow, no blur) */
.sticker {
  background: #fff;
  border: 3px solid var(--pk-ink);
  border-radius: 14px;
  box-shadow: 4px 4px 0 0 var(--pk-ink);
  padding: 12px 16px;
}
.sticker--soft { border-width: 2px; box-shadow: 2px 2px 0 0 var(--pk-ink); border-radius: 12px; }

/* Sticker button — interactive variant */
.btn-sticker {
  font-family: inherit;
  font-size: 16px;
  font-weight: 800;
  color: var(--pk-ink);
  background: #fff;
  border: 3px solid var(--pk-ink);
  border-radius: 14px;
  box-shadow: 4px 4px 0 0 var(--pk-ink);
  padding: 12px 20px;
  cursor: pointer;
  transition: transform 60ms ease, box-shadow 60ms ease;
}
.btn-sticker:active {
  transform: translate(2px, 2px);
  box-shadow: 2px 2px 0 0 var(--pk-ink);
}
.btn-sticker[disabled] { opacity: 0.5; cursor: not-allowed; }
.btn-sticker--yellow { background: var(--pk-yellow); }
.btn-sticker--green  { background: var(--pk-green); color: var(--pk-ink); }
.btn-sticker--red    { background: var(--pk-red); color: #fff; }
.btn-sticker--blue   { background: var(--pk-blue); color: #fff; }

/* Emoji header */
.emoji-header {
  font-size: 72px;
  text-align: center;
  line-height: 1;
  padding: 8px 0;
}

/* Hearts */
.hearts-row { display: flex; gap: 4px; justify-content: center; }
.heart { font-size: 22px; }
.heart--lost { opacity: 0.2; filter: grayscale(1); }

/* Category chip */
.category-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 800;
  align-self: center;
  padding: 6px 12px;
  background: rgba(0,0,0,0.06);
  border-radius: 999px;
}

/* Blanks (the word(s) being guessed) */
.blanks {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  justify-content: center;
  font-family: var(--font-mono);
}
.blank-word { display: flex; gap: 6px; }
.blank-letter {
  width: 22px;
  height: 28px;
  border-bottom: 3px solid var(--pk-ink);
  text-align: center;
  font-size: 22px;
  font-weight: 800;
  line-height: 28px;
}
.blank-letter--revealed { color: var(--pk-ink); }
.blank-letter--empty    { color: transparent; }

/* Keyboard */
.keyboard { display: flex; flex-direction: column; gap: 6px; }
.keyboard-row { display: flex; gap: 5px; justify-content: center; }
.key {
  flex: 1;
  max-width: 36px;
  height: 46px;
  font-family: var(--font-mono);
  font-size: 16px;
  font-weight: 700;
  background: #fff;
  border: 2px solid var(--pk-ink);
  border-radius: 6px;
  cursor: pointer;
  color: var(--pk-ink);
}
.key--correct { background: var(--pk-green); color: var(--pk-ink); }
.key--wrong   { background: var(--pk-red);   color: #fff; opacity: 0.6; }
.key[disabled] { cursor: not-allowed; }

/* Modal */
#modal-root .modal-backdrop {
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex; align-items: center; justify-content: center;
  z-index: 50;
}
.modal {
  background: var(--pk-paper);
  border: 3px solid var(--pk-ink);
  border-radius: 18px;
  padding: 24px;
  width: min(420px, 92vw);
  display: flex; flex-direction: column; gap: 16px;
  box-shadow: 6px 6px 0 0 var(--pk-ink);
}

/* Toast */
#toast-root .toast {
  position: fixed; left: 50%; bottom: 24px; transform: translateX(-50%);
  background: var(--pk-ink);
  color: var(--pk-paper);
  padding: 10px 16px;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 700;
  z-index: 60;
  animation: toast-in 200ms ease-out;
}
@keyframes toast-in {
  from { transform: translate(-50%, 20px); opacity: 0; }
  to   { transform: translate(-50%, 0);     opacity: 1; }
}

/* Celebration canvas */
canvas.celebration {
  position: fixed; inset: 0;
  pointer-events: none;
  z-index: 40;
}
```

- [ ] **Step 3: Write a stub `web/js/main.js`**

```js
// Stub for Task 7 — replaced fully in Task 8.
console.log('Pictok web stub loaded');
document.querySelector('#screen-today').innerHTML = '<p>Loading…</p>';
```

- [ ] **Step 4: Serve and verify in browser**

Run: `cd /Users/rehatchugh/emoji-decode/web && python3 -m http.server 8080 &`
Then visit `http://localhost:8080/` in a browser. Verify:
- Page loads on Pictok paper background
- "Pictok" header visible
- Three tab buttons (Play / Endless / Stats) visible
- "Loading…" visible in the today section
- No console errors

Kill the server with `kill %1` or by closing.

- [ ] **Step 5: Commit**

```bash
git add web/index.html web/style.css web/js/main.js
git commit -m "web: HTML skeleton + sticker CSS (theme variables, layout, modal/toast)"
```

---

## Task 8: Daily mode — TodaySession + UI wiring

**Files:**
- Create: `web/js/today-session.js`
- Create: `web/js/ui.js`
- Modify: `web/js/main.js` (full replacement)

- [ ] **Step 1: Write `web/js/today-session.js`**

The Daily session persists guess progress to UserState's `today*` fields so refreshing the browser resumes the puzzle.

```js
// Daily-puzzle session: persistent across refresh via UserState.today*.
import * as engine from './game-engine.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;
const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

export function createTodaySession(puzzle, state, storage) {
  // Reset today's progress when the date rolls over (different puzzle than stored).
  if (state.todayPuzzleId !== puzzle.id) {
    state.todayPuzzleId = puzzle.id;
    state.todayWrongGuesses = [];
    state.todayCorrectGuesses = [];
    state.todayHintUsed = null;
    state.todayRevealedLetter = null;
    state.todaySolved = false;
    state.todayFailed = false;
    state.lives = MAX_HEARTS;
    us.save(state, storage);
  }

  const session = {
    puzzle,
    get lives()        { return state.lives; },
    get correct()      { return new Set(state.todayCorrectGuesses); },
    get wrong()        { return new Set(state.todayWrongGuesses); },
    get solved()       { return state.todaySolved; },
    get failed()       { return state.todayFailed; },
    get hintUsed()     { return state.todayHintUsed !== null; },
    get revealed()     { return state.todayRevealedLetter; },
    get hasShownOneChanceWarning() { return session._oneChanceShown; },
    _oneChanceShown: false,
    /** Returns true when the answer is fully revealed but Submit hasn't been pressed. */
    get needsSubmit() {
      if (state.todaySolved || state.todayFailed) return false;
      return engine.isSolved(puzzle.answer, this.correct, state.todayRevealedLetter);
    },
    guess(letter) {
      if (state.todaySolved || state.todayFailed) return;
      const u = String(letter).toUpperCase();
      if (this.correct.has(u) || this.wrong.has(u)) return;
      if (engine.isCorrect(u, puzzle.answer)) {
        state.todayCorrectGuesses = [...state.todayCorrectGuesses, u];
      } else {
        state.todayWrongGuesses = [...state.todayWrongGuesses, u];
        state.lives = Math.max(0, state.lives - 1);
        if (state.lives === 1 && !session._oneChanceShown) {
          session._oneChanceShown = true;
        }
        if (engine.isFailed(state.lives)) {
          state.todayFailed = true;
          recordFailure(state, puzzle);
        }
      }
      us.save(state, storage);
    },
    useHint() {
      if (state.todayHintUsed || state.todaySolved || state.todayFailed) return;
      const letter = engine.letterToReveal(puzzle.answer, this.correct);
      if (!letter) return;
      state.todayRevealedLetter = letter;
      state.todayHintUsed = 'letter';
      state.lives = Math.max(0, state.lives - engine.heartCost('letter'));
      if (engine.isFailed(state.lives)) {
        state.todayFailed = true;
        recordFailure(state, puzzle);
      }
      us.save(state, storage);
    },
    submit(today) {
      if (!this.needsSubmit) return;
      state.todaySolved = true;
      recordSolve(state, puzzle, today);
      us.save(state, storage);
    },
  };
  return session;
}

function recordSolve(state, puzzle, today) {
  state.hasEverSolved = true;
  state.totalPlayed += 1;
  state.totalSolved += 1;
  state.lifetimeSolvedCount += 1;
  if (!state.solvedPuzzleIds.includes(puzzle.id)) {
    state.solvedPuzzleIds = [...state.solvedPuzzleIds, puzzle.id];
  }
  const wrongCount = state.todayWrongGuesses.length;
  state.guessDistribution[wrongCount] = (state.guessDistribution[wrongCount] ?? 0) + 1;
  const r = engine.streakAfterSolve(today, state.lastSolvedDate, state.currentStreak, state.streakFreezesAvailable);
  state.currentStreak = r.streak;
  state.streakFreezesAvailable = r.freezesAvailable;
  state.longestStreak = Math.max(state.longestStreak, state.currentStreak);
  state.lastSolvedDate = today;
}

function recordFailure(state, puzzle) {
  state.totalPlayed += 1;
  state.currentStreak = engine.streakAfterFail(state.currentStreak);
  if (!state.failedPuzzleIds.includes(puzzle.id)) {
    state.failedPuzzleIds = [...state.failedPuzzleIds, puzzle.id];
  }
}
```

- [ ] **Step 2: Write `web/js/ui.js`**

DOM helpers and reusable renderers.

```js
// DOM helpers. Pure functions where possible; the few side-effect functions are
// the only places we touch the document.
export const $ = (sel, root = document) => root.querySelector(sel);

export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'disabled' && v) node.setAttribute('disabled', '');
    else if (v === false || v == null) continue;
    else node.setAttribute(k, v);
  }
  for (const c of [].concat(children)) {
    if (c == null) continue;
    node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
  return node;
}

export function showScreen(name) {
  for (const s of document.querySelectorAll('.screen')) s.hidden = !s.id.endsWith(name);
  for (const t of document.querySelectorAll('.tab')) {
    if (t.dataset.screen === name) t.setAttribute('aria-current', 'page');
    else t.removeAttribute('aria-current');
  }
}

export function showToast(text, ms = 2200) {
  const root = $('#toast-root');
  root.replaceChildren(el('div', { class: 'toast' }, [text]));
  setTimeout(() => root.replaceChildren(), ms);
}

export function showModal(buildContent) {
  const root = $('#modal-root');
  const close = () => root.replaceChildren();
  const content = buildContent({ close });
  root.replaceChildren(el('div', { class: 'modal-backdrop' }, [
    el('div', { class: 'modal' }, [content]),
  ]));
}

const ALPHABET = 'QWERTYUIOPASDFGHJKLZXCVBNM';
export function renderKeyboard({ correct, wrong, onGuess, disabled }) {
  const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  return el('div', { class: 'keyboard' }, rows.map(row =>
    el('div', { class: 'keyboard-row' }, [...row].map(ch => {
      const status = correct.has(ch) ? 'correct' : wrong.has(ch) ? 'wrong' : '';
      const used = correct.has(ch) || wrong.has(ch);
      return el('button', {
        class: `key ${status ? `key--${status}` : ''}`.trim(),
        disabled: disabled || used,
        onclick: () => onGuess(ch),
      }, [ch]);
    }))
  ));
}

export function renderBlanks(answer, correct, revealedLetter) {
  const known = new Set(correct);
  if (revealedLetter) known.add(revealedLetter);
  const words = answer.split(' ');
  return el('div', { class: 'blanks' }, words.map(word =>
    el('div', { class: 'blank-word' }, [...word].map(ch => {
      const shown = known.has(ch.toUpperCase()) ? ch : '';
      return el('div', {
        class: `blank-letter ${shown ? 'blank-letter--revealed' : 'blank-letter--empty'}`,
      }, [shown || '·']);
    }))
  ));
}

export function renderHearts(remaining, max = 5) {
  return el('div', { class: 'hearts-row' }, Array.from({ length: max }, (_, i) =>
    el('span', { class: `heart ${i < remaining ? '' : 'heart--lost'}`.trim() }, ['❤️'])
  ));
}

export function renderCategoryChip(category, subcategory) {
  const icons = { Movie: '🎬', Song: '🎵', Book: '📚', Brand: '🏷️', Celeb: '🎤' };
  const text = subcategory ? `${category} · ${subcategory}` : category;
  return el('div', { class: 'category-chip' }, [`${icons[category] ?? ''} ${text}`]);
}
```

- [ ] **Step 3: Replace `web/js/main.js` with the Today screen wiring**

```js
import * as us from './user-state.js';
import * as puzzleLoader from './puzzle-loader.js';
import { createTodaySession } from './today-session.js';
import * as ui from './ui.js';

const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

async function boot() {
  const storage = window.localStorage;
  const state = us.load(storage);
  const loader = await puzzleLoader.fromUrl('puzzles.json');
  const today = puzzleLoader.dateString(new Date(), TZ);
  const todayPuzzle = loader.puzzleFor(today);

  // Tab routing
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => ui.showScreen(tab.dataset.screen));
  }

  if (!todayPuzzle) {
    document.querySelector('#screen-today').replaceChildren(
      ui.el('div', { class: 'sticker' }, [
        ui.el('h2', {}, ["No puzzle today"]),
        ui.el('p', {}, ["The Daily bundle ends here for now. Try Endless mode while we cook up more puzzles."]),
      ])
    );
    return;
  }

  const session = createTodaySession(todayPuzzle, state, storage);
  renderToday(session, state, today);
}

function renderToday(session, state, today) {
  const root = document.querySelector('#screen-today');

  function rerender() {
    root.replaceChildren(
      ui.renderHearts(session.lives),
      ui.el('div', { class: 'emoji-header' }, [session.puzzle.emoji]),
      ui.renderCategoryChip(session.puzzle.category, session.puzzle.subcategory),
      ui.renderBlanks(session.puzzle.answer, session.correct, session.revealed),
      ui.el('div', { class: 'btn-row', style: 'display:flex;justify-content:flex-end;gap:8px' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow',
          disabled: session.hintUsed || session.solved || session.failed,
          onclick: () => { session.useHint(); afterAction(); },
        }, ['💡 Hint (–2 ❤️)']),
      ]),
      session.needsSubmit
        ? ui.el('button', {
            class: 'btn-sticker btn-sticker--green',
            onclick: () => { session.submit(today); afterAction(); },
          }, ['Submit ✓'])
        : null,
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed || session.needsSubmit,
        onGuess: (letter) => { session.guess(letter); afterAction(); },
      }),
    );
  }

  function afterAction() {
    rerender();
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      ui.showModal(({ close }) => ui.el('div', {}, [
        ui.el('h2', {}, ['One chance left']),
        ui.el('p', {}, ['Make it count — one more wrong guess ends the puzzle.']),
        ui.el('button', { class: 'btn-sticker', onclick: close }, ['OK']),
      ]));
    }
    if (session.solved) showResultModal(session, state, true);
    if (session.failed) showResultModal(session, state, false);
  }

  rerender();
}

function showResultModal(session, state, success) {
  ui.showModal(({ close }) => ui.el('div', {}, [
    ui.el('h2', {}, [success ? '🎉 You solved it!' : '💔 Better luck tomorrow']),
    ui.el('p', {}, [`Answer: ${session.puzzle.answer}`]),
    ui.el('p', {}, [`Streak: ${state.currentStreak}`]),
    ui.el('button', { class: 'btn-sticker', onclick: close }, ['Close']),
  ]));
}

boot();
```

- [ ] **Step 4: Verify in the browser — full Daily round-trip**

Run: `cd /Users/rehatchugh/emoji-decode/web && python3 -m http.server 8080`
Open `http://localhost:8080/`.

Manual QA checklist:
- Today's puzzle (WATERLOO, 2026-05-21) shows with category `🎵 Song · ABBA · 1974` and emoji `💧🚽`.
- 5 hearts visible.
- On-screen keyboard works; correct letters fill blanks and turn green; wrong letters turn red and drop a heart.
- Hint button reveals a letter and drops 2 hearts.
- Once all letters revealed, "Submit ✓" appears; tapping it shows the success modal.
- Refresh the page mid-solve — progress (guesses, hearts) persists.
- localStorage in DevTools shows key `pictok.state.v1` populated.

- [ ] **Step 5: Commit**

```bash
git add web/js/today-session.js web/js/ui.js web/js/main.js
git commit -m "web: Daily mode — TodaySession + UI render + localStorage persistence"
```

---

## Task 9: Endless mode — EndlessSession + UI

**Files:**
- Create: `web/js/endless-session.js`
- Modify: `web/js/main.js` (add Endless screen renderer)

- [ ] **Step 1: Write `web/js/endless-session.js`**

Mirrors `Pictok/Game/EndlessSession.swift`. State per-puzzle resets on `advance()`.

```js
import * as engine from './game-engine.js';
import { nextPuzzle } from './endless-selector.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;
const RECENT_BUFFER = 5;

export function createEndlessSession(allPuzzles, state, today, storage) {
  let puzzle = nextPuzzle(allPuzzles, state, today);

  const session = {
    get currentPuzzle() { return puzzle; },
    hearts: MAX_HEARTS,
    correct: new Set(),
    wrong: new Set(),
    solved: false,
    failed: false,
    hintUsed: false,
    hasShownOneChanceWarning: false,
    solvedThisSession: 0,
    get needsSubmit() {
      if (!puzzle || session.solved || session.failed) return false;
      return engine.isSolved(puzzle.answer, session.correct, null);
    },
    guess(letter) {
      if (!puzzle || session.solved || session.failed) return;
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
        if (engine.isFailed(session.hearts)) {
          session.failed = true;
          recordFail(state, puzzle, storage);
        }
      }
    },
    useHint() {
      if (session.hintUsed || !puzzle || session.solved || session.failed) return;
      const letter = engine.letterToReveal(puzzle.answer, session.correct);
      if (!letter) return;
      session.correct.add(letter);
      session.hintUsed = true;
    },
    submit() {
      if (!session.needsSubmit) return;
      session.solved = true;
      session.solvedThisSession += 1;
      recordSolve(state, puzzle, storage);
    },
    advance() {
      if (puzzle) {
        const buf = [...(state.recentEndlessIds ?? []), puzzle.id];
        state.recentEndlessIds = buf.slice(-RECENT_BUFFER);
        us.save(state, storage);
      }
      session.hearts = MAX_HEARTS;
      session.correct = new Set();
      session.wrong = new Set();
      session.solved = false;
      session.failed = false;
      session.hintUsed = false;
      session.hasShownOneChanceWarning = false;
      puzzle = nextPuzzle(allPuzzles, state, today);
    },
  };
  return session;
}

function recordSolve(state, puzzle, storage) {
  if (!state.solvedPuzzleIds.includes(puzzle.id)) {
    state.solvedPuzzleIds = [...state.solvedPuzzleIds, puzzle.id];
  }
  state.lifetimeSolvedCount += 1;
  us.save(state, storage);
}

function recordFail(state, puzzle, storage) {
  if (!state.failedPuzzleIds.includes(puzzle.id)) {
    state.failedPuzzleIds = [...state.failedPuzzleIds, puzzle.id];
  }
  us.save(state, storage);
}
```

- [ ] **Step 2: Modify `web/js/main.js` to render Endless screen**

Replace `boot()` and add `renderEndless()`. After the `boot()` `tab.addEventListener` block, add a call to render Endless when its screen is shown.

Find the existing block in `web/js/main.js`:
```js
  // Tab routing
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => ui.showScreen(tab.dataset.screen));
  }
```

Replace it with:
```js
  // Tab routing
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => {
      ui.showScreen(tab.dataset.screen);
      if (tab.dataset.screen === 'endless') {
        ensureEndlessScreen(loader.allPuzzles, state, today, storage);
      }
    });
  }
```

Then, at the top of `web/js/main.js`, change the import line:
```js
import { createTodaySession } from './today-session.js';
```
to also import the Endless session:
```js
import { createTodaySession } from './today-session.js';
import { createEndlessSession } from './endless-session.js';
```

Append to `web/js/main.js`:
```js
let endlessRendered = false;
function ensureEndlessScreen(allPuzzles, state, today, storage) {
  if (endlessRendered) return;
  endlessRendered = true;
  const session = createEndlessSession(allPuzzles, state, today, storage);
  const root = document.querySelector('#screen-endless');

  function rerender(awaitingNext = false) {
    if (!session.currentPuzzle) {
      root.replaceChildren(ui.el('div', { class: 'sticker' }, [
        ui.el('h2', {}, ['🎉 You\'ve played every puzzle!']),
        ui.el('p', {}, ['Come back tomorrow for a fresh Daily.']),
      ]));
      return;
    }
    if (awaitingNext) {
      root.replaceChildren(ui.el('div', { style: 'display:flex;flex-direction:column;gap:18px;align-items:center;padding:48px 16px' }, [
        ui.el('p', { style: 'opacity:0.7' }, [session.solvedThisSession === 0 ? 'Better luck next round.' : 'Nice. Keep going?']),
        ui.el('button', {
          class: 'btn-sticker btn-sticker--green',
          onclick: () => { session.advance(); rerender(false); },
        }, ['Next puzzle →']),
      ]));
      return;
    }
    const p = session.currentPuzzle;
    root.replaceChildren(
      ui.el('div', { style: 'display:flex;justify-content:space-between;align-items:center' }, [
        ui.el('button', {
          class: 'btn-sticker sticker--soft',
          style: 'padding:8px 12px;font-size:14px',
          onclick: () => ui.showScreen('today'),
        }, ['✕ End Session']),
        ui.el('span', { style: 'font-size:14px;opacity:0.7;font-weight:800' }, [
          session.solvedThisSession === 0 ? 'Just started'
            : session.solvedThisSession === 1 ? '1 solved'
            : `${session.solvedThisSession} solved`
        ]),
      ]),
      ui.renderHearts(session.hearts),
      ui.el('div', { class: 'emoji-header' }, [p.emoji]),
      ui.renderCategoryChip(p.category, null),
      ui.renderBlanks(p.answer, session.correct, null),
      ui.el('div', { style: 'display:flex;justify-content:flex-end' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow',
          disabled: session.hintUsed || session.solved || session.failed,
          onclick: () => { session.useHint(); afterAction(); },
        }, ['💡 Hint']),
      ]),
      session.needsSubmit ? ui.el('button', {
        class: 'btn-sticker btn-sticker--green',
        onclick: () => { session.submit(); afterAction(); },
      }, ['Submit ✓']) : null,
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed || session.needsSubmit,
        onGuess: (l) => { session.guess(l); afterAction(); },
      }),
    );
  }

  function afterAction() {
    rerender(false);
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      ui.showModal(({ close }) => ui.el('div', {}, [
        ui.el('h2', {}, ['One chance left']),
        ui.el('p', {}, ['Make it count — one more wrong guess ends the puzzle.']),
        ui.el('button', { class: 'btn-sticker', onclick: close }, ['OK']),
      ]));
    }
    if (session.solved || session.failed) {
      setTimeout(() => rerender(true), 1500);
    }
  }
  rerender(false);
}
```

- [ ] **Step 3: Verify Endless in the browser**

Refresh `http://localhost:8080/`. Tap **Endless** tab.

Manual QA:
- A puzzle different from today's Daily loads.
- The top bar shows "✕ End Session" (left) and "Just started" (right).
- After solving, the screen waits and then shows "Nice. Keep going?" + green "Next puzzle →" button.
- Pressing "Next puzzle →" loads a new puzzle (different from what just solved if pool allows).
- Solved counter increments (1 solved, 2 solved…).
- Failing a puzzle shows "Better luck next round." instead.
- "✕ End Session" returns to the Play tab.

- [ ] **Step 4: Commit**

```bash
git add web/js/endless-session.js web/js/main.js
git commit -m "web: Endless mode — EndlessSession + Next-puzzle gating + session counter"
```

---

## Task 10: Win/Fail celebrations + sounds

**Files:**
- Create: `web/js/celebration.js`
- Modify: `web/js/main.js` (call celebrations from `afterAction`)

- [ ] **Step 1: Write `web/js/celebration.js`**

Canvas-based fireworks (win) and rain (fail). Returns a Promise that resolves when animation finishes. Plays the relevant sound on call.

```js
// Mirrors Pictok/Views/Effects (Fireworks/Rain). Returns a Promise resolved when done.

const COLORS = ['#FFD60A', '#E63946', '#06D6A0', '#118AB2'];

export function celebrateWin() {
  playSound('sounds/win.wav');
  return runCanvas(fireworks, 1800);
}

export function celebrateFail() {
  playSound('sounds/fail.wav');
  return runCanvas(rain, 2800);
}

export function tickCorrect() { playSound('sounds/correct.wav', 0.25); }
export function tickWrong()   { playSound('sounds/wrong.wav', 0.4); }

function playSound(src, volume = 0.5) {
  try {
    const a = new Audio(src);
    a.volume = volume;
    a.play().catch(() => { /* user-gesture gated; ignore */ });
  } catch { /* ignore */ }
}

function runCanvas(drawFrame, totalMs) {
  return new Promise(resolve => {
    const canvas = document.createElement('canvas');
    canvas.className = 'celebration';
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    document.body.appendChild(canvas);
    const ctx = canvas.getContext('2d');
    const start = performance.now();
    let raf;
    const tick = (now) => {
      const t = (now - start) / totalMs;
      if (t >= 1) {
        cancelAnimationFrame(raf);
        canvas.remove();
        resolve();
        return;
      }
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawFrame(ctx, t, canvas.width, canvas.height);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });
}

// Fireworks: 6 bursts, each ~30 particles, gravity-arcing.
function fireworks(ctx, t, W, H) {
  const burstCount = 6;
  for (let b = 0; b < burstCount; b++) {
    const delay = b * 0.12;
    const local = t - delay;
    if (local < 0 || local > 0.6) continue;
    const cx = (W / (burstCount + 1)) * (b + 1) + ((b % 2) ? 30 : -30);
    const cy = H * (0.3 + 0.15 * Math.sin(b));
    const color = COLORS[b % COLORS.length];
    drawBurst(ctx, cx, cy, local / 0.6, color);
  }
}

function drawBurst(ctx, cx, cy, p, color) {
  const N = 30;
  for (let i = 0; i < N; i++) {
    const angle = (i / N) * Math.PI * 2;
    const speed = 180 * p;
    const x = cx + Math.cos(angle) * speed;
    const y = cy + Math.sin(angle) * speed + (p * p * 90);  // gravity
    const alpha = Math.max(0, 1 - p);
    ctx.fillStyle = color;
    ctx.globalAlpha = alpha;
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

// Rain: 40 blue drops streaming down.
function rain(ctx, t, W, H) {
  const N = 40;
  for (let i = 0; i < N; i++) {
    const x = ((i * 53) % W);
    const speed = 600 + ((i * 31) % 200);
    const y = ((t * speed + i * 47) % (H + 40)) - 20;
    const alpha = Math.max(0, 1 - t * 0.6);
    ctx.strokeStyle = '#118AB2';
    ctx.globalAlpha = alpha;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - 4, y + 14);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}
```

- [ ] **Step 2: Wire celebrations into `main.js`**

At the top of `web/js/main.js`, add:
```js
import { celebrateWin, celebrateFail, tickCorrect, tickWrong } from './celebration.js';
```

In the Today `afterAction()` (inside `renderToday`), replace the `if (session.solved) showResultModal(...)` block with:
```js
    if (session.solved) {
      celebrateWin().then(() => showResultModal(session, state, true));
    }
    if (session.failed) {
      celebrateFail().then(() => showResultModal(session, state, false));
    }
```

In the Today `afterAction()`, add right before that, after `rerender():`:
```js
    // Tick sound on the most recent guess result. (We infer correct/wrong from
    // whether the last appended letter is in correct or wrong sets.)
```
(Better — pass a flag from `session.guess()`. Make the surface explicit.)

Modify `web/js/today-session.js`'s `guess()` to return the result:
- Before: `guess(letter) { ... }`
- After: `guess(letter) { ...; return engine.isCorrect(u, puzzle.answer) ? 'correct' : 'wrong'; }` (capture the boolean before mutating).

Specifically, rewrite the relevant lines:
```js
    guess(letter) {
      if (state.todaySolved || state.todayFailed) return null;
      const u = String(letter).toUpperCase();
      if (this.correct.has(u) || this.wrong.has(u)) return null;
      const correct = engine.isCorrect(u, puzzle.answer);
      if (correct) {
        state.todayCorrectGuesses = [...state.todayCorrectGuesses, u];
      } else {
        state.todayWrongGuesses = [...state.todayWrongGuesses, u];
        state.lives = Math.max(0, state.lives - 1);
        if (state.lives === 1 && !session._oneChanceShown) {
          session._oneChanceShown = true;
        }
        if (engine.isFailed(state.lives)) {
          state.todayFailed = true;
          recordFailure(state, puzzle);
        }
      }
      us.save(state, storage);
      return correct ? 'correct' : 'wrong';
    },
```

In `web/js/main.js` `renderToday`'s `onGuess` handler:
```js
        onGuess: (letter) => {
          const r = session.guess(letter);
          if (r === 'correct') tickCorrect();
          if (r === 'wrong')   tickWrong();
          afterAction();
        },
```

Modify `web/js/endless-session.js` `guess()` the same way. Find:
```js
    guess(letter) {
      if (!puzzle || session.solved || session.failed) return;
      const u = String(letter).toUpperCase();
      if (session.correct.has(u) || session.wrong.has(u)) return;
      if (engine.isCorrect(u, puzzle.answer)) {
        session.correct.add(u);
      } else {
```
Replace with:
```js
    guess(letter) {
      if (!puzzle || session.solved || session.failed) return null;
      const u = String(letter).toUpperCase();
      if (session.correct.has(u) || session.wrong.has(u)) return null;
      const correct = engine.isCorrect(u, puzzle.answer);
      if (correct) {
        session.correct.add(u);
      } else {
```
And at the end of the function (before the closing `}` of `guess`), add `return correct ? 'correct' : 'wrong';`.

In `web/js/main.js` `ensureEndlessScreen`'s `onGuess` handler:
```js
        onGuess: (l) => {
          const r = session.guess(l);
          if (r === 'correct') tickCorrect();
          if (r === 'wrong')   tickWrong();
          afterAction();
        },
```

In `web/js/main.js` `ensureEndlessScreen`'s `afterAction`, replace:
```js
    if (session.solved || session.failed) {
      setTimeout(() => rerender(true), 1500);
    }
```
with:
```js
    if (session.solved) {
      celebrateWin().then(() => rerender(true));
    } else if (session.failed) {
      celebrateFail().then(() => rerender(true));
    }
```

- [ ] **Step 3: Verify in the browser**

Refresh. Solve today's Daily (or Endless puzzle). Confirm:
- Each correct guess plays a soft click.
- Each wrong guess plays a duller thunk.
- On solve, fireworks animation runs over the screen for ~1.8s, "win" sound plays, then result modal appears.
- On fail, rain falls for ~2.8s, "fail" sound plays, then result modal / next button appears.

- [ ] **Step 4: Commit**

```bash
git add web/js/celebration.js web/js/today-session.js web/js/endless-session.js web/js/main.js
git commit -m "web: win fireworks + fail rain canvases + correct/wrong tick sounds"
```

---

## Task 11: Stats screen

**Files:**
- Create: `web/js/stats.js`
- Create: `web/tests/stats.test.js`
- Modify: `web/js/main.js` (render Stats on tab click)

- [ ] **Step 1: Write failing tests for stats math**

`web/tests/stats.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { winPercent, maxDistributionCount } from '../js/stats.js';

test('winPercent: 0 played -> 0', () => {
  assert.equal(winPercent({ totalSolved: 0, totalPlayed: 0 }), 0);
});

test('winPercent: 3/4 -> 75', () => {
  assert.equal(winPercent({ totalSolved: 3, totalPlayed: 4 }), 75);
});

test('winPercent: rounds to nearest int', () => {
  assert.equal(winPercent({ totalSolved: 2, totalPlayed: 3 }), 67);
});

test('maxDistributionCount: empty -> 0', () => {
  assert.equal(maxDistributionCount({}), 0);
});

test('maxDistributionCount: returns max', () => {
  assert.equal(maxDistributionCount({ '0': 2, '1': 5, '2': 3 }), 5);
});
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement `web/js/stats.js`**

```js
// Pure stats math + DOM render of the Stats screen.

export function winPercent({ totalSolved, totalPlayed }) {
  if (!totalPlayed) return 0;
  return Math.round((totalSolved / totalPlayed) * 100);
}

export function maxDistributionCount(dist) {
  const vals = Object.values(dist ?? {});
  return vals.length ? Math.max(...vals) : 0;
}

import { el } from './ui.js';

export function renderStats(state) {
  const pct = winPercent(state);
  const max = maxDistributionCount(state.guessDistribution);

  return el('div', { style: 'display:flex;flex-direction:column;gap:14px' }, [
    pairCard('Current streak', state.currentStreak, 'Longest', state.longestStreak),
    pairCard('Lifetime solved', state.lifetimeSolvedCount, 'Win %', `${pct}%`),
    distributionCard(state.guessDistribution, max),
  ]);
}

function pairCard(labelA, valueA, labelB, valueB) {
  return el('div', { class: 'sticker', style: 'display:grid;grid-template-columns:1fr 1px 1fr;align-items:center;gap:0;padding:18px' }, [
    statCell(labelA, valueA),
    el('div', { style: 'width:1px;background:rgba(0,0,0,0.1);height:48px;justify-self:center' }),
    statCell(labelB, valueB),
  ]);
}

function statCell(label, value) {
  return el('div', { style: 'display:flex;flex-direction:column;align-items:center;gap:4px' }, [
    el('div', { style: 'font-size:32px;font-weight:900' }, [String(value)]),
    el('div', { style: 'font-size:12px;opacity:0.6;text-transform:uppercase;letter-spacing:0.06em' }, [label]),
  ]);
}

function distributionCard(dist, max) {
  const buckets = [0, 1, 2, 3, 4, 5];
  return el('div', { class: 'sticker', style: 'padding:18px;display:flex;flex-direction:column;gap:8px' }, [
    el('div', { style: 'font-size:12px;opacity:0.6;text-transform:uppercase;letter-spacing:0.06em' }, ['Guess distribution']),
    ...buckets.map(b => {
      const count = dist[b] ?? 0;
      const widthPct = max ? Math.max(4, (count / max) * 100) : 4;
      return el('div', { style: 'display:flex;align-items:center;gap:8px' }, [
        el('div', { style: 'width:18px;font-size:13px;font-weight:700;text-align:right' }, [String(b)]),
        el('div', { style: `background:var(--pk-green);height:18px;border-radius:4px;width:${widthPct}%;display:flex;align-items:center;justify-content:flex-end;padding:0 6px;font-size:12px;font-weight:800;color:var(--pk-ink);min-width:24px` }, [count > 0 ? String(count) : '']),
      ]);
    }),
  ]);
}
```

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Wire Stats into main.js**

In the `tab.addEventListener` handler in `boot()`, expand:
```js
    tab.addEventListener('click', () => {
      ui.showScreen(tab.dataset.screen);
      if (tab.dataset.screen === 'endless') {
        ensureEndlessScreen(loader.allPuzzles, state, today, storage);
      }
      if (tab.dataset.screen === 'stats') {
        document.querySelector('#screen-stats').replaceChildren(stats.renderStats(state));
      }
    });
```

At the top of `web/js/main.js`, add:
```js
import * as stats from './stats.js';
```

- [ ] **Step 6: Verify in the browser**

Refresh. Solve today's Daily (if not already solved). Tap Stats tab.
- Current streak / Longest streak card visible.
- Lifetime solved / Win % card visible.
- Guess distribution bar chart with row 0 highlighted (1 solve, 0 wrong).
- Refreshing the page preserves stats.

- [ ] **Step 7: Commit**

```bash
git add web/js/stats.js web/tests/stats.test.js web/js/main.js
git commit -m "web: Stats screen — editorial cards + guess distribution chart"
```

---

## Task 12: Share button + Web Share API

**Files:**
- Modify: `web/js/share.js` (add `shareText()` runtime function)
- Modify: `web/js/main.js` (add Share button to result modal)

- [ ] **Step 1: Add `shareText()` runtime function**

Append to `web/js/share.js`:
```js
/// Runtime share: native sheet if supported, else clipboard with toast.
export async function shareText(text, { onClipboardSuccess } = {}) {
  if (typeof navigator !== 'undefined' && navigator.share) {
    try {
      await navigator.share({ text });
      return 'shared';
    } catch (err) {
      if (err && err.name === 'AbortError') return 'cancelled';
      // Fall through to clipboard.
    }
  }
  if (typeof navigator !== 'undefined' && navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(text);
      onClipboardSuccess?.();
      return 'copied';
    } catch { /* ignore */ }
  }
  return 'failed';
}
```

- [ ] **Step 2: Hook Share into the success modal in `main.js`**

In `web/js/main.js`, find `showResultModal` and replace with:
```js
function showResultModal(session, state, success) {
  const url = 'pictok.app';
  const shareTextValue = success
    ? share.successCard({
        heartsRemaining: state.lives,
        hintUsed: session.hintUsed,
        currentStreak: state.currentStreak,
        url,
      })
    : share.failureCard({
        previousStreak: Math.max(state.currentStreak, state.longestStreak),
        url,
      });

  ui.showModal(({ close }) => ui.el('div', {}, [
    ui.el('h2', {}, [success ? '🎉 You solved it!' : '💔 Better luck tomorrow']),
    ui.el('p', {}, [`Answer: ${session.puzzle.answer}`]),
    ui.el('p', {}, [`Streak: ${state.currentStreak}`]),
    ui.el('div', { style: 'display:flex;gap:8px' }, [
      ui.el('button', {
        class: 'btn-sticker btn-sticker--green',
        onclick: async () => {
          const r = await share.shareText(shareTextValue, {
            onClipboardSuccess: () => ui.showToast('Copied — paste it anywhere!'),
          });
          if (r === 'failed') ui.showToast('Share unavailable');
        },
      }, ['Share']),
      ui.el('button', { class: 'btn-sticker', onclick: close }, ['Close']),
    ]),
  ]));
}
```

Also at the top of `web/js/main.js`, add:
```js
import * as share from './share.js';
```

- [ ] **Step 3: Verify in the browser**

Refresh. Solve today's Daily.
- Share button appears in the result modal.
- Tap Share: on mobile Safari/Chrome the native share sheet opens; on desktop it copies to clipboard.
- A toast appears confirming the copy.
- The copied/shared text is the exact `successCard()` output with the Unicode-bold challenge line.

- [ ] **Step 4: Commit**

```bash
git add web/js/share.js web/js/main.js
git commit -m "web: Share button — Web Share API on mobile, clipboard + toast on desktop"
```

---

## Task 13: PWA manifest + icons

**Files:**
- Create: `web/manifest.webmanifest`
- Create: `web/icon-192.png` and `web/icon-512.png` (copies of iOS App Icon)
- Modify: `web/index.html` (link manifest + Apple touch icon)

- [ ] **Step 1: Generate the two PWA icon sizes from the iOS App Icon source**

Source file: `/Users/rehatchugh/emoji-decode/Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024×1024).

Run:
```bash
sips -z 192 192 /Users/rehatchugh/emoji-decode/Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out /Users/rehatchugh/emoji-decode/web/icon-192.png
sips -z 512 512 /Users/rehatchugh/emoji-decode/Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out /Users/rehatchugh/emoji-decode/web/icon-512.png
```

Verify:
```bash
file /Users/rehatchugh/emoji-decode/web/icon-192.png /Users/rehatchugh/emoji-decode/web/icon-512.png
```
Expected: both report `PNG image data` with the right dimensions.

- [ ] **Step 2: Write `web/manifest.webmanifest`**

```json
{
  "name": "Pictok",
  "short_name": "Pictok",
  "description": "Daily emoji-decode puzzle. One per day.",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FEF3D9",
  "theme_color": "#FEF3D9",
  "orientation": "portrait",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
```

- [ ] **Step 3: Link manifest from index.html**

In `web/index.html`, inside `<head>`, after the existing `<meta name="theme-color">` line, add:
```html
  <link rel="manifest" href="manifest.webmanifest" />
  <link rel="apple-touch-icon" href="icon-192.png" />
```

- [ ] **Step 4: Verify in the browser**

Refresh `http://localhost:8080/`. Open DevTools → Application → Manifest. Confirm:
- Name: Pictok
- Icons render correctly
- No manifest errors

- [ ] **Step 5: Commit**

```bash
git add web/manifest.webmanifest web/icon-192.png web/icon-512.png web/index.html
git commit -m "web: PWA manifest + 192/512 icons + Apple touch icon"
```

---

## Task 14: Service worker for offline play

**Files:**
- Create: `web/sw.js`
- Modify: `web/js/main.js` (register the SW)

- [ ] **Step 1: Write `web/sw.js`**

Cache-first for static assets. Network-first for nothing (this is a static SPA — no dynamic content).

```js
// Pictok service worker. Cache-first for all listed assets.

const CACHE = 'pictok-v1';
const ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/manifest.webmanifest',
  '/puzzles.json',
  '/icon-192.png',
  '/icon-512.png',
  '/sounds/correct.wav',
  '/sounds/wrong.wav',
  '/sounds/win.wav',
  '/sounds/fail.wav',
  '/js/main.js',
  '/js/ui.js',
  '/js/game-engine.js',
  '/js/user-state.js',
  '/js/puzzle-loader.js',
  '/js/endless-selector.js',
  '/js/endless-session.js',
  '/js/today-session.js',
  '/js/celebration.js',
  '/js/stats.js',
  '/js/share.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(hit => hit ?? fetch(e.request).then(res => {
      const clone = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, clone));
      return res;
    }).catch(() => caches.match('/')))
  );
});
```

- [ ] **Step 2: Register the service worker in `main.js`**

At the bottom of `web/js/main.js`, before `boot()`, add:
```js
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(err =>
    console.warn('SW registration failed:', err)
  );
}
```

- [ ] **Step 3: Verify in the browser**

Refresh `http://localhost:8080/`. In DevTools → Application → Service Workers, confirm `sw.js` is **activated and running**. Then in Network tab, throttle to "Offline" and refresh — the app should still load and Today's puzzle should play.

- [ ] **Step 4: Commit**

```bash
git add web/sw.js web/js/main.js
git commit -m "web: service worker — cache-first for static assets, offline-capable"
```

---

## Task 15: Cloudflare Pages deploy + custom domain

**Files:**
- Modify: `README.md` (or create `web/README.md`) — deployment notes

This task is operator-driven. The plan documents the steps; the human runs them in the Cloudflare dashboard.

- [ ] **Step 1: Push the repo to GitHub if not already done**

Run: `cd /Users/rehatchugh/emoji-decode && git remote -v`
If no remote, the human creates a GitHub repo and runs `git remote add origin <url>` then `git push -u origin main`.

- [ ] **Step 2: Create the Cloudflare Pages project**

Operator steps:
1. Log in to dash.cloudflare.com → Workers & Pages → Create application → Pages → Connect to Git.
2. Authorize Cloudflare's GitHub App if not already done.
3. Select the `emoji-decode` repo.
4. Build settings:
   - **Framework preset:** None
   - **Build command:** (leave empty)
   - **Build output directory:** `web`
   - **Root directory:** (leave empty / repo root)
5. Click **Save and Deploy**. Cloudflare builds and assigns a `*.pages.dev` URL.

- [ ] **Step 3: Test the `*.pages.dev` URL**

The operator opens the assigned `https://pictok-<hash>.pages.dev` URL. Verify:
- Today's puzzle loads.
- Endless mode works.
- Service worker registers (DevTools → Application → SW).

- [ ] **Step 4: Connect the custom domain `pictok.app`**

Operator steps:
1. In the Cloudflare Pages project: **Custom domains** → Set up a custom domain → enter `pictok.app`.
2. If `pictok.app` already uses Cloudflare nameservers (it does, since the user owns it via Cloudflare or has pointed nameservers there), Cloudflare auto-creates the CNAME. Otherwise, follow the on-screen DNS instructions.
3. Wait 1–5 minutes for the SSL cert to issue.
4. Visit `https://pictok.app/` — should load the game.

- [ ] **Step 5: Write `web/README.md` with deploy & sync notes**

```markdown
# Pictok Web

The browser version of Pictok at https://pictok.app.

## Local development

```bash
cd web
python3 -m http.server 8080
```
Visit http://localhost:8080.

## Run tests

```bash
cd web
npm test
```

## Sync puzzles & sounds from the iOS source of truth

Whenever `Pictok/Resources/puzzles.json` or `Pictok/Resources/Sounds/*.wav` changes:

```bash
cd web
./sync-puzzles.sh
```
Commit the resulting changes to `web/puzzles.json` and `web/sounds/*`.

## Deploy

Pushes to `main` auto-deploy to Cloudflare Pages.
Build output directory: `web`. No build step.
```

- [ ] **Step 6: Commit + push**

```bash
git add web/README.md
git commit -m "web: deploy notes — Cloudflare Pages, custom domain, sync script"
git push origin main
```

- [ ] **Step 7: End-to-end production verification**

The operator opens `https://pictok.app/` on:
- A desktop browser
- An iOS phone Safari (tap Share → "Add to Home Screen" — verify it installs as a PWA with the Pictok icon)
- An Android Chrome

Verify on each: Today's puzzle loads, Endless works, Stats render, Share works.

---

## Final verification

Run the full test suite:
```bash
cd /Users/rehatchugh/emoji-decode/web && npm test
```
Expected: all tests pass across game-engine.test.js, user-state.test.js, puzzle-loader.test.js, endless-selector.test.js, share.test.js, stats.test.js.

Run a final manual smoke test at `https://pictok.app/`:
- Play and solve Today's Daily.
- Share. The native share sheet opens (mobile) or text is copied (desktop). Verify the bold "𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲?" appears.
- Refresh the page — progress persists.
- Play Endless mode: solve 2 puzzles in a row, confirm "Next puzzle →" gating + counter.
- Open Stats — all numbers match what just happened.
- Go offline (airplane mode) — game still plays.
