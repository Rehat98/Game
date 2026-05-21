import { test } from 'node:test';
import assert from 'node:assert/strict';
import { winPercent, buildCalendarGrid } from '../js/stats.js';

test('winPercent: 0 played -> 0', () => {
  assert.equal(winPercent({ totalSolved: 0, totalPlayed: 0 }), 0);
});

test('winPercent: 3/4 -> 75', () => {
  assert.equal(winPercent({ totalSolved: 3, totalPlayed: 4 }), 75);
});

test('winPercent: rounds to nearest int', () => {
  assert.equal(winPercent({ totalSolved: 2, totalPlayed: 3 }), 67);
});

test('buildCalendarGrid: returns 4×7 by default', () => {
  // 2026-05-21 is a Thursday.
  const g = buildCalendarGrid('2026-05-21', []);
  assert.equal(g.length, 4);
  for (const row of g) assert.equal(row.length, 7);
});

test('buildCalendarGrid: today cell is marked, future cells flagged', () => {
  // Thursday 2026-05-21 → Mon-Sun current week, today at index 3 of last row.
  const g = buildCalendarGrid('2026-05-21', []);
  const lastRow = g[g.length - 1];
  assert.equal(lastRow[3].date, '2026-05-21');
  assert.equal(lastRow[3].isToday, true);
  assert.equal(lastRow[4].isFuture, true,  'Friday should be future');
  assert.equal(lastRow[2].isFuture, false, 'Wednesday should not be future');
});

test('buildCalendarGrid: history entries map to cells', () => {
  const g = buildCalendarGrid('2026-05-21', [
    { date: '2026-05-18', result: 'perfect' },
    { date: '2026-05-20', result: 'solved' },
    { date: '2026-05-19', result: 'failed' },
  ]);
  const flat = g.flat();
  const by = Object.fromEntries(flat.map(c => [c.date, c.result]));
  assert.equal(by['2026-05-18'], 'perfect');
  assert.equal(by['2026-05-19'], 'failed');
  assert.equal(by['2026-05-20'], 'solved');
  assert.equal(by['2026-05-21'], null, 'today has no result yet');
});

test('buildCalendarGrid: handles Sunday today (week-start edge)', () => {
  // 2026-05-24 is a Sunday — Monday-aligned week should put Sunday at index 6.
  const g = buildCalendarGrid('2026-05-24', []);
  const lastRow = g[g.length - 1];
  assert.equal(lastRow[6].date, '2026-05-24');
  assert.equal(lastRow[6].isToday, true);
});
