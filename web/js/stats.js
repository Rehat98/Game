// Pure stats math + DOM render of the Stats screen.

export function winPercent({ totalSolved, totalPlayed }) {
  if (!totalPlayed) return 0;
  return Math.round((totalSolved / totalPlayed) * 100);
}

/// Builds a `weeks × 7` array of cells ending in the week that contains `today`.
/// Each cell: `{ date, result: 'perfect'|'solved'|'failed'|null, isToday, isFuture }`.
/// Weeks start on Monday.
export function buildCalendarGrid(today, solveHistory, weeks = 4) {
  const historyMap = new Map((solveHistory ?? []).map(h => [h.date, h.result]));
  const todayMs = parseYMD(today);
  if (todayMs === null) return [];

  const todayDate = new Date(todayMs);
  const dow = todayDate.getUTCDay();                  // 0=Sun, 1=Mon, ..., 6=Sat
  const daysFromMonday = dow === 0 ? 6 : dow - 1;
  const mondayThisWeek = todayMs - daysFromMonday * 86_400_000;
  const startMs = mondayThisWeek - (weeks - 1) * 7 * 86_400_000;

  const grid = [];
  for (let w = 0; w < weeks; w++) {
    const row = [];
    for (let d = 0; d < 7; d++) {
      const cellMs = startMs + (w * 7 + d) * 86_400_000;
      const cellDate = msToYMD(cellMs);
      row.push({
        date: cellDate,
        result: historyMap.get(cellDate) ?? null,
        isToday: cellDate === today,
        isFuture: cellMs > todayMs,
      });
    }
    grid.push(row);
  }
  return grid;
}

function parseYMD(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}

function msToYMD(ms) {
  const d = new Date(ms);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

import { el } from './ui.js';

export function renderStats(state, today) {
  const pct = winPercent(state);
  return el('div', { class: 'stats-screen' }, [
    pairCard('Current streak', state.currentStreak, 'Longest', state.longestStreak),
    pairCard('Lifetime solved', state.lifetimeSolvedCount, 'Win %', `${pct}%`),
    calendarCard(today, state.solveHistory ?? []),
  ]);
}

function pairCard(labelA, valueA, labelB, valueB) {
  return el('div', { class: 'sticker stats-pair' }, [
    statCell(labelA, valueA),
    el('div', { class: 'stats-pair-divider' }),
    statCell(labelB, valueB),
  ]);
}

function statCell(label, value) {
  return el('div', { class: 'stats-cell' }, [
    el('div', { class: 'stats-value' }, [String(value)]),
    el('div', { class: 'stats-label' }, [label]),
  ]);
}

function calendarCard(today, history) {
  const grid = buildCalendarGrid(today, history, 4);
  const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return el('div', { class: 'sticker calendar-card' }, [
    el('div', { class: 'stats-label calendar-eyebrow' }, ['Last 4 weeks']),
    el('div', { class: 'calendar-grid' }, [
      ...dayLabels.map(l => el('div', { class: 'calendar-day-label' }, [l])),
      ...grid.flatMap(row => row.map(cell => {
        const status = cell.isFuture ? 'future' : (cell.result ?? 'empty');
        const todayMod = cell.isToday ? ' calendar-cell--today' : '';
        return el('div', {
          class: `calendar-cell calendar-cell--${status}${todayMod}`,
          title: cellTooltip(cell),
        });
      })),
    ]),
    el('div', { class: 'calendar-legend' }, [
      legendItem('perfect', 'Perfect'),
      legendItem('solved', 'Solved with hint or lost hearts'),
      legendItem('failed', 'Failed'),
    ]),
  ]);
}

function legendItem(status, label) {
  return el('div', { class: 'legend-item' }, [
    el('div', { class: `calendar-cell calendar-cell--${status} calendar-cell--legend` }),
    el('span', {}, [label]),
  ]);
}

function cellTooltip(cell) {
  if (cell.isFuture) return cell.date;
  if (cell.result === 'perfect') return `${cell.date}: perfect`;
  if (cell.result === 'solved')  return `${cell.date}: solved`;
  if (cell.result === 'failed')  return `${cell.date}: failed`;
  return `${cell.date}: didn't play`;
}
