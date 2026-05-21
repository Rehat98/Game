// DOM helpers. Pure functions where possible; the few side-effect functions are
// the only places we touch the document.
export const $ = (sel, root = document) => root.querySelector(sel);

export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'disabled' && v) node.setAttribute('disabled', '');
    else if (v === false || v == null) continue;
    else node.setAttribute(k, v);
  }
  for (const c of [].concat(children)) {
    if (c == null) continue;
    node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
  return node;
}

export function showScreen(name) {
  for (const s of document.querySelectorAll('.screen')) s.hidden = !s.id.endsWith(name);
  for (const t of document.querySelectorAll('.tab')) {
    if (t.dataset.screen === name) t.setAttribute('aria-current', 'page');
    else t.removeAttribute('aria-current');
  }
}

export function showToast(text, ms = 2200) {
  const root = $('#toast-root');
  root.replaceChildren(el('div', { class: 'toast' }, [text]));
  setTimeout(() => root.replaceChildren(), ms);
}

export function showModal(buildContent) {
  const root = $('#modal-root');
  const close = () => root.replaceChildren();
  const content = buildContent({ close });
  root.replaceChildren(el('div', { class: 'modal-backdrop' }, [
    el('div', { class: 'modal' }, [content]),
  ]));
}

export function renderKeyboard({ correct, wrong, onGuess, disabled }) {
  const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  return el('div', { class: 'keyboard' }, rows.map(row =>
    el('div', { class: 'keyboard-row' }, [...row].map(ch => {
      const status = correct.has(ch) ? 'correct' : wrong.has(ch) ? 'wrong' : '';
      const used = correct.has(ch) || wrong.has(ch);
      return el('button', {
        class: `key ${status ? `key--${status}` : ''}`.trim(),
        disabled: disabled || used,
        onclick: () => onGuess(ch),
      }, [ch]);
    }))
  ));
}

export function renderBlanks(answer, correct, revealedLetter) {
  const known = new Set(correct);
  if (revealedLetter) known.add(revealedLetter);
  const words = answer.split(' ');
  return el('div', { class: 'blanks' }, words.map(word =>
    el('div', { class: 'blank-word' }, [...word].map(ch => {
      const shown = known.has(ch.toUpperCase()) ? ch : '';
      return el('div', {
        class: `blank-letter ${shown ? 'blank-letter--revealed' : 'blank-letter--empty'}`,
      }, [shown || '·']);
    }))
  ));
}

export function renderHearts(remaining, max = 5) {
  return el('div', { class: 'hearts-row' }, Array.from({ length: max }, (_, i) =>
    el('span', { class: `heart ${i < remaining ? '' : 'heart--lost'}`.trim() }, ['❤️'])
  ));
}

export function renderCategoryChip(category, subcategory) {
  const icons = { Movie: '🎬', Song: '🎵', Book: '📚', Brand: '🏷️', Celeb: '🎤' };
  const text = subcategory ? `${category} · ${subcategory}` : category;
  return el('div', { class: 'category-chip' }, [`${icons[category] ?? ''} ${text}`]);
}
