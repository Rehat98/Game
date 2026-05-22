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

test('recordArchiveOutcome: solved with no hint or wrong → perfect, lifetime fields bump', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 0, hintUsed: false });
  assert.ok(state.solvedPuzzleIds.includes('puzzle-010'));
  assert.equal(state.totalSolved, 1);
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.lifetimeSolvedCount, 1);
  assert.deepEqual(state.guessDistribution, { 0: 1 });
  assert.deepEqual(state.solveHistory, [{ date: '2026-05-10', result: 'perfect' }]);
});

test('recordArchiveOutcome: solved with hint → "solved" not "perfect"', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-011', date: '2026-05-11' },
                          { solved: true, wrongGuesses: 0, hintUsed: true });
  assert.equal(state.solveHistory[0].result, 'solved');
});

test('recordArchiveOutcome: failed → adds to failedPuzzleIds, no totalSolved', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-013', date: '2026-05-13' },
                          { solved: false, wrongGuesses: 5, hintUsed: false });
  assert.ok(state.failedPuzzleIds.includes('puzzle-013'));
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.totalSolved, 0);
  assert.equal(state.lifetimeSolvedCount, 0);
  assert.equal(state.solveHistory[0].result, 'failed');
});

test('recordArchiveOutcome: NEVER changes streak fields', () => {
  const state = us.fresh();
  state.currentStreak = 7;
  state.longestStreak = 12;
  state.lastSolvedDate = '2026-05-21';
  state.streakFreezesAvailable = 1;

  us.recordArchiveOutcome(state, { id: 'puzzle-009', date: '2026-05-09' },
                          { solved: true, wrongGuesses: 1, hintUsed: false });
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: false, wrongGuesses: 5, hintUsed: true });

  assert.equal(state.currentStreak, 7);
  assert.equal(state.longestStreak, 12);
  assert.equal(state.lastSolvedDate, '2026-05-21');
  assert.equal(state.streakFreezesAvailable, 1);
});

test('recordArchiveOutcome: replaces existing history entry for the same date', () => {
  const state = us.fresh();
  state.solveHistory = [{ date: '2026-05-10', result: 'failed' }];

  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 0, hintUsed: false });

  const matches = state.solveHistory.filter(h => h.date === '2026-05-10');
  assert.equal(matches.length, 1);
  assert.equal(matches[0].result, 'perfect');
});

test('recordArchiveOutcome: idempotent for same puzzleId — second call is a no-op', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 1, hintUsed: false });
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.totalSolved, 1);

  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 1, hintUsed: false });
  assert.equal(state.totalPlayed, 1, 'totalPlayed must not double on repeat call');
  assert.equal(state.totalSolved, 1);
  assert.equal(state.lifetimeSolvedCount, 1);
});

test('recordArchiveOutcome: previously-failed puzzleId cannot be retroactively solved', () => {
  const state = us.fresh();
  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: false, wrongGuesses: 5, hintUsed: false });

  us.recordArchiveOutcome(state, { id: 'puzzle-010', date: '2026-05-10' },
                          { solved: true, wrongGuesses: 0, hintUsed: false });
  assert.equal(state.totalPlayed, 1);
  assert.equal(state.totalSolved, 0);
  assert.ok(!state.solvedPuzzleIds.includes('puzzle-010'));
});
