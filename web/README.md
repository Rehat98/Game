# Pictok Web

The browser version of [Pictok](https://pictok.app), the daily emoji-decode puzzle. Companion to the iOS app.

## Local development

```bash
cd web
python3 -m http.server 8080
```
Visit `http://localhost:8080`.

## Run tests

```bash
cd web
npm test
```
Pure-logic modules (game engine, state, share builder, etc.) have Node-runner unit tests. UI modules are verified by browser QA.

## Sync puzzles & sounds from the iOS source of truth

Whenever `Pictok/Resources/puzzles.json` or `Pictok/Resources/Sounds/*.wav` changes:

```bash
cd web
./sync-puzzles.sh
```
Commit the resulting changes to `web/puzzles.json` and `web/sounds/*`.

## Deploy

Two options. **Option A** requires a GitHub repo. **Option B** uploads directly from your laptop.

### Option A — Cloudflare Pages with GitHub auto-deploy (recommended for long-term)

1. Push this repo to GitHub:
   ```bash
   gh repo create rehatchugh/emoji-decode --private --source=. --remote=origin --push
   ```
   (or create the repo via the github.com UI and `git remote add origin <url>` + `git push -u origin main`).

2. In Cloudflare dashboard: **Workers & Pages → Create application → Pages → Connect to Git**.

3. Build settings:
   - **Framework preset:** None
   - **Build command:** (empty)
   - **Build output directory:** `web`
   - **Root directory:** (empty)

4. Save and deploy. Cloudflare assigns a `*.pages.dev` URL.

5. **Custom domain:** In the Pages project → **Custom domains** → enter `pictok.app`. Since `pictok.app` already uses Cloudflare DNS (user owns it on Cloudflare), the CNAME is auto-created.

6. After deploy: every push to `main` triggers an auto-deploy.

### Option B — Wrangler CLI direct upload (no GitHub required)

1. Install Wrangler once: `npm install -g wrangler` then `wrangler login`.

2. Create the Pages project (one-time):
   ```bash
   wrangler pages project create pictok --production-branch main
   ```

3. Deploy:
   ```bash
   cd web
   wrangler pages deploy . --project-name pictok --branch main
   ```

4. Attach `pictok.app` via Cloudflare dashboard → Pages → Custom domains (same as Option A step 5).

## Architecture

Static SPA, zero build step. Source files are deployed verbatim from `web/`.

- `index.html` — SPA shell with three screen containers (Today / Endless / Stats).
- `style.css` — Theme variables matching `Pictok/Views/Theme.swift`, sticker aesthetic.
- `js/` — ES2020 modules. Pure-logic at the leaves (`game-engine.js`, `user-state.js`, `puzzle-loader.js`, `endless-selector.js`, `share.js`, `stats.js`); session orchestrators in the middle (`today-session.js`, `endless-session.js`); UI helpers in `ui.js`, `celebration.js`; entry point in `main.js`.
- `sw.js` — Service worker, cache-first for all static assets. Offline-capable after first visit.
- `manifest.webmanifest` + `icon-192.png` + `icon-512.png` — PWA installable.
- `puzzles.json` — Synced from `Pictok/Resources/puzzles.json` via `sync-puzzles.sh`.
- `sounds/` — Synced from `Pictok/Resources/Sounds/`.

State persists in browser `localStorage` under key `pictok.state.v1`. Schema matches iOS UserState exactly (forward-compatible — unknown future fields are preserved on load).
