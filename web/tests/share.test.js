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
