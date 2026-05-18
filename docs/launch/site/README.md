# Pictok — pre-launch website

Static HTML for `pictok.app`. Five pages sharing one stylesheet.

```
site/
├── index.html      Landing — hero + example puzzles + features
├── faq.html        Frequently asked questions
├── press.html      Press kit (description, fact sheet, quotes, downloads)
├── support.html    Bug reports, feature requests, puzzle suggestions
├── privacy.html    Privacy policy (HTML version)
└── assets/
    ├── icon.png    1024×1024 app icon (also used as favicon)
    └── style.css   Shared site-wide CSS
```

## Test locally

From this directory, run:

```bash
cd /Users/rehatchugh/emoji-decode/docs/launch/site
python3 -m http.server 8080
```

Then open <http://localhost:8080> in your browser. Hot-reload isn't included; refresh manually after edits.

## Placeholders to fill before launching

Search and replace these across all 5 HTML files:

| Placeholder | What goes here |
|---|---|
| `[YOUR_NAME]` | Your name or studio name |
| `[YOUR_LAUNCH_DATE]` | The actual release date (e.g., "May 25, 2026") |
| `[YOUR_FEEDBACK_EMAIL]` | The support / bug-report email |
| `[YOUR_PRESS_EMAIL]` | A separate press email if you want one, else same as support |
| `[YOUR_PRIVACY_EMAIL]` | Privacy contact (typically same as support) |
| `[YOUR_ROLE / "solo iOS developer..."]` | A one-line developer bio |
| `[YOUR_GITHUB]` | Your GitHub username if you make the repo public |
| `idXXXXXXXXX` | The Pictok App Store ID, post-submission |

To do this all at once with `sed` (replace values first):

```bash
cd /Users/rehatchugh/emoji-decode/docs/launch/site
sed -i '' \
  -e 's/\[YOUR_NAME\]/Rehat Chugh/g' \
  -e 's/\[YOUR_FEEDBACK_EMAIL\]/hello@pictok.app/g' \
  -e 's/\[YOUR_PRESS_EMAIL\]/hello@pictok.app/g' \
  -e 's/\[YOUR_PRIVACY_EMAIL\]/hello@pictok.app/g' \
  -e 's/\[YOUR_LAUNCH_DATE\]/May 25, 2026/g' \
  *.html
```

(Backup first, or do it on a branch — `sed` rewrites in place.)

## Hosting options

All five pages are pure static HTML/CSS, no build step.

### Option 1 — GitHub Pages (free, easiest)

1. Create a public GitHub repo named `pictok-app` (or any name)
2. Push the `site/` folder as the repo contents (i.e., `index.html` at repo root)
3. Settings → Pages → Source: `main` branch, root → Save
4. Wait 1–2 minutes, then visit `https://[YOUR_GITHUB].github.io/pictok-app/`
5. Optionally: point your `pictok.app` domain at it via CNAME

### Option 2 — Netlify (free, drag-and-drop)

1. Sign up at netlify.com (free tier)
2. Drag the `site/` folder onto netlify.com/drop
3. Done — you'll get a random `*.netlify.app` URL immediately
4. Settings → Domain → Add custom domain → `pictok.app` (Netlify walks you through DNS)

### Option 3 — Vercel / Cloudflare Pages

Similar to Netlify. Drag-and-drop or connect a Git repo.

### Option 4 — Self-host on any web server

Upload the `site/` directory to any web host. No requirements beyond serving static files.

## Custom domain setup (pictok.app)

If you buy `pictok.app` from any registrar (Namecheap, Cloudflare, Porkbun, Apple's preferred .app TLD is enforced HTTPS so you also need TLS — most static hosts give you this for free):

- For **GitHub Pages**: add CNAME record pointing `www.pictok.app` to `[YOUR_GITHUB].github.io`; add A records for apex `pictok.app` to GitHub's IPs (185.199.108.153, .109.153, .110.153, .111.153).
- For **Netlify/Vercel/Cloudflare Pages**: their dashboard walks you through it — usually one CNAME and you're done.

## When you ship a real App Store build

1. Update App Store URL: replace `idXXXXXXXXX` with the actual ID across all files
2. Take real screenshots from the simulator/device, save under `assets/screenshots/`, link from `press.html`
3. Update the launch date placeholder
4. Add `<meta name="apple-itunes-app" content="app-id=XXXXXXXXX">` to `index.html` so iOS Safari shows the "Open in App" banner

## Things explicitly NOT here (v1)

- No analytics (matches the privacy policy stance — no Google Analytics, no Plausible, nothing)
- No service worker / PWA
- No newsletter signup
- No blog
- No JavaScript at all (every page is HTML+CSS only — works without JS enabled)

Keep it that way unless you have a strong reason to change it.
