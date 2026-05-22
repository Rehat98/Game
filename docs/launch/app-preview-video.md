# Pictok App Preview Video — Recording Guide

A 30-second App Store preview video. Apple's data consistently shows preview videos lift conversion 10-25% over screenshots alone. This doc is the operator's checklist — what to record, what state to put the simulator in, and how to assemble.

**Output spec (App Store Connect requirements):**
- Length: 15-30 seconds (we target ~28s)
- Format: .mp4 or .mov (H.264, AAC audio optional)
- Aspect ratio: portrait
- Resolution: 1290×2796 (iPhone 6.7") or 1320×2868 (iPhone 6.9" — what our screenshots already use)
- Max file size: 500MB

## Storyboard — 28 seconds total

| Time | Scene | What's on screen | Caption (optional) |
|------|-------|------------------|---------------------|
| 0:00 – 0:03 | Cold open | App icon (1024×1024) zooms in, transitions to HowToPlay card 1 ("One puzzle a day" with 📌) | **DECODE EMOJIS DAILY** |
| 0:03 – 0:06 | Concept | Swipe through HowToPlay cards 2 & 3 ("Five hearts", "Streak") | **5 HEARTS · 1 HINT · ONE PUZZLE** |
| 0:06 – 0:11 | First puzzle | Land on TOY STORY 🧸📖 with the yellow tutorial banner. Tap T → letter appears. Tap O → letter appears. Tap Y → letter appears. | **TAP LETTERS · BUILD THE TITLE** |
| 0:11 – 0:14 | Wrong guess | Tap Z → heart drops (5→4) with the existing pop animation | **WRONG LETTERS COST HEARTS** |
| 0:14 – 0:18 | Solve | Tap S, then R. Submit ✓ button appears. Tap Submit → fireworks fire | **SOLVE BEFORE MIDNIGHT** |
| 0:18 – 0:22 | First-solve special | "Day 1 streak 🔥 Welcome to Pictok" overlay | **KEEP YOUR STREAK ALIVE** |
| 0:22 – 0:25 | Stats glance | Tap Stats tab. Calendar heatmap with today's cell green. | **TRACK PROGRESS · ARCHIVE PLAYS** |
| 0:25 – 0:28 | Endless tease | Tap Endless tab. New puzzle visible. Quick cut to share card text "I solved today's Pictok! ❤️❤️❤️❤️🖤" | **SHARE WITH FRIENDS** |

End frame (last 0.5s): app icon + "pictok.pages.dev" or App Store badge.

## How to record

### Prereqs
- macOS Sonoma+ with Xcode 26.5
- iPhone 17 Pro Max simulator booted
- Pictok built and installed: `xcodebuild build -project Pictok.xcodeproj -scheme Pictok -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -derivedDataPath ./build/derived && xcrun simctl install booted ./build/derived/Build/Products/Debug-iphonesimulator/Pictok.app`

### Recording

**Option A — One continuous take with QuickTime**

1. Open QuickTime Player → File → New Screen Recording → toggle "Record selected portion" → drag a tight box around just the simulator's iOS screen (exclude the device bezel and the macOS title bar; this gets you 1320×2868-ish at retina).
2. Reset state for a true cold start:
   ```
   xcrun simctl terminate booted com.rehatchugh.pictok
   xcrun simctl uninstall  booted com.rehatchugh.pictok
   xcrun simctl install    booted ./build/derived/Build/Products/Debug-iphonesimulator/Pictok.app
   ```
3. Click Record in QuickTime. Switch to Simulator (Cmd-Tab).
4. Launch: `xcrun simctl launch booted com.rehatchugh.pictok` — HowToPlay card 1 appears.
5. Tap Next twice to walk the carousel, then Start playing. (~3s)
6. Tutorial banner shows. Tap T, O, Y, S, R on the in-game keyboard. (TOY STORY's unique letters.)
7. Tap any wrong letter once (Z) to show the heart drop.
8. Tap S then R (the missing letters). Submit ✓ becomes available — tap it. Fireworks. Day-1 streak overlay. Tap "Let's go".
9. Tap the Stats tab in the tab bar.
10. Tap the Endless tab.
11. Stop QuickTime recording.

**Option B — Per-scene clips assembled in iMovie**

If a single take is too fiddly, capture each scene as its own clip and stitch in iMovie. The debug presets in `PictokApp.swift` make scene setup deterministic:

```bash
# Fresh launch (HowToPlay + ambassador):
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl uninstall booted com.rehatchugh.pictok
xcrun simctl install booted ./build/derived/Build/Products/Debug-iphonesimulator/Pictok.app
xcrun simctl launch booted com.rehatchugh.pictok

# Pre-populated Stats (calendar heatmap, streak 7, 47 lifetime solves):
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl launch    booted com.rehatchugh.pictok --screenshot-state=populated --present-stats

# Endless mode directly:
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl launch    booted com.rehatchugh.pictok --screenshot-state=populated --present-endless

# Mid-solve (one correct, one wrong letter visible):
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl launch    booted com.rehatchugh.pictok --screenshot-state=midSolve
```

Use the macOS Simulator's **Device → Trigger Screenshot** for stills and `simctl io booted recordVideo /tmp/clip.mov` for short captures (Ctrl-C in the terminal stops it).

## Editing

- **iMovie (free, easy):** drop clips on the timeline, add a 0.3s cross-fade between scenes, add lower-third captions. Export at 1080p portrait, 30fps.
- **CapCut / Final Cut Pro:** same flow if you want more control over text styling.
- **No music required** — App Store videos auto-mute on autoplay. Keep audio: solve haptic ticks + win sound (already in the recording).

## Upload

App Store Connect → My Apps → Pictok → App Preview & Screenshots → upload one preview per device size. The 6.9" preview can also serve 6.7" if you only have one — Apple lets a larger preview cover smaller buckets.
