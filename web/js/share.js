// Mirrors Pictok/Game/ShareCardBuilder.swift. Pure text builders.
// Uses Unicode Mathematical Sans-Serif Bold codepoints for bold-without-Markdown.

export const CHALLENGE_BOLD = '🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯';
export const FAIL_BOLD      = '🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯';

export function successCard({ heartsRemaining, hintUsed, currentStreak, url }) {
  const heartsLost = Math.max(0, Math.min(5, 5 - heartsRemaining));
  const firstLine = challengeLine(hintUsed, heartsLost);
  return `${firstLine}\nStreak: ${currentStreak}\n\n${CHALLENGE_BOLD}\n→ ${url}`;
}

export function failureCard({ previousStreak, url }) {
  return `Today's Pictok beat me.\nStreak: ${previousStreak} → 0\n\n${FAIL_BOLD}\n→ ${url}`;
}

function challengeLine(hintUsed, heartsLost) {
  if (!hintUsed && heartsLost === 0) {
    return "I solved today's Pictok with no hints — perfect run.";
  }
  if (hintUsed && heartsLost === 0) {
    return "I solved today's Pictok using 1 hint.";
  }
  if (!hintUsed) {
    const noun = heartsLost === 1 ? 'guess' : 'guesses';
    return `I solved today's Pictok (${heartsLost} wrong ${noun}).`;
  }
  const noun = heartsLost === 1 ? 'guess' : 'guesses';
  return `I solved today's Pictok with 1 hint and ${heartsLost} wrong ${noun}.`;
}
