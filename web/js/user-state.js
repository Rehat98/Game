// Mirrors Pictok/Models/UserState.swift schema. Persists to localStorage.

export const STORAGE_KEY = 'pictok.state.v1';

export function fresh() {
  return {
    currentStreak: 0,
    longestStreak: 0,
    lastSolvedDate: null,
    streakFreezesAvailable: 1,
    totalSolved: 0,
    totalPlayed: 0,
    guessDistribution: {},
    lives: 5,
    todayPuzzleId: null,
    todayWrongGuesses: [],
    todayCorrectGuesses: [],
    todayHintUsed: null,
    todayRevealedLetter: null,
    todaySolved: false,
    todayFailed: false,
    hasEverSolved: false,
    hasAskedForNotificationPermission: false,
    solvedPuzzleIds: [],
    failedPuzzleIds: [],
    lifetimeSolvedCount: 0,
    recentEndlessIds: [],
    solveHistory: [],
  };
}

export function load(storage = globalThis.localStorage) {
  if (!storage) return fresh();
  const raw = storage.getItem(STORAGE_KEY);
  if (!raw) return fresh();
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return fresh();
  }
  return { ...fresh(), ...parsed };
}

export function save(state, storage = globalThis.localStorage) {
  if (!storage) return;
  storage.setItem(STORAGE_KEY, JSON.stringify(state));
}
