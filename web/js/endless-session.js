import * as engine from './game-engine.js';
import { nextPuzzle } from './endless-selector.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;
const RECENT_BUFFER = 5;

export function createEndlessSession(allPuzzles, state, today, storage) {
  let puzzle = nextPuzzle(allPuzzles, state, today);

  const session = {
    get currentPuzzle() { return puzzle; },
    hearts: MAX_HEARTS,
    correct: new Set(),
    wrong: new Set(),
    solved: false,
    failed: false,
    hintUsed: false,
    hasShownOneChanceWarning: false,
    solvedThisSession: 0,
    get needsSubmit() {
      if (!puzzle || session.solved || session.failed) return false;
      return engine.isSolved(puzzle.answer, session.correct, null);
    },
    guess(letter) {
      if (!puzzle || session.solved || session.failed) return;
      const u = String(letter).toUpperCase();
      if (session.correct.has(u) || session.wrong.has(u)) return;
      if (engine.isCorrect(u, puzzle.answer)) {
        session.correct.add(u);
      } else {
        session.wrong.add(u);
        session.hearts -= 1;
        if (session.hearts === 1 && !session.hasShownOneChanceWarning) {
          session.hasShownOneChanceWarning = true;
        }
        if (engine.isFailed(session.hearts)) {
          session.failed = true;
          recordFail(state, puzzle, storage);
        }
      }
    },
    useHint() {
      if (session.hintUsed || !puzzle || session.solved || session.failed) return;
      const letter = engine.letterToReveal(puzzle.answer, session.correct);
      if (!letter) return;
      session.correct.add(letter);
      session.hintUsed = true;
    },
    submit() {
      if (!session.needsSubmit) return;
      session.solved = true;
      session.solvedThisSession += 1;
      recordSolve(state, puzzle, storage);
    },
    advance() {
      if (puzzle) {
        const buf = [...(state.recentEndlessIds ?? []), puzzle.id];
        state.recentEndlessIds = buf.slice(-RECENT_BUFFER);
        us.save(state, storage);
      }
      session.hearts = MAX_HEARTS;
      session.correct = new Set();
      session.wrong = new Set();
      session.solved = false;
      session.failed = false;
      session.hintUsed = false;
      session.hasShownOneChanceWarning = false;
      puzzle = nextPuzzle(allPuzzles, state, today);
    },
  };
  return session;
}

function recordSolve(state, puzzle, storage) {
  if (!state.solvedPuzzleIds.includes(puzzle.id)) {
    state.solvedPuzzleIds = [...state.solvedPuzzleIds, puzzle.id];
  }
  state.lifetimeSolvedCount += 1;
  us.save(state, storage);
}

function recordFail(state, puzzle, storage) {
  if (!state.failedPuzzleIds.includes(puzzle.id)) {
    state.failedPuzzleIds = [...state.failedPuzzleIds, puzzle.id];
  }
  us.save(state, storage);
}
