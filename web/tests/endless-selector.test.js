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
    // Sweep rng across [0, 1) to exercise every candidate index.
    const r = (i * 0.13) % 1;
    const pick = nextPuzzle(POOL, state, TODAY, () => r);
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

test('rng [0,1) values map across the full pool index range', () => {
  // Regression: an earlier impl used Math.floor(rng()) % pool.length, which
  // collapses every Math.random() return value to index 0. Verify the
  // selector actually maps [0, 1) floats across pool indexes.
  const state = fresh();
  state.solvedPuzzleIds = ['next-week', 'far'];   // narrow tier-1 to ['past'] only
  // Force tier-2 (any unseen): unseen candidates left = ['tomorrow'].
  // Try an rng() = 0.99 — must still pick the only candidate, not crash or return undefined.
  const pick = nextPuzzle(POOL, state, TODAY, () => 0.99);
  assert.equal(pick.id, 'past'); // tier-1 'past' is spoiler-safe (>7 days before today)

  // With pool of 3 spoiler-safe candidates and rng() = 0.99,
  // Math.floor(0.99 * 3) = 2 -> index 2. Previously buggy code gave 0.
  const state2 = fresh();
  const pick2 = nextPuzzle(POOL, state2, TODAY, () => 0.99);
  // tier-1 candidates in POOL order: tomorrow (excluded — inside window), next-week, far, past
  // safe filter keeps {next-week, far, past}. Index 2 must be 'past'.
  assert.equal(pick2.id, 'past',
    'rng=0.99 with 3 spoiler-safe candidates should pick index 2 (\'past\'), not index 0');
});
