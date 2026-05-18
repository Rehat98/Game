# TestFlight setup — Pictok v1

Copy/paste ready text for App Store Connect's TestFlight section. Substitute `[YOUR_…]` placeholders before launch.

---

## What to Test (max 4000 chars, shown to testers in the TestFlight app)

```
Thanks for testing Pictok! Here's what to focus on:

📅 DAILY FLOW
Open the app once a day. Solve today's puzzle. Confirm:
- Puzzle is the same on every device for the same date
- You can't replay after solving (you'll see the result screen)
- The countdown to tomorrow updates correctly

❤️ LIVES + HINTS
- Each wrong letter takes a heart (you start with 5)
- The puzzle locks when you run out
- Lives refill 1 per 4 hours (test by leaving the app, returning later)
- Try one hint per puzzle: reveal-category costs 1 heart, reveal-letter costs 2

🔥 STREAKS
- Solve consecutive days — streak should go up by 1 each day
- Skip one day, then solve — streak should still increment (free weekly streak-freeze rescues it)
- Skip two days, then solve — streak should reset to 1

🔔 NOTIFICATIONS
- The app should NOT ask for notification permission on first launch
- After your first solve, you'll see a "want a reminder?" sheet — accept it
- Confirm you get a notification at 9 AM local the next day
- Confirm tapping the notification opens the app to Today

📤 SHARE CARD
- After solving, tap Share — the system share sheet opens
- The shared text should look like:
    Pictok #N 📌
    🎬 Hard
    ❤️❤️❤️🖤🖤 · 🔥 7
    pictok.app
- Try with hint used (💡 should appear)
- Try a failure variant (force fail by guessing wrong letters)

📊 STATS
- Stats tab should show current/longest streak, totals, win %, and a bar chart of guesses-to-solve
- Numbers should update immediately after a solve

🐞 BUGS TO REPORT
Email any bugs to [YOUR_FEEDBACK_EMAIL] with:
- iOS version + iPhone model
- What you did
- What went wrong (screenshot if possible)
- Whether you can reproduce it

Thanks! 🙏
```

---

## Internal tester invite — email template

**Subject:** Help me test Pictok before App Store launch?

**Body:**

```
Hi [NAME],

I'm about to ship Pictok — a daily emoji puzzle game I've been building for iOS. Before it hits the App Store, I want a small group of friends to bash on it for a week.

What you'd do:
- Install TestFlight (free Apple app) if you don't already have it
- Tap the invite link below to install Pictok
- Play the daily puzzle once a day for a week
- Email me anything weird, broken, or annoying

It's a Wordle-style daily game where you decode emoji puzzles into words. Like 🐱🐟 = CATFISH, or 🐝🍃 = BELIEF (bee-leaf → "be-lief"). 60 puzzles in v1, takes a minute or two each.

Invite link: [TESTFLIGHT_PUBLIC_LINK]
(Apple makes you install TestFlight first, then this link puts Pictok in there.)

If you want to nope out, no worries — totally fine to say no. I just want eyes on it before strangers see it.

Thanks 🙏
[YOUR_NAME]
```

---

## External tester pitch (if you want public beta)

For a TestFlight public link, you can post this on Twitter/Reddit:

**Twitter / X:**

```
Building Pictok — a daily emoji puzzle for iOS (Wordle's annoying little cousin).

🐱🐟 = CATFISH
🐝🍃 = BELIEF
🅰️🐝🛣️ = ABBEY ROAD

Looking for 50 beta testers before App Store launch.
Reply or DM if you want in.

[TESTFLIGHT_PUBLIC_LINK]
```

**Reddit (r/TestFlight or r/iosbeta):**

Title: `[iOS 17+] Pictok — daily emoji-decode puzzle game (Wordle-style), beta testers wanted`

Body:

```
Hey r/TestFlight! I'm a solo dev wrapping up v1 of Pictok, a daily emoji puzzle game.

WHAT IT IS
One emoji puzzle a day. Each emoji decodes to a word (literally or as a rebus pun), and you guess the answer hangman-style. Examples:
- 🐱🐟 → CATFISH
- 🐝🍃 → BELIEF (bee-leaf → "be-lief")
- 🪡⚡ → TAYLOR SWIFT (tailor + swift)

There are 60 puzzles in v1 — about 2 months of daily content.

WHAT I NEED FROM YOU
- Play once a day for a week
- Tell me what's confusing, broken, or unfair
- Bonus: rate puzzles on quality (some are clever, some might be obscure)

WHAT IT'S NOT
- No ads, no tracking, no accounts. Local-only.
- No IAP, free forever.

iOS 17+ required.

[TESTFLIGHT_PUBLIC_LINK]
```

---

## Feedback collection

Set up one of these:

**Option A (simplest):** A dedicated email — `[YOUR_FEEDBACK_EMAIL]` — that you actually check.

**Option B (organized):** A free Notion form or Google Form linked from the "What to Test" text. Five fields:
- What you were doing (free text)
- What went wrong (free text)
- iOS version
- iPhone model
- Severity (Blocker / Major / Minor / Nitpick)

**Option C (lazy but effective):** A public Twitter/X account `@pictokapp` or a Discord channel for feedback.

---

## After beta — App Store submission

Once you've got 3–7 days of beta feedback and the blockers are fixed:

1. In App Store Connect → My Apps → Pictok → App Store tab
2. Upload screenshots from `docs/launch/app-store-listing.md` (screenshots plan)
3. Paste description / keywords from `app-store-listing.md`
4. Pick the build that's in TestFlight
5. **Set release type to "Manual"** for your first submission (so you control launch timing)
6. Submit for review — typically 24–72 hours
7. Once approved, you'll get an email; tap "Release this version" when you're ready

After "Ready for Sale" notification:
- Update the `[TESTFLIGHT_PUBLIC_LINK]` placeholders to the actual App Store URL
- Post the launch content (see future launch-content doc — TBD)
- Open the App Store Connect → Analytics tab and watch your installs
