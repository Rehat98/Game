# Pictok App Icon — Design Brief (Locked direction)

For: designer (Fiverr / 99designs / freelance) **or** AI image generation (Midjourney / DALL-E / Stable Diffusion).

**Output needed:** Single 1024×1024 PNG, opaque background (no transparency, no rounded corners — iOS rounds them automatically), sRGB color space, < 1 MB file size.

---

## Locked direction (2026-05-18)

**Composition:** Two-row Wordle-style grid (3 columns × 2 rows) — total 6 sticker tiles forming a Wordle-mini-board. The grid spells the app name partially: top row filled with letters `P`, `I`, `C`; bottom row has `T` then two blank tiles.

**Palette:** Cream paper background + four brand colors (one color per filled tile).

**Why this works:** Reads instantly as a "daily word puzzle" in the Wordle/Connections genre. Multi-color tiles add playfulness without flashiness. The in-progress bottom row hints at "today's puzzle still being solved." The icon is self-referential — it spells `PICTOK` as the puzzle being decoded.

---

## Exact layout (use this as a Figma spec)

```
1024 × 1024 canvas
Cream paper background:   #FEF3D9 (full bleed)

Grid: centered on canvas
  3 columns × 2 rows
  Tile size: 180 × 180 pt each
  Tile gap (horizontal & vertical): 50 pt
  Total grid: 640 × 410 pt, centered at (512, 512)

Tiles (left-to-right, top-to-bottom):
  Top row (all filled):
    1. P  — fill #C9485D (muted red),    letter color #FEF3D9
    2. I  — fill #E8C547 (muted yellow), letter color #1A1A1A
    3. C  — fill #4FB58C (muted green),  letter color #FEF3D9
  Bottom row:
    4. T  — fill #3A7894 (muted blue),   letter color #FEF3D9
    5. (blank) — fill #FEF3D9 (cream),    no letter
    6. (blank) — fill #FEF3D9 (cream),    no letter

Tile borders:
  Stroke: #1A1A1A, 10 pt
  Border-radius: 28 pt

Drop shadow on every tile:
  Color: #1A1A1A (solid, no transparency)
  Offset: x=0, y=8 pt
  Blur: 0 pt (hard-edged sticker shadow)

Letters inside filled tiles:
  Font: bold rounded sans-serif (Rubik Black, or system-ui font-weight 900)
  Size: 120 pt, centered both axes
  Optical centering: letter visual center matches tile center
```

## Color palette (exact hex codes)

| Use | Hex | Notes |
|---|---|---|
| Background (canvas + blank tiles) | `#FEF3D9` | Cream paper |
| Letters on dark tiles | `#FEF3D9` | Same cream for legibility |
| Letter on yellow tile (I) | `#1A1A1A` | Ink black for contrast |
| Tile P fill | `#C9485D` | Muted red |
| Tile I fill | `#E8C547` | Muted yellow |
| Tile C fill | `#4FB58C` | Muted green |
| Tile T fill | `#3A7894` | Muted blue |
| All borders + shadows | `#1A1A1A` | Solid ink black |

---

## Mood references (good — look like this)

- **NYT Connections** — colored grid of tiles, playful but mature
- **Wordle (NYT)** — single row of colored squares, white space, no gradients
- **NYT Spelling Bee** — restrained color, premium feel
- **Threes** — playful with muted palette
- **Linear** — abstract geometric mark

## Must-avoids

- ❌ Bright neon or saturated gradients
- ❌ Drop shadows softer than 0px (we want hard-edged sticker shadows specifically)
- ❌ Realistic 3D rendering, glass effects, glossiness
- ❌ Emoji on the icon (the composition uses letters only)
- ❌ Wordmark text outside the grid (no "PICTOK" written below or around)
- ❌ Photographic textures, wood grain, leather
- ❌ A magnifying glass, lightbulb, question mark, or other "puzzle game cliché" element

## Must-haves

- ✅ Reads instantly at **30×30 pixels** (the smallest size iOS will show it)
- ✅ Each tile is recognizably a sticker (border + offset hard shadow)
- ✅ Letters are bold rounded sans-serif, optically centered
- ✅ Opaque background (cream `#FEF3D9` covers the full canvas)
- ✅ Square 1024×1024, no rounded corners (iOS handles rounding)
- ✅ Slight (1–2°) rotation on each tile is acceptable and adds warmth — make sure each tile is rotated slightly differently so they read as hand-placed stickers, not a perfect grid. The rotation should be subtle, not Comic-Sans-y.

---

## Midjourney prompt (locked palette)

Paste this verbatim into Midjourney v6+:

```
ios app icon, 1024x1024, six rounded sticker tiles arranged in a 3-column 2-row grid, top row tiles colored muted red muted yellow muted green with letters P I C in white, bottom row left tile muted blue with letter T in white plus two blank cream tiles, on a cream paper background #FEF3D9, hand-drawn ink outline 10pt black stroke, hard-edged offset paper shadow, minimal, geometric, restrained, Wordle visual genre, in the style of NYT Connections and Spelling Bee, no text outside the grid, no gradients, flat colors, premium feel, app store icon --ar 1:1 --style raw --stylize 100
```

**Iteration tips for Midjourney:**
- If letters wrong → add `letters P I C T spelled correctly in tiles`
- If too perfect → add `slight casual rotation on each tile, hand-placed`
- If too cartoony → add `restrained, premium, NYT-style`
- Generate 4 variations, pick the best, then upscale and bring into Figma to clean up any leftover artifacts (especially the letterforms — AI often gets text slightly wrong).

## Fiverr / 99designs brief (locked palette)

**Project title:** Daily word puzzle iOS app icon — Wordle-style mini grid, multi-color tiles

**Description (paste this):**
> I need a 1024×1024 iOS app icon for "Pictok," a daily emoji puzzle game. The visual direction is locked: **a 3×2 grid of sticker tiles** in a Wordle / NYT Connections style. The grid partially spells the app name PICTOK as a puzzle being solved.
>
> **Exact specs:**
> - Background: cream paper `#FEF3D9` (full bleed)
> - 6 tiles in a 3-column 2-row grid, centered on canvas
> - Top row tiles: red `#C9485D` with letter "P", yellow `#E8C547` with letter "I", green `#4FB58C` with letter "C"
> - Bottom row tiles: blue `#3A7894` with letter "T", then two empty cream tiles
> - Tile size 180×180pt with 50pt gaps
> - Each tile has a 10pt black `#1A1A1A` border and a hard-edged drop shadow (offset y=8pt, blur=0)
> - Letters are bold rounded sans-serif (Rubik Black, 120pt), `#FEF3D9` on dark tiles and `#1A1A1A` on the yellow
> - Each tile rotated slightly differently (±2°) so it reads as hand-placed stickers
>
> Mood references: NYT Connections, NYT Spelling Bee, Wordle. NOT Candy Crush, NOT Duolingo, NOT gradient-heavy.
>
> Deliverables:
> - Final 1024×1024 PNG, opaque, no rounded corners (iOS handles rounding)
> - Editable Figma/AI/PSD source
> - 2–3 initial concepts so I can pick a direction before final polish
>
> Timeline: 5 business days. Budget: $150 fixed.

**Designer-side red flags to watch for:**
- Any concept with rounded blurry shadows → reject (we want hard-edged paper shadows)
- Any concept with letters smaller than the spec → reject (legibility matters at thumbnail size)
- Any concept with gradient backgrounds → reject (cream flat only)
- Any concept where the tiles look 3D or glossy → reject (we want flat sticker aesthetic)

---

## Once you have the final PNG

1. Save it as `AppIcon-1024.png` in `/Users/rehatchugh/emoji-decode/Pictok/Resources/Assets.xcassets/AppIcon.appiconset/`
2. In Xcode (once installed): open `Assets.xcassets`, drag the PNG into the "App Store" slot of the `AppIcon` set
3. iOS 17+ accepts a single 1024×1024 PNG — no need for 30+ legacy sizes
4. Run the app in the simulator, long-press home → confirm icon shows on the home screen

If the icon ever needs revision after launch, you can ship updates in any future app version.

---

## Status

- ✅ Direction locked (2026-05-18)
- ✅ Composition locked: Y (3×2 Wordle grid)
- ✅ Palette locked: 5 (cream + multi-color)
- ✅ Final 1024×1024 PNG produced (rendered from `icon-source.svg`, 61 KB, sRGB, opaque, no rounded corners) — at `Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- ✅ Added to Xcode Assets.xcassets and bundled in the app (`AppIcon60x60@2x.png` = 120×120 iPhone home, plus iPad sizes, compiled into `Assets.car`)
- ✅ Verified rendering on iPhone 17 / iOS 26.5 simulator home screen (2026-05-19) — icon reads as the 3×2 Wordle grid at thumbnail size

**Future polish (post-launch, not required to ship):** if user feedback says the cream-on-cream blank tiles disappear against light home-screen wallpapers, consider darkening the blank tiles to `#F0E5C5` (slightly off-cream) for a touch more contrast.
