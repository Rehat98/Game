// Pure stats math + DOM render of the Stats screen.

export function winPercent({ totalSolved, totalPlayed }) {
  if (!totalPlayed) return 0;
  return Math.round((totalSolved / totalPlayed) * 100);
}

export function maxDistributionCount(dist) {
  const vals = Object.values(dist ?? {});
  return vals.length ? Math.max(...vals) : 0;
}

import { el } from './ui.js';

export function renderStats(state) {
  const pct = winPercent(state);
  const max = maxDistributionCount(state.guessDistribution);

  return el('div', { style: 'display:flex;flex-direction:column;gap:14px' }, [
    pairCard('Current streak', state.currentStreak, 'Longest', state.longestStreak),
    pairCard('Lifetime solved', state.lifetimeSolvedCount, 'Win %', `${pct}%`),
    distributionCard(state.guessDistribution, max),
  ]);
}

function pairCard(labelA, valueA, labelB, valueB) {
  return el('div', { class: 'sticker', style: 'display:grid;grid-template-columns:1fr 1px 1fr;align-items:center;gap:0;padding:18px' }, [
    statCell(labelA, valueA),
    el('div', { style: 'width:1px;background:rgba(0,0,0,0.1);height:48px;justify-self:center' }),
    statCell(labelB, valueB),
  ]);
}

function statCell(label, value) {
  return el('div', { style: 'display:flex;flex-direction:column;align-items:center;gap:4px' }, [
    el('div', { style: 'font-size:32px;font-weight:900' }, [String(value)]),
    el('div', { style: 'font-size:12px;opacity:0.6;text-transform:uppercase;letter-spacing:0.06em' }, [label]),
  ]);
}

function distributionCard(dist, max) {
  const buckets = [0, 1, 2, 3, 4, 5];
  return el('div', { class: 'sticker', style: 'padding:18px;display:flex;flex-direction:column;gap:8px' }, [
    el('div', { style: 'font-size:12px;opacity:0.6;text-transform:uppercase;letter-spacing:0.06em' }, ['Guess distribution']),
    ...buckets.map(b => {
      const count = dist[b] ?? 0;
      const widthPct = max ? Math.max(4, (count / max) * 100) : 4;
      return el('div', { style: 'display:flex;align-items:center;gap:8px' }, [
        el('div', { style: 'width:18px;font-size:13px;font-weight:700;text-align:right' }, [String(b)]),
        el('div', { style: `background:var(--pk-green);height:18px;border-radius:4px;width:${widthPct}%;display:flex;align-items:center;justify-content:flex-end;padding:0 6px;font-size:12px;font-weight:800;color:var(--pk-ink);min-width:24px` }, [count > 0 ? String(count) : '']),
      ]);
    }),
  ]);
}
