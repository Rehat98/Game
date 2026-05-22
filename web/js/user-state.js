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

/**
 * Records the outcome of an archive (catch-up) play. Mutates `state` in place:
 * updates lifetime fields and `solveHistory`, but never touches `currentStreak`,
 * `longestStreak`, `lastSolvedDate`, or `streakFreezesAvailable` — archive plays
 * are streak-neutral by design. Idempotent for the same puzzleId: if the puzzle
 * is already recorded as solved or failed, the call is a no-op (matches iOS).
 */
export function recordArchiveOutcome(state, puzzle, { solved, wrongGuesses, hintUsed }) {
  if (state.solvedPuzzleIds.includes(puzzle.id) ||
      state.failedPuzzleIds.includes(puzzle.id)) {
    return;
  }
  state.totalPlayed += 1;
  if (solved) {
    state.solvedPuzzleIds.push(puzzle.id);
    state.totalSolved += 1;
    state.lifetimeSolvedCount += 1;
    state.guessDistribution[wrongGuesses] = (state.guessDistribution[wrongGuesses] ?? 0) + 1;
  } else {
    state.failedPuzzleIds.push(puzzle.id);
  }
  const result = solved
    ? (wrongGuesses === 0 && !hintUsed ? 'perfect' : 'solved')
    : 'failed';
  state.solveHistory = state.solveHistory.filter(h => h.date !== puzzle.date);
  state.solveHistory.push({ date: puzzle.date, result });
}
