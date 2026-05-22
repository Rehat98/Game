# Preview Video Assets

This folder holds the App Store preview-video output and its source frames.

## `preview.mp4`

A 23.5-second cross-faded slideshow ready to upload to App Store Connect (My Apps → Pictok → App Preview & Screenshots).

- 1290×2796, H.264, yuv420p, 30 fps, ~470 kbps, ~1.4 MB
- Matches the iPhone 6.9" device spec exactly (iPhone 16/17 Pro Max bucket)
- File size well under the 500 MB App Store ceiling

## What's in it

| Time | Frame | Captures |
|------|-------|----------|
| 0:00 – 0:02.5 | `00-intro.png` | Pictok logo + tagline "Daily emoji puzzle" |
| 0:02 – 0:06 | `01-howtoplay.png` | First-launch HowToPlay carousel card 1 |
| 0:05.5 – 0:10.5 | `02-tutorial.png` | TOY STORY puzzle with yellow tutorial banner |
| 0:10 – 0:14 | `03-midsolve.png` | Mid-solve state (1 correct letter, 1 wrong, hearts at 4) |
| 0:13.5 – 0:18 | `04-stats.png` | Stats tab with the calendar heatmap (populated state) |
| 0:17.5 – 0:21.5 | `05-endless.png` | Endless tab |
| 0:21 – 0:23.5 | `06-outro.png` | Pictok logo + pictok.pages.dev |

Cross-fade transitions of 0.5 s between every pair.

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

# 4. Re-stitch:
cd docs/launch/preview-video && ffmpeg -y \
  -loop 1 -t 2.5 -i frames/00-intro.png \
  -loop 1 -t 4   -i frames/01-howtoplay.png \
  -loop 1 -t 5   -i frames/02-tutorial.png \
  -loop 1 -t 4   -i frames/03-midsolve.png \
  -loop 1 -t 4.5 -i frames/04-stats.png \
  -loop 1 -t 4   -i frames/05-endless.png \
  -loop 1 -t 2.5 -i frames/06-outro.png \
  -filter_complex "[0]scale=1290:2796:flags=lanczos[s0];[1]scale=1290:2796:flags=lanczos[s1];[2]scale=1290:2796:flags=lanczos[s2];[3]scale=1290:2796:flags=lanczos[s3];[4]scale=1290:2796:flags=lanczos[s4];[5]scale=1290:2796:flags=lanczos[s5];[6]scale=1290:2796:flags=lanczos[s6];[s0][s1]xfade=transition=fade:duration=0.5:offset=2[v01];[v01][s2]xfade=transition=fade:duration=0.5:offset=5.5[v02];[v02][s3]xfade=transition=fade:duration=0.5:offset=10[v03];[v03][s4]xfade=transition=fade:duration=0.5:offset=13.5[v04];[v04][s5]xfade=transition=fade:duration=0.5:offset=17.5[v05];[v05][s6]xfade=transition=fade:duration=0.5:offset=21[vout]" \
  -map "[vout]" -c:v libx264 -pix_fmt yuv420p -r 30 -movflags +faststart preview.mp4
```

## Slideshow vs gameplay video — when to upgrade

This slideshow is the "ship something" version. Apple still accepts it (real apps do this). When you have 30 minutes for an evening, consider recording a real gameplay take with QuickTime per `../app-preview-video.md` — actual finger taps + the win celebration + Day-1 streak overlay will convert better than static frames.
