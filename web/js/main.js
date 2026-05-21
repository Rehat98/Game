import * as us from './user-state.js';
import * as puzzleLoader from './puzzle-loader.js';
import { createTodaySession } from './today-session.js';
import * as ui from './ui.js';

const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

async function boot() {
  const storage = window.localStorage;
  const state = us.load(storage);
  const loader = await puzzleLoader.fromUrl('puzzles.json');
  const today = puzzleLoader.dateString(new Date(), TZ);
  const todayPuzzle = loader.puzzleFor(today);

  // Tab routing
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => ui.showScreen(tab.dataset.screen));
  }

  if (!todayPuzzle) {
    document.querySelector('#screen-today').replaceChildren(
      ui.el('div', { class: 'sticker' }, [
        ui.el('h2', {}, ["No puzzle today"]),
        ui.el('p', {}, ["The Daily bundle ends here for now. Try Endless mode while we cook up more puzzles."]),
      ])
    );
    return;
  }

  const session = createTodaySession(todayPuzzle, state, storage);
  renderToday(session, state, today);
}

function renderToday(session, state, today) {
  const root = document.querySelector('#screen-today');

  function rerender() {
    root.replaceChildren(
      ui.renderHearts(session.lives),
      ui.el('div', { class: 'emoji-header' }, [session.puzzle.emoji]),
      ui.renderCategoryChip(session.puzzle.category, session.puzzle.subcategory),
      ui.renderBlanks(session.puzzle.answer, session.correct, session.revealed),
      ui.el('div', { class: 'btn-row', style: 'display:flex;justify-content:flex-end;gap:8px' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow',
          disabled: session.hintUsed || session.solved || session.failed,
          onclick: () => { session.useHint(); afterAction(); },
        }, ['💡 Hint (–2 ❤️)']),
      ]),
      session.needsSubmit
        ? ui.el('button', {
            class: 'btn-sticker btn-sticker--green',
            onclick: () => { session.submit(today); afterAction(); },
          }, ['Submit ✓'])
        : null,
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed || session.needsSubmit,
        onGuess: (letter) => { session.guess(letter); afterAction(); },
      }),
    );
  }

  function afterAction() {
    rerender();
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      ui.showModal(({ close }) => ui.el('div', {}, [
        ui.el('h2', {}, ['One chance left']),
        ui.el('p', {}, ['Make it count — one more wrong guess ends the puzzle.']),
        ui.el('button', { class: 'btn-sticker', onclick: close }, ['OK']),
      ]));
    }
    if (session.solved) showResultModal(session, state, true);
    if (session.failed) showResultModal(session, state, false);
  }

  rerender();
}

function showResultModal(session, state, success) {
  ui.showModal(({ close }) => ui.el('div', {}, [
    ui.el('h2', {}, [success ? '🎉 You solved it!' : '💔 Better luck tomorrow']),
    ui.el('p', {}, [`Answer: ${session.puzzle.answer}`]),
    ui.el('p', {}, [`Streak: ${state.currentStreak}`]),
    ui.el('button', { class: 'btn-sticker', onclick: close }, ['Close']),
  ]));
}

boot();
