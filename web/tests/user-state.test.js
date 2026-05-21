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
