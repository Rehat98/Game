import { createArchiveSession } from './archive-session.js';
import { celebrateWin, celebrateFail, tickCorrect, tickWrong } from './celebration.js';
import * as ui from './ui.js';

const MONTH_NAMES = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

/**
 * Opens an archive (catch-up) game for `puzzle` inside the global modal.
 *
 * The modal closes automatically after a solve or fail celebration finishes,
 * then `onDone()` fires so the host (Stats screen) can rerender the calendar
 * with the now-coloured cell. `onDone` is also called if the user manually
 * closes the modal mid-game — the caller decides what to do.
 *
 *   puzzle:  the past Daily puzzle object (id, date, emoji, answer, category…)
 *   state:   the in-memory user state (mutated by the session)
 *   storage: localStorage (or compatible) — passed through to the session for save()
 *   onDone:  () => void, fired after celebration or manual close
 */
export function mountArchive(puzzle, state, { storage, onDone }) {
  const session = createArchiveSession(puzzle, state, storage);

  function render() {
    ui.showModal(({ close }) => buildContent(close));
  }

  function buildContent(close) {
    const closeHandler = () => { close(); onDone?.(); };

    const children = [
      ui.el('div', { class: 'archive-topbar' }, [
        ui.el('button', {
          type: 'button',
          class: 'archive-close',
          'aria-label': 'Close',
          onclick: closeHandler,
        }, ['✕']),
        ui.el('div', { class: 'archive-date' }, [formatDate(puzzle.date)]),
      ]),
      ui.renderHearts(session.hearts),
      ui.el('div', { class: 'emoji-header' }, [puzzle.emoji]),
      ui.renderCategoryChip(puzzle.category, puzzle.subcategory),
      ui.renderBlanks(puzzle.answer, session.correct, null),
      ui.el('div', { class: 'archive-actions' }, [
        ui.el('button', {
          type: 'button',
          class: 'btn-sticker sticker--soft archive-hint',
          disabled: session.hintUsed || session.solved || session.failed,
          onclick: () => { session.useHint(); render(); },
        }, ['💡 Hint']),
      ]),
    ];

    if (session.needsSubmit) {
      children.push(
        ui.el('button', {
          type: 'button',
          class: 'btn-sticker btn-sticker--green archive-submit',
          onclick: () => onSubmit(close),
        }, ['Submit ✓'])
      );
    }

    children.push(
      ui.renderKeyboard({
        correct: session.correct,
        wrong: session.wrong,
        disabled: session.solved || session.failed,
        onGuess: (letter) => onGuess(letter, close),
      })
    );

    return ui.el('div', { class: 'modal-body archive-body' }, children);
  }

  function onGuess(letter, close) {
    const heartsBefore = session.hearts;
    session.guess(letter);
    if (session.hearts < heartsBefore) {
      tickWrong();
    } else if (session.correct.has(String(letter).toUpperCase())) {
      tickCorrect();
    }
    if (session.failed) {
      close();
      celebrateFail().then(() => onDone?.());
    } else {
      render();
    }
  }

  function onSubmit(close) {
    session.submit();
    if (session.solved) {
      close();
      celebrateWin().then(() => onDone?.());
    }
  }

  function formatDate(ymd) {
    const [y, m, d] = ymd.split('-');
    return `${MONTH_NAMES[parseInt(m, 10) - 1]} ${parseInt(d, 10)}`;
  }

  render();
}
