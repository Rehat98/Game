# App Store Screenshots

5 PNGs at **1320×2868** (iPhone 17 Pro Max native, satisfies App Store's 6.9" iPhone requirement). Upload these to App Store Connect → Pictok → App Store → Screenshots → 6.9" iPhone.

| File | What it shows | Suggested caption |
|------|---------------|-------------------|
| `01-today-tab.png` | Today's Daily puzzle (I ROBOT, 5 hearts, Continue Playing button) | "Decode the daily emoji puzzle." |
| `02-stats-tab.png` | Stats with realistic player data (streak 7, lifetime 47, win rate 89%, full distribution chart) | "Build your streak. Keep it alive." |
| `03-mid-solve.png` | Word-by-word reveal in action — TOY solved, STORY pending, 4 hearts, wrong-letter shake | "One word at a time." |
| `04-solved-daily.png` | Result sheet with share card preview, 🔥 8 streak, "Movie · Will Smith sci-fi" subcategory | "Share spoiler-free. Brag responsibly." |
| `05-continue-playing.png` | Endless mode mid-puzzle (WILL SMITH, hint button visible) | "Hooked? Keep playing in Endless." |

All sourced from the live app — no Photoshop, no marketing mockups. Each capture was driven by a `--screenshot-state=<preset>` launch argument that seeds the app's `UserStateStore` with a known state. See `PictokApp.applyScreenshotPresetIfRequested()` (DEBUG-only) for the preset definitions.

## Regenerating these screenshots

```bash
# Boot iPhone 17 Pro Max (1320×2868 native)
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator

# Build for the Pro Max sim
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -quiet
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Pictok.app" -path "*Debug-iphonesimulator*" -type d | head -1)

# Capture each preset
for preset in populated midSolve solvedToday; do
    xcrun simctl terminate booted com.rehatchugh.pictok 2>/dev/null
    xcrun simctl uninstall booted com.rehatchugh.pictok 2>/dev/null
    xcrun simctl install booted "$APP"
    xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=$preset
    sleep 3
    xcrun simctl io booted screenshot "/tmp/pictok-$preset.png"
done

# Endless mode (different flag)
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl uninstall booted com.rehatchugh.pictok
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=populated --present-endless
sleep 3
xcrun simctl io booted screenshot /tmp/pictok-endless.png
```

For the Stats tab, temporarily change `TabView { ... }` to `TabView(selection: .constant(1)) { ... }` with `.tag(0)` / `.tag(1)` on the two tabs (`simctl` cannot navigate tabs).

## Caption / annotation layer

These screenshots are raw, no caption overlay. For App Store you can either upload them as-is (Apple shows them clean), or run them through a screenshot generator (Fastlane snapshot + frameit, Screenshot Studio, Rotato, AppLaunchpad, etc.) to add device frames + caption text.
