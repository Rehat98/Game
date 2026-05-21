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
