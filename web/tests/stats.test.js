import { test } from 'node:test';
import assert from 'node:assert/strict';
import { winPercent, maxDistributionCount } from '../js/stats.js';

test('winPercent: 0 played -> 0', () => {
  assert.equal(winPercent({ totalSolved: 0, totalPlayed: 0 }), 0);
});

test('winPercent: 3/4 -> 75', () => {
  assert.equal(winPercent({ totalSolved: 3, totalPlayed: 4 }), 75);
});

test('winPercent: rounds to nearest int', () => {
  assert.equal(winPercent({ totalSolved: 2, totalPlayed: 3 }), 67);
});

test('maxDistributionCount: empty -> 0', () => {
  assert.equal(maxDistributionCount({}), 0);
});

test('maxDistributionCount: returns max', () => {
  assert.equal(maxDistributionCount({ '0': 2, '1': 5, '2': 3 }), 5);
});
