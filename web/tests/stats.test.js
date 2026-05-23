import { test } from 'node:test';
import assert from 'node:assert/strict';
import { winPercent, buildLastDays } from '../js/stats.js';

test('winPercent: 0 played -> 0', () => {
  assert.equal(winPercent({ totalSolved: 0, totalPlayed: 0 }), 0);
});

test('winPercent: 3/4 -> 75', () => {
  assert.equal(winPercent({ totalSolved: 3, totalPlayed: 4 }), 75);
});

test('winPercent: rounds to nearest int', () => {
  assert.equal(winPercent({ totalSolved: 2, totalPlayed: 3 }), 67);
});

test('buildLastDays: returns 10 cells by default ending today', () => {
  const cells = buildLastDays('2026-05-23', []);
  assert.equal(cells.length, 10);
  assert.equal(cells[9].date, '2026-05-23');
  assert.equal(cells[9].isToday, true);
  assert.equal(cells[0].date, '2026-05-14');
});

test('buildLastDays: history entries map to cells', () => {
  const cells = buildLastDays('2026-05-23', [
    { date: '2026-05-20', result: 'perfect' },
    { date: '2026-05-21', result: 'solved' },
    { date: '2026-05-22', result: 'failed' },
  ]);
  const by = Object.fromEntries(cells.map(c => [c.date, c.result]));
  assert.equal(by['2026-05-20'], 'perfect');
  assert.equal(by['2026-05-21'], 'solved');
  assert.equal(by['2026-05-22'], 'failed');
  assert.equal(by['2026-05-23'], null, 'today has no result yet');
});

test('buildLastDays: respects custom days count', () => {
  const cells = buildLastDays('2026-05-23', [], 5);
  assert.equal(cells.length, 5);
  assert.equal(cells[0].date, '2026-05-19');
  assert.equal(cells[4].date, '2026-05-23');
});

test('buildLastDays: cells in the past are never future', () => {
  const cells = buildLastDays('2026-05-23', []);
  for (const c of cells) {
    assert.equal(c.isFuture, false);
  }
});
