// Pictok service worker. Cache-first for all listed assets.

const CACHE = 'pictok-v5';
const ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/manifest.webmanifest',
  '/puzzles.json',
  '/doodles.svg',
  '/icon-192.png',
  '/icon-512.png',
  '/sounds/correct.wav',
  '/sounds/wrong.wav',
  '/sounds/win.wav',
  '/sounds/fail.wav',
  '/js/main.js',
  '/js/ui.js',
  '/js/game-engine.js',
  '/js/user-state.js',
  '/js/puzzle-loader.js',
  '/js/endless-selector.js',
  '/js/endless-session.js',
  '/js/today-session.js',
  '/js/celebration.js',
  '/js/stats.js',
  '/js/share.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(hit => hit ?? fetch(e.request).then(res => {
      const clone = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, clone));
      return res;
    }).catch(() => caches.match('/')))
  );
});
