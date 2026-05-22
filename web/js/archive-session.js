import * as engine from './game-engine.js';
import * as us from './user-state.js';

const MAX_HEARTS = 5;

/**
 * Creates a session pinned to a single past Daily puzzle. Records its outcome
 * via `us.recordArchiveOutcome` (streak-neutral) on solve or fail. Mirrors
 * iOS `ArchiveSession`. The optional `storage` argument is forwarded to
 * `us.save` after each terminal write; pass `globalThis.localStorage` in
 * production, omit for unit tests that only inspect the in-memory state.
 */
export function createArchiveSession(puzzle, state, storage) {
  const session = {
    puzzle,
    hearts: MAX_HEARTS,
    correct: new Set(),
    wrong: new Set(),
    solved: false,
    failed: false,
    hintUsed: false,
    hasShownOneChanceWarning: false,

    get needsSubmit() {
      if (session.solved || session.failed) return false;
      return engine.isSolved(puzzle.answer, session.correct, null);
    },

    guess(letter) {
      if (session.solved || session.failed) return;
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
          recordOutcome(state, session, false, storage);
        }
      }
    },

    submit() {
      if (!session.needsSubmit) return;
      session.solved = true;
      recordOutcome(state, session, true, storage);
    },

    useHint() {
      if (session.hintUsed || session.solved || session.failed) return;
      const letter = engine.letterToReveal(puzzle.answer, session.correct);
      if (!letter) return;
      session.correct.add(letter);
      session.hintUsed = true;
    },
  };

  return session;
}

function recordOutcome(state, session, solved, storage) {
  us.recordArchiveOutcome(state, session.puzzle, {
    solved,
    wrongGuesses: session.wrong.size,
    hintUsed: session.hintUsed,
  });
  if (storage) us.save(state, storage);
}
