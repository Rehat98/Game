// Mirrors Pictok/Game/GameEngine.swift. Keep this file pure — no DOM, no fetch.

const LETTER_RE = /^[A-Z]$/;

export function isCorrect(letter, answer) {
  const u = String(letter).toUpperCase();
  if (!LETTER_RE.test(u)) return false;
  return answer.toUpperCase().includes(u);
}

export function isSolved(answer, correctGuesses, revealedLetter) {
  const known = new Set(correctGuesses);
  if (revealedLetter) known.add(String(revealedLetter).toUpperCase());
  for (const ch of answer.toUpperCase()) {
    if (!LETTER_RE.test(ch)) continue;
    if (!known.has(ch)) return false;
  }
  return true;
}

export function isFailed(lives) {
  return lives <= 0;
}

export function heartCost(hintType) {
  return hintType === 'category' ? 1 : 2;
}

export function letterToReveal(answer, correctGuesses) {
  for (const ch of answer.toUpperCase()) {
    if (!LETTER_RE.test(ch)) continue;
    if (!correctGuesses.has(ch)) return ch;
  }
  return null;
}

export function streakAfterSolve(today, lastSolvedDate, currentStreak, freezesAvailable) {
  if (!lastSolvedDate) {
    return { streak: 1, freezesAvailable };
  }
  const apart = daysBetween(lastSolvedDate, today);
  if (apart === 1) {
    return { streak: currentStreak + 1, freezesAvailable };
  }
  if (apart === 2 && freezesAvailable > 0) {
    return { streak: currentStreak + 1, freezesAvailable: freezesAvailable - 1 };
  }
  return { streak: 1, freezesAvailable };
}

export function streakAfterFail(_currentStreak) {
  return 0;
}

// Days between two YYYY-MM-DD strings (interpreted as UTC midnight).
// Returns Number.MAX_SAFE_INTEGER on malformed input.
function daysBetween(a, b) {
  const da = parseYMD(a);
  const db = parseYMD(b);
  if (da === null || db === null) return Number.MAX_SAFE_INTEGER;
  return Math.round((db - da) / 86_400_000);
}

function parseYMD(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}
