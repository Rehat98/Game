// Pure stats math + DOM render of the Stats screen.

export function winPercent({ totalSolved, totalPlayed }) {
  if (!totalPlayed) return 0;
  return Math.round((totalSolved / totalPlayed) * 100);
}

/// Builds a flat array of the last `days` cells ending today (inclusive).
/// Each cell: `{ date, result: 'perfect'|'solved'|'failed'|null, isToday, isFuture }`.
export function buildLastDays(today, solveHistory, days = 10) {
  const historyMap = new Map((solveHistory ?? []).map(h => [h.date, h.result]));
  const todayMs = parseYMD(today);
  if (todayMs === null) return [];

  const startMs = todayMs - (days - 1) * 86_400_000;
  const cells = [];
  for (let i = 0; i < days; i++) {
    const cellMs = startMs + i * 86_400_000;
    const cellDate = msToYMD(cellMs);
    cells.push({
      date: cellDate,
      result: historyMap.get(cellDate) ?? null,
      isToday: cellDate === today,
      isFuture: false,
    });
  }
  return cells;
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

export function renderStats(state, today, { onCellTap = () => {} } = {}) {
  const pct = winPercent(state);
  return el('div', { class: 'stats-screen' }, [
    pairCard('Current streak', state.currentStreak, 'Longest', state.longestStreak),
    pairCard('Lifetime solved', state.lifetimeSolvedCount, 'Win %', `${pct}%`),
    calendarCard(today, state.solveHistory ?? [], onCellTap),
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

function calendarCard(today, history, onCellTap) {
  const cells = buildLastDays(today, history, 10);
  return el('div', { class: 'sticker calendar-card' }, [
    el('div', { class: 'stats-label calendar-eyebrow' }, ['Last 10 days']),
    el('div', { class: 'calendar-grid calendar-grid--10' }, [
      ...cells.map(cell => {
        const status = cell.result ?? 'empty';
        const todayMod = cell.isToday ? ' calendar-cell--today' : '';
        return el('div', { class: 'calendar-day-stack' }, [
          el('button', {
            type: 'button',
            class: `calendar-cell calendar-cell--${status}${todayMod}`,
            'aria-label': cellAriaLabel(cell),
            title: cellTooltip(cell),
            onclick: () => onCellTap(cell),
          }),
          el('div', { class: 'calendar-day-number' }, [dayNumber(cell.date)]),
        ]);
      }),
    ]),
    el('div', { class: 'calendar-legend' }, [
      legendItem('perfect', 'Perfect'),
      legendItem('solved',  'Solved'),
      legendItem('failed',  'Failed'),
    ]),
  ]);
}

function dayNumber(ymd) {
  const m = /^\d{4}-\d{2}-(\d{2})$/.exec(ymd);
  return m ? String(Number(m[1])) : ymd;
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

function cellAriaLabel(cell) {
  if (cell.isToday) return `Today, ${cell.date}`;
  if (cell.isFuture) return `Future, ${cell.date}`;
  if (cell.result === 'perfect') return `${cell.date}: perfect`;
  if (cell.result === 'solved')  return `${cell.date}: solved`;
  if (cell.result === 'failed')  return `${cell.date}: failed`;
  return `${cell.date}: unplayed`;
}

export function renderAnswerPeek(puzzle, outcome, { onDismiss } = {}) {
  const outcomeLine = outcome === 'perfect' ? '✓ Perfect run'
                    : outcome === 'solved'  ? '✓ Solved'
                    : outcome === 'failed'  ? '✗ Beat you'
                    : '';
  const outcomeClass = outcome === 'failed' ? 'peek-outcome peek-outcome--fail' : 'peek-outcome';
  return el('div', { class: 'peek-modal-backdrop', onclick: onDismiss }, [
    el('div', { class: 'peek-modal', onclick: (e) => e.stopPropagation() }, [
      el('div', { class: 'peek-emoji' }, [puzzle.emoji]),
      el('div', { class: 'peek-category' }, [`${puzzle.category} · ${puzzle.subcategory}`]),
      el('div', { class: 'peek-answer' }, [puzzle.answer]),
      el('div', { class: outcomeClass }, [outcomeLine]),
      el('button', { type: 'button', class: 'peek-close sticker-button', onclick: onDismiss }, ['Got it']),
    ]),
  ]);
}
