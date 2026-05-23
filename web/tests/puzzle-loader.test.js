import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import * as loader from '../js/puzzle-loader.js';

const SAMPLE = [
  { id: 'p1', date: '2026-05-18', emoji: '🧸📖', answer: 'TOY STORY',  category: 'Movie', subcategory: '',          difficulty: 'medium' },
  { id: 'p2', date: '2026-05-19', emoji: '👁️🤖',  answer: 'I ROBOT',    category: 'Movie', subcategory: '',          difficulty: 'hard'   },
  { id: 'p3', date: '2026-05-21', emoji: '💧🚽',  answer: 'WATERLOO',   category: 'Song',  subcategory: 'ABBA · 1974', difficulty: 'hard' },
];

test('PuzzleLoader.fromArray: indexes by date', () => {
  const pl = loader.fromArray(SAMPLE);
  assert.equal(pl.puzzleFor('2026-05-18').answer, 'TOY STORY');
  assert.equal(pl.puzzleFor('2026-05-21').answer, 'WATERLOO');
  assert.equal(pl.puzzleFor('2026-05-20'), null);
});

test('PuzzleLoader.allPuzzles: returns all', () => {
  const pl = loader.fromArray(SAMPLE);
  assert.equal(pl.allPuzzles.length, 3);
});

test('dateString: formats YYYY-MM-DD in given timezone', () => {
  const d = new Date('2026-05-21T17:30:00Z');
  assert.equal(loader.dateString(d, 'UTC'), '2026-05-21');
  // In a far-west timezone the wall-clock is earlier — still same day at 17:30 UTC.
  assert.equal(loader.dateString(d, 'America/Los_Angeles'), '2026-05-21');
  // Just past midnight UTC -> previous calendar day in LA.
  const d2 = new Date('2026-05-22T01:00:00Z');
  assert.equal(loader.dateString(d2, 'America/Los_Angeles'), '2026-05-21');
});

test('puzzles.json on disk parses and has 85 puzzles', async () => {
  const path = fileURLToPath(new URL('../puzzles.json', import.meta.url));
  const data = JSON.parse(await readFile(path, 'utf-8'));
  assert.equal(data.length, 85);
  assert.ok(data.every(p => p.id && p.date && p.answer));
});
