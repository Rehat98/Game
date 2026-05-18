# Sound effects sourcing — Pictok v1

Pictok needs **3 short WAV files** (< 1 second each), royalty-free, no attribution required ideally.

| File | When it plays | Target vibe |
|------|---------------|-------------|
| `correct.wav` | Player guesses a correct letter | Soft, friendly pop or "ding" — not euphoric, just a happy little tick |
| `wrong.wav` | Player guesses a wrong letter | Gentle thud or low "nope" — never harsh, never punishing |
| `win.wav` | Player solves the puzzle | Quick triumphant flourish — a 3-note rising motif or a single sparkly chime |

## Recommended sources (free, CC0 or royalty-free)

### Mixkit — Game sound effects
**https://mixkit.co/free-sound-effects/game/**

- License: free for personal AND commercial use, no attribution required
- Format: ready WAVs and MP3s
- Curation: hand-curated, very App Store friendly
- Search terms to try: "pop", "click", "bubble", "win", "fail", "ding", "chime"
- **Best fit for Pictok**: their "game" and "kids" categories match the sticker/cute aesthetic

### Freesound.org (CC0 filter)
**https://freesound.org/search/?f=license:%22Creative+Commons+0%22**

- Massive library, user-uploaded
- Filter to CC0 only — those are public domain, zero attribution required
- Search terms: "pop", "ui click", "success ding", "fail buzz", "game win"
- Caveat: quality is variable — listen before downloading

### Pixabay — Sound effects
**https://pixabay.com/sound-effects/**

- Free for commercial use, no attribution required
- Higher production quality than Freesound on average
- Good for "win" type effects

### Zapsplat (free tier)
**https://www.zapsplat.com**

- Requires a free account, allows commercial use with the free tier (with attribution)
- Decent UI sound library
- The attribution requirement makes it slightly less convenient than Mixkit/Pixabay

## My specific suggestions to audition

When you visit the sites, search for these queries in order — the first decent match is usually fine:

**For `correct.wav`:**
- "pop" or "soft pop"
- "ui select"
- "tick"
- Listen for: something under 200ms, no reverb, single transient

**For `wrong.wav`:**
- "wrong"
- "buzz" (the soft kind)
- "low pop"
- Listen for: something under 300ms, descending pitch feels right

**For `win.wav`:**
- "win short"
- "game success"
- "level complete short"
- Listen for: 400–800ms max, rising/major-key, no triumphant fanfare (too much for a small puzzle)

## Format/conversion checklist

The plan's `SoundService.swift` expects **WAV files** in `Pictok/Resources/Sounds/`. If you download MP3s, convert to WAV with Audacity:

1. Open the MP3 in Audacity
2. **File → Export → Export as WAV**
3. Format: WAV signed 16-bit PCM
4. Sample rate: 44100 Hz
5. Channels: Mono is fine (saves bundle size)
6. Trim leading/trailing silence (Effect → Truncate Silence)
7. Normalize to -1.0 dB peak (Effect → Normalize)

Bundle each file under 30 KB if possible.

## What to do once you have the 3 files

1. Drop them into `Pictok/Resources/Sounds/` with the exact filenames:
   - `correct.wav`
   - `wrong.wav`
   - `win.wav`
2. In Xcode (once installed): drag the Sounds folder into the Resources group, check the Pictok target in the dialog
3. They'll automatically be available to `SoundService.shared.play(.correct)` etc.

If a file is missing at runtime, `SoundService` silently no-ops (no crash). So you can ship without sounds and add them in v1.0.1 if you run out of time.
