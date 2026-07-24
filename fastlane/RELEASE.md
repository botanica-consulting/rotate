# Rotate — release runbook

Local, Mac-based release via fastlane + an App Store Connect API key. No match,
no CI, no registered devices.

## Prerequisites (once)

1. Secrets in `~/.config/rotate-release.env` (already used by `beta`):
   ```sh
   export TEAMID=...
   export FASTLANE_ISSUER_ID=...
   export FASTLANE_KEY_ID=...
   export FASTLANE_KEY_PATH=...
   # optional, for external TestFlight:
   export TESTFLIGHT_GROUP="External Testers"   # exact ASC group name
   export BETA_CHANGELOG="What to test this build…"
   ```
2. `xcodegen generate` (the `.xcodeproj` is generated and gitignored).
3. `fastlane register_app` then `fastlane setup_app` (idempotent).
4. **Website-only steps an API key can't do:**
   - Create the App Store Connect **app record** (Apps → +).
   - Create + **deploy the CloudKit container/schema to Production** — see repo issue #3. Without this, sync silently fails for released users.

## Lanes

| Lane | What it does |
|---|---|
| `fastlane beta` | Build + upload to TestFlight. **Internal** by default; if `TESTFLIGHT_GROUP` is set it waits for processing and submits to that **external** group for Beta App Review. |
| `fastlane screenshots` | Capture App Store screenshots (needs one-time wiring — see below). |
| `fastlane release` | Build + upload to the App Store with metadata + screenshots, then submit for review (manual release after approval). |

## Before the first `fastlane release` — fill these in

Metadata lives in `fastlane/metadata/`. Drafted copy is provided; **you must replace**:

- [ ] `en-US/privacy_url.txt` — currently a placeholder (`https://botanica.consulting/rotate/privacy`). **A privacy policy is mandatory**; host a real page and put its URL here. (`support_url.txt` points at the GitHub repo, which is fine for now.)
- [ ] `en-US/description.txt`, `subtitle.txt`, `promotional_text.txt`, `release_notes.txt` — review/adjust the drafted copy.
- [ ] `review_information/notes.txt` — review it (explains "standalone, not a medical device, optional companion handoff, private iCloud, no HealthKit").
- [ ] Screenshots present in `fastlane/screenshots/en-US/` (see below).

Set **in App Store Connect once** (fastlane can't manage these):
- [ ] **App Privacy "nutrition label"** — answer *Data Not Collected* (private CloudKit, no analytics).
- [ ] **Age rating** questionnaire (answer the Medical/Treatment Information question honestly).
- [ ] Primary/secondary **category** (e.g. Medical / Health & Fitness).

Keywords deliberately exclude brand names (Omnipod/Dexcom/Loop) — using others' trademarks as keywords is a common rejection reason.

## Screenshots — one-time wiring

`fastlane screenshots` calls `capture_screenshots` (config in `Snapfile`), but the
UI test needs the fastlane helper first:

1. `fastlane snapshot init` — drops `SnapshotHelper.swift` (add it to the
   `InsulinPumpSiteJournalUITests` target; XcodeGen picks it up automatically).
2. In `ScreenshotWalkUITests`: call `setupSnapshot(app)` before `app.launch()`,
   and replace each `snap("…")` stage with `snapshot("…")`. The existing stage
   names already mark good frames (home, body map, settings, etc.).
3. `fastlane screenshots` → images land in `fastlane/screenshots/en-US/`.

(Until wired, `release` will fail the screenshot step — either wire it or add
screenshots manually in App Store Connect and set `skip_screenshots: true` on the
`release` lane temporarily.)

## Typical flows

```sh
# External TestFlight
TESTFLIGHT_GROUP="External Testers" BETA_CHANGELOG="…" fastlane beta

# App Store
fastlane screenshots        # once wired
fastlane release            # uploads metadata + binary, submits for review
```

## What still isn't automated (portal / manual)

- App Store Connect app-record creation, CloudKit container + **schema deploy** (issue #3).
- App Privacy nutrition label, age rating, categories, legal/tax/banking agreements.
- The privacy-policy **content** (fastlane only submits the URL).
