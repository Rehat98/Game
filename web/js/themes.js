// Themes tab — category picker for the formerly-Endless screen.
// Mirrors iOS Pictok/Views/ThemesView.swift.

import * as ui from './ui.js';

const CATEGORY_ICONS = {
  Movie: '🎬',
  Song:  '🎵',
  Book:  '📚',
  Brand: '🏷️',
  Celeb: '🎤',
};

const CATEGORY_LABELS = {
  Movie: 'Movies',
  Song:  'Songs',
  Book:  'Books',
  Brand: 'Brands',
  Celeb: 'Celebs',
};

const CATEGORIES = ['Movie', 'Song', 'Book', 'Brand', 'Celeb'];

/**
 * Renders the picker into `root`. Each card invokes `onPick(category)` on tap;
 * pass `null` from the "All themes" card to represent the legacy Endless mix.
 */
export function renderThemesPicker(root, { allPuzzles, onPick }) {
  const total = allPuzzles.length;
  ui.setChildren(root,
    ui.el('div', { class: 'themes-screen' }, [
      ui.el('h1', { class: 'themes-title' }, ['Themes']),
      ui.el('p',  { class: 'themes-sub' },   ['Pick a theme and play through it.']),
      themeCard({
        icon: '🎲',
        title: 'All themes',
        subtitle: `${total} puzzles · random rotation`,
        onClick: () => onPick(null),
      }),
      ...CATEGORIES.map(cat => {
        const count = allPuzzles.filter(p => p.category === cat).length;
        return themeCard({
          icon: CATEGORY_ICONS[cat],
          title: CATEGORY_LABELS[cat],
          subtitle: `${count} ${count === 1 ? 'puzzle' : 'puzzles'}`,
          onClick: () => onPick(cat),
        });
      }),
    ])
  );
}

export function categoryLabel(cat) {
  return CATEGORY_LABELS[cat] ?? cat;
}

function themeCard({ icon, title, subtitle, onClick }) {
  return ui.el('button', { type: 'button', class: 'theme-card', onclick: onClick }, [
    ui.el('span', { class: 'theme-icon' }, [icon]),
    ui.el('div',  { class: 'theme-text' }, [
      ui.el('div', { class: 'theme-name' },  [title]),
      ui.el('div', { class: 'theme-count' }, [subtitle]),
    ]),
    ui.el('span', { class: 'theme-chev' }, ['›']),
  ]);
}
