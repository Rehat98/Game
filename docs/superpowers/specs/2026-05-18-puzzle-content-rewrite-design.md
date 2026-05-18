# Pictok v1 — Puzzle Content Rewrite Design

**Date:** 2026-05-18
**Author:** Rehat + Claude
**Status:** Approved, ready to implement
**Supersedes:** Content portions of `puzzles-draft.json` (60 entries authored 2026-05-18, rejected as too easy).

## Background

The first puzzle draft (60 entries in `puzzles-draft.json`) was rejected for failing the difficulty bar. Pattern: ~40% of entries were pure label compounds where each emoji *is* the word in the answer (🤔👩=WONDER WOMAN, 🦁👑=LION KING, 🌧️👨=RAIN MAN). These give the player no decoding work, so the "aha" moment is missing — the puzzle reads instantly.

The parent design spec (`2026-05-18-emoji-decode-design.md`) already removed the Easy tier and stated that each emoji must decode to a word in the answer. This document **narrows that rule** to ban pure label compounds outright and defines a calibrated workflow that prevents another full-batch rejection.

## Authoring rules (the bar)

### Banned

Pure label compounds where each emoji *is* the word, requiring zero decoding work from the player. Detection rule: **if I can read the answer from the emojis without thinking, the puzzle is too easy.**

Banned examples:
- 🤔👩 = WONDER WOMAN (thinking emoji = "wonder")
- 🦁👑 = LION KING (each emoji is the word)
- 🌧️👨 = RAIN MAN

### Allowed — Medium (30 puzzles)

Either light-abstraction compounds *or* light phonetic rebus.

**Light-abstraction compounds:** emoji means a related-but-not-identical word. Player must abstract.

- 🧸📖 = TOY STORY (teddy → "toy", book → "story")
- 🌽🐕 = CORN DOG
- 🌳🏠 = TREEHOUSE

**Light phonetic rebus:** one emoji decodes to a sound, not a meaning.

- 🐝🍃 = BELIEF (bee → "be" + leaf → "lief")
- 👀🍭 = EYE CANDY (eye literal, candy literal — but the *expression* requires interpretation)

### Allowed — Hard (30 puzzles)

Multi-step decoding, longer chains, or phonetic puns that require lateral thinking. **Answer must remain well-known** (Marvel-tier movies, top-100 songs, household brands). Hard difficulty comes from the decode work, never from "I never heard of this answer." This is anti-churn design: failing because you've never heard of the answer is the worst possible daily-game UX.

- A🐝🚶 = ABBEY ROAD (A + bee → "abbey" + walk → "road"; Beatles album)
- 👀⛰️ = EVEREST (eye → "eve" + rest = mountain)
- 💧🚽 = WATERLOO (water + loo, British slang for toilet; ABBA song)
- 🅱️4️⃣ = BEFORE (letter B + number 4 → "B-four" → "before"; multi-step phonetic)

## Content structure

**Count:** 60 puzzles total (matches parent spec — ~2 months daily runway).

**Difficulty split:** 30 Medium + 30 Hard, randomly ordered across days. Spec calls for "no day-of-week pattern."

**Category mix:** 12 puzzles per category, evenly distributed.

| Category | Count | Authoring confidence | Notes |
|----------|-------|----------------------|-------|
| Movie    | 12    | High                 | Largest authoring space. Marvel, Disney, classics. |
| Song     | 12    | High                 | Top-100 universe, decade-spanning. |
| Brand    | 12    | High                 | APPLE, AMAZON, TWITTER/X, etc. — many rebus candidates. |
| Book     | 12    | Medium               | Tight space — most titles are 1-word abstractions. Will flag at sample time if I can't hit 12 quality candidates. |
| Celeb    | 12    | Medium               | Names rarely rebus cleanly. Likely leans on stage names (DRAKE, THE WEEKND). Will flag if I can't hit 12. |

**If Book or Celeb can't hit 12 strong candidates:** flag during Phase A with a count of how many strong candidates I have. User decides between: (a) drop the weak category and rebalance to remaining four (e.g., 15 each), or (b) accept fewer puzzles in that category and overweight Movie/Brand to keep the total at 60. The bar itself never moves.

## Schema

Matches existing `Puzzle.swift` (no model changes):

```json
{
  "id": "puzzle-001",
  "date": "",
  "emoji": "🐝🍃",
  "answer": "BELIEF",
  "category": "Book",
  "subcategory": "Self-help",
  "difficulty": "medium"
}
```

**Field rules:**
- `id`: `puzzle-NNN` (zero-padded to 3 digits), assigned sequentially in author order.
- `date`: empty string `""` until launch-date assignment (Phase D). Populated by script, not by hand.
- `emoji`: 2–4 emojis. Whitespace-free.
- `answer`: UPPERCASE, spaces preserved, no punctuation.
- `category`: one of `Movie | Song | Book | Brand | Celeb` (matches `Category` enum).
- `subcategory`: short string used by the "reveal subcategory" hint. Format: `Genre · Year/decade` if applicable. Never reveals the answer.
- `difficulty`: `medium` or `hard`. **No `easy`** in v1 (already enforced by spec).

## Date assignment

Dates are baked into `puzzles.json` at bundle-build time (no server, no scheduling). Author with `date: ""` placeholders. When user picks a launch date, a one-line script populates `date` sequentially:

```bash
python3 -c "
import json, datetime as dt
start = dt.date.fromisoformat('YYYY-MM-DD')  # user picks
p = json.load(open('puzzles.json'))
for i, x in enumerate(p): x['date'] = (start + dt.timedelta(days=i)).isoformat()
json.dump(p, open('puzzles.json','w'), ensure_ascii=False, indent=2)
"
```

If launch slips, re-run the script with a new start date.

## Authoring workflow (the safety net)

The previous draft was rejected after delivering all 60 at once. The rewrite uses a phased workflow with checkpoints.

### Phase A — Calibration sample (~10 puzzles)

- Author 10 puzzles spanning all 5 categories and both difficulties (2 per category, 1 Medium + 1 Hard each).
- Deliver as a markdown table for inline review.
- User accepts / rejects / requests fixes per row.
- Iterate until the bar is locked. **Goal: zero rejections in the next batch.**
- Flag any structural concerns (e.g., "Book is harder than I thought, I can only produce 8 quality candidates") here.

### Phase B — Per-category batches (~12 at a time)

- Author each category as one focused batch.
- Deliver each batch for review before moving to the next.
- Catches drift early.
- Order: lead with the highest-confidence categories (Brand, Movie, Song) to build approval momentum; Book and Celeb last so any per-category fallbacks decided in Phase A are already in place.

### Phase C — Final assembly

- Merge approved batches into `puzzles.json` (60 entries, `date: ""`).
- Mechanical checks:
  - No duplicate `emoji` patterns
  - No duplicate `answer` strings
  - Schema parses against `Puzzle` model (run `PuzzleDecodingTests.test_decodesAllPuzzlesFromFixture` pointed at the new file, or write a one-shot script that decodes and reports)
  - Difficulty distribution: 30 Medium + 30 Hard exactly
  - Category distribution: 12 each (or the negotiated fallback from Phase A)
- Commit.

### Phase D — Date assignment & bundle wiring

- User picks day-1 launch date.
- Run the date-assignment script.
- Move file to `Pictok/Resources/puzzles.json`.
- Run `xcodegen generate` (auto-picks up the new resource).
- `xcodebuild build` then relaunch in simulator.
- Confirm the Today view renders the day-1 puzzle (not the "Failed to load" fallback we currently see).

## Success criteria

- 60 puzzles in `puzzles.json`, all passing the "can't read it instantly" test.
- 30 Medium + 30 Hard.
- 12 per category, or a documented Phase-A fallback distribution.
- Schema decodes via `PuzzleDecodingTests`.
- App launches in simulator and renders a real puzzle on the Today view.
- Zero post-bundle rewrites needed (the per-batch review catches everything).

## Out of scope

- Backend-loaded puzzles (post-v1).
- Daily-puzzle rotation past day 60 (post-v1, requires either content drop #2 or a server).
- Difficulty curve over time (puzzles are randomly ordered per spec; no day-1-easier ramp).
- Localization (English only in v1).

## Open questions

None — all design decisions resolved in the brainstorming session.
