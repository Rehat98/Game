// Daily-puzzle session: persistent across refresh via UserState.today*.
import * as engine from './game-engine.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;
const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

export function createTodaySession(puzzle, state, storage) {
  // Reset today's progress when the date rolls over (different puzzle than stored).
  if (state.todayPuzzleId !== puzzle.id) {
    state.todayPuzzleId = puzzle.id;
    state.todayWrongGuesses = [];
    state.todayCorrectGuesses = [];
    state.todayHintUsed = null;
    state.todayRevealedLetter = null;
    state.todaySolved = false;
    state.todayFailed = false;
    state.lives = MAX_HEARTS;
    us.save(state, storage);
  }

  const session = {
    puzzle,
    get lives()        { return state.lives; },
    get correct()      { return new Set(state.todayCorrectGuesses); },
    get wrong()        { return new Set(state.todayWrongGuesses); },
    get solved()       { return state.todaySolved; },
    get failed()       { return state.todayFailed; },
    get hintUsed()     { return state.todayHintUsed !== null; },
    get revealed()     { return state.todayRevealedLetter; },
    get hasShownOneChanceWarning() { return session._oneChanceShown; },
    _oneChanceShown: false,
    /** Returns true when the answer is fully revealed but Submit hasn't been pressed. */
    get needsSubmit() {
      if (state.todaySolved || state.todayFailed) return false;
      return engine.isSolved(puzzle.answer, this.correct, state.todayRevealedLetter);
    },
    guess(letter) {
      if (state.todaySolved || state.todayFailed) return null;
      const u = String(letter).toUpperCase();
      if (this.correct.has(u) || this.wrong.has(u)) return null;
      const correct = engine.isCorrect(u, puzzle.answer);
      if (correct) {
        state.todayCorrectGuesses = [...state.todayCorrectGuesses, u];
      } else {
        state.todayWrongGuesses = [...state.todayWrongGuesses, u];
        state.lives = Math.max(0, state.lives - 1);
        if (state.lives === 1 && !session._oneChanceShown) {
          session._oneChanceShown = true;
        }
        if (engine.isFailed(state.lives)) {
          state.todayFailed = true;
          recordFailure(state, puzzle);
        }
      }
      us.save(state, storage);
      return correct ? 'correct' : 'wrong';
    },
    useHint() {
      if (state.todayHintUsed || state.todaySolved || state.todayFailed) return;
      const letter = engine.letterToReveal(puzzle.answer, this.correct);
      if (!letter) return;
      state.todayRevealedLetter = letter;
      state.todayHintUsed = 'letter';
      state.lives = Math.max(0, state.lives - engine.heartCost('letter'));
      if (engine.isFailed(state.lives)) {
        state.todayFailed = true;
        recordFailure(state, puzzle);
      }
      us.save(state, storage);
    },
    submit(today) {
      if (!this.needsSubmit) return;
      state.todaySolved = true;
      recordSolve(state, puzzle, today);
      us.save(state, storage);
    },
  };
  return session;
}

function recordSolve(state, puzzle, today) {
  state.hasEverSolved = true;
  state.totalPlayed += 1;
  state.totalSolved += 1;
  state.lifetimeSolvedCount += 1;
  if (!state.solvedPuzzleIds.includes(puzzle.id)) {
    state.solvedPuzzleIds = [...state.solvedPuzzleIds, puzzle.id];
  }
  const wrongCount = state.todayWrongGuesses.length;
  state.guessDistribution[wrongCount] = (state.guessDistribution[wrongCount] ?? 0) + 1;
  const r = engine.streakAfterSolve(today, state.lastSolvedDate, state.currentStreak, state.streakFreezesAvailable);
  state.currentStreak = r.streak;
  state.streakFreezesAvailable = r.freezesAvailable;
  state.longestStreak = Math.max(state.longestStreak, state.currentStreak);
  state.lastSolvedDate = today;
}

function recordFailure(state, puzzle) {
  state.totalPlayed += 1;
  state.currentStreak = engine.streakAfterFail(state.currentStreak);
  if (!state.failedPuzzleIds.includes(puzzle.id)) {
    state.failedPuzzleIds = [...state.failedPuzzleIds, puzzle.id];
  }
}
