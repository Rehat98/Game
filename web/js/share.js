// Mirrors Pictok/Game/ShareCardBuilder.swift. Pure text builders.
// Uses Unicode Mathematical Sans-Serif Bold codepoints for bold-without-Markdown.
// Performance is shown via a 5-wide hearts strip (❤️ remaining, 🖤 lost),
// with a 💡 suffix when a hint was used.

export const CHALLENGE_BOLD = '🎯 𝗖𝗮𝗻 𝘆𝗼𝘂 𝗯𝗲𝗮𝘁 𝗺𝗲? 🎯';
export const FAIL_BOLD      = '🎯 𝗧𝗮𝗸𝗲 𝗮 𝘀𝘄𝗶𝗻𝗴? 🎯';

export function successCard({ heartsRemaining, hintUsed, currentStreak, url }) {
  const hearts = heartsLine(heartsRemaining, hintUsed);
  return `I solved today's Pictok!\n${hearts}\nStreak: ${currentStreak}\n\n${CHALLENGE_BOLD}\n→ ${url}`;
}

export function failureCard({ previousStreak, url }) {
  return `Today's Pictok beat me.\n🖤🖤🖤🖤🖤\nStreak: ${previousStreak} → 0\n\n${FAIL_BOLD}\n→ ${url}`;
}

function heartsLine(heartsRemaining, hintUsed) {
  const safe = Math.max(0, Math.min(5, heartsRemaining));
  const strip = '❤️'.repeat(safe) + '🖤'.repeat(5 - safe);
  return hintUsed ? `${strip} 💡` : strip;
}

/// Runtime share: native sheet if supported, else clipboard with toast.
export async function shareText(text, { onClipboardSuccess } = {}) {
  if (typeof navigator !== 'undefined' && navigator.share) {
    try {
      await navigator.share({ text });
      return 'shared';
    } catch (err) {
      if (err && err.name === 'AbortError') return 'cancelled';
      // Fall through to clipboard.
    }
  }
  if (typeof navigator !== 'undefined' && navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(text);
      onClipboardSuccess?.();
      return 'copied';
    } catch { /* ignore */ }
  }
  return 'failed';
}
