# InsulinPumpSiteJournal

A small native iOS app that keeps a local journal of Omnipod pump-site placements,
suggests four rotation sites when you start a new Pod (least-recently-used, region-diverse),
saves your choice, and reminds you to continue Pod activation in [Loop](https://github.com/LoopKit/Loop).

This MVP is a polished UI/UX prototype: it has **no** Loop integration, pump communication,
networking, accounts, HealthKit, or CloudKit. Data is stored locally with SwiftData and stays
eligible for your normal encrypted iPhone backup.

> **Not a medical device.** Follow your Omnipod training and the
> [Omnipod placement guide](https://www.omnipod.com/current-podders/resources/pod-placement-guide)
> for approved placement details.

## Requirements

- Xcode 26 (iOS 26 SDK — the UI uses native Liquid Glass APIs)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```sh
xcodegen generate
open InsulinPumpSiteJournal.xcodeproj
```

The `.xcodeproj` and `Info.plist` are generated from `project.yml` and are not committed.

## Build & test (CLI)

```sh
xcodebuild -project InsulinPumpSiteJournal.xcodeproj \
  -scheme InsulinPumpSiteJournal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

xcodebuild ... test -only-testing:InsulinPumpSiteJournalTests
xcodebuild ... test -only-testing:InsulinPumpSiteJournalUITests
```

## TestFlight builds from a browser (no Mac required)

The repo ships the same fastlane + GitHub Actions "browser build" process as
[LoopWorkspace](https://github.com/LoopKit/LoopWorkspace): fork the repo, add
the same 6 Secrets used by the Loop browser build, and run the numbered
workflows under the Actions tab (1. Validate Secrets → 2. Add Identifiers →
4. Build Rotate). See [fastlane/testflight.md](fastlane/testflight.md).

## iCloud sync (prepared, not enabled)

Data is currently local-only (still covered by normal encrypted device backup).
The model is already CloudKit-compatible (no unique constraints, defaulted
properties). To turn sync on:

1. Uncomment the `entitlements:` block in `project.yml`, run `xcodegen generate`.
2. In `InsulinPumpSiteJournalApp.swift`, change `cloudKitDatabase: .none` to
   `.private("iCloud.io.github.0xa10.InsulinPumpSiteJournal")`.
3. Build with a development team that has the iCloud capability; test signed
   into iCloud.

## Structure

- `Models/` — `PlacementRecord` (SwiftData) and the compile-time `PumpSite` catalog (12 sites)
- `Services/SiteSuggestionEngine.swift` — deterministic LRU + region-diversity picker
- `Views/` — history home, new-Pod flow (suggestions → confirm → Loop handoff), body silhouettes
- `Design/AppTheme.swift` — Loop's palette (systemBlue accent, insulin orange for recent history), rounded type
