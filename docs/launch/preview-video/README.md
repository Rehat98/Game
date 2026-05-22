# Preview Video Assets

This folder holds the App Store preview-video output and its source frames.

## `preview.mp4`

A 14.4-second cross-faded slideshow ready to upload to App Store Connect (My Apps → Pictok → App Preview & Screenshots).

- 1290×2796, H.264, yuv420p, 30 fps, ~590 kbps, ~1.0 MB
- Matches the iPhone 6.9" device spec exactly (iPhone 16/17 Pro Max bucket)
- File size well under the 500 MB App Store ceiling

## What's in it

| Frame | Duration | Captures |
|-------|----------|----------|
| `00-intro.png`     | 1.5 s | Pictok logo + tagline "Daily emoji puzzle" |
| `01-howtoplay.png` | 2.0 s | First-launch HowToPlay carousel card 1 |
| `02-tutorial.png`  | 2.5 s | TOY STORY puzzle with yellow tutorial banner |
| `03-midsolve.png`  | 2.5 s | Today's puzzle mid-solve — 3 distinct letters revealed + 1 wrong guess + hearts at 4 |
| `03b-nearsubmit.png` | 2.5 s | All letters of today's puzzle revealed — Submit ✓ sticker mid-screen |
| `04-stats.png`     | 2.0 s | Stats tab with the calendar heatmap (populated state) |
| `05-endless.png`   | 2.0 s | Endless tab |
| `06-outro.png`     | 1.5 s | Pictok logo + pictok.pages.dev |

Cross-fade transitions of 0.3 s between every pair.

## Regenerating

If you tweak the app or want different scenes, re-capture frames and re-stitch:

```bash
# 1. Build + install latest
cd /Users/rehatchugh/emoji-decode
xcodebuild build -project Pictok.xcodeproj -scheme Pictok \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath ./build/derived
xcrun simctl terminate booted com.rehatchugh.pictok
xcrun simctl uninstall booted com.rehatchugh.pictok
xcrun simctl install booted ./build/derived/Build/Products/Debug-iphonesimulator/Pictok.app

# 2. Recapture frames (see frame list above for the launch flags each one used)
xcrun simctl launch booted com.rehatchugh.pictok                                                   # 01
xcrun simctl spawn  booted defaults write com.rehatchugh.pictok pictok.hasSeenHowToPlay -bool true # skip HowToPlay
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok  # 02
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=midSolve  # 03
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=populated --present-stats  # 04
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=populated --present-endless  # 05
# screenshot each with: xcrun simctl io booted screenshot frames/0N-name.png

# 3. Regenerate intro/outro cards (Pillow):
python3 docs/launch/preview-video/make_cards.py   # script is below

# 4. Re-stitch (8 frames, 14.4 s output):
cd docs/launch/preview-video && ffmpeg -y \
  -loop 1 -t 1.5 -i frames/00-intro.png \
  -loop 1 -t 2   -i frames/01-howtoplay.png \
  -loop 1 -t 2.5 -i frames/02-tutorial.png \
  -loop 1 -t 2.5 -i frames/03-midsolve.png \
  -loop 1 -t 2.5 -i frames/03b-nearsubmit.png \
  -loop 1 -t 2   -i frames/04-stats.png \
  -loop 1 -t 2   -i frames/05-endless.png \
  -loop 1 -t 1.5 -i frames/06-outro.png \
  -filter_complex "[0]scale=1290:2796:flags=lanczos[s0];[1]scale=1290:2796:flags=lanczos[s1];[2]scale=1290:2796:flags=lanczos[s2];[3]scale=1290:2796:flags=lanczos[s3];[4]scale=1290:2796:flags=lanczos[s4];[5]scale=1290:2796:flags=lanczos[s5];[6]scale=1290:2796:flags=lanczos[s6];[7]scale=1290:2796:flags=lanczos[s7];[s0][s1]xfade=transition=fade:duration=0.3:offset=1.2[v01];[v01][s2]xfade=transition=fade:duration=0.3:offset=2.9[v02];[v02][s3]xfade=transition=fade:duration=0.3:offset=5.1[v03];[v03][s4]xfade=transition=fade:duration=0.3:offset=7.3[v04];[v04][s5]xfade=transition=fade:duration=0.3:offset=9.5[v05];[v05][s6]xfade=transition=fade:duration=0.3:offset=11.2[v06];[v06][s7]xfade=transition=fade:duration=0.3:offset=12.9[vout]" \
  -map "[vout]" -c:v libx264 -pix_fmt yuv420p -r 30 -movflags +faststart preview.mp4
```

Capture commands for the new mid-solve frames:

```bash
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=midSolve     # 03
xcrun simctl terminate booted com.rehatchugh.pictok && xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=nearSubmit   # 03b
```

## Slideshow vs gameplay video — when to upgrade

This slideshow is the "ship something" version. Apple still accepts it (real apps do this). When you have 30 minutes for an evening, consider recording a real gameplay take with QuickTime per `../app-preview-video.md` — actual finger taps + the win celebration + Day-1 streak overlay will convert better than static frames.
