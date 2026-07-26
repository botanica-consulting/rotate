# Contributing to Rotate

Thanks for taking an interest. Rotate is a small, focused iOS app; the bar for changes is
that they keep it **calm, private, and clearly not a medical device**.

## Setup

```sh
brew install xcodegen
git clone https://github.com/botanica-consulting/rotate && cd rotate
xcodegen generate
open InsulinPumpSiteJournal.xcodeproj
```

The `.xcodeproj` and `InsulinPumpSiteJournal/Info.plist` are generated from
[`project.yml`](project.yml) and are **not** committed. **Re-run `xcodegen generate` whenever
you add or remove a `.swift` file** (edits to existing files, and asset-catalog changes, don't
need it).

## Build & test

```sh
DEST='platform=iOS Simulator,name=iPhone 17 Pro'

xcodebuild -project InsulinPumpSiteJournal.xcodeproj -scheme InsulinPumpSiteJournal \
  -destination "$DEST" build

# Full default plan (unit + UI). The visual-QA walks are excluded from it on purpose.
xcodebuild -project InsulinPumpSiteJournal.xcodeproj -scheme InsulinPumpSiteJournal \
  -destination "$DEST" test

# Just the unit suite:
xcodebuild ... test -only-testing:InsulinPumpSiteJournalTests
```

### Launch arguments (DEBUG)

The app reads a few arguments to make UI tests and visual QA deterministic:

| Argument | Effect |
|---|---|
| `--uitest-reset` | In-memory store; skips first-launch onboarding |
| `--uitest-seed` | Seeds a demo journal so every surface looks lived-in |
| `--uitest-onboarding` | Forces the first-launch setup wizard |

### Visual QA & screenshots

- `ScreenshotWalkUITests` (the `VisualWalk` scheme) walks every major surface for review.
- `AppStoreScreenshotsUITests` (the `Screenshots` scheme) drives fastlane `snapshot`.

Both are kept **out** of the default test plan so ordinary runs stay fast.

## Conventions

- **Swift 6, `MainActor` by default.** The app target sets
  `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`; keep off-main work explicit.
- **No new product/brand names in user-facing copy.** Rotate stays device-agnostic in the UI.
- **No medical claims, ever.** No glucose, no dosing, no site-health diagnosis — those are out
  of scope by design (see the disclaimer in the [README](README.md)).
- **Match the surrounding code** — comment density, naming, and idiom.

## Releasing (maintainers)

Local fastlane flow — see [`fastlane/Fastfile`](fastlane/Fastfile). Credentials live in
`~/.config/rotate-release.env` and are never committed.

```sh
set -a && source ~/.config/rotate-release.env && set +a
fastlane beta          # build + TestFlight upload (bumps the build number only)
fastlane screenshots   # regenerate App Store screenshots
fastlane metadata      # push listing text + screenshots (no binary)
fastlane release       # metadata + screenshots + submit for review
```

Hold `MARKETING_VERSION` steady and let `fastlane beta` bump only the datecode build number
for quick test spins; changing the version string forces a fresh Beta App Review.

## Pull requests

- Keep PRs small and focused; describe the user-visible change.
- Run the default test plan before opening a PR.
- By contributing, you agree your work is licensed under the [MIT License](LICENSE).
