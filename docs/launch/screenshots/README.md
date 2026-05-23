# App Store Screenshots

5 PNGs at **1320×2868** (iPhone 17 Pro Max native, matches App Store Connect's current 6.9" iPhone requirement). Upload these to App Store Connect → Pictok → App Store → Screenshots → 6.9" iPhone.

| File | What it shows |
|------|---------------|
| `01-today-tab.png` | Today's Daily puzzle waiting to be played. Emoji clue, 5 hearts, Book category chip, full keyboard, Continue Playing CTA. Hero shot. |
| `02-mid-solve.png` | Word reveal in action — partial answer visible, 4 hearts, correct keys highlighted green, wrong key red. Shows the gameplay loop. |
| `03-themes-picker.png` | Themes picker with all 7 categories — All themes (136 puzzles), Movies, Songs, Books, Brands, Celebs, Food, TV Shows — and per-category counts. |
| `04-stats-tab.png` | Stats screen — current streak (7) + best (12), lifetime (47 solved, 89% win rate), 10-day calendar with color-coded outcomes. |
| `05-solved-result.png` | Result sheet on a solved puzzle. "Solved!" header, answer + subcategory chip, stats grid, spoiler-free share card, Copy + Share. |

All sourced live from the app — no Photoshop, no mockups. Each capture is driven by a `--screenshot-state=<preset>` launch argument that seeds `UserStateStore` with a known state. See `PictokApp.applyScreenshotPresetIfRequested()` (DEBUG-only) for the preset definitions.

## Regenerating these screenshots

```bash
# Boot iPhone 17 Pro Max (1320×2868 native)
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator

# Build for the Pro Max sim
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Pictok.app" \
  -path "*Debug-iphonesimulator*" -type d -not -path "*PlugIns*" | head -1)

# Capture each scene (preset:extra-args:filename)
for spec in "populated::01-today-tab" \
            "midSolve::02-mid-solve" \
            "populated:--present-themes:03-themes-picker" \
            "populated:--present-stats:04-stats-tab" \
            "solvedToday::05-solved-result"; do
  preset=$(echo "$spec" | cut -d: -f1)
  extra=$(echo "$spec" | cut -d: -f2)
  name=$(echo "$spec" | cut -d: -f3)
  xcrun simctl terminate booted com.rehatchugh.pictok 2>/dev/null
  xcrun simctl uninstall booted com.rehatchugh.pictok 2>/dev/null
  xcrun simctl install booted "$APP"
  xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=$preset $extra
  sleep 4
  xcrun simctl io booted screenshot "docs/launch/screenshots/${name}.png"
done
```

`--present-themes` and `--present-stats` are DEBUG launch args that select the corresponding tab on first render (see `RootView.selectedTab`), so `simctl` doesn't need to tap a tab bar.

## Framed marketing versions

`framed/` holds the same 5 screenshots wrapped in a device bezel (drop shadow + rounded corners) for landing-page or social-media use. Regenerate via `python3 scripts/frame-screenshots.py`. These are NOT what you upload to App Store Connect — upload the raw files from this directory.

## Caption / annotation layer

These screenshots are raw, no caption overlay. App Store Connect accepts them as-is. If you want banner-captioned versions later, run them through Fastlane snapshot+frameit, Screenshot Studio, Rotato, or AppLaunchpad.
