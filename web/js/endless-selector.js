// Mirrors Pictok/Game/EndlessSelector.swift. 3-tier priority.

const SPOILER_WINDOW_DAYS = 7;

export function nextPuzzle(allPuzzles, state, today, rng = Math.random) {
  const candidates = allPuzzles.filter(p => p.date !== today);

  const seen = new Set([...(state.solvedPuzzleIds ?? []), ...(state.failedPuzzleIds ?? [])]);
  const unseen = candidates.filter(p => !seen.has(p.id));

  // Tier 1: unseen + spoiler-safe.
  const safe = unseen.filter(p => Math.abs(daysBetween(today, p.date)) > SPOILER_WINDOW_DAYS);
  const pick1 = randomPick(safe, rng);
  if (pick1) return pick1;

  // Tier 2: any unseen.
  const pick2 = randomPick(unseen, rng);
  if (pick2) return pick2;

  // Tier 3: replay, skip recent.
  const recent = new Set(state.recentEndlessIds ?? []);
  const replayable = candidates.filter(p => !recent.has(p.id));
  const pick3 = randomPick(replayable, rng);
  if (pick3) return pick3;

  // Last resort: any non-today candidate.
  return randomPick(candidates, rng);
}

function randomPick(pool, rng) {
  if (!pool.length) return null;
  const index = Math.floor(rng()) % pool.length;
  return pool[index];
}

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
