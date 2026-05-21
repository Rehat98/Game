import * as us from './user-state.js';
import * as puzzleLoader from './puzzle-loader.js';
import { createTodaySession } from './today-session.js';
import { createEndlessSession } from './endless-session.js';
import * as ui from './ui.js';
import { celebrateWin, celebrateFail, tickCorrect, tickWrong } from './celebration.js';

const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;

async function boot() {
  const storage = window.localStorage;
  const state = us.load(storage);
  const loader = await puzzleLoader.fromUrl('puzzles.json');
  const today = puzzleLoader.dateString(new Date(), TZ);
  const todayPuzzle = loader.puzzleFor(today);

  // Tab routing
  for (const tab of document.querySelectorAll('.tab')) {
    tab.addEventListener('click', () => {
      ui.showScreen(tab.dataset.screen);
      if (tab.dataset.screen === 'endless') {
        ensureEndlessScreen(loader.allPuzzles, state, today, storage);
      }
    });
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
        onGuess: (letter) => {
          const r = session.guess(letter);
          if (r === 'correct') tickCorrect();
          if (r === 'wrong')   tickWrong();
          afterAction();
        },
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
    if (session.solved) {
      celebrateWin().then(() => showResultModal(session, state, true));
    }
    if (session.failed) {
      celebrateFail().then(() => showResultModal(session, state, false));
    }
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

let endlessRendered = false;
function ensureEndlessScreen(allPuzzles, state, today, storage) {
  if (endlessRendered) return;
  endlessRendered = true;
  const session = createEndlessSession(allPuzzles, state, today, storage);
  const root = document.querySelector('#screen-endless');

  function rerender(awaitingNext = false) {
    if (!session.currentPuzzle) {
      root.replaceChildren(ui.el('div', { class: 'sticker' }, [
        ui.el('h2', {}, ['🎉 You\'ve played every puzzle!']),
        ui.el('p', {}, ['Come back tomorrow for a fresh Daily.']),
      ]));
      return;
    }
    if (awaitingNext) {
      root.replaceChildren(ui.el('div', { style: 'display:flex;flex-direction:column;gap:18px;align-items:center;padding:48px 16px' }, [
        ui.el('p', { style: 'opacity:0.7' }, [session.solvedThisSession === 0 ? 'Better luck next round.' : 'Nice. Keep going?']),
        ui.el('button', {
          class: 'btn-sticker btn-sticker--green',
          onclick: () => { session.advance(); rerender(false); },
        }, ['Next puzzle →']),
      ]));
      return;
    }
    const p = session.currentPuzzle;
    root.replaceChildren(
      ui.el('div', { style: 'display:flex;justify-content:space-between;align-items:center' }, [
        ui.el('button', {
          class: 'btn-sticker sticker--soft',
          style: 'padding:8px 12px;font-size:14px',
          onclick: () => ui.showScreen('today'),
        }, ['✕ End Session']),
        ui.el('span', { style: 'font-size:14px;opacity:0.7;font-weight:800' }, [
          session.solvedThisSession === 0 ? 'Just started'
            : session.solvedThisSession === 1 ? '1 solved'
            : `${session.solvedThisSession} solved`
        ]),
      ]),
      ui.renderHearts(session.hearts),
      ui.el('div', { class: 'emoji-header' }, [p.emoji]),
      ui.renderCategoryChip(p.category, null),
      ui.renderBlanks(p.answer, session.correct, null),
      ui.el('div', { style: 'display:flex;justify-content:flex-end' }, [
        ui.el('button', {
          class: 'btn-sticker btn-sticker--yellow',
          disabled: session.hintUsed || session.solved || session.failed,
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

  function afterAction() {
    rerender(false);
    if (session.hasShownOneChanceWarning && !session._warnedShown) {
      session._warnedShown = true;
      ui.showModal(({ close }) => ui.el('div', {}, [
        ui.el('h2', {}, ['One chance left']),
        ui.el('p', {}, ['Make it count — one more wrong guess ends the puzzle.']),
        ui.el('button', { class: 'btn-sticker', onclick: close }, ['OK']),
      ]));
    }
    if (session.solved) {
      celebrateWin().then(() => rerender(true));
    } else if (session.failed) {
      celebrateFail().then(() => rerender(true));
    }
  }
  rerender(false);
}
