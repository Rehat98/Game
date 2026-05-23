# TestFlight Submission Checklist — Pictok v1

Step-by-step from "build is green on simulator" to "testers tap install on their phones." Last refreshed 2026-05-23.

This document is the **operator's checklist** — what you click, type, and upload. The tester-facing copy lives in [`testflight.md`](./testflight.md); the App Store listing copy lives in [`app-store-listing.md`](./app-store-listing.md).

---

## Phase 1 — Apple Developer + signing

These are one-time per developer + per app. Skip steps you've already done.

### 1.1 Apple Developer Program membership ($99/year)

- [ ] Sign in at https://developer.apple.com → "Account"
- [ ] If no membership: enroll under your Apple ID. Individual or Organization is fine for solo dev.
- [ ] Confirm the membership is "Active" (it expires annually; renew before expiration to keep TestFlight working)

### 1.2 Team ID

- [x] Already set: `DEVELOPMENT_TEAM: "339X8FLFXX"` in both Pictok and PictokTests targets (rehatachugh@gmail.com, fixed on 2026-05-23 — see commit `7fe9dd8`).
- [x] xcodegen regenerated and pbxproj contains the new team id.

If you ever publish under a different team, swap the value in `project.yml` and re-run `xcodegen generate`.

### 1.3 App ID (Bundle Identifier)

- [ ] Developer Portal → Certificates, Identifiers & Profiles → Identifiers → "+" → App IDs
- [ ] Description: `Pictok iOS App`
- [ ] Bundle ID: **Explicit** → `com.rehatchugh.pictok` (must match `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`)
- [ ] Capabilities to enable now: none beyond defaults (no push, no iCloud, no in-app purchase in v1). Local notifications work without any explicit capability.
- [ ] Continue → Register

### 1.4 Signing certificate

Xcode handles this automatically once the team is set. To verify:

- [ ] Open `Pictok.xcodeproj` in Xcode (`open /Users/rehatchugh/emoji-decode/Pictok.xcodeproj`)
- [ ] Click the project root → select the `Pictok` target → "Signing & Capabilities" tab
- [ ] "Automatically manage signing" should be checked, Team should be selected
- [ ] If Xcode says "No matching profiles found" or similar, click "Try Again" — it will create a development provisioning profile

---

## Phase 2 — App Store Connect record

### 2.1 Create the app record

- [ ] Sign in at https://appstoreconnect.apple.com
- [ ] My Apps → "+" → New App
- [ ] Platform: **iOS**
- [ ] Name: **Pictok** (you have 90 days after first reservation to ship something; if "Pictok" is taken, you'll need a fallback — see §"If the name is taken")
- [ ] Primary Language: **English (US)**
- [ ] Bundle ID: pick the `com.rehatchugh.pictok` you just registered
- [ ] SKU: any unique string for your records, e.g., `PICTOK-V1`
- [ ] Click Create

### 2.2 Reserve the name everywhere else (recommended same day)

While you're here, defensively reserve handles:
- [ ] `pictok.app` domain (if not already owned)
- [ ] `@pictokapp` on Twitter/X
- [ ] `r/pictok` on Reddit (optional)
- [ ] `pictok` on Instagram (optional)

### 2.3 If the name is taken

The current spec [§11](../superpowers/specs/2026-05-18-emoji-decode-design.md) flags `Pictok` as phonetically close to TikTok (ByteDance trademark). If App Store Connect rejects the name OR clearance comes back risky, the fallback list to consider:

- Emodle (emoji + Wordle)
- Decoji
- Picplay
- Glyphix
- (Run any final pick through USPTO TESS + App Store name search before reserving)

A rename means: app name in plist (`CFBundleDisplayName`), App Store Connect record, domain, social handles, in-app copy ("Pictok #N" share card text). All find-replaceable from a single source-of-truth string change.

---

## Phase 3 — Build + archive

### 3.1 Bump version + build number (every TestFlight upload)

- [ ] In `project.yml`, the `MARKETING_VERSION` ("1.0.0") rarely changes between TestFlight builds — only bump it for App Store releases.
- [ ] The `CURRENT_PROJECT_VERSION` ("1") MUST be unique per uploaded build. Increment before every archive:

```yaml
MARKETING_VERSION: "1.0.0"
CURRENT_PROJECT_VERSION: "2"   # was 1, bump to 2 for second TestFlight upload
```

- [ ] Regenerate: `xcodegen generate`

### 3.2 Verify the build is shippable

- [ ] Run the full test suite: `xcodebuild test -project Pictok.xcodeproj -scheme Pictok -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -quiet` → all 89 tests pass
- [ ] Run the web tests too: `cd web && npm test` → 64/64 pass
- [ ] Launch on simulator → confirm puzzle loads, Themes picker opens, Archive cell launches the catch-up game, Stats calendar shows colored cells, hint Menu offers both Category and Letter
- [x] `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: "NO"` is already set in `project.yml` line 38
- [x] `PrivacyInfo.xcprivacy` shipped (commit `93d7ff6`) — declares no tracking, no data collected, UserDefaults access with reason CA92.1

### 3.3 Archive

Two options.

**Option A — Xcode UI (simplest first time):**

- [ ] Open `Pictok.xcodeproj` in Xcode
- [ ] Top toolbar → change destination from "iPhone 17 Simulator" to **"Any iOS Device (arm64)"** (this is required for archive; you can't archive against a simulator)
- [ ] Menu: Product → Archive
- [ ] Wait ~30–60 seconds. Xcode Organizer opens automatically when done.
- [ ] In Organizer → select the new archive → "Distribute App" → "App Store Connect" → "Upload"
- [ ] Accept default options through the wizard (automatic signing, strip symbols, manage version/build automatically: NO since we set them manually).
- [ ] Upload — takes 1–5 minutes.

**Option B — Command line:**

```bash
cd /Users/rehatchugh/emoji-decode

# Archive
xcodebuild archive \
  -project Pictok.xcodeproj \
  -scheme Pictok \
  -destination 'generic/platform=iOS' \
  -archivePath build/Pictok.xcarchive \
  -allowProvisioningUpdates

# Export options plist
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF

# Upload
xcodebuild -exportArchive \
  -archivePath build/Pictok.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates
```

### 3.4 Wait for processing

- [ ] In App Store Connect → My Apps → Pictok → TestFlight → iOS builds. The new build appears with status **"Processing"** for ~5–20 minutes.
- [ ] When status flips to **"Ready to Submit"** (yellow icon) or **"Missing Compliance"** (red icon, if `ITSAppUsesNonExemptEncryption` weren't set — but we set it, so you should see green/yellow), you can move on.
- [ ] You'll get an email from Apple either way.

---

## Phase 4 — TestFlight configuration

### 4.1 Build metadata (first upload only)

- [ ] App Store Connect → Pictok → TestFlight → click the new build
- [ ] Fill in **What to Test** — paste the block from [`testflight.md`](./testflight.md) (replace `[YOUR_FEEDBACK_EMAIL]` first)
- [ ] Tester contact email and marketing URL: fill if you have them

### 4.2 Export compliance

- [ ] Build → Manage Encryption section → "Does your app use encryption?" → **No** (Pictok uses no custom encryption; HTTPS via system frameworks is exempt) → save
- [ ] Status should now show "Ready to Submit" or directly skip to internal-test-ready

### 4.3 Internal testing (no review required)

For your own Apple ID + up to 100 internal users.

- [ ] TestFlight → Internal Testing → click + → create a group "Devs" or similar
- [ ] Add yourself as a tester (via the App Store Connect Users and Access page if you're not already there)
- [ ] Attach the build to the group → testers get an email + can install via TestFlight app
- [ ] Self-test on your phone for at least 24 hours before inviting external testers

### 4.4 External testing (Beta App Review required)

For friends, public link, or anyone not on your team's App Store Connect account.

- [ ] TestFlight → External Testing → create a group e.g., "Friends" or "Public Beta"
- [ ] Add the build → click **Submit for Review** (Beta App Review — typically 24 hours, sometimes same-day)
- [ ] Provide a Test Information block: short description, plus a demo account if you had one (you don't — it's local-only)
- [ ] Once approved, invite testers individually OR generate a **public link** (gives you an unlimited URL you can post on Twitter/Reddit)

---

## Phase 5 — Pre-App-Store-submission gates

You don't have to do these before TestFlight, but they're blockers for App Store submission. Knock them out during beta.

- [ ] **Privacy Policy URL**: blocked on `pictok.app` domain + `support@pictok.app` email setup. Once those are live, `web/privacy.html` ships to `pictok.pages.dev/privacy` (or `pictok.app/privacy` if the custom domain is wired). Required field in App Store Connect.
- [ ] **Support URL**: blocked on same email setup. `web/support.html` ships to the same domain at `/support`. Required field.
- [x] **Screenshots** (1320×2868 PNGs, 6.9" iPhone Pro Max, Apple's current preferred size): 5 ready at `docs/launch/screenshots/` — `01-today-tab` / `02-mid-solve` / `03-themes-picker` / `04-stats-tab` / `05-solved-result`. Matching framed marketing versions at `docs/launch/screenshots/framed/`.
- [x] **App preview video** (optional, max 30s, .mov): `docs/launch/preview-video/preview.mp4` (14.4s, 1290×2796, H.264 baseline) — optional upload.
- [ ] **Age rating questionnaire**: 4+ (no questionable content). Fill in App Store Connect → Pictok → App Information → Age Rating.
- [ ] **Pricing**: Free. Pictok → Pricing and Availability → set tier 0.
- [ ] **App Privacy questionnaire**: single answer — "No, we do not collect data from this app." Resulting badge: **Data Not Collected**. (See `app-store-listing.md` § "App Privacy questionnaire".)
- [ ] **Trademark clearance**: USPTO TESS + App Store name search for "Pictok". Flagged in v1 spec — do this before App Store submission, not before TestFlight.

---

## Quick reference — what you need on hand

| Item | Where it lives | Status |
|------|----------------|--------|
| Apple Developer membership | https://developer.apple.com | TODO — real TestFlight blocker |
| Team ID | `project.yml` DEVELOPMENT_TEAM | ✅ 339X8FLFXX |
| Bundle ID `com.rehatchugh.pictok` | Developer Portal → Identifiers | Register once after Dev Program is active |
| App Store Connect record | https://appstoreconnect.apple.com | Create once after Dev Program is active |
| App icon 1024×1024 | `Pictok/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | ✅ Done |
| Privacy manifest | `Pictok/PrivacyInfo.xcprivacy` | ✅ Done |
| Privacy policy URL | `web/privacy.html` → pictok.pages.dev/privacy | Blocked on email setup |
| Support URL | `web/support.html` → pictok.pages.dev/support | Blocked on email setup |
| Screenshots (5) | `docs/launch/screenshots/0[1-5]-*.png` at 1320×2868 | ✅ Done |
| Test notes | `docs/launch/testflight.md` | ✅ Refreshed 2026-05-19 |
| Listing copy | `docs/launch/app-store-listing.md` | ✅ Refreshed 2026-05-23 |

---

## Common failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Upload fails with "No suitable application records were found" | Bundle ID in Xcode doesn't match the one in App Store Connect | Check `PRODUCT_BUNDLE_IDENTIFIER` in project.yml |
| "Missing Compliance" red icon in TestFlight build list | Export compliance wasn't answered OR `ITSAppUsesNonExemptEncryption` is missing from Info.plist | We've set the plist key. If still flagged, manually answer the compliance question in App Store Connect. |
| "No matching provisioning profile" during archive | Team ID wrong, or App ID not registered | Phase 1.2 + 1.3 — verify both. |
| Archive grayed out / "Generic iOS Device" not in destinations | Project still set to a simulator destination | Change scheme run destination to "Any iOS Device (arm64)" |
| `xcodebuild archive` fails with "Cannot allocate memory" or hangs | Simulator runtime taking memory | `xcrun simctl shutdown all` then retry |
| Build version conflict | Already uploaded a build with the same `CURRENT_PROJECT_VERSION` | Bump it (Phase 3.1) |
