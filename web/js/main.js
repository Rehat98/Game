import * as us from './user-state.js';
import * as puzzleLoader from './puzzle-loader.js';
import { createTodaySession } from './today-session.js';
import { createEndlessSession } from './endless-session.js';
import * as ui from './ui.js';
import { celebrateWin, celebrateFail, tickCorrect, tickWrong } from './celebration.js';
import * as stats from './stats.js';
import * as share from './share.js';
import { mountArchive } from './archive.js';
import { renderThemesPicker, categoryLabel } from './themes.js';

const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

async function boot() {
  const storage = window.localStorage;
  const state = us.load(storage);
  const loader = await puzzleLoader.fromUrl('puzzles.json');
  const today = puzzleLoader.dateString(new Date(), TZ);
  const todayPuzzle = loader.puzzleFor(today);
  const puzzlesByDate = new Map(loader.allPuzzles.map(p => [p.date, p]));

  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => {
      ui.showScreen(tab.dataset.screen);
      if (tab.dataset.screen === 'themes') {
        ensureThemesScreen(loader.allPuzzles, state, today, storage);
      }
      if (tab.dataset.screen === 'stats') {
        rerenderStats();
      }
    });
  }

  if (!todayPuzzle) {
    document.querySelector('#screen-today').replaceChildren(
      ui.el('div', { class: 'sticker' }, [
        ui.el('h2', {}, ["No puzzle today"]),
        ui.el('p', {}, ["The Daily bundle ends here for now. Try Themes while we cook up more puzzles."]),
      ])
    );
    return;
  }

  const session = createTodaySession(todayPuzzle, state, storage, today);
  renderToday(session, state, today, loader.allPuzzles, storage);

  // Right rail (Today panel) — only meaningful on wide viewports where it's visible.
  renderRightRail(state, loader, today);
  setInterval(() => renderRightRail(state, loader, today), 60_000);

  function rerenderStats() {
    const screen = document.querySelector('#screen-stats');
    if (!screen) return;
    screen.replaceChildren(stats.renderStats(state, today, {
      onCellTap: handleCalendarTap,
    }));
  }

  function handleCalendarTap(cell) {
    if (cell.isToday || cell.isFuture) return;
    const puzzle = puzzlesByDate.get(cell.date);
    if (!puzzle) return;

    const modalRoot = document.getElementById('modal-root');
    if (cell.result) {
      // Already played — show answer peek
      modalRoot.replaceChildren(
        stats.renderAnswerPeek(puzzle, cell.result, {
          onDismiss: () => modalRoot.replaceChildren(),
        })
      );
    } else {
      // Unplayed past — launch archive game
      mountArchive(puzzle, state, {
        storage,
        onDone: () => {
          rerenderStats();
        },
      });
    }
  }
}

function renderRightRail(state, loader, today) {
  const root = document.querySelector('#rail-right');
  if (!root) return;
  const ymd = yesterdayKey(today);
  const yp = loader.puzzleFor(ymd);
  const countdown = timeUntilNextPuzzle();

  ui.setChildren(root,
    ui.el('div', { class: 'rail-title' }, ['Today']),
    ui.el('div', { class: 'rail-block' }, [
      ui.el('div', { class: 'rail-block-eyebrow' }, ['Next puzzle in']),
      ui.el('div', { class: 'rail-block-value' }, [countdown]),
    ]),
    ui.el('div', { class: 'rail-block' }, [
      ui.el('div', { class: 'rail-block-eyebrow' }, ['Streak']),
      ui.el('div', { class: 'rail-block-value' }, [
        state.currentStreak === 0 ? '0' : `🔥 ${state.currentStreak}`,
      ]),
      ui.el('div', { class: 'rail-block-sub' }, [
        state.longestStreak > state.currentStreak ? `Best: ${state.longestStreak}` : 'Keep it alive',
      ]),
    ]),
    yp
      ? ui.el('div', { class: 'rail-block' }, [
          ui.el('div', { class: 'rail-block-eyebrow' }, ['Yesterday was']),
          ui.el('div', { class: 'rail-yesterday-emoji' }, [yp.emoji]),
          ui.el('div', { class: 'rail-yesterday-blanks' }, [maskAnswer(yp.answer)]),
        ])
      : null,
  );
}

function yesterdayKey(today) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(today);
  if (!m) return today;
  const ms = Date.UTC(+m[1], +m[2] - 1, +m[3]) - 86_400_000;
  const d = new Date(ms);
  const y = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${mm}-${dd}`;
}

function timeUntilNextPuzzle() {
  const now = new Date();
  const next = new Date(now);
  next.setHours(24, 0, 0, 0);
  const ms = next - now;
  const h = Math.floor(ms / 3_600_000);
  const m = Math.floor((ms % 3_600_000) / 60_000);
  if (h <= 0) return `${m}m`;
  return `${h}h ${m}m`;
}

function maskAnswer(answer) {
  return [...answer].map(ch => ch === ' ' ? '   ' : '_').join(' ');
}

function goToEndless(allPuzzles, state, today, storage) {
  // "Continue Playing" from the Today screen drops straight into the All
  // themes rotation (the legacy Endless behaviour) rather than the picker.
  currentThemeCategory = ALL_KEY;
  ui.showScreen('themes');
  ensureThemesScreen(allPuzzles, state, today, storage);
}

function renderToday(session, state, today, allPuzzles, storage) {
  const root = document.querySelector('#screen-today');

  function rerender() {
    ui.setChildren(root,
      ui.renderHearts(session.lives),
      ui.el('div', { class: 'emoji-header' }, [session.puzzle.emoji]),
      ui.renderCategoryChip(session.puzzle.category, session.puzzle.subcategory),
      ui.renderBlanks(session.puzzle.answer, session.correct, session.revealed),
      ui.el('div', { class: 'action-row' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow btn-sticker--sm',
          disabled: session.hintUsed || session.solved || session.failed,
          onclick: () => { session.useHint(); afterAction(); },
        }, ['💡 Hint (–2 ❤️)']),
      ]),
      session.needsSubmit
        ? ui.el('button', {
            class: 'btn-sticker btn-sticker--green',
            onclick: () => { session.submit(); afterAction(); },
          }, ['Submit ✓'])
        : null,
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed || session.needsSubmit,
        onGuess: (letter) => {
          const r = session.guess(letter);
          if (r === 'correct') tickCorrect();
          if (r === 'wrong')   tickWrong();
          afterAction();
        },
      }),
      ui.el('div', { class: 'continue-row' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--continue',
          onclick: () => goToEndless(allPuzzles, state, today, storage),
        }, [
          (session.solved || session.failed) ? 'Continue playing →' : 'Want more? Play Endless →'
        ]),
      ]),
    );
  }

  function afterAction() {
    rerender();
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      showOneChanceModal();
    }
    if (session.solved) {
      celebrateWin().then(() => showResultModal(session, state, true, allPuzzles, today, storage));
    }
    if (session.failed) {
      celebrateFail().then(() => showResultModal(session, state, false, allPuzzles, today, storage));
    }
  }

  rerender();
}

function showOneChanceModal() {
  ui.showModal(({ close }) => ui.el('div', { class: 'modal-body' }, [
    ui.el('div', { class: 'modal-eyebrow' }, ['Heads up']),
    ui.el('h2', { class: 'modal-title' }, ['One chance left']),
    ui.el('p', { class: 'modal-body-text' }, ['Make it count. One more wrong guess ends the puzzle.']),
    ui.el('button', { class: 'btn-sticker btn-sticker--green btn-block', onclick: close }, ['OK']),
  ]));
}

function showResultModal(session, state, success, allPuzzles, today, storage) {
  const url = 'pictok.pages.dev';
  const shareTextValue = success
    ? share.successCard({
        heartsRemaining: state.lives,
        hintUsed: session.hintUsed,
        currentStreak: state.currentStreak,
        url,
      })
    : share.failureCard({
        previousStreak: Math.max(state.currentStreak, state.longestStreak),
        url,
      });

  const eyebrow = success ? "Today's Pictok" : "Today's Pictok";
  const statusLine = success
    ? successStatusLine(state, session)
    : "Tough one. Beat me today.";
  const streakLine = success
    ? `Streak: ${state.currentStreak}`
    : `Streak: ${Math.max(state.currentStreak, state.longestStreak)} → 0`;

  ui.showModal(({ close }) => ui.el('div', { class: 'modal-body result-modal' }, [
    ui.el('div', { class: 'modal-eyebrow' }, [eyebrow]),
    ui.el('h2', { class: 'result-answer' }, [session.puzzle.answer]),
    ui.renderCategoryChip(session.puzzle.category, session.puzzle.subcategory),
    ui.el('div', { class: 'result-divider' }, []),
    ui.el('p', { class: 'result-status' }, [statusLine]),
    ui.el('p', { class: 'result-streak' }, [streakLine]),
    ui.el('div', { class: 'share-preview' }, [
      ui.el('div', { class: 'share-preview-line share-preview-bold' }, [
        success ? share.CHALLENGE_BOLD : share.FAIL_BOLD,
      ]),
    ]),
    ui.el('button', {
      class: 'btn-sticker btn-sticker--green btn-block',
      onclick: async () => {
        const r = await share.shareText(shareTextValue, {
          onClipboardSuccess: () => ui.showToast('Copied. Paste it anywhere!'),
        });
        if (r === 'failed') ui.showToast('Share unavailable');
      },
    }, ['Share challenge']),
    ui.el('button', {
      class: 'btn-sticker btn-sticker--continue btn-block',
      onclick: () => { close(); goToEndless(allPuzzles, state, today, storage); },
    }, ['Continue playing →']),
    ui.el('button', { class: 'modal-close-link', onclick: close }, ['Close']),
  ]));
}

function successStatusLine(state, session) {
  const heartsLost = Math.max(0, Math.min(5, 5 - state.lives));
  if (!session.hintUsed && heartsLost === 0) return 'Perfect run. No hints, no wrong guesses.';
  if (session.hintUsed && heartsLost === 0) return 'Solved with 1 hint.';
  if (!session.hintUsed) return `Solved with ${heartsLost} wrong ${heartsLost === 1 ? 'guess' : 'guesses'}.`;
  return `Solved with 1 hint and ${heartsLost} wrong ${heartsLost === 1 ? 'guess' : 'guesses'}.`;
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(err =>
    console.warn('SW registration failed:', err)
  );
}

// Inject the doodle layer inline so the SVG's CSS animations run.
(async () => {
  try {
    const r = await fetch('doodles.svg');
    if (!r.ok) return;
    const layer = document.querySelector('.doodles-bg');
    if (layer) layer.innerHTML = await r.text();
  } catch { /* doodles are decorative — failure is non-blocking */ }
})();

boot();

// Themes tab — picker landing + category-filtered endless rotation. A single
// session is cached per category key (or ALL_KEY for "All themes") so tab
// switches preserve in-flight game state.
const ALL_KEY = '__all__';
const themeSessions = new Map();   // categoryKey → session
let currentThemeCategory = null;   // null = picker; ALL_KEY or Category string = game

function ensureThemesScreen(allPuzzles, state, today, storage) {
  const root = document.querySelector('#screen-themes');
  if (currentThemeCategory === null) {
    renderThemesPicker(root, {
      allPuzzles,
      onPick: (cat) => {
        currentThemeCategory = cat ?? ALL_KEY;
        ensureThemesScreen(allPuzzles, state, today, storage);
      },
    });
    return;
  }
  const key = currentThemeCategory;
  if (!themeSessions.has(key)) {
    const pool = key === ALL_KEY
      ? allPuzzles
      : allPuzzles.filter(p => p.category === key);
    themeSessions.set(key, createEndlessSession(pool, state, today, storage));
  }
  renderThemesGame(root, themeSessions.get(key), key, allPuzzles, state, today, storage);
}

function renderThemesGame(root, session, categoryKey, allPuzzles, state, today, storage) {
  const eyebrow = categoryKey === ALL_KEY ? 'ALL THEMES' : categoryLabel(categoryKey).toUpperCase();

  function rerender(awaitingNext = false) {
    if (!session.currentPuzzle) {
      const themeName = categoryKey === ALL_KEY ? '' : categoryLabel(categoryKey) + ' ';
      ui.setChildren(root,
        ui.el('div', { class: 'endless-topbar' }, [backButton()]),
        ui.el('div', { class: 'sticker' }, [
          ui.el('h2', {}, [`🎉 You've played every ${themeName}puzzle!`]),
          ui.el('p', {}, ['Pick another theme or come back tomorrow for the Daily.']),
        ]),
      );
      return;
    }
    if (awaitingNext) {
      ui.setChildren(root,
        ui.el('div', { class: 'endless-topbar' }, [backButton()]),
        ui.el('div', { class: 'next-overlay' }, [
          ui.el('p', { class: 'next-overlay-text' }, [
            session.solvedThisSession === 0 ? 'Better luck next round.' : 'Nice. Keep going?'
          ]),
          ui.el('button', {
            class: 'btn-sticker btn-sticker--green',
            onclick: () => { session.advance(); rerender(false); },
          }, ['Next puzzle →']),
        ]),
      );
      return;
    }
    const p = session.currentPuzzle;
    ui.setChildren(root,
      ui.el('div', { class: 'endless-topbar' }, [
        backButton(),
        ui.el('div', { class: 'endless-counter-block' }, [
          ui.el('span', { class: 'endless-eyebrow' }, [eyebrow]),
          ui.el('span', { class: 'endless-counter' }, [
            session.solvedThisSession === 0 ? 'Just started'
              : session.solvedThisSession === 1 ? '1 solved'
              : `${session.solvedThisSession} solved`
          ]),
        ]),
      ]),
      ui.renderHearts(session.hearts),
      ui.el('div', { class: 'emoji-header' }, [p.emoji]),
      ui.renderCategoryChip(p.category, null),
      ui.renderBlanks(p.answer, session.correct, null),
      ui.el('div', { class: 'action-row' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow btn-sticker--sm',
          disabled: session.hintUsed || session.solved || session.failed || session.needsSubmit,
          onclick: () => { session.useHint(); afterAction(); },
        }, ['💡 Hint']),
      ]),
      session.needsSubmit ? ui.el('button', {
        class: 'btn-sticker btn-sticker--green',
        onclick: () => { session.submit(); afterAction(); },
      }, ['Submit ✓']) : null,
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed || session.needsSubmit,
        onGuess: (l) => {
          const r = session.guess(l);
          if (r === 'correct') tickCorrect();
          if (r === 'wrong')   tickWrong();
          afterAction();
        },
      }),
    );
  }

  function backButton() {
    return ui.el('button', {
      class: 'btn-sticker btn-sticker--sm',
      onclick: () => {
        currentThemeCategory = null;
        ensureThemesScreen(allPuzzles, state, today, storage);
      },
    }, ['‹ Themes']);
  }

  function afterAction() {
    rerender(false);
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      showOneChanceModal();
    }
    if (session.solved) {
      celebrateWin().then(() => rerender(true));
    } else if (session.failed) {
      celebrateFail().then(() => rerender(true));
    }
  }
  rerender(false);
}
