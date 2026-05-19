# Pictok — App Store Listing Copy

Drafted 2026-05-18 in advance of submission. Substitute placeholders before going live.

---

## App name
**Pictok**

## Subtitle (max 30 chars)
**Daily emoji puzzles**

(28 chars; passes Apple's limit. Backup option: "Decode the daily puzzle" — 23 chars.)

## Promotional text (max 170 chars, editable post-launch)
**A new emoji puzzle every day. Decode rebus-style clues — bee + leaf = belief — and keep your streak alive. Spoiler-free share card lets you brag responsibly.**

(169 chars.)

## Description (max 4000 chars)

```
Solve one emoji puzzle a day. Or many.

Pictok gives you a fresh emoji riddle every morning — a movie, song, book, brand, or celeb hidden inside a tiny string of emojis. Each emoji represents a word in the answer. Some are literal. Some are clever rebus puns. All of them want to be figured out.

🐝 + 🍃 = BE-LIEF
🅰️ + 🐝 + 🛣️ = ABBEY ROAD
🐻 + 🦶 = BARE-FOOT
🪡 + 🏃 = TAYLOR SWIFT

Solve today's Daily for your streak — that's the social anchor, with a spoiler-free share card. Then tap Continue Playing to keep going with more puzzles in Endless mode, as many as you want, no time gates.

Built for the 30-second-to-2-minute solve — that satisfying "oh" moment when the answer clicks.

WHY YOU'LL COME BACK TOMORROW
• A new Daily puzzle every day, hand-curated
• Build your streak — miss a day and the free streak-freeze rescues you once
• Endless mode lets you binge extras without breaking the daily anchor
• Share your spoiler-free result to text threads, group chats, anywhere
• Track streak, lifetime solves, win rate, and guess distribution

WHAT'S DIFFERENT
• No ads. No tracking. No accounts.
• Everything stays on your device.
• No "energy bars," no IAP gotchas. Just the puzzle.

WHAT YOU GET
• 60 hand-curated puzzles in v1 (~2 months of Daily content)
• Medium and Hard difficulty — every puzzle requires real thinking
• Word-by-word reveal: solve one word before the next opens up
• Free hint per Endless puzzle to nudge you when stuck
• Fireworks celebration when you solve. Gentle rain when you don't.
• Optional daily reminder so you don't lose your streak
• Sticker/paper-craft visual style — no generic UI templates here
• Built for iPhone, looks great on iOS 17+

Wordle gave the world daily 5-letter guessing. Pictok gives you daily emoji decoding — and lets you keep playing when you're hooked.

Tap to play. Solve. Share. Repeat tomorrow.
```

(~2,300 chars — comfortably under the 4,000 limit.)

## Keywords (max 100 chars, comma-separated)

```
puzzle,daily,emoji,word,rebus,riddle,decode,guess,streak,brain,wordle,trivia
```

(76 chars. Apple deduplicates against the app name + category, so "pictok" and "word" aren't worth burning a slot on if they're already strong matches elsewhere.)

## Primary category
**Games → Word**

## Secondary category (optional)
**Games → Trivia**

## Age rating
**4+**

(No violence, no mature themes, no UGC. Trivial to clear.)

## Support URL
**[YOUR_SUPPORT_URL]**

(Until you have one: a simple GitHub repo README, a Notion public page, or a one-page site at pictok.app/support is fine.)

## Marketing URL (optional)
**[YOUR_MARKETING_URL]**

## Privacy policy URL (required)
**[YOUR_PRIVACY_POLICY_URL]**

(Use `docs/launch/privacy-policy.md` in this repo. Host as static HTML on GitHub Pages or pictok.app/privacy.)

## Privacy contact email
**[YOUR_PRIVACY_EMAIL]**

---

## Screenshot plan (6.7" iPhone — required)

Apple wants 1290×2796 PNGs. Minimum 3, maximum 10. Recommend 5–6 in this order:

1. **Hero — puzzle mid-solve**
   - Show 🍓🌾 with `S T R A W B E R R Y / F _ E L D S` blanks
   - Hearts: 4/5, 1 wrong guess
   - Caption overlay: "One emoji puzzle. Every day."

2. **Result celebration**
   - Solved state of a hard puzzle (e.g., ABBEY ROAD)
   - Share card visible
   - Streak count: 🔥 7
   - Caption: "Solve. Share. Brag responsibly."

3. **Variety**
   - Show 4 thumbnail puzzles across categories: 🐱🐟 / 💍🔥 / 🌴📖 / ⭐💵
   - Caption: "Movies, songs, books, brands. All decoded."

4. **Stats**
   - Stats screen with a real streak and the guess distribution chart populated
   - Caption: "Build your streak. Don't break it."

5. **No-fluff promise**
   - Today screen, very clean, no UI clutter
   - Caption: "No ads. No accounts. Just the puzzle."

6. (Optional) **How to play**
   - One of the 3 onboarding cards
   - Caption: "Each emoji is a word."

## App Store screenshot text overlay style guide
- Use Pictok's brand fonts (chunky rounded sans-serif, ~64pt for headlines)
- Cream paper background (`#FEF3D9`) behind the device frame
- Black-on-cream text only — match the in-app sticker aesthetic
- Avoid stock photography or hand silhouettes — let the app speak

## Pre-launch checklist (App Store Connect)
- [ ] Bundle ID matches the Xcode target (`com.yourname.pictok`)
- [ ] App icon uploaded (1024×1024, opaque, no rounded corners — iOS rounds them)
- [ ] All 5+ screenshots uploaded
- [ ] App description proofread for typos
- [ ] Keywords saved
- [ ] Privacy policy URL is live and returns 200
- [ ] Support URL is live
- [ ] Age rating set to 4+
- [ ] Price set to Free
- [ ] Localizations: English only for v1
- [ ] Build uploaded via Xcode Organizer
- [ ] TestFlight tested by at least 3 humans for 1 week
- [ ] Submitted for review with a release type chosen (manual recommended for first submission)

## Suggested launch sequence
1. Submit to App Store Connect with **manual release** selected
2. Wait for "Ready for Sale" notification (typically 24–72h after approval)
3. Tweet/post the App Store link only after the listing is live
4. Day 1: Post to r/iOSProgramming (build process), r/iosgaming (the game itself), Hacker News if you have a strong narrative angle
5. Submit to Product Hunt for the following Monday
6. Track installs daily in App Store Connect → Analytics
