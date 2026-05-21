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
