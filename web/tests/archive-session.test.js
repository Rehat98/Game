import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createArchiveSession } from '../js/archive-session.js';
import * as us from '../js/user-state.js';

function makePuzzle(answer = 'CAT') {
  return {
    id: 'puzzle-010', date: '2026-05-10', emoji: '🐱', answer,
    category: 'Movie', subcategory: 't', difficulty: 'medium',
  };
}

test('archive session: init pins puzzle, 5 hearts, no guesses', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  assert.equal(s.hearts, 5);
  assert.equal(s.puzzle.id, 'puzzle-010');
  assert.equal(s.correct.size, 0);
  assert.equal(s.wrong.size, 0);
  assert.equal(s.solved, false);
  assert.equal(s.failed, false);
});

test('archive session: correct guess adds letter, keeps hearts', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.guess('C');
  assert.ok(s.correct.has('C'));
  assert.equal(s.hearts, 5);
});

test('archive session: wrong guess adds letter, decrements hearts', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.guess('Z');
  assert.ok(s.wrong.has('Z'));
  assert.equal(s.hearts, 4);
});

test('archive session: submit when all letters revealed → solved + outcome recorded', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  assert.ok(s.needsSubmit);
  s.submit();
  assert.ok(s.solved);
  assert.ok(state.solvedPuzzleIds.includes('puzzle-010'));
  assert.equal(state.lifetimeSolvedCount, 1);
});

test('archive session: perfect run records as "perfect"', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  s.submit();
  assert.equal(state.solveHistory[0].result, 'perfect');
});

test('archive session: 5 wrong guesses → failed + outcome recorded', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  ['B', 'D', 'E', 'F', 'G'].forEach(l => s.guess(l));
  assert.ok(s.failed);
  assert.equal(s.hearts, 0);
  assert.ok(state.failedPuzzleIds.includes('puzzle-010'));
});

test('archive session: solve never changes streak fields', () => {
  const state = us.fresh();
  state.currentStreak = 4;
  state.longestStreak = 9;
  const s = createArchiveSession(makePuzzle(), state);
  ['C', 'A', 'T'].forEach(l => s.guess(l));
  s.submit();
  assert.equal(state.currentStreak, 4);
  assert.equal(state.longestStreak, 9);
});

test('archive session: useHint reveals one letter, keeps all hearts', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.useHint();
  assert.ok(s.hintUsed);
  assert.equal(s.hearts, 5);
  assert.equal(s.correct.size, 1);
});

test('archive session: second useHint is a no-op', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle(), state);
  s.useHint();
  const after1 = new Set(s.correct);
  s.useHint();
  assert.deepEqual(new Set(s.correct), after1, 'second useHint must not reveal another letter');
});

test('archive session: one-chance warning fires at 2→1 transition', () => {
  const state = us.fresh();
  const s = createArchiveSession(makePuzzle('AAA'), state);
  ['B', 'C', 'D'].forEach(l => s.guess(l));
  assert.equal(s.hearts, 2);
  assert.equal(s.hasShownOneChanceWarning, false);
  s.guess('E');
  assert.equal(s.hearts, 1);
  assert.equal(s.hasShownOneChanceWarning, true);
});
