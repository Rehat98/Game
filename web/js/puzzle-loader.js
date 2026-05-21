// Mirrors Pictok/Game/PuzzleLoader.swift. fetch()-based for browser, fromArray for tests.

export async function fromUrl(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch puzzles.json: ${res.status}`);
  const data = await res.json();
  return fromArray(data);
}

export function fromArray(puzzles) {
  const byDate = new Map(puzzles.map(p => [p.date, p]));
  return {
    allPuzzles: puzzles,
    puzzleFor(date) {
      return byDate.get(date) ?? null;
    },
  };
}

/// Formats a Date to "YYYY-MM-DD" in the given IANA timezone.
export function dateString(date, timeZone) {
  // en-CA uses YYYY-MM-DD natively, sidestepping locale formatting.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}
