# Pictok — App Store Listing Copy

Last updated 2026-05-23. URLs still pending domain setup (see "Open inputs" at the end).

---

## App name (30 char limit)
**Pictok** (6 chars)

## Subtitle (30 char limit)
**A daily emoji rebus puzzle** (26 chars)

Backups: `Decode an emoji clue daily` · `One emoji puzzle every day`.

(Note: avoid "Wordle" anywhere — Apple has been flagging that trademark on submission.)

## Promotional text (170 char limit, editable post-launch without resubmit)
**Themes update is live: pick Movies, Songs, Books, Brands, Food, TV, or Celebs and play 136+ puzzles your way. New daily emoji rebus every morning at midnight.** (168 chars)

## Description (4000 char limit)

```
Decode the emojis. Solve the puzzle. Come back tomorrow.

Pictok is a daily emoji rebus game. Every morning at midnight, a new picture puzzle drops — two or three emojis that, decoded together, spell out a movie, song, book, brand, food, TV show, or celebrity. You guess one letter at a time. You have five hearts. Get the answer before they run out.

ONE PUZZLE A DAY. BUILD A STREAK.

Pictok is built around the daily ritual. Each day's puzzle is the same one for every player in the world, so you can compare with friends. Solve enough days in a row and your streak grows. Miss a day, and the Archive lets you catch up.

THEMES: PLAY YOUR FAVORITE CATEGORY.

Not in the mood for today's puzzle? Hop into Themes and pick a category — Movies, Songs, Books, Brands, Food, TV Shows, or Celebs — and play through endless puzzles in just that theme. Over 136 puzzles ship at launch, with more arriving regularly.

HINTS WHEN YOU NEED THEM.

Stuck? Trade hearts for a clue. Reveal the category for one heart, or reveal a letter for two. Use both if you really need to — the puzzle stays winnable as long as you have a heart left.

STATS THAT ACTUALLY MEAN SOMETHING.

See your current streak, your longest streak, your guess distribution, and a ten-day calendar showing how you did. No vanity metrics, no leaderboards, no dark patterns.

DESIGNED FOR THE WAY YOU ACTUALLY PLAY.

No accounts. No login. No email. No ads. No in-app purchases. No notifications you didn't ask for. Pictok runs entirely on your device — your stats, your streak, and your solve history live only on your phone and never leave it. Data Not Collected, period.

TRY THE WEB VERSION FIRST.

Pictok also lives on the web at pictok.pages.dev. Same puzzles, same daily rotation, played from any browser. No install required.

WHAT MAKES A GOOD PICTOK PUZZLE?

Some are direct compounds: a heart and a foot equals BAREFOOT. Some are phonetic plays: a number one and a deer reads "won-deer" for WONDER. Some are homophones: a bee and a leaf reads "be-leaf" for BELIEF. The category chip and difficulty stars help you calibrate. The best puzzles surprise you with how obvious they were once you see it.

Three minutes a day. A streak worth keeping. One emoji puzzle, every morning, free forever.
```

(~2,650 chars — well under limit, leaves room for future updates.)

## Keywords (100 char limit, comma-separated, NO spaces)

```
emoji,rebus,puzzle,daily,wordgame,brain,trivia,guess,decode,picturepuzzle,emojigame,wordpuzzle
```

(94 chars. App name `Pictok` and subtitle words ("daily", "emoji", "rebus", "puzzle") are auto-indexed by Apple, but partial-match boosting still helps for compound keywords like `wordpuzzle` vs separate `word puzzle`.)

## Categories
- **Primary:** Games → **Puzzle** (rebus puzzles fit Puzzle better than Word)
- **Secondary:** Games → **Word**

## Age rating
**4+** — no objectionable content, no violence, no UGC, no third-party content. Trivial to clear.

## What's New (Version 1.0)

```
Welcome to Pictok. 136 emoji rebus puzzles to launch with — one new puzzle every morning. Three modes: Today's daily puzzle, Themes for browsing by category, and Archive for catching up on days you missed. Stats track your streak, perfect runs, and last ten days. No ads, no accounts, no tracking.
```

## App Privacy questionnaire (App Store Connect → App Privacy)

**Q: Does your app collect data from this app?** → **No, we do not collect data from this app.**

That single answer ends the entire questionnaire. Apple defines "collect" as transmitting off-device to your servers or third parties. Pictok stores everything via UserDefaults locally and makes zero network calls. Resulting App Store badge: **"Data Not Collected"**.

## Other questionnaire answers
- **Encryption export compliance:** Pre-answered NO via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: "NO"` in `project.yml`. App Store Connect won't prompt.
- **Content rights:** "Does your app contain, show, or access third-party content?" → **No** (all puzzles original).
- **Made for Kids:** **No** (we're 4+ but not in the Kids category — adult-targeted app that happens to be rated 4+).

## Price
**Free** — no IAP, no ads.

---

## URLs needed (still TBD)

| Field | Value | Status |
|-------|-------|--------|
| Marketing URL (optional) | `https://pictok.pages.dev/` | Live now |
| Support URL (required) | `https://pictok.pages.dev/support` | TODO: write `web/support.html` |
| Privacy Policy URL (required) | `https://pictok.pages.dev/privacy` | TODO: write `web/privacy.html` |
| Support contact email (required for privacy page) | `support@pictok.app` | TODO: register pictok.app + set up Cloudflare Email Routing |

All four can collapse to `pictok.app/...` once the domain is set up and pointed at Cloudflare Pages (Pages → Custom Domains → add pictok.app).

---

## Pre-launch checklist (App Store Connect)

- [x] Bundle ID matches the Xcode target (`com.rehatchugh.pictok`)
- [x] App icon uploaded (1024×1024, opaque, no rounded corners — `Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)
- [x] Privacy manifest (`Pictok/PrivacyInfo.xcprivacy`) — declares UserDefaults / CA92.1, no tracking, no data collected
- [x] 5 screenshots ready (`docs/launch/screenshots/01-today-tab.png` … `05-solved-result.png`, 1320×2868)
- [x] App description proofread
- [x] Keywords drafted
- [x] Age rating: 4+
- [x] Price: Free
- [x] Localizations: English (US) only for v1
- [ ] Privacy Policy URL is live and returns 200 (blocked on pictok.app email setup → can ship with placeholder for now, swap in before submission)
- [ ] Support URL is live and returns 200 (same)
- [ ] Apple Developer Program membership active (BLOCKER — user pending purchase)
- [ ] Xcode installed + first archive built locally
- [ ] Build uploaded via Xcode Organizer or `xcrun altool`
- [ ] TestFlight tested by ≥3 humans for ~1 week
- [ ] Submit for review with **manual release** selected

## Suggested launch sequence

1. Submit to App Store Connect with **manual release** selected
2. Wait for "Ready for Sale" notification (typically 24–72h after approval)
3. Tweet/post the App Store link only after the listing is live
4. Day 1: post to r/iOSProgramming (build process angle), r/iosgaming (the game itself), Hacker News if you have a strong narrative
5. Submit to Product Hunt for the following Monday
6. Track installs daily in App Store Connect → Analytics
