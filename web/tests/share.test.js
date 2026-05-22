import { test } from 'node:test';
import assert from 'node:assert/strict';
import { successCard, failureCard, CHALLENGE_BOLD, FAIL_BOLD } from '../js/share.js';

test('successCard: perfect run (no hint, no wrong)', () => {
  const card = successCard({
    heartsRemaining: 5, hintUsed: false, currentStreak: 7, url: 'pictok.app',
  });
  const expected =
    `I solved today's Pictok!\n` +
    `❤️❤️❤️❤️❤️\n` +
    `Streak: 7\n` +
    `\n` +
    `🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯\n` +
    `→ pictok.app`;
  assert.equal(card, expected);
});

test('successCard: hint used, no wrong → full hearts + 💡', () => {
  const card = successCard({ heartsRemaining: 5, hintUsed: true, currentStreak: 3, url: 'pictok.app' });
  assert.ok(card.includes('❤️❤️❤️❤️❤️ 💡'), card);
});

test('successCard: one wrong guess → 4❤️ + 1🖤', () => {
  const card = successCard({ heartsRemaining: 4, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('❤️❤️❤️❤️🖤'), card);
  assert.ok(!card.includes('💡'), card);
});

test('successCard: three wrong guesses → 2❤️ + 3🖤', () => {
  const card = successCard({ heartsRemaining: 2, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('❤️❤️🖤🖤🖤'), card);
});

test('successCard: hint AND wrong guesses → mixed strip + 💡', () => {
  const card = successCard({ heartsRemaining: 3, hintUsed: true, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes('❤️❤️❤️🖤🖤 💡'), card);
});

test('successCard: includes bold challenge line + URL, no puzzle index', () => {
  const card = successCard({ heartsRemaining: 5, hintUsed: false, currentStreak: 1, url: 'pictok.app' });
  assert.ok(card.includes(CHALLENGE_BOLD));
  assert.ok(card.includes('→ pictok.app'));
  assert.ok(!card.includes('#'));
});

test('successCard: clamps heartsRemaining to 0..5', () => {
  const over = successCard({ heartsRemaining: 99, hintUsed: false, currentStreak: 1, url: 'p' });
  assert.ok(over.includes('❤️❤️❤️❤️❤️'), over);
  const under = successCard({ heartsRemaining: -3, hintUsed: false, currentStreak: 1, url: 'p' });
  assert.ok(under.includes('🖤🖤🖤🖤🖤'), under);
});

test('failureCard: exact format', () => {
  const card = failureCard({ previousStreak: 7, url: 'pictok.app' });
  const expected =
    `Today's Pictok beat me.\n` +
    `🖤🖤🖤🖤🖤\n` +
    `Streak: 7 → 0\n` +
    `\n` +
    `🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯\n` +
    `→ pictok.app`;
  assert.equal(card, expected);
});
