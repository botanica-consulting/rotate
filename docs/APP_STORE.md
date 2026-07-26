# App Store submission — Rotate

Everything needed to get Rotate reviewed and onto the App Store. Text fields live as files
under [`fastlane/metadata/`](../fastlane/metadata) and are pushed with `fastlane metadata`;
the items that **no API key can set** are listed at the bottom and must be done once in the
[App Store Connect](https://appstoreconnect.apple.com) UI.

## Identity

| Field | Value |
|---|---|
| App name | **Rotate: Pump & CGM Sites** (`fastlane/metadata/en-US/name.txt`) |
| Subtitle | **Rotate sites, rest your skin** |
| Bundle ID | `consulting.botanica.rotate` |
| App Store app | `6793580813` |
| Primary language | English (U.S.) |
| Primary category | **Health & Fitness** |
| Secondary category | **Medical** |
| Price | Free |
| Copyright | 2026 Alon Livne |

## Listing text (files, pushed by `fastlane metadata`)

| Field | Limit | File |
|---|---|---|
| Name | 30 | `en-US/name.txt` (24) |
| Subtitle | 30 | `en-US/subtitle.txt` (28) |
| Promotional text | 170 | `en-US/promotional_text.txt` (167) |
| Keywords | 100 | `en-US/keywords.txt` (93) |
| Description | 4000 | `en-US/description.txt` |
| What's New | 4000 | `en-US/release_notes.txt` |
| Support URL | — | `https://github.com/botanica-consulting/rotate/issues` |
| Marketing URL | — | `https://github.com/botanica-consulting/rotate` |
| Privacy Policy URL | — | `https://github.com/botanica-consulting/rotate/blob/main/PRIVACY.md` |

## Screenshots

- **Required size:** 6.9" iPhone only (iPhone-only app; App Store scales it to smaller sizes).
- **Set (5):** Overview → Body map → Choose site → History → Areas.
- **Location:** `fastlane/screenshots/en-US/` — regenerate with `fastlane screenshots`.
  Captured with a clean 9:41 status bar over seeded demo data, no third-party brand names.

## App Privacy (nutrition label)

**Data Not Collected.** Rotate has no account, no server, no analytics, and no third-party
SDKs; the journal is stored on-device and mirrored only to the user's own private CloudKit
database. In App Store Connect → App Privacy, choose **"Data Not Collected"**. This matches
[`PRIVACY.md`](../PRIVACY.md).

## Age rating

Answer every content question **None / No** → results in **4+**. Rotate contains no
objectionable content, no unrestricted web access, and does not itself provide medical or
treatment advice (it is a journaling aid, not a source of medical/treatment information).

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already declared in the Info.plist (via
`project.yml`), so there is **no** encryption prompt at submission. The `release` lane also
sends `export_compliance_uses_encryption: false`.

## Review information

- **Sign-in required:** No. The app opens straight to its home screen — no demo account needed
  (`review_information/demo_user.txt` / `demo_password.txt` are intentionally empty).
- **Review notes:** `fastlane/metadata/review_information/notes.txt` (no device/server/account;
  the optional Loop hand-off just opens Loop via URL scheme if installed).
- **Contact info:** intentionally **not** committed (this repo is public). Set the reviewer
  contact name / email / phone once in App Store Connect → App Review Information, or export
  `DELIVER_*` contact vars before running `fastlane release`.

## One-time steps an API key cannot do

These are done once in the App Store Connect website, then persist:

1. **App record** — created (`6793580813`). ✔
2. **CloudKit container** `iCloud.consulting.botanica.rotate` — created & assigned. ✔
3. **App Privacy** → "Data Not Collected" (see above).
4. **Age rating** questionnaire → 4+ (see above).
5. **App Review contact** name / email / phone.

## Ship it

```sh
set -a && source ~/.config/rotate-release.env && set +a
fastlane beta          # build + upload the binary to TestFlight
fastlane screenshots   # (re)generate screenshots
fastlane release       # push metadata + screenshots and submit the latest build for review
```
