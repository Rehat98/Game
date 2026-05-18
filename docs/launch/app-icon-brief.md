# Pictok App Icon — Design Brief

For: designer (Fiverr / 99designs / freelance) **or** AI image generation (Midjourney / DALL-E / Stable Diffusion).

**Output needed:** Single 1024×1024 PNG, opaque background (no transparency, no rounded corners — iOS rounds them automatically), sRGB color space, < 1 MB file size.

---

## The app in one sentence

Pictok is a daily emoji-decode puzzle game for iOS — players see a string of emojis (each representing a word) and guess the hidden answer hangman-style.

## Direction: Abstract geometric, Wordle-style but quieter

The icon does **not** show emojis or characters. It uses **pure geometric shapes** that hint at the gameplay without depicting it literally. The mood is **calm, modern, restrained** — like Notion, Linear, or the NYT Crossword icon. Not flashy, not gradient-heavy, not cartoony.

---

## Concept

A small arrangement of **sticker-paper tiles** suggesting a daily puzzle. Three or four soft, slightly-tilted rounded squares — like little Post-it notes pinned to cream paper. Some are colored (representing solved letters), some are blank (representing unsolved). The composition reads as "a puzzle being filled in" without spelling anything out.

Think: **Wordle's 5-square row, but turned into stickers, in muted earth tones instead of high-contrast neon.**

---

## Composition options for the designer

Any of these three layouts is acceptable. The designer picks based on what reads best at small sizes:

**Option A — 3-tile row, slightly tilted:**
Three rounded squares in a row, each at a slightly different rotation (like stickers casually placed). Two filled with muted color, one outlined/empty. Optional: a single horizontal pencil line underneath the row, suggesting a blank to fill in.

**Option B — 2×2 grid:**
Four rounded squares in a 2×2 grid. Top-left and bottom-right filled with muted color, top-right and bottom-left blank/outlined. Reads as "puzzle in progress."

**Option C — Stacked stickers:**
Three rounded squares stacked at offset angles (like a small pile of paper notes). Top one is muted yellow, middle muted green, bottom muted blue. No text or detail.

---

## Color palette (muted version of brand)

Use these specific hex values. Resist the urge to brighten them.

| Color | Hex | Use |
|---|---|---|
| Paper cream | `#FEF3D9` | Background |
| Ink black | `#1A1A1A` | Outlines (1.5–2pt only) and details |
| Muted yellow | `#E8C547` | Tile fill (was `#FFD60A` in app — toned down ~15%) |
| Muted red | `#C9485D` | Tile fill (was `#E63946` — toned down) |
| Muted green | `#4FB58C` | Tile fill (was `#06D6A0` — toned down) |
| Muted blue | `#3A7894` | Tile fill (was `#118AB2` — toned down) |

**Use only 2–3 of these colors at most.** Pairing yellow + green or yellow + red works well. Avoid using all four.

---

## Mood references

Look at these icons for direction (visually, not literally):

- **NYT Spelling Bee** — single hexagon, restrained color, premium feel
- **NYT Connections** — geometric grid of muted color blocks
- **Wordle (NYT)** — single row of colored squares, white space, no gradients
- **Threes** — playful but minimal, muted palette
- **Notion** — restrained, geometric, mature
- **Linear** — abstract geometric mark, premium feel

**Do NOT look at:** Candy Crush (too busy), Pokemon Go (too character-driven), Headspace (too gradient-heavy), Duolingo (too cartoon-y).

---

## Must-haves

- ✅ Reads instantly at **30×30 pixels** (the smallest size iOS will show it)
- ✅ One clear focal element (no busy backgrounds)
- ✅ Sticker-paper aesthetic — slightly hand-drawn, slight imperfection in lines, **subtle paper texture** if possible
- ✅ Opaque background (cream `#FEF3D9` works as the canvas)
- ✅ Square 1024×1024, no rounded corners (iOS handles rounding)

## Must-avoids

- ❌ Bright gradients (no neon, no rainbow, no Instagram-style fades)
- ❌ Drop shadows softer than 2px (we want hard-edged sticker shadows, not blurry)
- ❌ Realistic 3D rendering, glass effects, glossiness
- ❌ Emoji on the icon (the whole point of "abstract geometric")
- ❌ Letters or text (no "P," no "PICTOK," no wordmark)
- ❌ Photographic textures, wood grain, leather, etc.
- ❌ More than 4 distinct colors total
- ❌ A magnifying glass, lightbulb, question mark, or other "puzzle game cliché" element

---

## Midjourney prompt (if going AI route)

Paste this verbatim into Midjourney v6+:

```
ios app icon, 1024x1024, three rounded sticker squares arranged in a row with slight casual rotation, muted yellow and muted green colors, on a cream paper background, hand-drawn ink outline 2pt black stroke, hard-edged offset paper shadow, minimal, geometric, restrained, paper-craft aesthetic, like a small puzzle being filled in, no text, no letters, no emoji, no characters, no gradients, flat colors only, in the style of NYT Spelling Bee and Linear app icons, premium feel, app store icon --ar 1:1 --style raw --stylize 100
```

**Iteration tips for Midjourney:**
- If too busy → add `, ultra minimal, fewer elements`
- If too sharp → add `, soft watercolor edges`
- If too generic → add `, distinctive composition, memorable silhouette`
- Generate 4 variations, pick the best, then upscale and bring into Figma to clean up any leftover artifacts.

## Fiverr / 99designs brief (if going designer route)

**Project title:** Daily puzzle game iOS app icon — abstract geometric, muted palette

**Description (paste this):**
> I need a 1024×1024 iOS app icon for "Pictok," a daily emoji puzzle game. The visual direction is **abstract geometric, sticker-paper style, muted colors** — restrained and premium, in the spirit of NYT Spelling Bee or Linear, NOT flashy or character-driven.
>
> The composition should suggest a daily puzzle being filled in — e.g., a row or grid of 3–4 small rounded sticker tiles, some filled with color and some blank, casually arranged on cream paper. No emoji, no letters, no characters, no gradients. Hand-drawn ink outlines (2pt black) with hard-edged paper drop shadows.
>
> Palette: cream `#FEF3D9` background; ink `#1A1A1A` outlines; tile fills from muted yellow `#E8C547`, muted green `#4FB58C`, or muted blue `#3A7894`. Use only 2 colors max.
>
> Deliverables:
> - Final 1024×1024 PNG, opaque, no rounded corners (iOS handles rounding)
> - Editable source file (Figma/AI/PSD)
> - 3–5 initial concepts so I can pick a direction before final polish
>
> Timeline: 5 business days. Budget: $150 fixed.

**Designer-side red flags to watch for:**
- Any concept with a magnifying glass, lightbulb, brain, or thinking-face emoji → reject (cliché)
- Any concept with a gradient background → reject (too flashy)
- Any concept featuring letters or wordmark → reject (we said abstract)
- Any concept that looks similar to Candy Crush, Pokemon Go, Duolingo → reject (wrong genre cue)

---

## Once you have the final PNG

1. Save it as `AppIcon-1024.png` in `/Users/rehatchugh/emoji-decode/Pictok/Resources/Assets.xcassets/AppIcon.appiconset/`
2. In Xcode (once installed): open `Assets.xcassets`, drag the PNG into the "App Store" slot of the `AppIcon` set
3. iOS 17+ accepts a single 1024×1024 PNG — no need for 30+ legacy sizes
4. Run the app in the simulator, long-press home → confirm icon shows on the home screen

If the icon ever needs revision after launch, you can ship updates in any future app version. Don't sweat picking the "perfect" icon — pick a *good* icon and iterate from user feedback.
